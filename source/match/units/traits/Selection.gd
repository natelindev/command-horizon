@tool
extends Node3D

const FACTION_STYLES = {"bastion": 0, "helix": 1, "frontier": 2}
const FACTION_SHADER = preload("res://source/shaders/3d/faction_selection.gdshader")

@export_range(0.001, 50.0) var radius = 1.0:
	set = _set_radius
# Rectangular structures (the runway airfield) outline their footprint instead.
@export var half_extents = Vector2.ZERO
@export_range(0.001, 50.0) var width = 3.0:
	set = _set_width

var _selected = false
var _range_ring = null
var _show_range = false
var _animation_time = 0.0
var _faction_style = -1
var _ground_map = null
var _ground_terrain = null
var _ground_point = Vector2.INF
var _ground_elevated = false

@onready var _unit = get_parent()
@onready var _circle = find_child("FadedCircle3D")
# A parent's script properties are fixed; their values remain live below.
@onready var _ground_capable = "movement_domain" in _unit and "_match" in _unit


func _ready():
	_update_circle_params()
	if Engine.is_editor_hint():
		return
	set_process(false)
	_setup_faction_ring()
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null:
		signals.deselect_all_units.connect(deselect)
	if _unit != null and _unit.has_signal("input_event"):
		_unit.input_event.connect(_on_input_event)
	if _circle != null:
		_circle.hide()


func select():
	if _unit.has_meta("garrison_host"):
		var host = _unit.get_meta("garrison_host")
		if not is_instance_valid(host):
			deselect()
			return
		# Vehicle cargo retains its control groups, but commands select the carrier.
		# Shelters and field bunkers keep their existing occupant selection behavior.
		if host.is_in_group("units") and "garrison_mount" in host and host.garrison_mount != null:
			deselect()
			if (
				host != _unit
				and host.player == _unit.player
				and host.hp > 0
				and not host.is_queued_for_deletion()
			):
				var selection = host.get_node_or_null("Selection")
				if selection != null:
					selection.select()
			return
	if _selected:
		return
	_selected = true
	_animation_time = 0.0
	set_process(true)
	if not _unit.is_in_group("selected_units"):
		_unit.add_to_group("selected_units")
	_update_circle_color()
	_set_team_footprint_visible(false)
	if _circle != null:
		_circle.scale = Vector3.ONE * (1.0 if Globals.options.reduced_flashes else 1.15)
		_circle.show()
	_refresh_selected_ranges()
	_update_ground_indicator_visibility()
	if "selected" in _unit:
		_unit.selected.emit()
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null:
		signals.unit_selected.emit(_unit)


func deselect():
	if not _selected:
		return
	_selected = false
	set_process(false)
	if _unit.is_in_group("selected_units"):
		_unit.remove_from_group("selected_units")
	if _circle != null:
		_circle.hide()
	_set_team_footprint_visible(true)
	if _range_ring != null:
		_range_ring.hide()
	_refresh_selected_ranges()
	if "deselected" in _unit:
		_unit.deselected.emit()
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null:
		signals.unit_deselected.emit(_unit)


func _exit_tree():
	if Engine.is_editor_hint() or not _selected:
		return
	_selected = false
	_unit.remove_from_group("selected_units")
	_refresh_selected_ranges()


func _refresh_selected_ranges():
	var selected = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return not unit.is_queued_for_deletion()
	)
	# Group selection keeps ownership outlines, without overlapping attack circles.
	for unit in selected:
		var selection = unit.get_node_or_null("Selection")
		if selection == null:
			continue
		if selected.size() == 1 and selection._range_ring == null:
			selection._setup_range_ring()
		selection._show_range = selected.size() == 1
		if selection._range_ring != null:
			selection._range_ring.visible = (
				selection._show_range and not selection._on_elevated_ground()
			)


func _setup_range_ring():
	if not "attack_range" in _unit or _unit.attack_range == null or _unit.attack_range <= 0:
		return
	_range_ring = preload("res://source/match/effects/TacticalRangeRing.gd").create(
		_unit.attack_range
	)
	add_child(_range_ring)


func _set_radius(a_radius):
	radius = a_radius
	_update_circle_params()


