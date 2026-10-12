@tool
extends Node3D

@export_range(0.001, 50.0) var radius = 1.0:
	set = _set_radius
@export_range(0.001, 50.0) var width = 10.0:
	set = _set_width

var _selected = false

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


var _range_ring = null


func select():
	if _selected:
		return
	_selected = true
	if not _unit.is_in_group("selected_units"):
		_unit.add_to_group("selected_units")
	_update_circle_color()
	if _circle != null:
		_circle.show()
	if _range_ring == null:
		_setup_range_ring()
	elif _range_ring != null:
		_range_ring.show()
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
	if "deselected" in _unit:
		_unit.deselected.emit()
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null:
		signals.unit_deselected.emit(_unit)


func _setup_range_ring():
	if not "attack_range" in _unit or _unit.attack_range == null or _unit.attack_range <= 0:
		return
	_range_ring = MeshInstance3D.new()
	_range_ring.name = "TacticalRangeRing"
	var torus = TorusMesh.new()
	torus.inner_radius = _unit.attack_range - 0.08
	torus.outer_radius = _unit.attack_range + 0.08
	_range_ring.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.25, 0.2, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_range_ring.material_override = mat
	add_child(_range_ring)
	_range_ring.position = Vector3(0, 0.05, 0)


func _set_radius(a_radius):
	radius = a_radius
	_update_circle_params()


func _set_width(a_width):
	width = a_width
	_update_circle_params()


func _update_circle_color():
	if _circle == null:
		return
	if _unit.is_in_group("controlled_units"):
		_circle.color = Constants.Match.OWNED_PLAYER_CIRCLE_COLOR
	elif _unit.is_in_group("adversary_units"):
		_circle.color = Constants.Match.ADVERSARY_PLAYER_CIRCLE_COLOR
	elif _unit.is_in_group("resource_units"):
		_circle.color = Constants.Match.RESOURCE_CIRCLE_COLOR
	else:
		_circle.color = Constants.Match.DEFAULT_CIRCLE_COLOR


func _update_circle_params():
	if _circle == null:
		return
	_circle.radius = radius
	_circle.width = width
	_circle.inner_edge_width = width


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _selected and Globals.options.selection_modifier_pressed():
			deselect()
			return
		select()
