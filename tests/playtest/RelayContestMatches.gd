extends "res://tests/playtest/RegionalRecoveryMatches.gd"

var expedition
var relay_protected = []


func _play_case(index):
	expedition = _new_expedition()
	relay_protected.clear()
	await super(index)


func _new_expedition():
	return load("res://tests/playtest/reference/RelayExpeditionPolicy.gd").new()


func _command():
	# Recovery updates in the inherited command take precedence on this tick.
	# Afterwards, exclude those patients from the optional expedition.
	super()
	relay_protected = expedition.update(
		game,
		human,
		plan_rules.owned_units(human),
		phase,
		armor_protected + conventional_protected,
		defense_point
	)
	metrics.relay_expeditions = expedition.episodes
	if archive_prefix != "" and game.map.relays.any(func(relay): return relay.captured_by == human):
		_archive_progress("relay_secured")


func _protected_from_command(unit):
	return unit in relay_protected or super(unit)


func _policy_army():
	return super().filter(func(unit): return unit not in relay_protected)
