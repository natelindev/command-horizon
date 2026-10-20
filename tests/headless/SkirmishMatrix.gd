extends "res://tests/headless/SkirmishLoop.gd"

const MAPS = ["DesertFrontier", "AlpineRelay"]
var repair_order
var metrics = {}
var records = []
var observed_hp = {}
var travel_samples = {}
var defense_point = Vector3.ZERO
var expanded = false
var active_case = -1
var repetition = 0
var output_path = "res://tmp/skirmish-matrix.json"
var deadline = 0
var recovery_probe
var coordination_probe


func _initialize():
	deadline = Time.get_ticks_msec() + 7200000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Skirmish matrix wall-clock timeout")
		quit(1)
	return false


func _run():
	repair_order = load("res://source/match/units/actions/Repairing.gd")
	plan_rules = load("res://tests/UnitQueries.gd")
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	construct_action = load("res://source/match/units/actions/Constructing.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var selected = -1
	var repeats = 3
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="):
			selected = argument.trim_prefix("--case=").to_int()
		if argument.begins_with("--repeats="):
			repeats = argument.trim_prefix("--repeats=").to_int()
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	root.get_node("MatchSignals").unit_spawned.connect(_track_unit)
	root.get_node("MatchSignals").unit_destroying.connect(_loss)
	for repeat_index in repeats:
		repetition = repeat_index
		for case_index in 8:
			if selected >= 0 and case_index != selected:
				continue
			active_case = case_index
			await _play_case(case_index)
	saves.autosaves_enabled = autosaves
	_check(
		records.size() == repeats * (1 if selected >= 0 else 8), "Missing complete-match records"
	)
	for message in _errors:
		push_error(message)
	print("Skirmish matrix: %d records, %d unresolved checks" % [records.size(), _errors.size()])
	quit(0 if _errors.is_empty() else 1)


func _map_id(index):
	return MAPS[(index / 2) % 2]


func _faction_id(index):
	return ["bastion", "helix"][index / 4]


func _opponent_id(index):
	return "helix" if _faction_id(index) == "bastion" else "bastion"


func _play_case(index):
	recovery_probe = load("res://tests/headless/SkirmishRecoveryMetrics.gd").new()
	coordination_probe = load("res://tests/headless/SkirmishCoordinationMetrics.gd").new()
	seed(4100 + repetition)
	var faction = _faction_id(index)
	var map_id = _map_id(index)
	var advanced = index % 2 == 1
	var settings = _settings(faction, _opponent_id(index), advanced)
	settings.map_path = "res://source/match/maps/%s.tscn" % map_id
	settings.players[1].spawn_index_offset = 0
	settings.players[1].difficulty = 1
	metrics = {
		"case": index,
		"repetition": repetition,
		"seed": 4100 + repetition,
		"faction": faction,
		"opponent": _opponent_id(index),
		"map": map_id,
		"advanced": advanced,
		"difficulty": "Normal",
		"first_contact": null,
		"lab_unlock": null,
		"first_guard": null,
		"first_assault": null,
		"expansion_order": null,
		"expansion_return": null,
		"losses": [{}, {}],
		"repaired_hp": [0.0, 0.0],
		"damage_hp": [0.0, 0.0],
		"stationary_travel_unit_seconds": [0.0, 0.0],
		"longest_stationary_travel": [0.0, 0.0],
		"samples": []
	}
	observed_hp.clear()
	travel_samples.clear()
	game = await _start(settings)
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	for unit in get_nodes_in_group("units"):
		_track_unit(unit)
	var home = game.map.FIELDS[0]
	var headquarters = _unit(human, "CommandCenter").global_position_yless
	defense_point = headquarters.lerp(Vector3(home.x + 5, 0, home.y), 0.5)
	_guarded = false
	_guard = null
	_launched = false
	_spent = Vector2.ZERO
	_last_attack = -100.0
	_last_defense = -100.0
	expanded = false
	print(
		"MATRIX START ",
		index,
		" repeat=",
		repetition,
		" ",
		faction,
		" ",
		map_id,
		" advanced=",
		advanced
	)
	for tick in 3600:
		if game.finished:
			break
		_economy()
		_produce()
		_command()
		_measure()
		if tick % 120 == 0:
			var row = _sample()
			metrics.samples.append(row)
			print("MATRIX SAMPLE ", JSON.stringify(row))
		await _frames(30)
	_measure()
	metrics.result = game.result if game.finished else "Unresolved at 30:00"
	metrics.seconds = snappedf(game.simulation_time, 0.1)
	metrics.enemy_attacks = opponent.attacks_launched
	metrics.spent = [_spent.x, _spent.y]
	var initial = Vector2(120, 60) if advanced else Vector2(60, 12)
	var income = Vector2(human.resource_a, human.resource_b) - initial + _spent
	metrics.harvested = [income.x, income.y]
	metrics.final = _sample()
	metrics.ai_recovery = recovery_probe.records
	metrics.ai_coordination = coordination_probe.summary()
	_check(coordination_probe.violations.is_empty(), "AI task/order coordination violations")
	records.append(metrics.duplicate(true))
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	_check(file != null, "Cannot write matrix observations")
	if file != null:
		file.store_string(JSON.stringify(records, "\t"))
		file.close()
	print("MATRIX RESULT ", JSON.stringify(metrics))
	_check(game.finished, "Case %d repeat %d did not reach a result" % [index, repetition])
	await _review_match_end()
	paused = false
	game.queue_free()
	await _frames(5)
	game = null
	human = null
	opponent = null


func _review_match_end():
	return true


func _economy():
	if not human.has_completed_structure("CommandCenter"):
		var workers = _economy_workers(plan_rules.owned_units(human))
		if not workers.is_empty() and _unit(human, "CommandCenter") == null:
			if human.has_resources(factions.cost(human, "CommandCenter", true)):
				_place("CommandCenter", workers[0])
	super()
	if expanded or game.simulation_time < 360:
		return
	var workers = _economy_workers(plan_rules.owned_units(human)).filter(
		func(unit):
			return unit.type == "Worker" and not is_instance_of(unit.action, construct_action)
	)
	if workers.size() < 4:
		return
	var outer = game.map.FIELDS[2]
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit):
			return (
				"resource_b" in unit
				and Vector2(unit.position.x, unit.position.z).distance_to(outer) < 10
			)
	)
	if deposits.is_empty():
		return
	var worker = workers[-1]
	worker.set_meta("matrix_expansion", true)
	worker.issue_manual_order(harvest_action.new(deposits[0]))
	expanded = true
	metrics.expansion_order = game.simulation_time


