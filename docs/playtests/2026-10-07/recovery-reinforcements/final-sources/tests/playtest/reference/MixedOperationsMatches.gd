extends "res://tests/playtest/reference/MixedReadinessMatches.gd"

var proactive = false


func _initialize():
	proactive = "--proactive" in OS.get_cmdline_user_args()
	super()


func _requires_home_attack():
	return not proactive


func _command():
	var before = phase
	super()
	metrics.operation_policy = "proactive" if proactive else "after_home_attack"
	if phase != before:
		if not metrics.has("operation_changes"):
			metrics.operation_changes = []
		var force = []
		for unit in _policy_army():
			force.append(
				{
					"role": unit.type,
					"hp": unit.hp / unit.hp_max,
					"point": [unit.position.x, unit.position.z],
					"action": str(unit.action)
				}
			)
		var row = {
			"seconds": game.simulation_time,
			"phase": phase,
			"previous": before,
			"readiness": load("res://tests/playtest/reference/PolicyReadiness.gd").sample(self),
			"force": force
		}
		metrics.operation_changes.append(row)
		print("OPERATION CHANGE ", JSON.stringify(row))
