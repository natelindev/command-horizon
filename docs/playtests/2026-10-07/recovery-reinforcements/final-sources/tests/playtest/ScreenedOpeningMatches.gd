extends "res://tests/playtest/ConventionalRecoveryMatches.gd"

var opening_ready = false


func _play_case(index):
	opening_ready = false
	await super(index)


func _opening_tank_target():
	return 2


func _ready_for_command_lab():
	if not opening_ready:
		opening_ready = (
			plan_rules.owned_units(human).filter(func(unit): return unit.type == "Tank").size() >= 2
		)
	return opening_ready


func _command():
	super()
	metrics.opening_policy = "two_tanks_before_lab"
	if not metrics.has("opening_screen_at") and _ready_for_command_lab():
		metrics.opening_screen_at = game.simulation_time
	if archive_prefix != "" and metrics.get("first_contact") != null:
		_archive_progress("opening_contact")
