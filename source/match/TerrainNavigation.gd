extends Node3D

const DOMAIN = Constants.Match.Navigation.Domain.TERRAIN
const ELEVATED_MAX_CLIMB = 0.6
# Baked walkable surfaces sit about one voxel step above the authored ground.
const SURFACE_LIFT = 0.5
const SURFACE_MATCH = 0.35
const PROJECTION_CELL_SIZE = 6.0
const EMPTY_PROJECTIONS = []
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")

var _earliest_frame_to_perform_next_rebake = null
var _is_baking = false
var _iteration_before_publication = -1
var _region_before_publication = -1
var _projection_cells = {}
var _projection_interiors: Dictionary[Vector2i, float] = {}
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


## Only authored, walkable plateau tops confer an advantage. Ramps, bridges,
## water beds and scenic mesas do not count, nor does an aircraft's altitude.
func has_plateau_advantage(point: Vector3) -> bool:
	if not _elevated or _map == null or not "terrain" in _map:
		return false
	return plateau_at(_map.terrain, Vector2(point.x, point.z))


static func plateau_at(terrain, point: Vector2) -> bool:
	if terrain == null or not Rect2(Vector2.ZERO, terrain.size).has_point(point):
		return false
	var excluded = (
		TerrainModel.RAMP
		| TerrainModel.WATER
		| TerrainModel.SOLID
		| TerrainModel.BARRIER
		| TerrainModel.BRIDGE
		| TerrainModel.FORD
	)
	if terrain.flag_at(point) & excluded != 0:
		return false
	# Smooth dunes and slag heaps also have elevated shoulders. Only their level
	# top cells count, using the same four corners as the navigation surface.
	var column = mini(int(point.x / TerrainModel.RESOLUTION), terrain.columns - 1)
	var row = mini(int(point.y / TerrainModel.RESOLUTION), terrain.rows - 1)
	var stride = terrain.columns + 1
	var index = row * stride + column
	var height = terrain.heights[index]
	return (
		height >= terrain.tier_step * 0.75
		and is_equal_approx(height, terrain.heights[index + 1])
		and is_equal_approx(height, terrain.heights[index + stride])
		and is_equal_approx(height, terrain.heights[index + stride + 1])
	)


