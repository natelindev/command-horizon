extends Node3D

const ComputeTexture = preload("res://source/match/rendering/FogTextureCompute.gd")

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
var _compute: RefCounted
var _compute_active := false
var _restoring_exploration := false
var _fog_revision := 0
var _submitted_revision := -1
var _submitted_style: Array = []

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
	if (
		DisplayServer.get_name() != "headless"
		and RenderingServer.get_current_rendering_method() != "gl_compatibility"
		and not "--viewport-fog" in OS.get_cmdline_user_args()
	):
		_start_compute.call_deferred()


func _start_compute():
	_compute = ComputeTexture.new()
	_compute.initialize(_fog_viewport.size)


func _exit_tree():
	if _compute != null:
		_compute.close()


func _activate_compute(exploration: Image = null):
	if _compute_active or _restoring_exploration or _compute == null or not _compute.ready:
		return
	# Copy accumulated exploration once when switching backends. No regular
	# GPU readback is needed; gameplay sight remains entirely CPU authoritative.
	var image: Image = exploration
	if image == null:
		image = _fog_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	_compute.restore(image)
	_compute_active = true
	for entry in _unit_to_circles_mapping.values():
		for circle in entry.circles:
			circle.queue_free()
		entry.circles.clear()
	_screen_overlay.material_override.set_shader_parameter(
		"world_visibility_texture", _compute.texture
	)
	var mask = find_parent("Match").find_child("FogOfWarMask", true, false)
	if mask != null:
		mask.material = mask.material.duplicate()
		mask.material.set_shader_parameter("reference_texture", _compute.texture)
	_fog_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_combined_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_physics_process(0.0)


func exploration_image() -> Image:
	if _compute_active:
		return _compute.history.get_image()
	return _fog_viewport.get_texture().get_image()


func restore_exploration(image: Image):
	# Restore into the selected backend directly. Rasterizing compute history
	# through viewport circles can expand it before the backend handoff completes.
	_restoring_exploration = true
	if _compute != null:
		while not _compute.ready and not _compute.failed:
			await get_tree().process_frame
	_restoring_exploration = false
	_activate_compute(image)
	if _compute_active:
		_compute.restore(image)
		_submitted_revision = -1
		_physics_process(0.0)
		await RenderingServer.frame_post_draw
		return
	_restoring_exploration = true
	var history := TextureRect.new()
	history.texture = ImageTexture.create_from_image(image)
	history.size = image.get_size()
	_fog_viewport.add_child(history)
	await RenderingServer.frame_post_draw
	history.queue_free()
	await get_tree().process_frame
	_restoring_exploration = false


func _process(delta):
	_activate_compute()
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
	for mapped_unit in _unit_to_circles_mapping.keys():
		if not mapped_unit in units_synced:
			_cleanup_mapping(mapped_unit)
	_submit_compute()


func _submit_compute():
	if not _compute_active:
		return
	var style := [_revealer.visible, fog_circle_color, shroud_circle_color]
	if _submitted_revision == _fog_revision and _submitted_style == style:
		return
	_submitted_revision = _fog_revision
	_submitted_style = style
	_compute.update(
		_unit_to_circles_mapping.values(), _revealer.visible, fog_circle_color, shroud_circle_color
	)


func reveal():
	_revealer.show()
	_submit_compute()


func resize(map_size: Vector2):
	_fog_viewport.size = map_size * texture_units_per_world_unit
	_combined_viewport.size = map_size * texture_units_per_world_unit


func _unit_is_mapped(unit):
	return unit in _unit_to_circles_mapping


func _new_reveal():
	return RevealShape2D.new() if _terrain != null else DynamicCircle2D.instantiate()


func _map_unit_to_new_circles(unit):
	_fog_revision += 1
	var circles: Array = []
	if not _compute_active:
		var shroud_circle = _new_reveal()
		shroud_circle.color = fog_circle_color
		_fog_viewport.add_child(shroud_circle)
		var fow_circle = _new_reveal()
		fow_circle.color = shroud_circle_color
		_fog_viewport_container.add_sibling(fow_circle)
		circles = [shroud_circle, fow_circle]
	_unit_to_circles_mapping[unit] = {
		"position": Vector2.INF,
		"radius": 0.0,
		"triangles": PackedVector2Array(),
		"circles": circles
	}


func _sync_circles_to_unit(unit):
	var reach: float = (
		unit.effective_sight_range()
		if unit.has_method("effective_sight_range")
		else unit.sight_range
	)
	if unit.has_meta("garrison_host"):
		reach += unit.get_meta("garrison_host").radius + 2.0
	var entry: Dictionary = _unit_to_circles_mapping[unit]
	var radius: float = reach * texture_units_per_world_unit
	if not is_equal_approx(entry.radius, radius):
		entry.radius = radius
		_fog_revision += 1
	var point: Vector3 = unit.global_position
	var position_2d: Vector2 = Vector2(point.x, point.z) * texture_units_per_world_unit
	if position_2d.distance_squared_to(entry.position) > .0001:
		entry.position = position_2d
		_fog_revision += 1
	if _terrain != null:
		_sync_outline(unit, Vector2(point.x, point.z), reach)
	for circle in entry.circles:
		if not is_equal_approx(circle.radius, entry.radius):
			circle.radius = entry.radius
		if circle.position.distance_squared_to(entry.position) > .0001:
			circle.position = entry.position


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
	_unit_to_circles_mapping[unit].triangles = local
	_fog_revision += 1
	for circle in _unit_to_circles_mapping[unit].circles:
		circle.triangles = local


func _cleanup_mapping(unit):
	_fog_revision += 1
	for circle in _unit_to_circles_mapping[unit].circles:
		circle.queue_free()
	_unit_to_circles_mapping.erase(unit)
	_outline_origins.erase(unit)
	_outline_airborne.erase(unit)
	_outline_reach.erase(unit)
