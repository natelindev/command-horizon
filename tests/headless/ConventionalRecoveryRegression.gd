extends "res://tests/headless/SkirmishDefensePolicy.gd"

const ARCHIVE = "res://docs/playtests/2026-10-06/engineer-reassignment/reassigned-2-unresolved.json"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	constants = root.get_node("Constants")
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	library = load("res://source/match/programs/ProgramLibrary.gd")
	moving_order = load("res://source/match/units/actions/Moving.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	repair_order = load("res://source/match/units/actions/Repairing.gd")
	conventional_recovery_enabled = "--original-policy" not in OS.get_cmdline_user_args()
	conventional_recovery = (
		load("res://tests/playtest/reference/ConventionalRecoveryPolicy.gd").new()
	)
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, store.read_file(ARCHIVE))
	_check(loaded.ok, "Earned army restoration failed")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	phase = "recover"
	phase_started = 693.249999999698
	last_home_pressure = 1792.7499999987
	saw_home_attack = true
	defense_point = Vector3(18.5, 0, 40)
	metrics = {"first_assault": null, "first_program": null}
	for unit in _policy_army():
		if unit.program != null and unit.program.mode == "Running":
			unit.set_meta("policy_programmed", true)
	var wounded = _policy_army().filter(
		func(unit): return unit.type == "Infantry" and unit.hp < unit.hp_max * .8
	)
	_check(wounded.size() == 4, "Earned army no longer contains four wounded infantry")
	var healed = {}
	var rejoined = {}
	var checks = 0
	paused = false
	var started = game.simulation_time
	for frame in 7200:
		if frame % 30 == 0:
			_command()
			for unit in conventional_protected:
				_check(
					is_instance_of(unit.action, conventional_recovery.Recover),
					"Guard/assault overwrote treatment"
				)
				checks += 1
		for unit in wounded:
			if not is_instance_valid(unit) or unit.hp <= 0:
				continue
			var id = unit.get_instance_id()
			if unit.hp >= unit.hp_max * .8:
				healed[id] = true
			if healed.has(id) and is_instance_of(unit.action, attack_move_action):
				rejoined[id] = true
		if rejoined.size() == 4:
			break
		await physics_frame
	_check(healed.size() == 4, "Reference commander did not heal the four earned infantry")
	_check(rejoined.size() == 4, "Healed infantry did not rejoin the assault")
	_check(phase == "attack", "Healed army never cleared the assault gate")
	print(
		"CONVENTIONAL RETURN enabled=",
		conventional_recovery_enabled,
		" elapsed=",
		game.simulation_time - started,
		" healed=",
		healed.size(),
		" rejoined=",
		rejoined.size(),
		" authority_checks=",
		checks,
		" episodes=",
		conventional_recovery.episodes
	)
	for error in _errors:
		push_error(error)
	print("Conventional recovery: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _policy_army():
	return plan_rules.army(human).filter(
		func(unit): return unit.movement_domain == constants.Match.Navigation.Domain.TERRAIN
	)
