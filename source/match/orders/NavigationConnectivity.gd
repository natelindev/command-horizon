extends RefCounted

## Match-owned navigation components. Projection remains authoritative in the
## NavigationServer; component membership avoids repeating the same route search
## for every slot in a large formation. Ambiguous points retain the server oracle.
const CELL = 8.0
const POINT_CACHE_LIMIT = 8192


static func warm(navigation, domain: int, hovering = false):
	var region = (
		navigation.hover.region
		if hovering and navigation.hover != null
		else (
			navigation.air._navigation_region
			if domain == 0
			else navigation.terrain._navigation_region
		)
	)
	if region == null:
		return null
	var nav = region.get_navigation_map()
	if domain == 1 and not hovering and not navigation.terrain.is_synchronized():
		return null
	if hovering and not navigation.hover.is_synchronized():
		return null
	var iteration = NavigationServer3D.map_get_iteration_id(nav)
	if iteration == 0:
		return null
	var cache = navigation.connectivity_cache.get(nav)
	if cache != null and cache.iteration == iteration:
		return cache
	var mesh = region.navigation_mesh
	var vertices = mesh.get_vertices()
	var canonical = []
	var identities = {}
	for index in vertices.size():
		vertices[index] = region.global_transform * vertices[index]
		var key = vertices[index].snapped(Vector3.ONE * .001)
		if not identities.has(key):
			identities[key] = identities.size()
		canonical.append(identities[key])
	var parents = range(mesh.get_polygon_count())
	var edges = {}
	var shapes = []
	for index in mesh.get_polygon_count():
		var indices = mesh.get_polygon(index)
		var polygon = PackedVector2Array()
		var low = Vector2(INF, INF)
		var high = Vector2(-INF, -INF)
		for corner in indices.size():
			var vertex = vertices[indices[corner]]
			var point = Vector2(vertex.x, vertex.z)
			polygon.append(point)
			low = low.min(point)
			high = high.max(point)
			var first = canonical[indices[corner]]
			var second = canonical[indices[(corner + 1) % indices.size()]]
			var edge = Vector2i(mini(first, second), maxi(first, second))
			if edges.has(edge):
				parents[_root(parents, index)] = _root(parents, edges[edge])
			else:
				edges[edge] = index
		if indices.size() >= 3:
			var plane = Plane(vertices[indices[0]], vertices[indices[1]], vertices[indices[2]])
			shapes.append(
				{"polygon": polygon, "plane": plane, "low": low, "high": high, "component": index}
			)
	var cells = {}
	for shape in shapes:
		shape.component = _root(parents, shape.component)
		for x in range(floori(shape.low.x / CELL), floori(shape.high.x / CELL) + 1):
			for z in range(floori(shape.low.y / CELL), floori(shape.high.y / CELL) + 1):
				var key = Vector2i(x, z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(shape)
	var grouped_cells = {}
	for cell_key in cells:
		var groups = {}
		for shape in cells[cell_key]:
			var plane: Plane = shape.plane
			var key = (
				str(shape.component)
				+ ":"
				+ str(
					Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d).snapped(
						Vector4.ONE * .001
					)
				)
			)
			if not groups.has(key):
				groups[key] = {"component": shape.component, "plane": plane}
		grouped_cells[cell_key] = groups.values()
	cache = {
		"iteration": iteration,
		"cells": cells,
		"groups": grouped_cells,
		"points": {},
		"links": {},
		"parents": parents,
		"server_queries": 0
	}
	navigation.connectivity_cache[nav] = cache
	return cache


static func _root(parents: Array, index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index


static func _component(cache: Dictionary, point: Vector3) -> int:
	var key = Vector2i(floori(point.x / CELL), floori(point.z / CELL))
	var component = -1
	var ambiguous = false
	for group in cache.groups.get(key, []):
		if absf(group.plane.distance_to(point)) > .03:
			continue
		var candidate = _root(cache.parents, group.component)
		if component >= 0 and component != candidate:
			ambiguous = true
			break
		component = candidate
	if component >= 0 and not ambiguous:
		# The caller supplies an already projected point. A single coplanar
		# component in its cell therefore needs no repeated polygon tests.
		return component
	var flat = Vector2(point.x, point.z)
	for shape in cache.cells.get(key, []):
		if (
			absf(shape.plane.distance_to(point)) <= .03
			and Geometry2D.is_point_in_polygon(flat, shape.polygon)
		):
			return _root(cache.parents, shape.component)
	return -1


static func context(movement) -> Dictionary:
	var navigation = movement._match.navigation
	var expected = (
		navigation.hover.navigation_map_rid
		if movement._hovering
		else navigation.get_navigation_map_rid_by_domain(movement.domain)
	)
	var nav = movement.get_navigation_map()
	return {
		"map": nav,
		"query": navigation.path_query,
		"cache": warm(navigation, movement.domain, movement._hovering) if expected == nav else null,
		"projected": {}
	}


static func can_reach(movement, origin: Vector3, projected: Vector3, context_value = null) -> bool:
	var value = context(movement) if context_value == null else context_value
	var nav = value.map
	var cache = value.cache
	if cache != null:
		if cache.points.size() >= POINT_CACHE_LIMIT:
			cache.points.clear()
		if not cache.points.has(origin):
			# Flat terrain indexing proves exact vertical projection on the lowest
			# surface; retain the server oracle for elevated and hover maps.
			var from = (
				movement.project_command_point(origin)
				if movement.domain == 1 and not movement._hovering and not movement._elevated
				else NavigationServer3D.map_get_closest_point(nav, origin)
			)
			cache.points[origin] = _component(cache, from)
		var first = cache.points[origin]
		if not cache.points.has(projected):
			cache.points[projected] = _component(cache, projected)
		var second = cache.points[projected]
		if first >= 0 and second >= 0:
			first = _root(cache.parents, first)
			second = _root(cache.parents, second)
			if first == second:
				return true
			var pair = Vector2i(mini(first, second), maxi(first, second))
			if cache.links.has(pair):
				return cache.links[pair]
			var path = value.query.path(nav, origin, projected)
			cache.server_queries += 1
			var reachable = not path.is_empty() and path[-1].distance_to(projected) <= .1
			cache.links[pair] = reachable
			if reachable:
				cache.parents[first] = second
			return reachable
	if cache != null:
		cache.server_queries += 1
	var fallback = value.query.path(nav, origin, projected)
	return not fallback.is_empty() and fallback[-1].distance_to(projected) <= .1