func _produce():
	var factory = _unit(human, "VehicleFactory")
	if (
		factory != null
		and factory.is_constructed()
		and factory.production_queue.size() == 0
		and human.has_completed_structure("CommandLab")
		and _unit(human, "RepairRobot") == null
		and plan_rules.army(human).size() >= 6
	):
		var entry = factory.production_queue.produce(load(Catalog.scene_path("RepairRobot")))
		if entry != null:
			_spent += Vector2(entry.paid_cost.resource_a, entry.paid_cost.resource_b)
	super()


func _command():
	var army = plan_rules.army(human)
	var hq = _unit(human, "CommandCenter")
	var contacts = []
	if hq != null:
		contacts = game.battlefield.nearby_units(hq.global_position_yless, 28).filter(
			func(unit):
				return (
					unit.player != human
					and unit.hp > 0
					and game.battlefield.is_observed(human, unit)
				)
		)
	var defend_at = defense_point
	if not contacts.is_empty():
		contacts.sort_custom(
			func(a, b):
				return (
					a.position.distance_squared_to(defense_point)
					< b.position.distance_squared_to(defense_point)
				)
		)
		defend_at = contacts[0].global_position_yless
	if not _launched and game.simulation_time - _last_defense >= 15:
		for defender in army:
			if contacts.is_empty() and defender == _guard:
				continue
			defender.issue_manual_order(
				attack_move_action.new(defend_at + Vector3(defender.get_index() % 3, 0, 0))
			)
		_last_defense = game.simulation_time
	if not _guarded and human.has_completed_structure("CommandLab"):
		var behavior = load("res://source/match/orders/UnitBehavior.gd")
		for unit in army:
			if unit.type == "Tank":
				_check(behavior.guard(unit, defense_point), "Opening guard order rejected")
				_guarded = true
				_guard = unit
				_guard_at = game.simulation_time
				metrics.first_guard = _guard_at
				break
	var support = _unit(human, "RepairRobot")
	var armor = army.filter(func(unit): return unit.type == "Tank")
	if support != null and not armor.is_empty():
		if support.action == null or not is_instance_of(support.action, repair_order):
			support.issue_manual_order(repair_order.new(armor[0]))
	if not _guarded or game.simulation_time - _guard_at < 5 or army.size() < 9:
		return
	if game.simulation_time - _last_attack < 25:
		return
	var destination = game.map.find_child("SpawnPoints").get_child(1).position
	for unit in army:
		unit.issue_manual_order(
			attack_move_action.new(destination + Vector3(unit.get_index() % 3, 0, 0))
		)
		if unit == _guard:
			_check(
				(
					unit.manual_orders.current.is_empty()
					and is_instance_of(unit.action, attack_move_action)
				),
				"Assault order did not replace the guard order"
			)
	_launched = true
	_last_attack = game.simulation_time
	if metrics.first_assault == null:
		metrics.first_assault = game.simulation_time


