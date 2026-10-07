extends "res://tests/playtest/ArmorPreservationMatches.gd"

var _relay_states = []


func _map_id(index):
	return ["AlpineRelay", "IndustrialCrossroads"][(index / 2) % 2]


func _play_case(index):
	_relay_states.clear()
	await super(index)


func _measure():
	super()
	metrics.battle_record = game.battle_record.capture()
	var states = []
	for relay in game.map.relays:
		states.append(
			{
				"name": str(relay.name),
				"owner": _side(relay.captured_by),
				"candidate": _side(relay.candidate),
				"contested": relay.contested
			}
		)
	if states == _relay_states:
		return
	_relay_states = states.duplicate(true)
	if not metrics.has("relay_events"):
		metrics.relay_events = []
	var event = {"seconds": game.simulation_time, "relays": states}
	metrics.relay_events.append(event)
	print("REGIONAL RELAYS ", JSON.stringify(event))


func _side(player):
	if player == null:
		return "neutral"
	return "reference" if player == human else "opponent"
