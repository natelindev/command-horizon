extends "res://tests/playtest/CautiousRelayMatches.gd"

var electronics_handoff
var handoff_enabled = false


func _run():
	handoff_enabled = "--electronics-handoff" in OS.get_cmdline_user_args()
	await super()


func _play_case(index):
	electronics_handoff = load("res://tests/playtest/reference/ElectronicsHandoffPolicy.gd").new()
	await super(index)


func _economy():
	super()
	if not handoff_enabled:
		return
	var units = plan_rules.owned_units(human)
	var protected = units.filter(
		func(unit): return unit.type == "Worker" and engineer_safety.protected(unit)
	)
	var issued = electronics_handoff.update(game, human, units, protected)
	metrics.electronics_handoffs = electronics_handoff.handoffs
	if issued > 0:
		print("ELECTRONICS HANDOFF ", JSON.stringify(electronics_handoff.handoffs[-1]))
		if archive_prefix != "":
			_archive_progress("electronics_handoff")
