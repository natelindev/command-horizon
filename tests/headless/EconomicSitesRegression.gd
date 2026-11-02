extends "res://tests/headless/Skirmish.gd"

var game
var human
var enemy
var capture_action
var order_rules


func _run():
	Engine.physics_ticks_per_second = 60
	seed(8291)
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	capture_action = load("res://source/match/units/actions/Garrisoning.gd")
	order_rules = load("res://source/match/players/human/UnitActionsController.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = _settings("bastion", "helix", false)
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var refinery = game.map.points_of_interest.filter(func(site): return site.kind == "refinery")[0]
	var relay = game.map.points_of_interest.filter(func(site): return site.kind == "data_relay")[0]
	_check(
		game.map.points_of_interest.size() == 4,
		"Open Plains should have paired refineries and paired satellite relays"
	)
	await _capture_and_income(refinery)
	await _radar(relay)
	await _repair_ruin(refinery)
	game.queue_free()
	await _frames(5)
	await _map_placement_contract()
	for error in _errors:
		push_error(error)
	print("Economic sites: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _spawn(role, owner, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, false)
	unit.stance = unit.Stance.HOLD_FIRE
	return unit


func _capture_and_income(site):
	var soldier = _spawn("Infantry", human, site.global_position + Vector3(3.0, 0, 0))
	await _frames(90)
	var funds = Vector2i(human.resource_a, human.resource_b)
	soldier.issue_manual_order(capture_action.new(site))
	await _frames(640)
	_check(
		site.player == null and soldier.action._capture_elapsed < 12,
		"Economic facility captured before its 12-second channel"
	)
	await _frames(100)
	_check(site.player == human, "Infantry failed to finish economic facility capture")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds + Vector2i(50, 25),
		"Tech refinery capture bounty must pay exactly 50 M / 25 E"
	)
	site.set_physics_process(false)
	site.income_left = 4.0
	funds = Vector2i(human.resource_a, human.resource_b)
	var logistics = human.logistics
	site._physics_process(3.9)
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Refinery paid early")
	_check(human.logistics == logistics, "Refinery generated Logistics before its income tick")
	site._physics_process(.1)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds + Vector2i(3, 1),
		"Refinery interval must pay 3 M / 1 E every 4 seconds"
	)
	_check(human.logistics == logistics + 2, "Refinery must generate 2 Logistics every 4 seconds")
	site.stock_a = 0
	site.stock_b = 0
	site._physics_process(40.0)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds + Vector2i(33, 11),
		"Neutral refinery steady income incorrectly depletes"
	)
	var rival = _spawn("Infantry", enemy, site.global_position + Vector3(-3.1, 0, 0))
	await _frames(3)
	rival.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	funds = Vector2i(human.resource_a, human.resource_b)
	var clock = site.income_left
	logistics = human.logistics
	site._physics_process(10.0)
	_check(
		(
			site.contested
			and site.income_left == clock
			and Vector2i(human.resource_a, human.resource_b) == funds
			and human.logistics == logistics
		),
		"Enemy infantry failed to pause contested refinery income"
	)
	rival.global_position += Vector3(0, 0, 15)
	game.battlefield.invalidate()
	site._physics_process(4.0)
	_check(
		(
			not site.contested
			and Vector2i(human.resource_a, human.resource_b) == funds + Vector2i(3, 1)
		),
		"Income failed to resume after clearing enemy infantry"
	)
	# Enemy infantry must channel continuously and hostile damage cancels it.
	soldier.global_position += Vector3(0, 0, 15)
	rival.global_position = site.global_position + Vector3(-3.1, 0, 0)
	rival.process_mode = Node.PROCESS_MODE_INHERIT
	game.battlefield.invalidate()
	rival.issue_manual_order(capture_action.new(site))
	await _frames(130)
	_check(
		site.progress > 0 and site.player == human,
		"Recapture failed to start without changing ownership"
	)
	rival.hp -= 1.0
	await _frames(3)
	_check(
		(
			site.progress == 0
			and site.candidate == null
			and rival.action.get_script() != capture_action
		),
		"Damage failed to interrupt neutral economic capture"
	)
	rival.queue_free()
	soldier.queue_free()
	await _frames(3)


