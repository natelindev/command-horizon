extends "res://tests/playtest/reference/EngineerReassignmentPolicy.gd"


func _work_target_allowed(_game, worker, hq, target, kind):
	if (
		kind != "gather"
		or target.global_position_yless.distance_to(hq.global_position_yless) <= economy.HOME_RADIUS
	):
		return true
	var units = load("res://tests/UnitQueries.gd").owned_units(worker.player)
	return economy.guarded(units, target.global_position_yless)
