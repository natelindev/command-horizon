extends "res://tests/headless/MechanicsRegression.gd"

var _movement_utils
var _planner


class GeometryMember:
	extends RefCounted
	var type = "Tank"
	var radius_reads = 0
	var position_reads = 0
	var source_radius = 1.0
	var source_position = Vector3.ZERO
	var radius:
		get:
			radius_reads += 1
			return source_radius
	var global_position:
		get:
			position_reads += 1
			return source_position


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_movement_utils = load("res://source/match/utils/UnitMovementUtils.gd")
	_planner = load("res://source/match/orders/FormationPlanner.gd")
	_geometry_capture()
	var manual = load("res://source/match/orders/ManualOrders.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		var members = []
		var roles = ["Tank", "Infantry", "Worker", "RepairRobot"]
		for index in 20:
			members.append(
				_spawn(
					roles[index % roles.size()],
					_human,
					Vector3(25 + (index % 5) * 4, 0, 30 + (index / 5) * 4)
				)
			)
		await _frames(20)
		paused = true
		for member in members:
			member.manual_orders.submit(
				manual.point_order("move", member.global_position + Vector3(0, 0, 8)), false, false
			)
		for formation in _planner.POSTURES:
			_verify(members, Vector3(60, 0, 60), formation, faction + " open")
			_verify(members, Vector3(.1, 0, .1), formation, faction + " boundary")
		# A new synchronous command must read live traits and origins again.
		# None of these facts may leak from the preceding plan.
		var movement = members[0].get_node("Movement")
		var radius = movement.radius
		movement.radius *= 1.5
		members[0].global_position += Vector3(1, 0, -1)
		members.reverse()
		_verify(members, Vector3(58, 0, 62), "staggered", faction + " changed members")
		movement.radius = radius
		_verify_automatic_headings(members, faction)
		if faction == "bastion":
			paused = false
			var aircraft = _spawn("Drone", _human, Vector3(15, 4, 62))
			await _frames(12)
			paused = true
			_verify_automatic_headings(members + [aircraft], "mixed ground/air")
		if "--native-crowd-runtime" in OS.get_cmdline_user_args():
			_check(
				members.all(func(member): return member.get_node("Movement")._native_handle >= 0),
				"Planning lost native crowd bindings"
			)
		else:
			_check(_game.crowd_runtime == null, "Planning enabled optional native movement")
		paused = false
		_game.queue_free()
		_fixtures.clear()
		await _frames(5)
		print("Formation planning faction=", faction, " failures=", _errors.size())
	for message in _errors:
		push_error(message)
	print("Formation planning regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _geometry_capture():
	var members = []
	var origins = PackedVector3Array()
	for index in 12:
		var member = GeometryMember.new()
		member.type = "Tank" if index < 4 else ("Infantry" if index < 8 else "Worker")
		member.source_radius = .4 + index * .1
		member.source_position = Vector3(index * 2.3, index * .1, (index % 4) * 1.7)
		members.append(member)
		origins.append(member.source_position)
	for formation in _planner.POSTURES:
		for custom in [0.0, 4.2]:
			for member in members:
				member.radius_reads = 0
			var points = _planner.positions(
				members, Vector3(52.3, 0, 47.6), Vector3(.31, 0, -.73), formation, custom
			)
			_check(
				members.all(func(member): return member.radius_reads == 1),
				"Geometry reread derived radii: " + formation
			)
			var captured = _planner.positions(
				members, Vector3(52.3, 0, 47.6), Vector3(.31, 0, -.73), formation, custom, 1.5
			)
			_check(captured == points, "Captured radius changed slots: " + formation)
			var expected = _planner.assign(members, points, formation)
			for member in members:
				member.position_reads = 0
			var assigned = _planner.assign(members, points, formation, origins)
			_check(assigned == expected, "Captured origins changed Hungarian assignment")
			_check(
				members.all(func(member): return member.position_reads == 0),
				"Assignment reread captured origins"
			)


func _verify_automatic_headings(members: Array, label: String):
	var controller = _human.get_node("UnitActionsController")
	var point = Vector3(57.31, 0, 59.73)
	var heading = point - _movement_utils.calculate_aabb_crowd_pivot_yless(members)
	var terrain = members.filter(func(member): return member.movement_domain == 1)
	var air = members.filter(func(member): return member.movement_domain == 0)
	for formation in _planner.POSTURES:
		for member in members:
			member.manual_orders.formation = formation
		for explicit in [null, Vector3(.37, 0, -.83)]:
			var expected = _movement_utils.crowd_moved_to_new_pivot(
				terrain, point, explicit, formation
			)
			expected += _movement_utils.crowd_moved_to_new_pivot(air, point, explicit, formation)
			var actual = controller._group_destinations(members, point, explicit, heading)
			_check(actual == expected, label + ": changed domain heading or endpoint: " + formation)


func _verify(members: Array, point: Vector3, formation: String, label: String):
	var before = _states(members)
	var pairs = _movement_utils.crowd_moved_to_new_pivot(members, point, Vector3.FORWARD, formation)
	_check(pairs.size() == members.size(), label + ": lost a formation member")
	_check(_states(members) == before, label + ": planning changed live orders or motion")
	var identities = {}
	for index in pairs.size():
		var unit = pairs[index][0]
		var destination: Vector3 = pairs[index][1]
		_check(not identities.has(unit), label + ": duplicated a formation member")
		identities[unit] = true
		var movement = unit.get_node("Movement")
		var projected = movement.project_command_point(destination)
		_check(
			(destination - projected * Vector3(1, 0, 1)).length() < .02,
			label + ": endpoint is not on its final owner's surface"
		)
		var path = NavigationServer3D.map_get_path(
			movement.get_navigation_map(), unit.global_position, projected, true
		)
		_check(
			not path.is_empty() and path[-1].distance_to(projected) <= .1,
			label + ": final owner cannot reach its endpoint"
		)
		for previous in range(index):
			var separation: float = unit.radius + pairs[previous][0].radius
			_check(
				destination.distance_to(pairs[previous][1]) >= separation - .001,
				label + ": projected hulls overlap"
			)
	_check(_states(members) == before, label + ": validation changed live orders or motion")


func _states(members: Array) -> Array:
	var result = []
	for member in members:
		var movement = member.get_node("Movement")
		result.append(
			[
				member.global_transform,
				member.action,
				movement.target_position,
				movement._command_revision,
				member.manual_orders.current.duplicate(true),
				member.manual_orders.pending.duplicate(true)
			]
		)
	return result
