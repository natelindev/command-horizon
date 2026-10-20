@tool
extends Node3D

@export_range(0.001, 50.0) var radius = 1.0:
	set = _set_radius
# Rectangular structures (the runway airfield) outline their footprint instead.
@export var half_extents = Vector2.ZERO
@export_range(0.001, 50.0) var width = 3.0:
	set = _set_width

var _selected = false
var _range_ring = null

@onready var _unit = get_parent()
@onready var _circle = find_child("FadedCircle3D")


func _ready():
	_update_circle_params()
	if Engine.is_editor_hint():
		return
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
	if not _unit.is_in_group("selected_units"):
		_unit.add_to_group("selected_units")
	_update_circle_color()
	if _circle != null:
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
	if _unit.is_in_group("selected_units"):
		_unit.remove_from_group("selected_units")
	if _circle != null:
		_circle.hide()
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
	_circle.radius = radius
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
