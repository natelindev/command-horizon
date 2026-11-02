extends RefCounted

## Tiles are baking work units. Publish one stitched mesh only after the whole
## batch completes, preserving the single-region contract of native consumers.
const TILE_METRES = 32.0
const MAX_WORKERS = 2
const WELD = .0001
var meshes: Array[NavigationMesh] = []
var bounds: Array[Rect2] = []
var last_baked_tiles := 0
var _template: NavigationMesh
var _step := 0.0
var _border := 0.0
var _snapshot := {}
var _had_unknown := false
var _source: NavigationMeshSourceGeometryData3D
var _pending: Array[int] = []
var _active := 0
var _finished: Callable


func setup(template: NavigationMesh, source: NavigationMeshSourceGeometryData3D):
	_template = template.duplicate()
	_template.clear()
	_step = ceilf(TILE_METRES / template.cell_size) * template.cell_size
	_border = (
		ceilf((template.agent_radius + template.cell_size * 3.0) / template.cell_size)
		* template.cell_size
	)
	var area := template.filter_baking_aabb
	var count := Vector2i(ceili(area.size.x / _step), ceili(area.size.z / _step))
	for z in count.y:
		for x in count.x:
			var origin := Vector2(area.position.x, area.position.z) + Vector2(x, z) * _step
			var end := Vector2(area.end.x, area.end.z).min(origin + Vector2.ONE * _step)
			bounds.append(Rect2(origin, end - origin))
			var tile: NavigationMesh = _template.duplicate()
			tile.border_size = _border
			tile.edge_max_error = minf(1.0, tile.edge_max_error)
			# World-aligned voxel origins, with enough neighbor geometry for erosion.
			tile.filter_baking_aabb = AABB(
				Vector3(origin.x - _border, area.position.y, origin.y - _border),
				Vector3(
					end.x - origin.x + _border * 2.0, area.size.y, end.y - origin.y + _border * 2.0
				)
			)
			NavigationServer3D.bake_from_source_geometry_data(tile, source)
			meshes.append(tile)
	last_baked_tiles = meshes.size()


func rebake(nodes: Array, source: NavigationMeshSourceGeometryData3D, finished: Callable):
	assert(_active == 0 and _pending.is_empty())
	var current := {}
	var changed: Array[Rect2] = []
	var all_tiles := _had_unknown
	_had_unknown = false
	for node in nodes:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if not node is NavigationObstacle3D:
			# Unknown source geometry has no cheap, reliable change signature.
			all_tiles = true
			_had_unknown = true
			continue
		var obstacle: NavigationObstacle3D = node
		if not obstacle.affect_navigation_mesh:
			continue
		var outline := obstacle.vertices
		var signature := [
			obstacle.global_transform,
			outline,
			obstacle.height,
			obstacle.carve_navigation_mesh,
			obstacle.radius
		]
		var rectangle := Rect2(
			Vector2(obstacle.global_position.x, obstacle.global_position.z), Vector2.ZERO
		)
		if outline.is_empty():
			var reach: float = (
				obstacle.radius
				* maxf(
					absf(obstacle.global_basis.get_scale().x),
					absf(obstacle.global_basis.get_scale().z)
				)
			)
			rectangle = rectangle.grow(reach)
		for vertex in outline:
			var world := obstacle.global_transform * vertex
			rectangle = rectangle.expand(Vector2(world.x, world.z))
		var key := obstacle.get_instance_id()
		current[key] = {"signature": signature, "bounds": rectangle}
		if not _snapshot.has(key) or _snapshot[key].signature != signature:
			changed.append(rectangle)
			if _snapshot.has(key):
				changed.append(_snapshot[key].bounds)
	for key in _snapshot:
		if not current.has(key):
			changed.append(_snapshot[key].bounds)
	_snapshot = current
	for index in bounds.size():
		var dirty := all_tiles
		for rectangle in changed:
			if bounds[index].grow(_border).intersects(rectangle, true):
				dirty = true
				break
		if dirty:
			_pending.append(index)
	last_baked_tiles = _pending.size()
	_source = source
	_finished = finished
	_start_jobs()


