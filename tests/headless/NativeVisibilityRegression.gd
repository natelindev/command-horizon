extends "res://tests/headless/TerrainSightRegression.gd"


## Compare complete observation and fire queries with the retained script path.
## Both run on the same live objects, including changes inside one physics tick.
class Observer:
	extends Node3D
	var player
	var sight_range = 18.0
	var hp = 100.0
	var radius = 2.0
	var movement_domain = 1
	var constructed = true
	var range_factor = 1.1

	func is_constructed():
		return constructed

	func effective_sight_range(_point = null):
		return sight_range * range_factor


var _native: RefCounted
var _comparisons = 0


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	await _create_match()
	model = game.map.terrain
	var field = game.battlefield
	_native = field._native_visibility
	if _native == null:
		_check(false, "Run this test with --native-visibility-runtime; native queries are required")
	else:
		await _compare_queries()
	_check(_comparisons == 19200, "Full native/script comparison loop did not complete")
	await _close()
	for message in _errors:
		push_error(message)
	print(
		(
			"Native visibility: %d failures across %d full-query comparisons"
			% [_errors.size(), _comparisons]
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _compare_queries():
	var field = game.battlefield
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	var units := []
	for role in ["Tank", "Infantry", "Fighter", "Helicopter", "AircraftFactory", "RepairDepot"]:
		for player in [human, enemy]:
			units.append(_spawn_unit(role, player, Vector3(80 + units.size() * 3, 0, 80)))
	var generic = Observer.new()
	generic.player = human
	game.add_child(generic)
	generic.add_to_group("vision_sources")
	game.invalidate_vision_registry()
	_check(generic in game.get_observers(), "Generic observer was absent from the real query index")
	units.append(generic)
	await _frames(10)
	for unit in units:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var random := RandomNumberGenerator.new()
	random.seed = 913207
	var landmarks = [
		Vector2(54, 20),
		Vector2(65, 110),
		Vector2(110, 65),
		Vector2(48, 44),
		Vector2(96, 80),
		Vector2(30, 30)
	]
	for iteration in 2400:
		var observer = units[iteration % units.size()]
		var target = units[(iteration * 7 + 1) % units.size()]
		if observer == target:
			target = units[(iteration + 1) % units.size()]
		var centre: Vector2 = landmarks[iteration % landmarks.size()]
		var start := centre + Vector2(random.randf_range(-8, 8), random.randf_range(-8, 8))
		var end := centre + Vector2(random.randf_range(-30, 30), random.randf_range(-30, 30))
		observer.position = Vector3(start.x, model.height_at(start), start.y)
		target.position = Vector3(end.x, model.height_at(end), end.y)
		if iteration % 5 == 0:
			observer.position.y += 8.0
		if iteration % 7 == 0:
			target.position.y += 8.0
		observer.rotation.y = random.randf_range(-PI, PI)
		target.rotation.y = random.randf_range(-PI, PI)
		# The same host affects both range and source-blocker exclusions.
		if iteration % 11 == 0:
			observer.set_meta("garrison_host", units[8])
		else:
			observer.remove_meta("garrison_host")
		generic.constructed = iteration % 4 != 0
		generic.hp = 0.0 if iteration % 6 == 0 else 100.0
		generic.sight_range = 4.0 if iteration % 3 == 0 else 22.0
		generic.range_factor = 1.5 if iteration % 5 == 0 else 1.0
		generic.player = enemy if iteration % 2 == 0 else human
		if iteration % 13 == 0:
			generic.add_to_group("neutral_buildings")
		else:
			generic.remove_from_group("neutral_buildings")
		for structure in [units[8], units[9], units[10], units[11]]:
			structure._construction_progress = 1.0 if iteration % 3 == 0 else .5
		field.invalidate()
		field._refresh()
		var point: Vector3 = target.global_position + Vector3.UP * .8
		_compare("can_observe_point", [observer, point, target], iteration)
		_compare("can_observe", [observer, target], iteration)
		_compare("has_line_of_fire", [observer, target], iteration)
		_compare("is_observed", [human, target], iteration)
		_compare("is_observed", [enemy, target], iteration)
		_compare(
			"line_clear",
			[observer.global_position + Vector3.UP * .8, point, observer, target],
			iteration
		)
		# A second query after changing ownership/life/range tests witness revalidation.
		generic.player = human if generic.player == enemy else enemy
		generic.hp = 100.0 - generic.hp
		generic.position = target.position + Vector3(1, 0, 1)
		_compare("is_observed", [human, target], iteration)
		_compare("can_observe_point", [generic, point, target], iteration)
	for unit in units:
		unit.remove_meta("garrison_host")
	var statistics: Array = _native.statistics()
	if "--profile-runtime" in OS.get_cmdline_user_args():
		var timings: Array = _native.profile(false)
		_check(
			timings.size() == 10 and timings[2] > 0 and timings[7] > 0,
			"Native profile clock/point counters did not execute"
		)
	_check(
		statistics.size() == 5 and statistics[0] > 0 and statistics[1] > 0 and statistics[2] > 0,
		"Native observation, point and obstruction loops did not execute"
	)


func _compare(method: String, arguments: Array, iteration: int):
	var field = game.battlefield
	var resident: bool = field.native_battlefield_index
	var indexing: bool = field._native_index
	field._native_visibility = null
	if resident:
		field.native_battlefield_index = false
		field._native_index = false
		field.invalidate()
		field._refresh()
	var bounds = [field._max_sight, field._max_unit_radius, field._max_body_step]
	var expected = field.callv(method, arguments)
	field._native_visibility = _native
	if resident:
		field.native_battlefield_index = true
		field._native_index = indexing
		field.invalidate()
		field._refresh()
		_check(
			bounds == [field._max_sight, field._max_unit_radius, field._max_body_step],
			"Resident terrain index bounds differ"
		)
	var actual = field.callv(method, arguments)
	_comparisons += 1
	if expected != actual and _errors.size() < 30:
		_check(
			false,
			"%s differed in case %d: script=%s native=%s" % [method, iteration, expected, actual]
		)
