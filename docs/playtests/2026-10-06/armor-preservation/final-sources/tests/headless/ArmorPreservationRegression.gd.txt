extends "res://tests/playtest/ArmorPreservationMatches.gd"

var candidate


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	field_application = load("res://source/match/programs/ProgramApplication.gd")
	field_records = load("res://source/match/programs/ProgramRecord.gd")
	field_rules = load("res://source/match/programs/VisualRules.gd")
	constants = root.get_node("Constants")
	factions = load("res://source/match/FactionCatalog.gd")
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	library = load("res://source/match/programs/ProgramLibrary.gd")
	moving_order = load("res://source/match/units/actions/Moving.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	repair_order = load("res://source/match/units/actions/Repairing.gd")
	for faction in factions.IDS:
		await _fixture(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in _errors:
		push_error(error)
	print("Armor preservation: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _fixture(faction):
	var settings = _settings(faction, "helix" if faction == "bastion" else "bastion", true)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.hud.pause_after_load()
	for unit in plan_rules.owned_units(human):
		if unit.type == "RepairDepot":
			unit.queue_free()
	await _frames(5)
	human.resource_a = 100
	human.resource_b = 100
	var funds = Vector2i(human.resource_a, human.resource_b)
	var cost = factions.cost(human, "RepairDepot", true)
	var worker = _unit(human, "Worker")
	_place("CommandLab", worker)
	var depot = _unit(human, "RepairDepot")
	_check(depot != null and not depot.is_constructed(), "Early depot placement failed")
	if depot == null:
		return
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Early depot exact debit failed"
	)
	game.hud._toggle_pause()
	for frame in 4800:
		await _frames(1)
		if depot.is_constructed():
			break
	_check(depot.is_constructed(), "Paid depot never completed")
	game.hud.pause_after_load()
	candidate = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(
		candidate, Transform3D(Basis(), depot.position + Vector3(-7, 0, -5)), human
	)
	candidate.hp = candidate.hp_max * .5
	var infantry_policy = load("res://tests/playtest/reference/ConventionalRecoveryPolicy.gd")
	armor_recovery = load("res://tests/playtest/reference/ArmorRecoveryPolicy.gd").new()
	if "--original-policy" in OS.get_cmdline_user_args():
		armor_recovery = infantry_policy.new()
	retrofit = load("res://tests/playtest/reference/PaidRetrofitPolicy.gd").new()
	retrofit_spent = 0
	conventional_recovery_enabled = true
	conventional_recovery = infantry_policy.new()
	armor_protected.clear()
	phase = "defend"
	saw_home_attack = false
	defense_point = candidate.position
	metrics = {"first_assault": null, "first_program": null}
	_command()
	_check(candidate in armor_protected, faction + ": conventional wounded tank not withdrawn")
	if candidate not in armor_protected:
		return
	var action = candidate.action
	var hp = candidate.hp
	await _frames(30)
	_command()
	_check(
		candidate.hp == hp and candidate.action == action, "Paused treatment advanced or churned"
	)
	for stage in ["attack", "recover", "defend"]:
		phase = stage
		phase_started = game.simulation_time
		_command()
		_check(candidate.action == action, "Command phase interrupted armor treatment")
	# Treatment must retain authority above the 60% fitting threshold until 80%.
	candidate.hp = candidate.hp_max * .65
	_command()
	_check(
		candidate.action == action and retrofit.active.is_empty(),
		"Fitting interrupted active treatment"
	)
	candidate.hp = hp
	game.hud._toggle_pause()
	var treatment_funds = Vector2i(human.resource_a, human.resource_b)
	var released = false
	for frame in 7200:
		if frame % 30 == 0:
			_command()
		if candidate not in armor_protected and candidate.hp >= candidate.hp_max * .8:
			released = true
		if released and candidate.program.installed and candidate.program.mode == "Running":
			break
		await _frames(1)
	_check(released, "Healed tank never released")
	_check(
		candidate.program.installed and candidate.program.mode == "Running",
		"Healed conventional tank did not fit and run Guard"
	)
	_check(
		retrofit.episodes.size() == 1 and retrofit.episodes[0].result == "installed",
		"Recovery/retrofit handoff did not complete exactly once"
	)
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== treatment_funds - Vector2i(0, factions.chip_cost(faction))
		),
		"Treatment and fitting charged an unexpected fee"
	)
	game.hud.pause_after_load()
	candidate.hp = candidate.hp_max * .2
	var installed_action = candidate.action
	armor_recovery.update(game, human, plan_rules.owned_units(human), true)
	_check(candidate.action == installed_action, "Conventional policy seized installed program")
	candidate.program.installed = false
	candidate.program.mode = "Manual"
	candidate.issue_manual_order(null)
	candidate.manual_orders.submit({"kind": "move", "point": Vector3(45, 0, 25)})
	var queued_action = candidate.action
	armor_recovery.update(game, human, plan_rules.owned_units(human), true)
	_check(
		candidate.action == queued_action and candidate.manual_orders.pending.size() == 1,
		"Conventional policy replaced queued player work"
	)
	print(
		"ARMOR ",
		faction,
		" paid depot, live healing, release, paid chip and Running Guard; episodes=",
		armor_recovery.episodes
	)


func _policy_army():
	return [candidate] if is_instance_valid(candidate) and candidate.hp > 0 else []
