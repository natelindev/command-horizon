extends Node3D

const DOMAIN = Constants.Match.Navigation.Domain.TERRAIN
const ELEVATED_MAX_CLIMB = 0.6
# Baked walkable surfaces sit about one voxel step above the authored ground.
const SURFACE_LIFT = 0.5
const SURFACE_MATCH = 0.35

var _earliest_frame_to_perform_next_rebake = null
var _is_baking = false
var _iteration_before_publication = -1
var _region_before_publication = -1
var _projection_cells = {}
var _projection_height = INF
var _projection_tolerance = INF
var _elevated = false
var _map = null
var _projection_iteration = -1
var _map_geometry = NavigationMeshSourceGeometryData3D.new()

# A match owns its navigation lifetime. Reusing the viewport's world map can
# expose the previous battle's synchronized polygons during the next startup.
@onready var navigation_map_rid = NavigationServer3D.map_create()

@onready var _navigation_region = find_child("NavigationRegion3D")
@onready var _reference_static_collider_shape = find_child("CollisionShape3D")


func _ready():
	assert(_safety_checks())
	NavigationServer3D.map_set_cell_size(
		navigation_map_rid, Constants.Match.Terrain.Navmesh.CELL_SIZE
	)
	NavigationServer3D.map_set_cell_height(
		navigation_map_rid, Constants.Match.Terrain.Navmesh.CELL_HEIGHT
	)
	_navigation_region.set_navigation_map(navigation_map_rid)
	NavigationServer3D.map_set_active(navigation_map_rid, true)
	MatchSignals.schedule_navigation_rebake.connect(_on_schedule_navigation_rebake)


func _exit_tree():
	NavigationServer3D.free_rid(navigation_map_rid)


func _process(_delta):
	if (
		not _is_baking
		and _earliest_frame_to_perform_next_rebake != null
		and get_tree().get_frame() >= _earliest_frame_to_perform_next_rebake
	):
		_is_baking = true
		_earliest_frame_to_perform_next_rebake = null
		_rebake()


func bake(map):
	assert(
		_navigation_region.navigation_mesh.get_polygon_count() == 0,
		"bake() should be called exactly once - during runtime"
	)
	if _reference_static_collider_shape != null:
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(map.navigation_source_faces())
		_reference_static_collider_shape.shape = shape
	# setting custom AABB for baking so that height of dynamic AABB is always the same
	# - without such setting, re-baking may yield different results depending on geometry height
	var mesh: NavigationMesh = _navigation_region.navigation_mesh
	mesh.filter_baking_aabb = AABB(Vector3.ZERO, Vector3(map.size.x, 5.0, map.size.y))
	_elevated = map.is_elevated()
	_map = map if _elevated else null
	if _elevated:
		# Tiers and ramps: two voxels of climb joins ramp cells; cliffs stay walls.
		mesh.agent_max_climb = ELEVATED_MAX_CLIMB
		mesh.filter_baking_aabb = AABB(
			Vector3(0, -1, 0), Vector3(map.size.x, map.max_height() + 5.0, map.size.y)
		)
	NavigationServer3D.parse_source_geometry_data(
		_navigation_region.navigation_mesh, _map_geometry, get_tree().root
	)
	for node in get_tree().get_nodes_in_group("terrain_navigation_input"):
		node.remove_from_group("terrain_navigation_input")
	NavigationServer3D.bake_from_source_geometry_data(
		_navigation_region.navigation_mesh, _map_geometry
	)
	_sync_navmesh_changes()


func _rebake():
	# parse geometry other than map itself
	var full_geometry = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		_navigation_region.navigation_mesh, full_geometry, get_tree().root
	)
	# add pre-parsed map geometry
	full_geometry.merge(_map_geometry)

	NavigationServer3D.bake_from_source_geometry_data_async(
		_navigation_region.navigation_mesh, full_geometry, _on_bake_finished
	)


# TODO: remove whenever Godot fixes that on its side
func _sync_navmesh_changes():
	_projection_iteration = -1
	"""this function forces synchronization between server-level primitives and nodes"""
	_navigation_region.navigation_mesh = _navigation_region.navigation_mesh
	_iteration_before_publication = NavigationServer3D.map_get_iteration_id(navigation_map_rid)
	_region_before_publication = NavigationServer3D.region_get_iteration_id(
		_navigation_region.get_rid()
	)


func is_synchronized():
	return (
		not _is_baking
		and _earliest_frame_to_perform_next_rebake == null
		and (
			NavigationServer3D.region_get_iteration_id(_navigation_region.get_rid())
			> _region_before_publication
		)
		and (
			NavigationServer3D.map_get_iteration_id(navigation_map_rid)
			> _iteration_before_publication
		)
	)


