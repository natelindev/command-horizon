# gdlint: disable=max-returns
extends RefCounted

## Bounded packet decoding and strict frame validation on detached values.
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
const Frame = preload("res://source/match/network/AuthoritativeFrame.gd")
var result = {}
var validator = Frame.new()
var codec = Protocol.new()
var values = Values.new()


func _init():
	validator.prepare_validation()


func decode(job: Dictionary):
	var packet = codec.decode(job.bytes)
	if not packet is Dictionary or not packet.get("type") is String:
		result = {"error": codec.error}
		return
	if packet.type != "frame":
		result = {"packet": packet}
		return
	if (
		packet.keys().size() != 11
		or not packet.get("tick") is int
		or packet.tick < job.tick
		or not packet.get("base") is int
		or not packet.get("full") is bool
		or not packet.get("paused") is bool
		or not packet.get("pause_epoch") is int
		or packet.pause_epoch < 0
		or not packet.get("finished") is bool
		or not packet.get("result") is String
		or packet.result not in ["", "Victory", "Defeat", "Draw"]
		or not packet.get("view_hash") is String
		or packet.view_hash.length() != 64
		or not packet.get("hash") is String
		or packet.hash.length() != 64
	):
		result = {"error": "Invalid authoritative frame."}
		return
	if not packet.full and (job.previous.is_empty() or packet.base != job.tick or job.needs_full):
		result = {"resync": true}
		return
	var data = values.decode(packet.state)
	if not values.error.is_empty() or not data is Dictionary:
		result = {"error": "Invalid state values."}
		return
	if not packet.full and not Frame.valid_delta(data):
		result = {"error": "Invalid state delta."}
		return
	var snapshot = data if packet.full else Frame.apply_delta(job.previous, data)
	if (
		not validator.validate(snapshot, job.definitions)
		or Frame.hash_state(snapshot, values) != packet.hash
	):
		result = {"error": "State checksum mismatch: " + validator.error, "resync": true}
		return
	result = {"packet": packet, "snapshot": snapshot}
