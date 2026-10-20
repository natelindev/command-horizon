extends "res://tests/headless/SaveRestoreEdges.gd"

const Catalog = preload("res://source/match/BastionCatalog.gd")

var plan_rules


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _battle_state(faction)
	for message in errors:
		push_error(message)
	print("Battle state regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _battle_state(faction):
	plan_rules = load("res://tests/UnitQueries.gd")
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var workers = plan_rules.owned_units(human).filter(func(unit): return unit.type == "Worker")
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_a" in unit
	)
	deposits.sort_custom(
		func(a, b):
			return (
				a.position.distance_to(workers[0].position)
				< b.position.distance_to(workers[0].position)
			)
	)
	workers[0].issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposits[0])
	)
	for index in 5:
		_spawn_actor("Infantry", human, Vector3(22 + index, 0, 20))
	await _frames(10)
	game.hud._toggle_pause()
	_check(paused, "Battle-state fixture did not pause")
	_check(plan_rules.army(human).size() == 9, "Battle-state fixture did not reach nine combatants")
	var hidden = _spawn_actor("AdvancedTank", enemy, Vector3(105, 0, 85))
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(human, hidden), "Hidden-army fixture is visible")
	workers[0].position = Vector3(35, 0, 20)
	var attacker = _spawn_actor("Tank", enemy, Vector3(39, 0, 20))
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, attacker), "Nearby threat is not observed")
	attacker.position = Vector3(108, 0, 85)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(human, attacker), "Withdrawn attacker remains visible")
	var infantry = plan_rules.army(human).filter(func(unit): return unit.type == "Infantry")[0]
	infantry.position = Vector3(53, 0, 10)
	attacker.position = Vector3(57, 0, 10)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, attacker), "Field contact is not observed")
	attacker.position = Vector3(108, 0, 85)
	game.battlefield.invalidate()
	workers[0].last_enemy_damage_time = game.simulation_time
	var clock = game.simulation_time
	var point = workers[0].position
	var action = workers[0].action
	await _frames(30)
	_check(
		(
			game.simulation_time == clock
			and workers[0].position == point
			and workers[0].action == action
		),
		"Paused match advanced gameplay"
	)
	var snapshotter = Snapshot.new()
	var snapshot = snapshotter.capture(game)
	_check(snapshot != null, "Battle-state snapshot failed")
	if snapshot == null:
		quit(1)
		return
	var file = FileStore.new()
	var archive = "user://battle-state-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Battle-state disk write failed")
	var loaded = await Restore.new().restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "Battle-state disk restore failed")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	human = game._get_human_player()
	await _frames(30)
	_check(game.simulation_time == clock, "Paused restore advanced the simulation")
	var struck = plan_rules.owned_units(human).filter(
		func(unit): return unit.type == "Worker" and unit.last_enemy_damage_time > clock - 1
	)
	_check(
		struck.size() == 1 and is_equal_approx(struck[0].last_enemy_damage_time, clock),
		"Archive lost own incoming-fire time"
	)
	for unit in plan_rules.army(human):
		if unit.type == "Infantry":
			unit.queue_free()
	await _frames(5)
	var producers = plan_rules.owned_units(human).filter(
		func(unit): return unit.type in ["Barracks", "VehicleFactory"]
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	for producer in producers:
		producer.get_node("Selection").select()
	# Selection changes rebuild the command deck on the next idle frame.
	await process_frame
	var menus = game.find_child("UnitMenus")
	menus._refresh_buttons()
	_check(menus._selection.size() == 2, "Mixed production selection lost a building")
	_check(not menus._buttons.is_empty(), "Mixed production roster is missing")
	for entry in menus._buttons:
		var producer = menus._production_target(entry.type)
		_check(
			producer in producers and entry.type in Catalog.PRODUCES.get(producer.type, []),
			"Mixed production selection offers a job without an eligible producer"
		)
	await _double_click_selection(human)
	print("BATTLE STATE ", faction, " fog/pause/archive/selection checked")
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _spawn_actor(role, player, point):
	var catalog = load("res://source/match/BastionCatalog.gd")
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _double_click_selection(player):
	var tanks = plan_rules.army(player).filter(func(unit): return unit.type == "Tank")
	for index in tanks.size():
		tanks[index].position = Vector3(30 + index * 3, 0, 30)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(31, 0, 30))
	await _frames(3)
	_check(tanks.size() == 2, "Double-click fixture lacks two tanks")
	_check(
		tanks.all(func(unit): return camera.is_position_in_frustum(unit.position)),
		"Double-click tanks are off screen"
	)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.get_node("MatchSignals").deselect_all_units.emit()
	tanks[0].input_event.emit(camera, event, tanks[0].position, Vector3.UP, 0)
	_check(
		get_nodes_in_group("selected_units").size() == 1, "Single world click expanded selection"
	)
	event.double_click = true
	root.get_node("MatchSignals").deselect_all_units.emit()
	tanks[0].input_event.emit(camera, event, tanks[0].position, Vector3.UP, 0)
	var selected = get_nodes_in_group("selected_units")
	_check(
		selected.size() == 2 and tanks.all(func(unit): return unit in selected),
		"World double-click did not select visible matching units"
	)
