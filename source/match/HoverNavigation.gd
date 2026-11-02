extends Node3D

## Ground-combat hover surface: low rocks, shallow streams and rough ground are
## traversable, while large cliffs, solid formations and built footprints remain.
const TileBaker = preload("res://source/match/TerrainTileBaker.gd")

const Terrain = preload("res://source/match/maps/terrain/TerrainModel.gd")
var navigation_map_rid: RID
var region: NavigationRegion3D
var _map = null
var _faces = PackedVector3Array()
var _dirty = false
var _is_baking := false
var _tile_baker := TileBaker.new()
var _tiles_ready := false
var _iteration_before_publication = -1


func _ready():
	navigation_map_rid = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(navigation_map_rid, .25)
	NavigationServer3D.map_set_cell_height(navigation_map_rid, .25)
	NavigationServer3D.map_set_active(navigation_map_rid, true)
	region = NavigationRegion3D.new()
	region.navigation_mesh = NavigationMesh.new()
	region.navigation_mesh.cell_size = .25
	region.navigation_mesh.cell_height = .25
	region.navigation_mesh.agent_radius = .5
	region.navigation_mesh.agent_height = 1.0
	region.navigation_mesh.agent_max_climb = .25
	region.navigation_mesh.region_min_size = 0.0
	region.navigation_mesh.region_merge_size = 0.0
	add_child(region)
	region.set_navigation_map(navigation_map_rid)
	MatchSignals.schedule_navigation_rebake.connect(
		func(domain):
			if domain == Constants.Match.Navigation.Domain.TERRAIN:
				_dirty = true
	)


func _exit_tree():
	_tile_baker.cancel()
	if navigation_map_rid.is_valid():
		NavigationServer3D.free_rid(navigation_map_rid)


func bake(map):
	_map = map
	_faces.clear()
	var terrain = map.get("terrain")
	if terrain == null:
		_faces = map.navigation_source_faces()
		for index in _faces.size():
			_faces[index].y = 0.0
	else:
		# Merge complete horizontal runs before baking; no per-cell scene nodes.
		for row in terrain.rows:
			var first = -1
			for column in range(terrain.columns + 1):
				var free = column < terrain.columns and _hoverable(terrain, column, row)
				if free and first < 0:
					first = column
				elif not free and first >= 0:
					_quad(
						first * Terrain.RESOLUTION,
						column * Terrain.RESOLUTION,
						row * Terrain.RESOLUTION,
						(row + 1) * Terrain.RESOLUTION
					)
					first = -1
	_rebake()


func _hoverable(terrain, column: int, row: int) -> bool:
	var index = row * terrain.columns + column
	var flags = terrain.flags[index]
	if flags & Terrain.BARRIER:
		return false
	if flags & Terrain.SOLID:
		return terrain.cover_tops[index] - terrain.ground_tops[index] <= 1.25
	if flags & (Terrain.WATER | Terrain.FORD):
		return true
	return terrain.is_walkable_cell(column, row)


func _quad(left: float, right: float, top: float, bottom: float):
	var a = Vector3(left, 0, top)
	var b = Vector3(right, 0, top)
	var c = Vector3(right, 0, bottom)
	var d = Vector3(left, 0, bottom)
	_faces.append_array(PackedVector3Array([d, a, b, b, c, d]))


func is_synchronized() -> bool:
	return (
		not _dirty
		and not _is_baking
		and (
			NavigationServer3D.map_get_iteration_id(navigation_map_rid)
			> _iteration_before_publication
		)
	)


func _process(_delta):
	if _dirty and not _is_baking and _map != null:
		_dirty = false
		_rebake()


func _rebake():
	var source = NavigationMeshSourceGeometryData3D.new()
	source.add_faces(_faces, Transform3D.IDENTITY)
	var obstacles: Array = []
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		var obstacle = unit.get_node_or_null("MovementObstacle")
		if obstacle == null or not obstacle.affect_navigation_mesh:
			continue
		obstacles.append(obstacle)
		var outline = PackedVector3Array()
		if obstacle.footprint.is_empty():
			for index in 16:
				var angle = TAU * index / 16.0
				outline.append(
					(
						Vector3(cos(angle), 0, sin(angle)) * obstacle.radius
						+ unit.global_position * Vector3(1, 0, 1)
					)
				)
		else:
			for point in obstacle.footprint:
				outline.append(
					(
						(unit.global_basis * Vector3(point.x, 0, point.y) + unit.global_position)
						* Vector3(1, 0, 1)
					)
				)
		source.add_projected_obstruction(outline, -.5, 3.0, false)
	if not _tiles_ready:
		region.navigation_mesh.filter_baking_aabb = AABB(
			Vector3(0, -1, 0), Vector3(_map.size.x, 5, _map.size.y)
		)
		_tile_baker.setup(region.navigation_mesh, source)
		_tiles_ready = true
		_finish_bake()
	else:
		_is_baking = true
		_tile_baker.rebake(obstacles, source, _finish_bake)


func _finish_bake():
	region.navigation_mesh = _tile_baker.combined()
	_is_baking = false
	_iteration_before_publication = NavigationServer3D.map_get_iteration_id(navigation_map_rid)
	region.navigation_mesh = region.navigation_mesh
