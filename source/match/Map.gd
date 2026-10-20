@tool
extends Node3D

# TODO: add editor-only 2nd pass shader to 'Terrain' mesh highlighting map boundries

const TerrainTextures = preload("res://source/match/TerrainTextures.gd")
const EXTRA_MARGIN = 2
@export var size = Vector2(50, 50):
	set(a_size):
		size = a_size
		_resize_terrain()

var interior_obstacles = []


func get_topdown_polygon_2d():
	return [Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]


func _enter_tree():
	# Exported inherited scenes can assign the child mesh after the root size
	# setter runs. Apply the final dimensions before Match builds click collision.
	_resize_terrain()
	if Engine.is_editor_hint():
		return
	add_to_group("battle_map")
	# Before map scripts duplicate the terrain material, so copies inherit the layers.
	# Authored battlefields build their own ground mesh and material.
	var terrain = get_node_or_null("Geometry/Terrain")
	if terrain != null and terrain.mesh is PrimitiveMesh:
		TerrainTextures.apply(terrain.mesh.material)
	var catalog = load("res://source/match/ambient/AmbientCatalog.gd")
	catalog.populate_settlements(self)
	if catalog.entries(scene_file_path).is_empty():
		return
	var life = load("res://source/match/ambient/AmbientLife.gd").new()
	life.name = "AmbientLife"
	add_child(life)


func _resize_terrain():
	var terrain = get_node_or_null("Geometry/Terrain")
	if terrain == null or terrain.mesh == null:
		return
	terrain.mesh.size = size + Vector2(EXTRA_MARGIN, EXTRA_MARGIN) * 2
	terrain.mesh.center_offset = Vector3(size.x, 0.0, size.y) / 2.0


# Gameplay ground. Flat maps are level at y = 0; elevated battlefields override
# these with their authored tiers and ramps. Visual micro-relief is not included.
func height_at(_point: Vector2) -> float:
	return 0.0


func tier_at(_point: Vector2) -> int:
	return 0


func max_height() -> float:
	return 0.0


func min_height() -> float:
	return 0.0


func is_elevated() -> bool:
	return max_height() > 0.0


func ground_point(point: Vector2) -> Vector3:
	return Vector3(point.x, height_at(point), point.y)


# Walkable source triangles for the ground navigation bake.
func navigation_source_faces() -> PackedVector3Array:
	# Bake the land outline, not the rectangular map bounds: coastal inlets
	# remain impassable on both the initial bake and later obstacle rebakes.
	var polygon = PackedVector2Array(get_topdown_polygon_2d())
	var faces = PackedVector3Array()
	for index in Geometry2D.triangulate_polygon(polygon):
		faces.append(Vector3(polygon[index].x, 0, polygon[index].y))
	return faces


func flight_height_at(point, baseline):
	return load("res://source/match/maps/IndustrialLandmarks.gd").flight_height(
		interior_obstacles, point, baseline
	)
