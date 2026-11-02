extends "res://tests/headless/SaveRestoreEdges.gd"

var _factions
var _orders


func _run():
	Engine.physics_ticks_per_second = 60
	_factions = load("res://source/match/FactionCatalog.gd")
	_orders = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _collapse(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Structure collapse: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _unit(role, player, point):
	var unit = load(_factions.scene_path(player.faction, role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _freeze():
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED


func _collapse(faction):
	await _skirmish(faction, "res://source/match/maps/PlainAndSimple.tscn", false)
	game.settings.visibility = game.settings.Visibility.FULL
	_freeze()
	var human = game._get_human_player()
	var building = _unit("PowerPlant", human, Vector3(25, 0, 25))
	paused = true
	building.hp = 0.0
	var ruins = get_nodes_in_group("structure_ruins")
	_check(ruins.size() == 1, faction + ": destruction did not leave one ruin")
	if ruins.is_empty():
		return
	var ruin = ruins[0]
	var initial = ruin._model.scale.y
	await _frames(5)
	_check(ruin.age == 0.0 and ruin._model.scale.y == initial, "Paused collapse advanced")
	paused = false
	await _frames(45)
	_check(ruin.age > .2 and ruin.age < 1.5, "Collapse skipped its intermediate stage")
	_check(
		ruin._model.scale.y < initial and ruin._model.scale.y > .18,
		"Collapse did not lower the authored building model"
	)
	ruin.hp -= 7.0
	paused = true
	var snapshotter = Snapshot.new()
	var saved = snapshotter.capture(game)
	var id = snapshotter._reference(ruin)
	var loader = Restore.new()
	var result = await loader.restore(self, saved)
	_check(result.ok, "Collapse restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	_freeze()
	human = game._get_human_player()
	ruin = loader.entities[id]
	var record = saved.obstacles.filter(func(entry): return entry.id == id)[0]
	_check(
		ruin.age == record.ruin.age and ruin.hp == 73.0, "Restore changed collapse age or ruin HP"
	)
	paused = false
	await _frames(75)
	_check(is_equal_approx(ruin._model.scale.y, .18), "Building did not settle after1.5 seconds")
	_check(
		ruin.get_node("MovementObstacle").affect_navigation_mesh,
		"Persistent ruin did not retain navigation cover"
	)
	paused = true
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	var shooter = _unit("SniperInfantry", enemy, Vector3(18, 0, 25))
	var infantry = _unit("Infantry", human, Vector3(25 + ruin.radius + .6, 0, 25))
	var rules = load("res://source/match/combat/CombatRules.gd")
	var facts = rules.damage_facts(shooter)
	var protected = rules.damage_with_facts(facts, infantry)
	ruin.remove_from_group("structure_ruins")
	var exposed = rules.damage_with_facts(facts, infantry)
	ruin.add_to_group("structure_ruins")
	_check(
		is_equal_approx(protected, exposed * .8),
		"Nearby ruin did not provide directional light cover"
	)
	var worker = _units(human, "Worker")[0]
	worker.global_position = ruin.global_position + Vector3(ruin.radius + .5, 0, 0)
	paused = false
	worker.manual_orders.submit(_orders.target_order("collect_tactical", ruin), false, false)
	paused = true
	_check(
		worker.action != null and worker.action.has_method("_process"),
		"Worker rejected ruin salvage"
	)
	if worker.action == null:
		return
	worker.action._process(1.0)
	_check(ruin.hp > 0.0, "Ruin salvage completed before its channel")
	var reward = ruin.materials
	var before = human.resource_a
	saved = snapshotter.capture(game)
	id = snapshotter._reference(ruin)
	var worker_id = snapshotter._reference(worker)
	result = await loader.restore(self, saved)
	_check(result.ok, "Salvage channel restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	_freeze()
	human = game._get_human_player()
	ruin = loader.entities[id]
	worker = loader.entities[worker_id]
	worker.action._process(.9)
	_check(human.resource_a == before, "Restored salvage paid early")
	worker.action._process(.11)
	_check(
		human.resource_a == before + reward and ruin.hp == 0.0,
		"Restored salvage did not clear/pay exactly once"
	)
	_check(
		not ruin.collect(worker, 3.0) and human.resource_a == before + reward,
		"A second worker reused consumed structural salvage"
	)
	await _frames(3)
	_check(get_nodes_in_group("structure_ruins").is_empty(), "Salvaged ruin remained in the world")
	building = _unit("PowerPlant", human, Vector3(32, 0, 25))
	building.hp = 0.0
	ruin = get_nodes_in_group("structure_ruins")[0]
	var tank = _unit("Tank", human, ruin.global_position + Vector3(ruin.radius + .5, 0, 0))
	_check(ruin.crush_by(tank), "Heavy ground vehicle could not bulldoze structural ruins")
	_check(human.resource_a == before + reward, "Bulldozer incorrectly awarded engineer salvage")