func _setup_faction_ring():
	if _circle == null or _circle._plane == null:
		return
	# Resources retain their neutral circle. Faction units use distinct silhouettes
	# while preserving ownership color and rectangular building footprints.
	if not "player" in _unit or not is_instance_valid(_unit.player):
		return
	var material = _circle._plane.material_override
	material.shader = FACTION_SHADER
	_faction_style = FACTION_STYLES.get(_unit.player.faction, 0)
	material.set_shader_parameter("faction_style", _faction_style)
	material.set_shader_parameter("animation_time", 0.0)
	_circle._plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_circle_params()


func _set_team_footprint_visible(value):
	var footprint = _unit.get_node_or_null("TeamFootprint")
	if footprint != null:
		footprint.visible = value
		if value and footprint.has_method("_process"):
			# Deselecting an aircraft must publish its current ground position
			# before the previously hidden ownership mark becomes visible.
			footprint._process(0.0)


func _on_elevated_ground() -> bool:
	if not _ground_capable:
		return false
	if _unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN:
		return false
	var game = _unit._match
	if not is_instance_valid(game):
		return false
	var map = game.map
	if not is_instance_valid(map) or not map.is_elevated():
		return false
	var point = Vector2(_unit.global_position.x, _unit.global_position.z)
	var terrain = map.get("terrain")
	# Authored terrain is immutable during a match. Editor/map rebuilds replace
	# its model; custom dynamic height providers remain uncached.
	if terrain != null:
		if _ground_map != map or _ground_terrain != terrain or _ground_point != point:
			_ground_map = map
			_ground_terrain = terrain
			_ground_point = point
			_ground_elevated = map.height_at(point) > 0.1
		return _ground_elevated
	return map.height_at(point) > 0.1


func _update_ground_indicator_visibility():
	var visible_on_ground = not _on_elevated_ground()
	if _circle != null:
		_circle.visible = visible_on_ground
	if _range_ring != null:
		_range_ring.visible = visible_on_ground and _show_range


func _process(delta):
	_update_ground_indicator_visibility()
	if _circle == null or _circle._plane == null:
		return
	_animation_time += delta
	var entrance = (
		1.0
		if Globals.options.reduced_flashes
		else 1.0 + .15 * pow(1.0 - clampf(_animation_time / .18, 0.0, 1.0), 3)
	)
	_circle.scale = Vector3.ONE * entrance
	_circle._plane.material_override.set_shader_parameter(
		"animation_time", 0.0 if Globals.options.reduced_flashes else _animation_time
	)


func _set_width(a_width):
	width = a_width
	_update_circle_params()


func _update_circle_color():
	if _circle == null:
		return
	if "player" in _unit and is_instance_valid(_unit.player):
		_circle.color = _unit.player.color
	elif _unit.is_in_group("resource_units"):
		_circle.color = Constants.Match.RESOURCE_CIRCLE_COLOR
	else:
		_circle.color = Constants.Match.DEFAULT_CIRCLE_COLOR


func _update_circle_params():
	if _circle == null:
		return
	# Collision radii fit dense formations; projected marks must clear the hull.
	_circle.radius = radius * (1.4 if _faction_style == 0 else (1.1 if _faction_style > 0 else 1.0))
	_circle.half_extents = half_extents
	_circle.width = width
	_circle.inner_edge_width = 1.5
	_circle.outer_edge_width = 1.0


func _on_input_event(camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _unit != null and _unit.has_method("_is_movable") and not _unit._is_movable():
			var target = Utils.Match.find_unit_at_screen_point(
				get_tree(), camera, event.position, true
			)
			if (
				target != null
				and target != _unit
				and target.has_method("_is_movable")
				and target._is_movable()
			):
				var target_selection = target.get_node_or_null("Selection")
				if target_selection != null:
					if Globals.options.selection_modifier_pressed():
						if target_selection._selected:
							target_selection.deselect()
						else:
							target_selection.select()
					else:
						MatchSignals.deselect_all_units.emit()
						target_selection.select()
					if event.double_click and target.is_in_group("controlled_units"):
						var handler = get_tree().root.find_child(
							"DoubleClickUnitSelectionHandler", true, false
						)
						if handler != null and handler.has_method("handle_double_click"):
							handler.handle_double_click(target.type)
					return
		if _selected and Globals.options.selection_modifier_pressed():
			deselect()
			return
		select()
