extends PanelContainer

const Ownership = preload("res://source/match/hud/Ownership.gd")
const Unit = preload("res://source/match/units/Unit.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")
const AtmosphereProfiles = preload("res://source/match/environment/AtmosphereProfiles.gd")
const MinimapTerrain = preload("res://source/match/hud/MinimapTerrain.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
# Shown until (or instead of, when rendering is unavailable) the terrain capture.
const BIOME_GROUND = {
	"desert": Color("6d604c"),
	"alpine": Color("7f8b95"),
	"coastal": Color("566760"),
	"urban": Color("4c5659"),
	"temperate": Color("515d4b"),
}

const GROUND_LEVEL_PLANE = Plane(Vector3.UP, 0)
const MINIMAP_PIXELS_PER_WORLD_METER = 2

const MARKER_PHASES = 3

var _unit_to_corresponding_node_mapping = {}
var _camera_movement_active = false
var _marker_phase = 0

@onready var _match = find_parent("Match")
@onready var _camera_indicator = find_child("CameraIndicator")
@onready var _viewport_background = find_child("Background")
@onready var _texture_rect = find_child("MinimapTextureRect")


func _ready():
	BattleTheme.apply_housing(self, 20, 20)
	if not FeatureFlags.show_minimap:
		queue_free()
	# A recessed screen behind the map and a bezel over its edges.
	var backing = Panel.new()
	backing.name = "Screen"
	backing.add_theme_stylebox_override("panel", BattleTheme.socket())
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.add_sibling(backing)
	_texture_rect.get_parent().move_child(backing, 0)
	var bezel = Panel.new()
	bezel.name = "Bezel"
	bezel.add_theme_stylebox_override("panel", BattleTheme.socket_frame())
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.add_sibling(bezel)
	_remove_dummy_nodes()
	await _match.ready  # make sure Match is ready as it may change map on setup
	var map_size = _match.find_child("Map").size
	find_child("MinimapViewport").size = map_size * MINIMAP_PIXELS_PER_WORLD_METER
	# A fixed-height screen in the console housing; wide maps letterbox inside it.
	var screen = HudLayout.MINIMAP_SCREEN
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.custom_minimum_size = Vector2(
		clampf(
			screen * map_size.x / maxf(1.0, map_size.y),
			screen,
			screen * HudLayout.MINIMAP_ASPECT_LIMIT
		),
		screen
	)
	_texture_rect.gui_input.connect(_on_gui_input)
	_texture_rect.tooltip_text = Ownership.legend(_match)
	_texture_rect.accessibility_name = "Battlefield minimap. " + Ownership.legend(_match)
	_viewport_background.color = BIOME_GROUND[AtmosphereProfiles.biome(_match.map)]
	var terrain = MinimapTerrain.new()
	_viewport_background.add_child(terrain)
	if _match.map.has_method("overview"):
		var features = load("res://source/match/hud/MapFeatures.gd").new()
		features.map = _match.map
		features.pixel_scale = MINIMAP_PIXELS_PER_WORLD_METER
		features.terrain = terrain
		_viewport_background.add_child(features)
	terrain.capture(_match.map, MINIMAP_PIXELS_PER_WORLD_METER)
	if _camera_indicator != null:
		_camera_indicator.default_color = BattleTheme.accent()
		_camera_indicator.width = 2.0
	MatchSignals.tactical_ping.connect(_on_tactical_ping)


func _physics_process(_delta):
	# Each marker refreshes at 10 Hz at the 30 Hz simulation cadence. Spread
	# visibility queries and marker uploads over three ticks instead of a burst.
	_sync_real_units_with_minimap_representations(_marker_phase)
	_marker_phase = (_marker_phase + 1) % MARKER_PHASES
	_update_camera_indicator()


func _remove_dummy_nodes():
	for dummy_node in find_children("EditorOnlyDummy*"):
		dummy_node.queue_free()


func _sync_real_units_with_minimap_representations(phase = -1):
	var units_synced = {}
	var observer = _match._get_human_player()
	if observer == null:
		observer = _match.visible_player
	var units_to_sync = _match.get_units() + _match.get_cached_group("resource_units")
	for unit in units_to_sync:
		if phase >= 0 and unit.get_instance_id() % MARKER_PHASES != phase:
			units_synced[unit] = 1
			# Never retain a marker after its visible body was hidden or removed.
			if _unit_is_mapped(unit):
				var alive = not unit.is_queued_for_deletion() and unit.is_visible_in_tree()
				_unit_to_corresponding_node_mapping[unit].visible = alive and not _match.restoring
			continue
		if not Ownership.known_now(unit, _match):
			continue
		units_synced[unit] = 1
		if not _unit_is_mapped(unit):
			_map_unit(unit)
		_sync_unit(unit, observer)
	for mapped_unit in _unit_to_corresponding_node_mapping:
		if not mapped_unit in units_synced:
			_cleanup_mapping(mapped_unit)


func _unit_is_mapped(unit):
	return unit in _unit_to_corresponding_node_mapping


func _map_unit(unit):
	var node_representing_unit = load("res://source/match/hud/MinimapUnitMarker.gd").new()
	_viewport_background.add_sibling(node_representing_unit)
	_unit_to_corresponding_node_mapping[unit] = node_representing_unit


func _sync_unit(unit, observer):
	var unit_pos_3d = unit.global_transform.origin
	var unit_pos_2d = Vector2(unit_pos_3d.x, unit_pos_3d.z) * MINIMAP_PIXELS_PER_WORLD_METER
	var marker = _unit_to_corresponding_node_mapping[unit]
	marker.show()
	marker.position = unit_pos_2d
	marker.kind = (
		"resource"
		if unit.is_in_group("resource_units")
		else (
			"own"
			if unit.player == observer
			else (
				"ally"
				if load("res://source/match/Players.gd").allied(unit.player, observer)
				else "opponent"
			)
		)
	)
	marker.color = unit.player.color if unit is Unit else unit.color


func _cleanup_mapping(unit):
	_unit_to_corresponding_node_mapping[unit].queue_free()
	_unit_to_corresponding_node_mapping.erase(unit)


func _update_camera_indicator():
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	var viewport_size = viewport.get_visible_rect().size
	var camera_corners = [
		Vector2.ZERO,
		Vector2(0, viewport_size.y),
		viewport_size,
		Vector2(viewport_size.x, 0),
		Vector2.ZERO
	]
	for index in range(camera_corners.size()):
		var corner_mapped_to_3d_position_on_ground_level = (
			GROUND_LEVEL_PLANE.intersects_ray(
				camera.project_ray_origin(camera_corners[index]),
				camera.project_ray_normal(camera_corners[index])
			)
			* MINIMAP_PIXELS_PER_WORLD_METER
		)
		var point = Vector2(
			corner_mapped_to_3d_position_on_ground_level.x,
			corner_mapped_to_3d_position_on_ground_level.z
		)
		# A stationary camera must not rebuild the line's canvas geometry at
		# simulation cadence. Camera motion still updates every affected point.
		if _camera_indicator.get_point_position(index) != point:
			_camera_indicator.set_point_position(index, point)


func _texture_rect_position_to_world_position(position_2d_within_texture_rect):
	assert(
		_texture_rect.stretch_mode == _texture_rect.STRETCH_KEEP_ASPECT_CENTERED,
		"world 3d position retrieval algorithm assumes 'STRETCH_KEEP_ASPECT_CENTERED'"
	)
	var texture_rect_size = _texture_rect.size
	var texture_size = _texture_rect.texture.get_size()
	var proportions = texture_rect_size / texture_size
	var scaling_factor = proportions.x if proportions.x < proportions.y else proportions.y
	var scaled_texture_size = texture_size * scaling_factor
	var scaled_texture_position_within_texture_rect = (
		(texture_rect_size - scaled_texture_size) / 2.0
	)
	var rect_containing_scaled_texture = Rect2(
		scaled_texture_position_within_texture_rect, scaled_texture_size
	)
	if rect_containing_scaled_texture.has_point(position_2d_within_texture_rect):
		var position_2d_within_minimap = (
			(position_2d_within_texture_rect - rect_containing_scaled_texture.position)
			/ scaling_factor
		)
		return position_2d_within_minimap / MINIMAP_PIXELS_PER_WORLD_METER
	return null


func _try_teleporting_camera_based_on_local_texture_rect_position(position_2d_within_texture_rect):
	var world_position_2d = _texture_rect_position_to_world_position(
		position_2d_within_texture_rect
	)
	if world_position_2d == null:
		return
	var world_position_3d = Vector3(world_position_2d.x, 0, world_position_2d.y)
	get_viewport().get_camera_3d().set_position_safely(world_position_3d)


func _issue_movement_action(position_2d_within_texture_rect):
	var world_position_2d = _texture_rect_position_to_world_position(
		position_2d_within_texture_rect
	)
	if world_position_2d == null:
		return
	MatchSignals.terrain_targeted.emit(_match.map.ground_point(world_position_2d))


func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			if event.ctrl_pressed:
				var world_pos_2d = _texture_rect_position_to_world_position(event.position)
				if world_pos_2d != null:
					MatchSignals.tactical_ping.emit(_match.map.ground_point(world_pos_2d))
				return
			_try_teleporting_camera_based_on_local_texture_rect_position(event.position)
			_camera_movement_active = true
		if not event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			_camera_movement_active = false
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
			_issue_movement_action(event.position)
	elif event is InputEventMouseMotion and _camera_movement_active:
		_try_teleporting_camera_based_on_local_texture_rect_position(event.position)


func _on_tactical_ping(world_position: Vector3):
	var ping_node = Line2D.new()
	ping_node.width = 2.0
	ping_node.default_color = BattleTheme.accent()
	var pts = PackedVector2Array()
	var segs = 16
	for i in range(segs + 1):
		var ang = (float(i) / segs) * TAU
		pts.append(Vector2(cos(ang), sin(ang)))
	ping_node.points = pts
	var minimap_pos = Vector2(world_position.x, world_position.z) * MINIMAP_PIXELS_PER_WORLD_METER
	ping_node.position = minimap_pos
	_viewport_background.add_child(ping_node)
	var tween = create_tween()
	tween.tween_property(ping_node, "scale", Vector2(16.0, 16.0), 0.9)
	tween.parallel().tween_property(ping_node, "modulate:a", 0.0, 0.9)
	tween.tween_callback(ping_node.queue_free)
