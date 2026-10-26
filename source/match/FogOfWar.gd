extends Node3D

const DynamicCircle2D = preload("res://source/generic-scenes-and-nodes/2d/DynamicCircle2D.tscn")

const RevealShape2D = preload("res://source/generic-scenes-and-nodes/2d/RevealShape2D.gd")
const TerrainSight = preload("res://source/match/maps/terrain/TerrainSight.gd")
const DEFAULT_SIZE = Vector2i(100, 100)
# Occlusion outlines refresh after this much movement (metres).
const OUTLINE_REFRESH = 0.75
const OUTLINE_BUDGET_USEC = 2000

@export_range(1, 10) var texture_units_per_world_unit = 2  # px/m
@export var fog_circle_color = Color(0.25, 0.25, 0.25)
@export var shroud_circle_color = Color(1.0, 1.0, 1.0)

var _unit_to_circles_mapping = {}
# Elevated maps reveal what units can actually see, not full circles.
var _terrain = null
var _outline_origins = {}
var _outline_airborne = {}
var _outline_reach = {}
var _outline_deadline = 0
var _presented_tick = -1

@onready var _revealer = find_child("Revealer")
@onready var _fog_viewport = find_child("FogViewport")
@onready var _fog_viewport_container = find_child("FogViewportContainer")
@onready var _combined_viewport = find_child("CombinedViewport")
@onready var _screen_overlay = find_child("ScreenOverlay")


func _ready():
	var map = find_parent("Match").find_child("Map")
	if map != null and map.is_elevated() and "terrain" in map:
		_terrain = map.terrain
	if _fog_viewport.size == DEFAULT_SIZE:
		resize(map.size)
	_screen_overlay.material_override.set_shader_parameter(
		"texture_units_per_world_unit", texture_units_per_world_unit
	)
	_revealer.hide()
	find_child("EditorOnlyCircle").queue_free()
	# Fog is presentation. Catch-up ticks need only their final rendered state;
	# weapon visibility continues to query live simulation positions separately.
	set_physics_process(false)


func _process(delta):
	var tick = Engine.get_physics_frames()
	if tick != _presented_tick:
		_presented_tick = tick
		_physics_process(delta)


func _physics_process(_delta):
	_outline_deadline = Time.get_ticks_usec() + OUTLINE_BUDGET_USEC
	var units_synced = {}
	var units_to_sync = find_parent("Match").get_cached_group("revealed_units")
	for unit in units_to_sync:
		if not unit.is_revealing():
			continue
		units_synced[unit] = 1
		if not _unit_is_mapped(unit):
			_map_unit_to_new_circles(unit)
		_sync_circles_to_unit(unit)
	for mapped_unit in _unit_to_circles_mapping:
		if not mapped_unit in units_synced:
			_cleanup_mapping(mapped_unit)


func reveal():
	_revealer.show()


func resize(map_size: Vector2):
	_fog_viewport.size = map_size * texture_units_per_world_unit
	_combined_viewport.size = map_size * texture_units_per_world_unit


func _unit_is_mapped(unit):
	return unit in _unit_to_circles_mapping


func _new_reveal():
	return RevealShape2D.new() if _terrain != null else DynamicCircle2D.instantiate()


func _map_unit_to_new_circles(unit):
	var shroud_circle = _new_reveal()
	shroud_circle.color = fog_circle_color
	shroud_circle.radius = unit.sight_range * texture_units_per_world_unit
	_fog_viewport.add_child(shroud_circle)
	var fow_circle = _new_reveal()
	fow_circle.color = shroud_circle_color
	fow_circle.radius = unit.sight_range * texture_units_per_world_unit
	_fog_viewport_container.add_sibling(fow_circle)
	_unit_to_circles_mapping[unit] = [shroud_circle, fow_circle]


func _sync_circles_to_unit(unit):
	var reach = (
		unit.effective_sight_range()
		if unit.has_method("effective_sight_range")
		else unit.sight_range
	)
	if unit.has_meta("garrison_host"):
		reach += unit.get_meta("garrison_host").radius + 2.0
	for circle in _unit_to_circles_mapping[unit]:
		var radius = reach * texture_units_per_world_unit
		if not is_equal_approx(circle.radius, radius):
			circle.radius = radius
	var unit_pos_3d = unit.global_transform.origin
	var unit_pos_2d = Vector2(unit_pos_3d.x, unit_pos_3d.z) * texture_units_per_world_unit
	if (_unit_to_circles_mapping[unit][0].position - unit_pos_2d).length_squared() > 0.0001:
		_unit_to_circles_mapping[unit][0].position = unit_pos_2d
		_unit_to_circles_mapping[unit][1].position = unit_pos_2d
	if _terrain != null:
		_sync_outline(unit, Vector2(unit_pos_3d.x, unit_pos_3d.z), reach)


func _sync_outline(unit, centre: Vector2, reach: float):
	var airborne = (
		unit.combat_domain() == Constants.Match.Navigation.Domain.AIR
		if unit.has_method("combat_domain")
		else (
			"movement_domain" in unit
			and unit.movement_domain == Constants.Match.Navigation.Domain.AIR
		)
	)
	var previous = _outline_origins.get(unit)
	if (
		previous != null
		and previous.distance_to(centre) < OUTLINE_REFRESH
		and _outline_airborne.get(unit) == airborne
		and is_equal_approx(_outline_reach.get(unit, -1.0), reach)
	):
		return
	# Spread terrain occlusion work across frames; a reveal lags at most briefly.
	if Time.get_ticks_usec() > _outline_deadline:
		return
	_outline_origins[unit] = centre
	_outline_airborne[unit] = airborne
	_outline_reach[unit] = reach
	var local = PackedVector2Array()
	if not airborne:
		for point in TerrainSight.reveal_triangles(
			_terrain,
			centre,
			reach,
			(
				unit.sight_range
				if unit.has_method("terrain_advantage") and unit.terrain_advantage()
				else -1.0
			)
		):
			local.append((point - centre) * texture_units_per_world_unit)
	for circle in _unit_to_circles_mapping[unit]:
		circle.triangles = local


func _cleanup_mapping(unit):
	_unit_to_circles_mapping[unit][0].queue_free()
	_unit_to_circles_mapping[unit][1].queue_free()
	_unit_to_circles_mapping.erase(unit)
	_outline_origins.erase(unit)
	_outline_airborne.erase(unit)
	_outline_reach.erase(unit)
