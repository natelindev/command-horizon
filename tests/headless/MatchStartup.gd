extends SceneTree

const MAP_PATHS = [
	"res://source/match/maps/PlainAndSimple.tscn",
	"res://source/match/maps/BigArena.tscn",
]

var _failures = []


func _initialize():
	call_deferred("_run")


func _run():
	for map_path in MAP_PATHS:
		await _test_map(map_path)
	if _failures.is_empty():
		print("PASS: spawn positions, navigation domains, and ground/air movement on both maps")
	else:
		for failure in _failures:
			push_error(failure)
	await root.get_node("Globals").quit_game(0 if _failures.is_empty() else 1)


func _test_map(map_path):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	for index in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = 1 if index == 0 else 2
		settings.players.append(player)
	var game = load("res://source/match/Match.tscn").instantiate()
	game.settings = settings
	game.map = load(map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	var spawn = game.map.find_child("SpawnPoints").get_child(0).global_position
	var units = get_nodes_in_group("controlled_units")
	# Wait long enough to include initial alignment and the structure-triggered rebake.
	for _frame in range(60):
		await physics_frame
	for unit in units:
		_check(
			unit.global_position_yless.distance_to(spawn) < 6.0,
			map_path + ": " + unit.name + " moved away from its initial base"
		)
		var expected_height = 1.5 if unit.type == "Drone" else 0.0
		_check(
			abs(unit.global_position.y - expected_height) < 0.1,
			map_path + ": " + unit.name + " aligned to the wrong navigation height"
		)
	for domain in [game.navigation.air, game.navigation.terrain]:
		var region = domain.find_child("NavigationRegion3D")
		_check(
			region.get_navigation_map() == domain.navigation_map_rid,
			map_path + ": navigation region lost its assigned map"
		)
		_check(
			(
				NavigationServer3D
				. map_get_closest_point_owner(domain.navigation_map_rid, spawn)
				. is_valid()
			),
			map_path + ": baked navigation is not queryable"
		)
	var movable_units = units.filter(func(unit): return unit.type in ["Worker", "Drone"])
	var starts = {}
	for unit in movable_units:
		starts[unit] = unit.global_position_yless
		var target = unit.global_position_yless + Vector3(0, 0, 3)
		unit.action = load("res://source/match/units/actions/Moving.gd").new(target)
	for _frame in range(120):
		await physics_frame
	for unit in movable_units:
		_check(
			unit.global_position_yless.distance_to(starts[unit]) > 1.0,
			map_path + ": " + unit.name + " could not move on its navigation map"
		)
	game.queue_free()
	await process_frame
	await physics_frame


func _check(condition, message):
	if not condition:
		_failures.append(message)