func _safety_checks():
	assert(
		is_equal_approx(
			_navigation_region.navigation_mesh.agent_radius,
			Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
		),
		"Navmesh 'agent_radius' must match established constant"
	)
	assert(
		is_equal_approx(
			_navigation_region.navigation_mesh.cell_size, Constants.Match.Terrain.Navmesh.CELL_SIZE
		),
		"Navmesh 'cell_size' must match established constant"
	)
	assert(
		is_equal_approx(
			_navigation_region.navigation_mesh.cell_height,
			Constants.Match.Terrain.Navmesh.CELL_HEIGHT
		),
		"Navmesh 'cell_height' must match established constant"
	)
	return true


func _on_schedule_navigation_rebake(domain):
	if domain != DOMAIN or not is_inside_tree() or not FeatureFlags.allow_navigation_rebaking:
		return
	if _earliest_frame_to_perform_next_rebake == null:
		_earliest_frame_to_perform_next_rebake = get_tree().get_frame() + 1


func _on_bake_finished():
	_sync_navmesh_changes()
	_is_baking = false


# Most moving ground units are below a horizontal navmesh surface by their
# path-height offset. Inside the lowest surface, vertical projection is
# provably the nearest point: every other polygon is at least as high. On
# elevated maps a higher level qualifies while the point is closer to it than
# half the gap to any other level. Ramps, boundary points and in-flight
# rebakes use the server query.
func closest_point(point: Vector3) -> Vector3:
	if _elevated:
		return _closest_point_on_terrain(point)
	var iteration := NavigationServer3D.map_get_iteration_id(navigation_map_rid)
	if not _is_baking and _earliest_frame_to_perform_next_rebake == null:
		if _projection_iteration != iteration and is_synchronized():
			_index_projection_surface(iteration)
		if _projection_iteration == iteration:
			var flat := Vector2(point.x, point.z)
			var cell := Vector2i(floori(point.x / 6.0), floori(point.z / 6.0))
			var best := INF
			for entry in _projection_cells.get(cell, []):
				var height: float = entry[1]
				var gap := height - point.y
				if gap < 0.0 or gap >= best:
					continue
				if height != _projection_height and gap >= _projection_tolerance:
					continue
				if Geometry2D.is_point_in_polygon(flat, entry[0]):
					best = gap
			if best < INF:
				return Vector3(point.x, point.y + best, point.z)
	return NavigationServer3D.map_get_closest_point(navigation_map_rid, point)


# Elevated maps know their ground height, so project vertically from the
# expected surface. A query from below a sloped detail triangle would move the
# point sideways (downhill on ramps) every tick.
func _closest_point_on_terrain(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z)
	var surface: float = _map.height_at(flat) + SURFACE_LIFT
	var iteration := NavigationServer3D.map_get_iteration_id(navigation_map_rid)
	if not _is_baking and _earliest_frame_to_perform_next_rebake == null:
		if _projection_iteration != iteration and is_synchronized():
			_index_projection_surface(iteration)
		if _projection_iteration == iteration:
			var cell := Vector2i(floori(point.x / 6.0), floori(point.z / 6.0))
			for entry in _projection_cells.get(cell, []):
				if (
					absf(entry[1] - surface) <= SURFACE_MATCH
					and Geometry2D.is_point_in_polygon(flat, entry[0])
				):
					return Vector3(point.x, entry[1], point.z)
	return NavigationServer3D.map_get_closest_point(
		navigation_map_rid, Vector3(point.x, surface, point.z)
	)


func _index_projection_surface(iteration: int):
	_projection_cells.clear()
	_projection_height = INF
	_projection_tolerance = INF
	var mesh: NavigationMesh = _navigation_region.navigation_mesh
	var vertices := mesh.get_vertices()
	var transform: Transform3D = _navigation_region.global_transform
	for index in vertices.size():
		vertices[index] = transform * vertices[index]
		_projection_height = minf(_projection_height, vertices[index].y)
	var levels := {}
	for index in mesh.get_polygon_count():
		var polygon := PackedVector2Array()
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var indices := mesh.get_polygon(index)
		var height := vertices[indices[0]].y
		for vertex in indices:
			var point := vertices[vertex]
			if point.y != height:
				polygon.clear()
				break
			var flat := Vector2(point.x, point.z)
			polygon.append(flat)
			low = low.min(flat)
			high = high.max(flat)
		if polygon.size() < 3 or (not _elevated and height != _projection_height):
			continue
		levels[height] = true
		for x in range(floori(low.x / 6.0), floori(high.x / 6.0) + 1):
			for y in range(floori(low.y / 6.0), floori(high.y / 6.0) + 1):
				var cell := Vector2i(x, y)
				if not _projection_cells.has(cell):
					_projection_cells[cell] = []
				_projection_cells[cell].append([polygon, height])
	var heights := levels.keys()
	heights.sort()
	for index in range(1, heights.size()):
		var gap: float = heights[index] - heights[index - 1]
		_projection_tolerance = minf(_projection_tolerance, gap / 2.0)
	_projection_iteration = iteration
