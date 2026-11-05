extends "res://source/match/network/NetworkSession.gd"

## Fault injection drops actual received ENet state packets until the cached
## bootstrap full-frame retry arrives. All gameplay still uses the real server.
var dropped_initial = false
var recovered_after_ms = -1
var welcome_count = 0
var _dropped_at = 0


func _receive_decoded(sender: int, packet: Dictionary):
	super._receive_decoded(sender, packet)
	if sender == 1 and packet.get("type") == "welcome":
		welcome_count += 1


func _receive(sender: int, bytes: PackedByteArray):
	var packet = Protocol.new().decode(bytes)
	if packet is Dictionary and packet.get("type") == "frame":
		if not dropped_initial:
			dropped_initial = true
			_dropped_at = Time.get_ticks_msec()
			return
		if recovered_after_ms < 0:
			if not packet.get("full", false):
				return
			recovered_after_ms = Time.get_ticks_msec() - _dropped_at
	super._receive(sender, bytes)
