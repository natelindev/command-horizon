extends RefCounted

## Runs only on detached values. The main thread owns Nodes, files and ENet.
const Frame = preload("res://source/match/network/AuthoritativeFrame.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
const Digest = preload("res://source/match/network/ReplicaDigest.gd")
const Replay = preload("res://source/match/network/ReplayFile.gd")
var result = {}
var validator = Frame.new()
var values = Values.new()
var codec = Protocol.new()


func _init():
	validator.prepare_validation()


func prepare(job: Dictionary):
	var encoded = values.encode(job.snapshot)
	if not values.error.is_empty():
		result = {"error": values.error}
		return
	var snapshot = values.decode(encoded)
	if not validator.validate(snapshot, job.definitions):
		result = {"error": validator.error}
		return
	var packet = {
		"type": "frame",
		"tick": job.tick,
		"base": job.base,
		"full": true,
		"state": encoded,
		"hash": Frame.hash_state(snapshot, values),
		"view_hash": Digest.expected(snapshot),
		"paused": job.paused,
		"pause_epoch": job.get("pause_epoch", 0),
		"finished": job.finished,
		"result": job.outcome
	}
	var full_bytes = codec.encode(packet)
	if full_bytes.is_empty():
		result = {"error": codec.error}
		return
	if not job.full:
		packet = packet.duplicate()
		packet.full = false
		packet.state = values.encode(Frame.delta(job.previous, snapshot))
	var bytes = full_bytes if job.full else codec.encode(packet)
	if bytes.is_empty():
		result = {"error": codec.error}
		return
	result = {
		"snapshot": snapshot,
		"tick": job.tick,
		"hash": packet.hash,
		"bytes": bytes,
		"full_bytes": full_bytes,
		"record": Replay.prepare_record(bytes),
		"finished": job.finished,
		"full": job.full
	}
