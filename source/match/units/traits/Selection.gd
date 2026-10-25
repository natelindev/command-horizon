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
var _animation_time = 0.0
var _faction_style = -1

@onready var _unit = get_parent()
@onready var _circle = find_child("FadedCircle3D")


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
		if selection._range_ring != null:
			selection._range_ring.visible = selected.size() == 1


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


func _process(delta):
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


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _selected and Globals.options.selection_modifier_pressed():
			deselect()
			return
		select()
