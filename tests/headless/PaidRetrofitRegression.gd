extends "res://tests/headless/SkirmishDefensePolicy.gd"

var retrofit
var candidate
var service
var policy_script
var tank_scene
var transition_army = []


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	constants = root.get_node("Constants")
	factions = load("res://source/match/FactionCatalog.gd")
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	library = load("res://source/match/programs/ProgramLibrary.gd")
	moving_order = load("res://source/match/units/actions/Moving.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	repair_order = load("res://source/match/units/actions/Repairing.gd")
	tank_scene = load("res://source/match/units/Tank.tscn")
	policy_script = load("res://tests/playtest/reference/PaidRetrofitPolicy.gd")
	for faction in factions.IDS:
		await _fixture(faction)
		await _authority(faction)
		if "--authority-only" not in OS.get_cmdline_user_args():
			await _pressure_and_loss(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in _errors:
		push_error(error)
	print("Paid retrofit: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _fixture(faction):
	var settings = _settings(faction, "helix" if faction == "bastion" else "bastion", true)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.hud._toggle_pause()
	service = _unit(human, "CommandCenter")
	_new_candidate()
	phase = "defend"
	saw_home_attack = false
	retreating.clear()
	last_infantry_order = -100
	defense_point = candidate.position
	metrics = {"first_assault": null, "first_program": null}


func _new_candidate():
	candidate = tank_scene.instantiate()
	game._setup_and_spawn_unit(
		candidate, Transform3D(Basis(), service.position + Vector3(-4, 0, 0)), human
	)
	retrofit = policy_script.new()


func _policy_army():
	return (
		([candidate] + transition_army) if is_instance_valid(candidate) and candidate.hp > 0 else []
	)


func _protected_from_command(unit):
	return retrofit.protects(unit)


func _scope():
	return [candidate, service]


func _authority(faction):
	var before = human.resource_b
	var fee = factions.chip_cost(faction)
	retrofit.update(game, human, _scope())
	_check(
		retrofit.protects(candidate) and human.resource_b == before - fee,
		"Installation did not reserve exact fee"
	)
	var action = candidate.action
	var left = candidate.program.install_left
	var clock = game.simulation_time
	await _frames(30)
	_check(
		left == candidate.program.install_left and clock == game.simulation_time,
		"Paused installation advanced"
	)
	_command()
	_check(
		candidate.action == action and human.resource_b == before - fee,
		faction + ": commander interrupted paid installation"
	)
	if not retrofit.protects(candidate):
		return
	for stage in ["attack", "recover", "defend"]:
		phase = stage
		phase_started = game.simulation_time
		_command()
		_check(candidate.action == action, "Phase transition replaced installation")
	# Trigger the actual army-wide assault and regroup loops while fitting.
	for index in 8:
		var soldier = load("res://source/match/units/Infantry.tscn").instantiate()
		game._setup_and_spawn_unit(
			soldier, Transform3D(Basis(), service.position + Vector3(8 + index, 0, 8)), human
		)
		transition_army.append(soldier)
	saw_home_attack = true
	last_home_pressure = -100
	phase = "defend"
	_command()
	_check(
		phase == "attack" and candidate.action == action, "Assault entry interrupted installation"
	)
	for soldier in transition_army:
		soldier.hp = soldier.hp_max * .1
	phase_started = game.simulation_time - 20
	_command()
	_check(
		phase == "recover" and candidate.action == action, "Army regroup interrupted installation"
	)
	for soldier in transition_army:
		soldier.queue_free()
	transition_army.clear()
	await _frames(3)
	saw_home_attack = false
	phase = "defend"
	# A second conventional tank cannot start concurrently.
	var other = tank_scene.instantiate()
	game._setup_and_spawn_unit(
		other, Transform3D(Basis(), service.position + Vector3(-6, 0, 0)), human
	)
	retrofit.update(game, human, _scope() + [other])
	_check(
		other.program.install_left == 0 and human.resource_b == before - fee,
		"Concurrent retrofit withdrew another tank"
	)
	other.queue_free()
	game.hud._toggle_pause()
	for frame in 1800:
		await physics_frame
		if frame % 30 == 0:
			retrofit.update(game, human, _scope(), false)
			_command()
		if candidate.program.mode == "Running":
			break
	_check(
		candidate.program.installed and candidate.program.mode == "Running",
		"Paid retrofit did not reach running defense"
	)
	_check(
		human.resource_b == before - fee and retrofit.spent_e == fee,
		"Completed chip ledger mismatch"
	)
	_check(
		retrofit.episodes.size() == 1 and retrofit.episodes[0].result == "installed",
		"Missing installation result"
	)
	game.hud._toggle_pause()


func _pressure_and_loss(faction):
	candidate.issue_manual_order(null)
	candidate.queue_free()
	await _frames(3)
	_new_candidate()
	var before = human.resource_b
	var fee = factions.chip_cost(faction)
	human.resource_b = fee - 1
	retrofit.update(game, human, _scope())
	_check(
		retrofit.active.is_empty() and human.resource_b == fee - 1, "Unaffordable retrofit accepted"
	)
	human.resource_b = before
	candidate.hp = candidate.hp_max * .4
	retrofit.update(game, human, _scope())
	_check(
		retrofit.active.is_empty() and human.resource_b == before,
		"Wounded tank withdrawn for installation"
	)
	candidate.hp = candidate.hp_max
	candidate.manual_orders.submit({"kind": "move", "point": candidate.position})
	retrofit.update(game, human, _scope())
	_check(retrofit.active.is_empty(), "Queued manual work overridden by retrofit")
	candidate.manual_orders.cancel()
	var enemy = tank_scene.instantiate()
	game._setup_and_spawn_unit(
		enemy, Transform3D(Basis(), service.position + Vector3(6, 0, 0)), opponent
	)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var sights = {}
	for unit in plan_rules.owned_units(human):
		sights[unit] = unit.sight_range
		unit.sight_range = .1
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(human, enemy), "Hidden pressure fixture visible")
	retrofit.update(game, human, _scope())
	_check(retrofit.protects(candidate), "Hidden contact changed retrofit decision")
	for unit in sights:
		unit.sight_range = sights[unit]
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, enemy), "Visible threat fixture hidden")
	retrofit.update(game, human, _scope())
	_check(
		retrofit.active.is_empty() and human.resource_b == before and retrofit.spent_e == 0,
		"Threat cancellation did not refund once"
	)
	retrofit.update(game, human, _scope())
	_check(
		human.resource_b == before and retrofit.episodes.size() == 1,
		"Cancelled retrofit immediately rebought or refunded twice"
	)
	enemy.queue_free()
	await _frames(3)
	retrofit = policy_script.new()
	var provider = load("res://source/match/units/RepairDepot.tscn").instantiate()
	game._setup_and_spawn_unit(
		provider, Transform3D(Basis(), candidate.position + Vector3(-4, 0, 0)), human, false
	)
	retrofit.update(game, human, [candidate, provider])
	_check(
		retrofit.protects(candidate) and human.resource_b == before - fee,
		"Service-loss fixture did not start"
	)
	provider.queue_free()
	await _frames(3)
	retrofit.update(game, human, _scope())
	_check(
		retrofit.active.is_empty() and human.resource_b == before and retrofit.spent_e == 0,
		"Deleted provider failed to cancel and refund"
	)
	retrofit.update(game, human, _scope())
	_check(retrofit.episodes.size() == 1, "Service loss bypassed retry cooldown")
	retrofit = policy_script.new()
	retrofit.update(game, human, _scope())
	_check(retrofit.protects(candidate), "Fresh paid loss fixture did not start")
	candidate.hp = 0
	await _frames(3)
	retrofit.settle(game.simulation_time)
	_check(
		(
			retrofit.episodes[0].result == "lost"
			and human.resource_b == before - fee
			and retrofit.spent_e == fee
		),
		"Destroyed installation refunded its fee"
	)
