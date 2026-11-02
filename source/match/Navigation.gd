extends Node3D

var hover = null
var _static_obstacles = []
# Exact route estimates shared within one simulation tick, owned by this match.
var distance_frame = -1
var distance_cache = {}
var connectivity_cache = {}

@onready var air = find_child("Air")
@onready var terrain = find_child("Terrain")

@onready var _match = find_parent("Match")


func _ready():
	await _match.ready
	_setup_static_obstacles()


func _process(_delta):
	if (
		terrain._map_geometry == null
		or terrain._navigation_region.navigation_mesh.get_polygon_count() == 0
	):
		return
	var index = load("res://source/match/orders/NavigationConnectivity.gd")
	index.warm(self, 1)
	if hover != null:
		index.warm(self, 1, true)


func _exit_tree():
	for obstacle in _static_obstacles:
		NavigationServer3D.free_rid(obstacle)


func get_navigation_map_rid_by_domain(domain):
	return {
		Constants.Match.Navigation.Domain.AIR: air.navigation_map_rid,
		Constants.Match.Navigation.Domain.TERRAIN: terrain.navigation_map_rid,
	}[domain]


func wait_until_synchronized(domain):
	var navigation_map = get_navigation_map_rid_by_domain(domain)
	# A baked mesh can still be waiting for the server's asynchronous synchronization.
	while (
		NavigationServer3D.map_get_iteration_id(navigation_map) == 0
		or not (
			NavigationServer3D.map_get_closest_point_owner(navigation_map, Vector3.ZERO).is_valid()
		)
	):
		await get_tree().physics_frame


func setup(map):
	hover = load("res://source/match/HoverNavigation.gd").new()
	hover.name = "Hover"
	add_child(hover)
	hover.bake(map)
	assert(_static_obstacles.is_empty())
	air.bake(map)
	terrain.bake(map)
	_setup_static_obstacles()


func _setup_static_obstacles():
	if not _static_obstacles.is_empty():
		return
	for domain in [
		Constants.Match.Navigation.Domain.AIR, Constants.Match.Navigation.Domain.TERRAIN
	]:
		var obstacle = NavigationServer3D.obstacle_create()
		NavigationServer3D.obstacle_set_map(obstacle, get_navigation_map_rid_by_domain(domain))
		var obstacle_y = {
			Constants.Match.Navigation.Domain.AIR: Constants.Match.Air.Y,
			Constants.Match.Navigation.Domain.TERRAIN: 0,
		}[domain]
		NavigationServer3D.obstacle_set_position(obstacle, Vector3(0, obstacle_y, 0))
		if domain == Constants.Match.Navigation.Domain.TERRAIN and _match.map.is_elevated():
			# 2D avoidance skips obstacles above or below an agent; span every tier.
			var floor_y = _match.map.min_height() - 5.0
			NavigationServer3D.obstacle_set_position(obstacle, Vector3(0, floor_y, 0))
			NavigationServer3D.obstacle_set_height(
				obstacle, _match.map.max_height() - floor_y + 5.0
			)
		var obstacle_vertices = [
			Vector3(0, 0, 0),
			Vector3(0, 0, _match.map.size.y),
			Vector3(_match.map.size.x, 0, _match.map.size.y),
			Vector3(_match.map.size.x, 0, 0),
		]
		NavigationServer3D.obstacle_set_vertices(obstacle, obstacle_vertices)
		NavigationServer3D.obstacle_set_avoidance_enabled(obstacle, true)
		NavigationServer3D.obstacle_set_avoidance_layers(
			obstacle,
			Constants.Match.Navigation.AVOIDANCE_UNITS | Constants.Match.Navigation.AVOIDANCE_STATIC
		)
		_static_obstacles.append(obstacle)
