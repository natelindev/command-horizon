extends "res://tests/headless/ConventionalRecoveryRegression.gd"

const OPENING = (
	"res://docs/playtests/2026-10-06/conventional-recovery/"
	+ "earned-6-case6-11-worker_withdrawal.json"
)
var trace = []
var home_defense


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	constants = root.get_node("Constants")
	plan_rules = load("res://tests/UnitQueries.gd")
	moving_order = load("res://source/match/units/actions/Moving.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	repair_order = load("res://source/match/units/actions/Repairing.gd")
	home_defense = load("res://tests/playtest/reference/HomeDefensePolicy.gd").new()
	conventional_recovery_enabled = true
	conventional_recovery = (
		load("res://tests/playtest/reference/ConventionalRecoveryPolicy.gd").new()
	)
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, store.read_file(OPENING))
	_check(loaded.ok, "Earned opening restoration failed")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	defense_point = Vector3(18.5, 0, 40)
	if "--service-line" in OS.get_cmdline_user_args():
		defense_point = _unit(human, "Barracks").global_position_yless + Vector3(0, 0, 3)
	metrics = {"first_assault": null}
	var start = game.simulation_time
	paused = false
	for frame in 7200:
		if frame % 30 == 0:
			_command()
		if frame % 60 == 0:
			trace.append(_opening_sample(start))
		await physics_frame
	var output = "res://tmp/earned-opening.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(trace, "\t"))
	for error in _errors:
		push_error(error)
	print("Earned opening probe: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _opening_sample(start):
	var sides = [[], []]
	for unit in get_nodes_in_group("units"):
		if unit.attack_range == null or unit.movement_speed <= 0:
			continue
		var side = 0 if unit.player == human else 1
		var visible = game.battlefield.observed_enemies_near(unit, unit.sight_range)
		var in_range = visible.filter(
			func(target):
				return (
					unit.global_position_yless.distance_to(target.global_position_yless)
					<= unit.attack_range
				)
		)
		var legal = in_range.filter(func(target): return game.battlefield.can_fire(unit, target))
		sides[side].append(
			{
				"id": unit.get_instance_id(),
				"role": unit.type,
				"hp": unit.hp,
				"position": [unit.position.x, unit.position.z],
				"action": str(unit.action),
				"visible": visible.size(),
				"in_range": in_range.size(),
				"legal": legal.size(),
				"moving": unit.get_node("Movement")._has_destination
			}
		)
	return {"seconds": game.simulation_time - start, "sides": sides}


func _respond_to_home_threat(unit, threats):
	if "--responsive" not in OS.get_cmdline_user_args():
		return false
	return home_defense.command(unit, threats, game.simulation_time)