func cancel():
	_pending.clear()
	_finished = Callable()


func _start_jobs():
	while _active < MAX_WORKERS and not _pending.is_empty():
		var index: int = _pending.pop_back()
		_active += 1
		NavigationServer3D.bake_from_source_geometry_data_async(
			meshes[index], _source, _tile_finished.bind(index)
		)
	if _active == 0:
		_source = null
		var callback := _finished
		_finished = Callable()
		if callback.is_valid():
			callback.call()


func _tile_finished(_index: int):
	# Keep publication and subsequent jobs on the scene thread.
	_complete_tile.call_deferred()


func _complete_tile():
	_active -= 1
	_start_jobs()


func combined() -> NavigationMesh:
	var result: NavigationMesh = _template.duplicate()
	var vertices := PackedVector3Array()
	var identities: Dictionary[Vector3, int] = {}
	var polygons: Array[PackedInt32Array] = []
	for tile in meshes:
		var remap := PackedInt32Array()
		for vertex in tile.get_vertices():
			var key := vertex.snapped(Vector3.ONE * WELD)
			if not identities.has(key):
				identities[key] = vertices.size()
				vertices.append(vertex)
			remap.append(identities[key])
		for index in tile.get_polygon_count():
			var polygon := PackedInt32Array()
			for corner in tile.get_polygon(index):
				polygon.append(remap[corner])
			polygons.append(polygon)
	# Adjacent tiles can simplify the same edge into different segment lengths.
	# Insert the shared collinear vertices so every seam has matching edges.
	var seams := _seam_vertices(vertices)
	result.set_vertices(vertices)
	for polygon in polygons:
		result.add_polygon(_split_seams(polygon, vertices, seams))
	return result


func _seam_vertices(vertices: PackedVector3Array) -> Dictionary:
	var result := {}
	var origin := _template.filter_baking_aabb.position
	for index in vertices.size():
		var vertex := vertices[index]
		for axis in [0, 2]:
			var steps: float = (vertex[axis] - origin[axis]) / _step
			if absf(steps - roundf(steps)) * _step <= WELD * 2.0:
				var key := Vector2i(axis, roundi(vertex[axis] / WELD))
				result.get_or_add(key, []).append(index)
	return result


static func _split_seams(
	polygon: PackedInt32Array, vertices: PackedVector3Array, seams: Dictionary
) -> PackedInt32Array:
	var result := PackedInt32Array()
	for corner in polygon.size():
		var first := vertices[polygon[corner]]
		var second := vertices[polygon[(corner + 1) % polygon.size()]]
		result.append(polygon[corner])
		var delta := second - first
		var length := delta.length_squared()
		if length < WELD * WELD:
			continue
		for axis in [0, 2]:
			if absf(delta[axis]) > WELD:
				continue
			var key := Vector2i(axis, roundi(first[axis] / WELD))
			var inside: Array[Vector2] = []
			for index in seams.get(key, []):
				var offset := vertices[index] - first
				var along := offset.dot(delta) / length
				if (
					along > WELD
					and along < 1.0 - WELD
					and (offset - delta * along).length_squared() < WELD * WELD * 4.0
				):
					inside.append(Vector2(along, index))
			inside.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
			for item in inside:
				result.append(int(item.y))
			break
	# Consumers construct a plane from the first three corners. Begin at a turn,
	# rather than with three collinear seam samples.
	for corner in result.size():
		var a := vertices[result[corner]]
		var b := vertices[result[(corner + 1) % result.size()]]
		var c := vertices[result[(corner + 2) % result.size()]]
		if (b - a).cross(c - b).length_squared() > WELD * WELD:
			var rotated := PackedInt32Array()
			for offset in result.size():
				rotated.append(result[(corner + offset) % result.size()])
			return rotated
	return result
