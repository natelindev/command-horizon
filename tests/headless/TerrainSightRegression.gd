extends "res://tests/headless/TerrainNavRegression.gd"

# Combat visibility on authored terrain (TerrainTestMap): ground, cliffs,
# formations and forest occlude sight; forest does not stop shots; low ground
# cannot see up onto higher tiers without a spotter; and the fog of war reveals
# the same ground the visibility rules do.

const Sight = preload("res://source/match/maps/terrain/TerrainSight.gd")
var model


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	await _create_match()
	model = game.map.terrain
	_check_lines()
	await _check_high_ground()
	_check_fog_agreement()
	_check_cost()
	await _close()
	for message in _errors:
		push_error(message)
	print("Terrain sight: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _eye(x, z):
	return Vector3(x, model.height_at(Vector2(x, z)) + Sight.EYE, z)


func _line(a, b, expected, message, forest_blocks = true):
	var clear = Sight.segment_clear(model, _eye(a.x, a.y), _eye(b.x, b.y), forest_blocks)
	_check(clear == expected, "%s: sight %s" % [message, "clear" if clear else "blocked"])


func _check_lines():
	_line(Vector2(80, 80), Vector2(112, 80), false, "Mesa between low units")
	_line(Vector2(54, 20), Vector2(70, 20), true, "Plateau lip over low ground")
	_line(Vector2(40, 20), Vector2(58, 20), false, "Dead ground beneath the cliff")
	_line(Vector2(60, 110), Vector2(67.5, 110), true, "Forest edge")
	_line(Vector2(60, 110), Vector2(72, 110), false, "Deep forest")
	_line(Vector2(72, 108), Vector2(76, 110), true, "Within forest at close range")
	_line(Vector2(60, 110), Vector2(72, 110), true, "Shots pass through forest", false)
	_line(Vector2(105, 64), Vector2(126, 66), false, "Formation between")
	_line(Vector2(105, 64), Vector2(126, 66), false, "Shots stop at a formation", false)
	_line(Vector2(47, 43), Vector2(43, 39), true, "Up a ramp")
	_check(
		Sight.high_ground_hidden(model, Vector2(62, 20), Vector2(52, 20)),
		"Low ground sees onto the plateau"
	)
	_check(
		not Sight.high_ground_hidden(model, Vector2(47, 43), Vector2(43, 39)),
		"High ground rule hides the ramp top from mid-ramp"
	)
	_check(
		not Sight.high_ground_hidden(model, Vector2(52, 20), Vector2(62, 20)),
		"High ground cannot see down"
	)


func _check_high_ground():
	var players = get_nodes_in_group("players")
	var human = game._get_human_player()
	var enemy = players.filter(func(player): return player != human)[0]
	var low = _spawn_unit("Tank", human, Vector3(62, 0, 20))
	var high = _spawn_unit("Tank", enemy, Vector3(54.5, 3, 20))
	await _frames(20)
	var battlefield = game.battlefield
	_check(battlefield.is_observed(enemy, low), "High ground does not see the low tank")
	_check(not battlefield.is_observed(human, high), "Low tank sees onto the plateau")
	_check(not battlefield.can_fire(low, high), "Low tank fires at an unseen plateau target")
	var spotter = _spawn_unit("Infantry", human, Vector3(50, 3, 24))
	await _frames(20)
	battlefield.invalidate()
	_check(battlefield.is_observed(human, high), "Plateau spotter does not reveal the target")
	_check(battlefield.can_fire(low, high), "Spotted plateau target cannot be fired upon")
	for unit in [low, high, spotter]:
		unit.queue_free()
	await _frames(5)


func _spawn_unit(type, player, position):
	var unit = load("res://source/match/units/%s.tscn" % type).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), position), player)
	unit.set_process(false)
	return unit


# Each fog reveal must show what the visibility rules show; a point counts
# as a disagreement only when its neighbours half a metre away agree with it.
func _check_fog_agreement():
	var reach = 12.0
	for observer in [
		Vector2(50, 20),
		Vector2(62, 20),
		Vector2(60, 110),
		Vector2(105, 64),
		Vector2(47, 43),
		Vector2(88, 72),
		Vector2(140, 100)
	]:
		var triangles = Sight.reveal_triangles(model, observer, reach)
		var total = 0
		var wrong = 0
		for x in range(-12, 13):
			for z in range(-12, 13):
				var target = observer + Vector2(x, z)
				if target.distance_to(observer) > reach - 0.5 or target.distance_to(observer) < 1:
					continue
				total += 1
				var differs = true
				for offset in [Vector2.ZERO, Vector2(.5, 0), Vector2(-.5, 0), Vector2(0, .5)]:
					var point = target + offset
					if _seen(observer, point) == _revealed(triangles, observer, point, reach):
						differs = false
						break
				if differs:
					wrong += 1
		print("Fog agreement at %s: %d/%d differ" % [observer, wrong, total])
		_check(wrong <= total * 0.02, "Fog disagrees with sight at %s (%d)" % [observer, wrong])


func _seen(observer, target):
	return (
		not Sight.high_ground_hidden(model, observer, target)
		and Sight.segment_clear(model, _eye(observer.x, observer.y), _eye(target.x, target.y))
	)


func _revealed(triangles, observer, point, reach):
	if triangles.is_empty():
		return point.distance_to(observer) <= reach
	for index in range(0, triangles.size(), 3):
		if Geometry2D.point_is_inside_triangle(
			point, triangles[index], triangles[index + 1], triangles[index + 2]
		):
			return true
	return false


func _check_cost():
	# Best of three passes: one scheduler stall must not fail the budget.
	var per_line = INF
	for attempt in 3:
		var begun = Time.get_ticks_usec()
		var count = 0
		for x in range(10, 180, 7):
			for z in range(10, 150, 7):
				Sight.segment_clear(model, _eye(x, z), _eye(x + 9, z + 5))
				count += 1
		per_line = minf(per_line, float(Time.get_ticks_usec() - begun) / count)
	var started = Time.get_ticks_usec()
	for x in range(10, 180, 17):
		for z in range(10, 150, 17):
			Sight.reveal_triangles(model, Vector2(x, z), 12.0)
	var outlines = (Time.get_ticks_usec() - started) / 1000.0
	print("Sight line %.1f us average; fog outlines over the map %.1f ms" % [per_line, outlines])
	_check(per_line < 60.0, "Sight lines too slow: %.1f us" % per_line)
