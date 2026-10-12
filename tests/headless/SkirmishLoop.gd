extends "res://tests/headless/Skirmish.gd"

var plan_rules
var harvest_action
var construct_action
var attack_move_action
var library
var game
var human
var opponent
var _programmed = false
var _launched = false
var _spent = Vector2.ZERO
var _steps = {}
var _last_attack = -100.0
var _program_at = 0.0
var _last_defense = -100.0


func _run():
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	construct_action = load("res://source/match/units/actions/Constructing.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	library = load("res://source/match/programs/ProgramLibrary.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var selected_factions = []
	for faction in factions.IDS:
		if "--" + faction in OS.get_cmdline_user_args():
			selected_factions.append(faction)
	for faction in factions.IDS:
		if not selected_factions.is_empty() and faction not in selected_factions:
			continue
		await _play(faction)
	for error in _errors:
		push_error(error)
	print("Standard-start gameplay loop: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _play(faction):
	var settings = _settings(faction, "helix" if faction == "bastion" else "bastion", false)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	settings.players[1].spawn_index_offset = 0
	settings.players[1].difficulty = 0
	game = await _start(settings)
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	_programmed = false
	_launched = false
	_spent = Vector2.ZERO
	_steps.clear()
	_last_attack = -100.0
	_last_defense = -100.0
	_check(plan_rules.next_step(human).id == "economy", "Standard start lacks economy guidance")
	_check(plan_rules.idle_workers(human).size() == 4, "Starting engineers are not idle/selectable")
	for tick in 2400:
		if game.finished:
			break
		var step = plan_rules.next_step(human)
		if not _steps.has(step.id):
			_steps[step.id] = snappedf(game.simulation_time, 0.1)
			print("LOOP ", faction, " ", step.id, " at ", _steps[step.id])
		_economy()
		_produce()
		_command()
		await _frames(30)
	var income = Vector2(human.resource_a - 60, human.resource_b - 12) + _spent
	_check(income.x > 100 and income.y > 30, "Real harvesting did not fund progression")
	_check(_programmed, "Paid standard opening did not reach a running built-in program")
	_check(_launched, "Programmed army never received the player's assault order")
	# This exercises the match lifecycle, not an unbeatable strategy or a balance oracle.
	_check(
		game.finished and game.result in ["Victory", "Defeat", "Draw"],
		"The played match never reached a valid outcome"
	)
	_check(opponent.attacks_launched > 0, "Enemy never challenged the opening")
	print(
		"LOOP RESULT ",
		faction,
		" ",
		game.result,
		" seconds=",
		game.simulation_time,
		" income=",
		income,
		" produced=",
		game.units_produced,
		" enemy_attacks=",
		opponent.attacks_launched,
		" army=",
		plan_rules.army(human).size()
	)
	paused = false
	game.queue_free()
	await _frames(5)


func _ready_for_command_lab():
	return _unit(human, "Tank") != null


func _economy():
	var units = plan_rules.owned_units(human)
	var workers = _economy_workers(units)
	if workers.is_empty():
		return
	var pending = units.filter(
		func(unit): return unit.has_method("is_constructed") and not unit.is_constructed()
	)
	# Keep the scarce electronics route running while construction takes a
	# materials gatherer or idle engineer out of the labor pool.
	var builders = workers.filter(
		func(worker):
			return not is_instance_of(worker.action, harvest_action) or worker.action._kind != 2
	)
	var builder = builders[0] if not builders.is_empty() else workers[0]
	if not pending.is_empty():
		if not is_instance_of(builder.action, construct_action):
			builder.issue_manual_order(construct_action.new(pending[0]))
	else:
		var wanted = ""
		if human.power_totals().x < human.power_totals().y + 4:
			wanted = "PowerPlant"
		else:
			for role in ["Barracks", "VehicleFactory", "CommandLab"]:
				if not human.has_completed_structure(role):
					if role == "CommandLab" and not _ready_for_command_lab():
						break
					wanted = role
					break
		if wanted == "" and not human.has_completed_structure("RepairDepot"):
			var wounded = units.any(
				func(unit):
					return (
						unit.type in ["Tank", "Artillery", "RepairRobot"]
						and unit.hp < unit.hp_max * .8
					)
			)
			if wounded:
				wanted = "RepairDepot"
		if wanted != "" and human.has_resources(factions.cost(human, wanted, true)):
			_place(wanted, builder)
	var labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	# Count actual assignments so casualties cannot shift replacement engineers
	# away from electronics. Queued delivery-boundary handoffs count once.
	var electronics_count = 0
	for worker in workers:
		var queued = labor.queued_target(worker)
		if queued != null:
			electronics_count += 1 if "resource_b" in queued else 0
		elif is_instance_of(worker.action, harvest_action) and not worker.action.needs_assignment():
			electronics_count += 1 if worker.action._kind == 2 else 0
	var candidates = workers.filter(
		func(worker): return worker != builder and _labor_available(worker)
	)
	# Preserve the established opening choices; only the count, not a shifted
	# list index, determines which replacement engineers refill lost routes.
	candidates.sort_custom(
		func(a, b):
			var a_preferred = workers.find(a) in [2, 4]
			var b_preferred = workers.find(b) in [2, 4]
			return a_preferred and not b_preferred
	)
	var target = [2, 4].filter(func(index): return index < workers.size()).size()
	var needed = maxi(0, target - electronics_count)
	var electronics_workers = candidates.slice(0, needed)
	for index in workers.size():
		var worker = workers[index]
		if not _labor_available(worker) or (worker == builder and not pending.is_empty()):
			continue
		var electronics = worker in electronics_workers
		var deposits = get_nodes_in_group("resource_units").filter(
			func(node): return node.can_harvest(worker) and (("resource_b" in node) == electronics)
		)
		deposits.sort_custom(
			func(a, b):
				return (
					worker.position.distance_squared_to(a.global_position)
					< worker.position.distance_squared_to(b.global_position)
				)
		)
		if not deposits.is_empty():
			worker.issue_manual_order(
				harvest_action.new(deposits[0 if electronics else index % mini(3, deposits.size())])
			)


func _economy_workers(units):
	return units.filter(func(unit): return unit.type == "Worker")


func _labor_available(worker):
	return (
		worker.manual_orders.pending.is_empty()
		and (
			worker.action == null
			or (worker.action.has_method("needs_assignment") and worker.action.needs_assignment())
		)
	)


func _place(role, builder):
	var handler = human.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load(Catalog.scene_path(role)))
	var center = _unit(human, "CommandCenter")
	var origin = center.position if center != null else builder.position
	var placed = false
	for radius in [7.0, 11.0, 15.0, 19.0]:
		for index in 16:
			var angle = index * TAU / 16
			handler._active_blueprint_node.global_position = (
				origin + Vector3(cos(angle), 0, sin(angle)) * radius
			)
			if (
				(
					handler._calculate_blueprint_position_validity()
					== handler.BlueprintPositionValidity.VALID
				)
				and _placement_candidate_allowed(
					handler._active_blueprint_node.global_position, builder
				)
			):
				root.get_node("MatchSignals").deselect_all_units.emit()
				builder.get_node("Selection").select()
				var cost = factions.cost(human, role, true)
				handler._finish_structure_placement()
				_spent += Vector2(cost.resource_a, cost.resource_b)
				placed = true
				break
		if placed:
			break
	if not placed:
		handler._cancel_structure_placement()


func _placement_candidate_allowed(_point, _builder):
	return true


func _produce():
	var units = plan_rules.owned_units(human)
	for role in ["CommandCenter", "Barracks", "VehicleFactory"]:
		var producer = _unit(human, role)
		if (
			producer == null
			or not producer.is_constructed()
			or producer.production_queue.size() > 0
		):
			continue
		var product = ""
		if (
			role == "CommandCenter"
			and units.filter(func(unit): return unit.type == "Worker").size() < 6
		):
			product = "Worker"
		elif (
			role == "Barracks"
			and units.filter(func(unit): return unit.type == "Infantry").size() < 4
		):
			product = "Infantry"
		elif role == "VehicleFactory":
			# Field conventional armor before buying the first lab.
			if not human.has_completed_structure("CommandLab") and _unit(human, "Tank") != null:
				continue
			producer.production_queue.fit_chips = human.has_completed_structure("CommandLab")
			product = "Tank"
		if product != "":
			var entry = producer.production_queue.produce(load(Catalog.scene_path(product)))
			if entry != null:
				_spent += Vector2(entry.paid_cost.resource_a, entry.paid_cost.resource_b)


func _command():
	var army = plan_rules.army(human)
	if not _launched and game.simulation_time - _last_defense >= 15:
		for defender in army:
			if defender.program != null and defender.program.mode != "Manual":
				continue
			defender.issue_manual_order(
				attack_move_action.new(Vector3(19 + defender.get_index() % 3, 0, 43))
			)
		_last_defense = game.simulation_time

	if not _programmed:
		for unit in army:
			if unit.program != null and unit.program.ready_to_run():
				unit.program.configure(library.defaults("guard"), "Opening guard")
				unit.program.anchor = Vector3(20, 0, 43)
				unit.program.safe_point = _unit(human, "CommandCenter").global_position_yless
				_check(unit.program.run(), "First built-in program refused to run")
				_programmed = true
				_program_at = game.simulation_time
				break
	# The opening trains four infantry and armor. Commit a six-unit force
	# instead of waiting for nine while refusing further infantry production.
	if not _programmed or game.simulation_time - _program_at < 5 or army.size() < 6:
		return
	if game.simulation_time - _last_attack < 25:
		return
	# Opposing starting area is the strategic destination; ordinary attack-move
	# still acquires only currently observed, legal contacts.
	var destination = game.map.find_child("SpawnPoints").get_child(1).position
	for unit in army:
		unit.issue_manual_order(
			attack_move_action.new(destination + Vector3(unit.get_index() % 3, 0, 0))
		)
		if unit.program != null:
			_check(unit.program.mode == "Manual", "Assault order did not override program")
	_launched = true
	_last_attack = game.simulation_time