func _ready():
	assert(_safety_checks())
	NavigationServer3D.map_set_cell_size(
		navigation_map_rid, Constants.Match.Terrain.Navmesh.CELL_SIZE
	)
	NavigationServer3D.map_set_cell_height(
		navigation_map_rid, Constants.Match.Terrain.Navmesh.CELL_HEIGHT
	)
	# Server-created maps do not inherit the default world's project settings.
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(
		navigation_map_rid,
		ProjectSettings.get_setting_with_override("navigation/3d/merge_rasterizer_cell_scale")
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
		# The bake floor steps in whole tiers below -1 m so voxel rows, and with
		# them SURFACE_LIFT, sit at the same offset above authored ground.
		var floor_y = -1.0 - ceilf(maxf(0.0, -map.min_height()) / 3.0) * 3.0
		# Tiers and ramps: two voxels of climb joins ramp cells; cliffs stay walls.
		mesh.agent_max_climb = ELEVATED_MAX_CLIMB
		# Centre the voxel grid on the map so rotated or mirrored starts see
		# identical rasterization (sizes are not whole multiples of a cell).
		var cell: float = mesh.cell_size
		var inset = Vector2(fmod(map.size.x, cell) / 2.0, fmod(map.size.y, cell) / 2.0)
		mesh.filter_baking_aabb = AABB(
			Vector3(inset.x, floor_y, inset.y),
			Vector3(
				map.size.x - inset.x * 2.0,
				map.max_height() - floor_y + 5.0,
				map.size.y - inset.y * 2.0
			)
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
# elevated maps, indexed slope triangles also allow vertical projection.
# Boundary points and in-flight rebakes use the server query.
func closest_point(point: Vector3) -> Vector3:
	if _elevated:
		return _closest_point_on_terrain(point)
	var iteration := NavigationServer3D.map_get_iteration_id(navigation_map_rid)
	if not _is_baking and _earliest_frame_to_perform_next_rebake == null:
		if _projection_iteration != iteration and is_synchronized():
			_index_projection_surface(iteration)
		if _projection_iteration == iteration:
			var flat := Vector2(point.x, point.z)
			var cell := Vector2i(
				floori(point.x / PROJECTION_CELL_SIZE), floori(point.z / PROJECTION_CELL_SIZE)
			)
			# A convex navmesh polygon containing all four cell corners contains
			# every point in the cell. Reuse that proof for interior movement;
			# boundaries still use the exact polygon/server queries below.
			var interior: float = _projection_interiors.get(cell, -INF)
			if point.y <= interior:
				return Vector3(point.x, interior, point.z)
			for entry in _projection_cells.get(cell, EMPTY_PROJECTIONS):
				var height: float = entry[1]
				var gap := height - point.y
				if gap < 0.0:
					continue
				# Flat-map indexing retains only the lowest horizontal surface.
				# Every containing polygon therefore gives the same nearest height.
				if Geometry2D.is_point_in_polygon(flat, entry[0]):
					return Vector3(point.x, point.y + gap, point.z)
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
			var cell := Vector2i(
				floori(point.x / PROJECTION_CELL_SIZE), floori(point.z / PROJECTION_CELL_SIZE)
			)
			for entry in _projection_cells.get(cell, EMPTY_PROJECTIONS):
				var height: float = entry[1]
				if entry.size() == 3:
					var plane: Plane = entry[2]
					height = (
						(plane.d - plane.normal.x * point.x - plane.normal.z * point.z)
						/ plane.normal.y
					)
				if (
					absf(height - surface) <= SURFACE_MATCH
					and Geometry2D.is_point_in_polygon(flat, entry[0])
				):
					return Vector3(point.x, height, point.z)
	return NavigationServer3D.map_get_closest_point(
		navigation_map_rid, Vector3(point.x, surface, point.z)
	)


func _index_projection_surface(iteration: int):
	_projection_cells.clear()
	_projection_interiors.clear()
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
			if _elevated:
				for triangle in range(1, indices.size() - 1):
					_index_slope(
						vertices[indices[0]],
						vertices[indices[triangle]],
						vertices[indices[triangle + 1]]
					)
			continue
		levels[height] = true
		for x in range(
			floori(low.x / PROJECTION_CELL_SIZE), floori(high.x / PROJECTION_CELL_SIZE) + 1
		):
			for y in range(
				floori(low.y / PROJECTION_CELL_SIZE), floori(high.y / PROJECTION_CELL_SIZE) + 1
			):
				var cell := Vector2i(x, y)
				if not _projection_cells.has(cell):
					_projection_cells[cell] = []
				_projection_cells[cell].append([polygon, height])
				if not _elevated and not _projection_interiors.has(cell):
					var corner := Vector2(cell) * PROJECTION_CELL_SIZE
					if (
						Geometry2D.is_point_in_polygon(corner, polygon)
						and Geometry2D.is_point_in_polygon(
							corner + Vector2(PROJECTION_CELL_SIZE, 0), polygon
						)
						and Geometry2D.is_point_in_polygon(
							corner + Vector2(0, PROJECTION_CELL_SIZE), polygon
						)
						and Geometry2D.is_point_in_polygon(
							corner + Vector2.ONE * PROJECTION_CELL_SIZE, polygon
						)
					):
						_projection_interiors[cell] = height
	var heights := levels.keys()
	heights.sort()
	for index in range(1, heights.size()):
		var gap: float = heights[index] - heights[index - 1]
		_projection_tolerance = minf(_projection_tolerance, gap / 2.0)
	_projection_iteration = iteration


func _index_slope(a: Vector3, b: Vector3, c: Vector3):
	var plane := Plane(a, b, c)
	if absf(plane.normal.y) < .001:
		return
	var polygon := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
	var low := polygon[0].min(polygon[1]).min(polygon[2])
	var high := polygon[0].max(polygon[1]).max(polygon[2])
	for x in range(floori(low.x / PROJECTION_CELL_SIZE), floori(high.x / PROJECTION_CELL_SIZE) + 1):
		for y in range(
			floori(low.y / PROJECTION_CELL_SIZE), floori(high.y / PROJECTION_CELL_SIZE) + 1
		):
			var cell := Vector2i(x, y)
			if not _projection_cells.has(cell):
				_projection_cells[cell] = []
			_projection_cells[cell].append([polygon, a.y, plane])
