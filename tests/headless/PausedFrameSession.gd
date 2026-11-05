extends "res://source/match/network/NetworkSession.gd"


## Hold back running updates after bootstrap, like a slow replica whose queued
## deltas are discarded. Pausing must publish a fresh authoritative frame even
## though the ordinary physics publication loop has stopped.
func _receive(sender: int, bytes: PackedByteArray):
	var packet = Protocol.new().decode(bytes)
	if (
		packet is Dictionary
		and packet.get("type") == "frame"
		and packet.get("tick", 0) > 0
		and not packet.get("paused", false)
	):
		return
	super._receive(sender, bytes)
