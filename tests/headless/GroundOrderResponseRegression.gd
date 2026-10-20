extends "res://tests/headless/Skirmish.gd"

# Ground orders start on the press itself, a drag revises those same orders
# with formation and facing, and group destinations never cross paths.

var game
var human
var signals
var orders
var movement_utils
var issued = 0


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	orders = load("res://source/match/orders/ManualOrders.gd")
	signals = root.get_node("MatchSignals")
	movement_utils = root.get_node("Utils").Match.Unit.Movement
	root.get_node("SaveManager").autosaves_enabled = false
	game = await _start(_settings("bastion", "helix", false))
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	signals.unit_order_issued.connect(func(_unit, _kind): issued += 1)
	var center = Vector3(game.map.size.x / 2.0, 0, game.map.size.y / 2.0)
	var tanks = []
	for index in 9:
		var point = center + Vector3((index % 3) * 2.6, 0, (index / 3) * 2.6)
		var tank = load(Catalog.scene_path("Tank")).instantiate()
		game._setup_and_spawn_unit(tank, Transform3D(Basis(), point), human, false)
		tanks.append(tank)
	await _frames(30)
	await _press_and_drag(tanks, center)
	await _queued_revision(tanks, center)
	await _stale_revision(tanks, center)
	await _formation_assignment(tanks)
	game.queue_free()
	await _frames(4)
	for message in _errors:
		push_error(message)
	print("Ground order response: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _select(units):
	signals.deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()


func _press_and_drag(tanks, center):
	_select(tanks)
	issued = 0
	var point = center + Vector3(-12, 0, 6)
	signals.terrain_targeted.emit(point)
	for tank in tanks:
		_check(
			(
				tank.manual_orders.current.get("kind") == "move"
				and tank.manual_orders.pending.is_empty()
			),
			"Press did not start the move order in the same call"
		)
		_check(
			tank.get_node("Movement")._has_destination,
			"Press left movement without a destination until the next tick"
		)
	_check(issued == tanks.size(), "Press issued %d acknowledgements" % issued)
	var heading = Vector3(-1, 0, 0)
	var expected = {}
	for pair in movement_utils.crowd_moved_to_new_pivot(tanks, point, heading):
		expected[pair[0]] = pair[1]
	signals.terrain_target_heading_set.emit(point, heading)
	for tank in tanks:
		var current = tank.manual_orders.current
		_check(
			current.get("point", Vector3.INF).is_equal_approx(expected[tank]),
			"Drag did not revise the issued order to its formation slot"
		)
		_check(tank.manual_orders.pending.is_empty(), "Drag queued a second order")
		_check(
			tank.action._target_position.is_equal_approx(expected[tank]),
			"Drag left the running move on its press destination"
		)
	_check(issued == tanks.size(), "Drag repeated acknowledgements")
	await _frames(20)
	for tank in tanks:
		_check(tank.get_node("Movement")._has_destination, "Revised move stopped early")
	signals.deselect_all_units.emit()
	for tank in tanks:
		tank.issue_manual_order(null)


func _queued_revision(tanks, center):
	var first = center + Vector3(6, 0, -6)
	for tank in tanks:
		tank.manual_orders.submit(orders.point_order("move", first), false, false)
	_select(tanks)
	var held_key = InputMap.action_get_events("shift_selecting")[0].duplicate()
	held_key.keycode = held_key.physical_keycode
	held_key.pressed = true
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	var point = center + Vector3(10, 0, 8)
	signals.terrain_targeted.emit(point)
	var heading = Vector3(0, 0, 1)
	var expected = {}
	for pair in movement_utils.crowd_moved_to_new_pivot(tanks, point, heading):
		expected[pair[0]] = pair[1]
	signals.terrain_target_heading_set.emit(point, heading)
	held_key = held_key.duplicate()
	held_key.pressed = false
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	for tank in tanks:
		var pending = tank.manual_orders.pending
		_check(pending.size() == 1, "Queued drag changed the queue length")
		_check(
			pending.size() == 1 and pending[0].point.is_equal_approx(expected[tank]),
			"Queued drag did not revise the appended order"
		)
		_check(
			tank.manual_orders.current.get("point", Vector3.INF).is_equal_approx(first),
			"Queued drag replaced the running order"
		)
	signals.deselect_all_units.emit()
	for tank in tanks:
		tank.issue_manual_order(null)


func _stale_revision(tanks, center):
	_select(tanks)
	var point = center + Vector3(-6, 0, -6)
	signals.terrain_targeted.emit(point)
	var before = tanks.map(func(tank): return tank.manual_orders.current.point)
	signals.terrain_target_heading_set.emit(point + Vector3(3, 0, 0), Vector3(1, 0, 0))
	_check(
		tanks.map(func(tank): return tank.manual_orders.current.point) == before,
		"A drag from another press revised these orders"
	)
	signals.deselect_all_units.emit()
	for tank in tanks:
		tank.issue_manual_order(null)


func _formation_assignment(tanks):
	# A drag formation is a new shape. Slots were handed out greedily in
	# selection order, which sent units through each other into the line.
	var origin = Vector3(game.map.size.x / 2.0, 0, game.map.size.y / 2.0)
	for index in tanks.size():
		# A column in scrambled selection order, ordered into a line across it.
		tanks[index].global_position = origin + Vector3(0, 0, ((index * 4) % tanks.size()) * 2.6)
	await _frames(2)
	for heading in [Vector3(1, 0, 0), Vector3(-1, 0, 1).normalized()]:
		var pairs = movement_utils.calculate_formation_slots(
			tanks, origin + Vector3(14, 0, 10), heading
		)
		var crossings = 0
		for i in pairs.size():
			for j in range(i + 1, pairs.size()):
				if _segments_cross(
					pairs[i][0].global_position_yless,
					pairs[i][1] * Vector3(1, 0, 1),
					pairs[j][0].global_position_yless,
					pairs[j][1] * Vector3(1, 0, 1)
				):
					crossings += 1
		_check(crossings == 0, "Formation paths crossed %d times" % crossings)
		var unique = {}
		for pair in pairs:
			unique[pair[1].snapped(Vector3.ONE * .01)] = true
		_check(unique.size() == tanks.size(), "Formation slots were shared")
	# A plain translation keeps every unit's offset in the group.
	var spread = tanks.slice(0, 3)
	for index in spread.size():
		spread[index].global_position = origin + Vector3(index * 3.0, 0, 0)
	for tank in tanks.slice(3):
		tank.global_position = origin + Vector3(0, 0, 12)
	await _frames(2)
	# Choose open ground: a structure footprint legitimately displaces slots.
	var navmap = spread[0].get_node("Movement").get_navigation_map()
	var shift = Vector3.INF
	for candidate in [Vector3(8, 0, 4), Vector3(-8, 0, -4), Vector3(4, 0, 8), Vector3(-4, 0, 8)]:
		var open = true
		for tank in spread:
			for offset in [Vector3.ZERO, Vector3(1.4, 0, 0), Vector3(-1.4, 0, 0)]:
				var point = tank.global_position_yless + candidate + offset
				var nearest = NavigationServer3D.map_get_closest_point(navmap, point)
				open = open and ((nearest - point) * Vector3(1, 0, 1)).length() < .05
		if open:
			shift = candidate
			break
	_check(shift.is_finite(), "Translation fixture found no open ground")
	if not shift.is_finite():
		return
	var pivot = movement_utils.calculate_aabb_crowd_pivot_yless(spread)
	var pairs_moved = movement_utils.crowd_moved_to_new_pivot(spread, pivot + shift)
	for pair in pairs_moved:
		var translated = pair[0].global_position_yless + shift
		var nearest = pairs_moved.reduce(
			func(best, other):
				return (
					other
					if other[1].distance_to(translated) < best[1].distance_to(translated)
					else best
				)
		)
		_check(nearest[0] == pair[0], "Translation swapped units within the group")


func _segments_cross(a, b, c, d):
	var ab = b - a
	var cd = d - c
	var denominator = ab.x * cd.z - ab.z * cd.x
	if absf(denominator) < .000001:
		return false
	var t = ((c.x - a.x) * cd.z - (c.z - a.z) * cd.x) / denominator
	var u = ((c.x - a.x) * ab.z - (c.z - a.z) * ab.x) / denominator
	return t > .001 and t < .999 and u > .001 and u < .999
