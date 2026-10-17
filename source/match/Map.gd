@tool
extends Node3D

# TODO: add editor-only 2nd pass shader to 'Terrain' mesh highlighting map boundries

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


func flight_height_at(point, baseline):
	return load("res://source/match/maps/IndustrialLandmarks.gd").flight_height(
		interior_obstacles, point, baseline
	)
