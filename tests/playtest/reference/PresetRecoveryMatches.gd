extends "res://tests/headless/SkirmishMixedPolicy.gd"


func _review_match_end():
	if game.finished:
		return true
	var was_paused = paused
	paused = true
	var builder = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Unresolved-state capture failed: " + builder.error)
	if snapshot == null:
		paused = was_paused
		return false
	var disk = output_path.trim_suffix(".json") + "-unresolved.json"
	var saved = load("res://source/match/saves/SaveFile.gd").new().write_file(disk, snapshot)
	_check(saved, "Unresolved-state disk write failed")
	var policy = {
		"phase": phase,
		"phase_started": phase_started,
		"last_home_pressure": last_home_pressure,
		"saw_home_attack": saw_home_attack,
		"vehicle_sequence": vehicle_sequence,
		"retreating": [],
		"army": []
	}
	for unit in _policy_army():
		var id = builder._reference(unit)
		if retreating.has(unit.get_instance_id()):
			policy.retreating.append(id)
		policy.army.append(
			{
				"id": id,
				"role": unit.type,
				"hp": unit.hp / unit.hp_max,
				"action": str(unit.action)
			}
		)
	var file = FileAccess.open(
		output_path.trim_suffix(".json") + "-unresolved-policy.json", FileAccess.WRITE
	)
	_check(file != null, "Unresolved policy report could not be written")
	if file != null:
		file.store_string(JSON.stringify(policy, "\t"))
		file.close()
	print("UNRESOLVED ARCHIVE ", disk, " saved=", saved)
	paused = was_paused
	return true