func _radar(site):
	var soldier = _spawn("Infantry", human, site.global_position + Vector3(3.0, 0, 0))
	await _frames(45)
	soldier.issue_manual_order(capture_action.new(site))
	await _frames(850)
	_check(site.player == human, "Data relay capture failed")
	site.set_physics_process(false)
	var remote = _spawn("Infantry", enemy, Vector3(44, 0, 45))
	remote.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(human, remote), "Radar fixture must begin behind fog")
	var before = human.resource_b
	site.income_left = 5.0
	site._physics_process(5.0)
	_check(human.resource_b == before + 2, "Data relay failed to pay 2 E / 5 seconds")
	_check(
		site.radar_blips(human).any(
			func(point): return point.distance_to(remote.global_position) < .1
		),
		"Radar sweep failed to snapshot hidden hostile units"
	)
	_check(site.radar_blips(enemy).is_empty(), "Radar sweep leaked to an opponent")
	_check(
		not game.battlefield.is_observed(human, remote),
		"Radar sweep granted combat visibility through fog"
	)
	site._physics_process(3.1)
	_check(site.radar_blips(human).is_empty(), "Radar snapshots did not expire after three seconds")
	soldier.queue_free()
	remote.queue_free()
	await _frames(3)


func _repair_ruin(site):
	site._take_damage(10000.0)
	_check(
		site.hp == 0 and site.player == null and not site.operational(),
		"Destroyed tech refinery retained ownership or income"
	)
	var worker = _spawn("Worker", human, site.global_position + Vector3(3.0, 0, 0))
	await _frames(45)
	var repair = load("res://source/match/units/actions/Repairing.gd")
	_check(repair.is_applicable(worker, site), "Engineer cannot repair economic ruins")
	_check(
		order_rules.context_kind(worker, site) == "repair",
		"Right-clicking a visible economic ruin did not choose repair"
	)
	human.resource_a = 40
	worker.issue_manual_order(repair.new(site, true))
	await _frames(45)
	_check(
		site.hp == 10 and human.resource_a == 39, "Economic reconstruction must cost 1 M per 10 HP"
	)
	paused = true
	var health = site.hp
	await _frames(30)
	_check(site.hp == health and human.resource_a == 39, "Paused reconstruction advanced")
	paused = false
	await _frames(950)
	_check(
		site.hp == site.hp_max and human.resource_a == 10,
		"Engineer failed to fully restore the destroyed refinery"
	)
	_check(
		site.player == null and site.can_garrison(_spawn("Infantry", human, Vector3(10, 0, 10))),
		"Reconstruction must restore capturability without granting ownership"
	)


func _map_placement_contract():
	var sites = load("res://source/match/world/PointOfInterestCatalog.gd")
	var registry = load("res://source/match/maps/terrain/BattlefieldRegistry.gd")
	var ground_type = load("res://source/match/maps/terrain/TerrainModel.gd")
	for map_path in constants.Match.MAPS:
		var entries = sites.definitions(map_path)
		var relays = entries.filter(func(entry): return entry.kind == "data_relay")
		if not registry.is_authored(map_path):
			_check(
				relays.size() == 2, "Legacy battlefield lacks a satellite relay pair: " + map_path
			)
			continue
		var definition = registry.definition(map_path)
		var ground = ground_type.new(registry.layout(map_path))
		_check(
			relays.size() == definition.players,
			"Satellite relays do not match map symmetry: " + map_path
		)
		for relay in relays:
			for offset in [
				Vector2.ZERO, Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)
			]:
				var point: Vector2 = relay.position + offset
				_check(
					(
						(
							ground.flag_at(point)
							& (ground_type.WATER | ground_type.SOLID | ground_type.BARRIER)
						)
						== 0
					),
					"Satellite relay footprint overlaps blocked terrain: " + map_path
				)
	print("ECONOMIC site placement contracts reviewed on all maps")
