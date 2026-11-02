extends RefCounted

## Reconcile only fresh legacy skirmish homes. Child order and archived fields stay intact.
const Stocks = preload("res://source/match/economy/ResourceFieldStocks.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const MAPS = [
	"BastionDesert",
	"DesertFrontier",
	"AlpineRelay",
	"IndustrialCrossroads",
	"CoastalFoundry",
	"PlainAndSimple",
	"BigArena"
]
const BASE_LAYOUT = [
	["CommandCenter", Vector2.ZERO],
	["PowerPlant", Vector2(-6, 0)],
	["Barracks", Vector2(0, -6)],
	["VehicleFactory", Vector2(6, 0)],
	["CommandLab", Vector2(6, 6)],
	["RepairDepot", Vector2(-6, 6)]
]
const CLEARANCE = 1.8  # 0.6m pile, worker hull and a little room beyond the baked edge.
const LAND_INSET = 1.8


static func standardize(game) -> bool:
	if (
		game.restoring
		or not game.settings.skirmish
		or not game.settings.mission_id.is_empty()
		or game.settings.map_path.get_file().get_basename() not in MAPS
	):
		return true
	var map = game.map
	var resources = map.get_node("Resources").find_children("*", "", true, false).filter(
		func(node): return node.is_in_group("resource_units")
	)
	var homes = []
	var moving = []
	var reservations = []
	var catalog = load("res://source/match/BastionCatalog.gd")
	var radii = {}
	for entry in BASE_LAYOUT:
		var prototype = load(catalog.scene_path(entry[0])).instantiate()
		radii[entry[0]] = prototype.get_node("MovementObstacle").radius
		prototype.free()
	for marker in map.get_node("SpawnPoints").get_children():
		var start = Vector2(marker.global_position.x, marker.global_position.z)
		start = start.clamp(Vector2(10, 10), map.size - Vector2(10, 10))
		var materials = resources.filter(func(node): return "resource_a" in node)
		materials.sort_custom(
			func(a, b): return _flat(a).distance_to(start) < _flat(b).distance_to(start)
		)
		var nearest = _flat(materials[0])
		var piles = materials.filter(func(node): return _flat(node).distance_to(nearest) < 10.0)
		var centre = Vector2.ZERO
		for pile in piles:
			centre += _flat(pile)
		centre /= piles.size()
		var chips = resources.filter(
			func(node): return "resource_b" in node and _flat(node).distance_to(centre) < 12.0
		)
		if piles.size() != 5 or chips.size() != 2 or piles.any(func(node): return node in moving):
			push_error("Legacy home field could not be identified: " + game.settings.map_path)
			return false
		homes.append(
			{"start": start, "direction": (centre - start).normalized(), "nodes": piles + chips}
		)
		moving.append_array(piles + chips)
		var facing = -1.0 if start.y > map.size.y / 2.0 else 1.0
		for entry in BASE_LAYOUT:
			reservations.append({"point": start + entry[1] * facing, "radius": radii[entry[0]]})
	var obstacles = map.find_children("*", "NavigationObstacle3D", true, false).filter(
		func(obstacle):
			return obstacle.affect_navigation_mesh and obstacle.get_parent() not in moving
	)
	var plans = []
	for home in homes:
		var plan = _choose(map, home, obstacles, reservations, plans)
		if plan.is_empty():
			push_error("Legacy home field has no safe nine-metre arc: " + game.settings.map_path)
			return false
		plans.append(plan)
	for index in homes.size():
		var nodes = homes[index].nodes
		var plan = plans[index]
		for slot in nodes.size():
			var node = nodes[slot]
			node.set(
				"resource_a" if slot < 5 else "resource_b", Stocks.STOCKS.home[0 if slot < 5 else 1]
			)
			node.relocate_field(map.ground_point(plan.points[slot]), map.ground_point(plan.origin))
	map.set_meta("home_field_plans", plans)
	return true


static func _choose(map, home, obstacles, reservations, plans) -> Dictionary:
	var heading = home.direction.angle()
	for radius in [9.0, 8.8, 9.2, 9.4, 9.6]:
		for step in 24:
			var angle = heading + (1 if step % 2 else -1) * ceili(step / 2.0) * PI / 12.0
			var points = []
			for index in 5:
				points.append(
					home.start + Vector2.from_angle(angle + (index - 2) * 2.6 / radius) * radius
				)
			if not points.all(
				func(point): return _legal(map, point, obstacles, reservations, plans)
			):
				continue
			# Electronics can turn around the end of the material arc when a shore or
			# an advanced base blocks its original outer slot. Material haul distances
			# remain on the same nine-metre arc for every faction.
			for side in [-1, 1]:
				var chip = _electronics_slot(
					map, home.start, angle, side, radius, points, obstacles, reservations, plans
				)
				if chip == Vector2.INF:
					break
				points.append(chip)
			if points.size() == 7:
				return {"origin": home.start + Vector2.from_angle(angle) * radius, "points": points}
	return _choose_distributed(map, home, obstacles, reservations, plans)


static func _choose_distributed(map, home, obstacles, reservations, plans) -> Dictionary:
	# Compact legacy advanced bases surround the HQ on three sides. Split the
	# same short material arc around those foundations instead of forcing a
	# pile between a building and the edge of the map.
	var heading = home.direction.angle()
	for radius in [9.0, 9.2, 9.4, 8.8, 9.6]:
		var points = []
		for slot in 7:
			var preferred = heading + (slot - 2) * 2.6 / radius
			for step in 48:
				var shift = (1 if step % 2 else -1) * ceili(step / 2.0) * PI / 24.0
				var point = (
					home.start
					+ Vector2.from_angle(preferred + shift) * (radius if slot < 5 else radius + .6)
				)
				if (
					_legal(map, point, obstacles, reservations, plans)
					and points.all(func(other): return point.distance_to(other) >= 2.6)
				):
					points.append(point)
					break
			if points.size() != slot + 1:
				break
		if points.size() == 7:
			return {"origin": home.start + Vector2.from_angle(heading) * radius, "points": points}
	return {}


static func _electronics_slot(
	map, start, heading, side, radius, points, obstacles, reservations, plans
):
	for offset in [0.6, 1.6, 2.6]:
		for step in 16:
			var angle = heading + side * (3.3 * 2.6 / radius + step * PI / 16.0)
			var point = start + Vector2.from_angle(angle) * (radius + offset)
			if (
				_legal(map, point, obstacles, reservations, plans)
				and points.all(func(other): return point.distance_to(other) >= 2.6)
			):
				return point
	return Vector2.INF


static func _legal(map, point, obstacles, reservations, plans) -> bool:
	var land = PackedVector2Array(map.get_topdown_polygon_2d())
	for index in 8:
		if not Geometry2D.is_point_in_polygon(
			point + Vector2.from_angle(index * TAU / 8.0) * LAND_INSET, land
		):
			return false
	for reservation in reservations:
		if point.distance_to(reservation.point) < reservation.radius + CLEARANCE:
			return false
	for plan in plans:
		for other in plan.points:
			if point.distance_to(other) < 2.6:
				return false
	for obstacle in obstacles:
		var polygon = PackedVector2Array()
		for vertex in obstacle.vertices:
			var world = obstacle.global_transform * vertex
			polygon.append(Vector2(world.x, world.z))
		if not polygon.is_empty():
			if Footprint.polygon_touches_circle(polygon, point, CLEARANCE):
				return false
		elif point.distance_to(_flat(obstacle)) < obstacle.radius + CLEARANCE:
			return false
	return true


static func _flat(node) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)