func _track_unit(unit):
	if unit.hp == null or observed_hp.has(unit.get_instance_id()):
		return
	observed_hp[unit.get_instance_id()] = {
		"hp": float(unit.hp),
		"complete": not unit.has_method("is_constructed") or unit.is_constructed()
	}
	unit.hp_changed.connect(_hp_change.bind(unit))


func _hp_change(unit):
	if not is_instance_valid(game) or human == null or unit.player == null:
		return
	var id = unit.get_instance_id()
	var previous = observed_hp[id]
	var difference = float(unit.hp) - previous.hp
	var complete = not unit.has_method("is_constructed") or unit.is_constructed()
	observed_hp[id] = {"hp": float(unit.hp), "complete": complete}
	var side = 0 if unit.player == human else 1
	if difference < 0 and absf(game.simulation_time - unit.last_enemy_damage_time) < 0.001:
		metrics.damage_hp[side] -= difference
	elif difference > 0 and complete and previous.complete:
		metrics.repaired_hp[side] += difference


func _loss(unit):
	if not is_instance_valid(game) or human == null or unit.player == null:
		return
	if recovery_probe != null:
		recovery_probe.loss(unit, game)
	var side = 0 if unit.player == human else 1
	metrics.losses[side][unit.type] = metrics.losses[side].get(unit.type, 0) + 1


func _measure():
	if coordination_probe != null:
		coordination_probe.sample(game, opponent)
	if recovery_probe != null:
		recovery_probe.sample(game, opponent)
	if metrics.lab_unlock == null and human.lab_research_unlocked():
		metrics.lab_unlock = game.simulation_time
	for unit in get_nodes_in_group("units"):
		if unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		var side = 0 if unit.player == human else 1
		if (
			side == 1
			and metrics.first_contact == null
			and game.battlefield.is_observed(human, unit)
		):
			metrics.first_contact = game.simulation_time
		if unit.get_meta("matrix_expansion", false):
			var outer = game.map.FIELDS[2]
			var at_outer = Vector2(unit.position.x, unit.position.z).distance_to(outer) < 10
			if unit.resource_b > 0 and at_outer:
				unit.set_meta("matrix_cargo_seen", true)
			elif (
				unit.resource_b == 0
				and unit.get_meta("matrix_cargo_seen", false)
				and metrics.expansion_return == null
			):
				metrics.expansion_return = game.simulation_time
		var movement = unit.get_node_or_null("Movement")
		if movement == null or unit.movement_speed <= 0:
			continue
		var id = unit.get_instance_id()
		var previous = travel_samples.get(id, {"point": unit.position, "still": 0.0})
		var remaining = unit.position - movement.target_position
		if unit.movement_domain == constants.Match.Navigation.Domain.AIR:
			remaining.y = 0.0
		var stalled = (
			movement._has_destination
			and remaining.length() > 1.0
			and unit.position.distance_to(previous.point) < 0.05
		)
		var duration = previous.still + 0.5 if stalled else 0.0
		if duration >= 5:
			metrics.stationary_travel_unit_seconds[side] += 0.5
		metrics.longest_stationary_travel[side] = maxf(
			metrics.longest_stationary_travel[side], duration
		)
		travel_samples[id] = {"point": unit.position, "still": duration}


func _sample():
	var sides = []
	for player in [human, opponent]:
		var types = {}
		var allocation = {"materials": 0, "electronics": 0, "construction": 0, "other": 0}
		var worker_states = {}
		var army_value = Vector2.ZERO
		for unit in player.get_children():
			if "type" in unit and not unit.is_queued_for_deletion():
				types[unit.type] = types.get(unit.type, 0) + 1
				if unit.type == "Worker":
					var assignment = "other"
					var state = "Idle" if unit.action == null else str(unit.action)
					if is_instance_of(unit.action, construct_action):
						assignment = "construction"
					elif is_instance_of(unit.action, harvest_action):
						assignment = "materials" if unit.action._kind == 1 else "electronics"
						state = unit.action.harvest_status()
					allocation[assignment] += 1
					worker_states[state] = worker_states.get(state, 0) + 1
				elif unit.movement_speed > 0:
					var price = factions.cost(player, unit.type)
					army_value += Vector2(price.resource_a, price.resource_b)
		sides.append(
			{
				"funds": [player.resource_a, player.resource_b],
				"units": types,
				"workers": allocation,
				"worker_states": worker_states,
				"army_base_value": [army_value.x, army_value.y]
			}
		)
	return {
		"seconds": snappedf(game.simulation_time, 0.1),
		"sides": sides,
		"ai_tasks": coordination_probe.tasks(game, opponent) if coordination_probe != null else []
	}
