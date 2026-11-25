extends Node3D

enum BlueprintPositionValidity {
	VALID,
	COLLIDES_WITH_OBJECT,
	NOT_NAVIGABLE,
	NOT_ENOUGH_RESOURCES,
	OUT_OF_MAP,
	STRUCTURE_LIMIT,
}

const Bindings = preload("res://source/input/KeyBindings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const ROTATION_BY_KEY_STEP = 45.0
const ROTATION_DEAD_ZONE_DISTANCE = 0.1

const MATERIALS_ROOT = "res://source/match/resources/materials/"
const BLUEPRINT_VALID_PATH = MATERIALS_ROOT + "blueprint_valid.material.tres"
const BLUEPRINT_INVALID_PATH = MATERIALS_ROOT + "blueprint_invalid.material.tres"

var _active_blueprint_node = null
var _pending_structure_radius = null
# Local outline of a polygon-footprint structure (runway airfield); empty otherwise.
var _pending_structure_outline = PackedVector2Array()
var _pending_structure_navmap_rid = null
var _pending_structure_prototype = null
var _blueprint_rotating = false
var _placement_range = null
var _feedback
var _footprint
var _blueprint_materials = []
var _phase = 0.0

@onready var _player = get_parent()
@onready var _match = find_parent("Match")


func _ready():
	var feedback_layer = CanvasLayer.new()
	feedback_layer.layer = 4
	add_child(feedback_layer)
	_feedback = load("res://source/match/hud/PlacementFeedback.gd").new()
	feedback_layer.add_child(_feedback)
	MatchSignals.place_structure.connect(_on_structure_placement_request)
	_blueprint_materials = [
		preload(BLUEPRINT_INVALID_PATH).duplicate(), preload(BLUEPRINT_VALID_PATH).duplicate()
	]


func _process(delta):
	if not _structure_placement_started():
		return
	if not get_tree().paused:
		_phase += delta
	for material in _blueprint_materials:
		material.set_shader_parameter("phase", _phase)
		material.set_shader_parameter("steady", Globals.options.reduced_flashes)


func _input(event):
	if not event is InputEventKey or not _structure_placement_started():
		return
	var focus = get_viewport().gui_get_focus_owner()
	var manager = get_node_or_null("/root/SaveManager")
	if (
		focus is LineEdit
		or focus is TextEdit
		or is_instance_valid(Globals.settings_dialog)
		or (manager != null and is_instance_valid(manager.dialog))
		or (
			"hud" in _match
			and is_instance_valid(_match.hud)
			and "_overlay" in _match.hud
			and _match.hud._overlay != null
		)
	):
		return
	if Bindings.pressed(event, "rotate_structure"):
		_try_rotating_blueprint_by(ROTATION_BY_KEY_STEP)
		get_viewport().set_input_as_handled()


func _unhandled_input(event):
	if not _structure_placement_started():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_lmb_down_event(event)
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_handle_lmb_up_event(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_rmb_event(event)
	if event is InputEventMouseMotion:
		_handle_mouse_motion_event(event)


func _handle_lmb_down_event(event):
	get_viewport().set_input_as_handled()
	_set_blueprint_position(event.position)
	_start_blueprint_rotation()


func _handle_lmb_up_event(_event):
	get_viewport().set_input_as_handled()
	var blueprint_position_validity = _calculate_blueprint_position_validity()
	if blueprint_position_validity == BlueprintPositionValidity.VALID:
		_finish_structure_placement()
	elif blueprint_position_validity == BlueprintPositionValidity.NOT_ENOUGH_RESOURCES:
		MatchSignals.not_enough_resources_for_construction.emit(_player)
	_finish_blueprint_rotation()


func _handle_rmb_event(event):
	get_viewport().set_input_as_handled()
	if event.pressed:
		_finish_blueprint_rotation()
		_cancel_structure_placement()


func _handle_mouse_motion_event(event):
	get_viewport().set_input_as_handled()
	if _blueprint_rotation_started():
		_rotate_blueprint_towards_mouse_pos()
	else:
		_set_blueprint_position(event.position)
	var blueprint_position_validity = _calculate_blueprint_position_validity()
	_update_feedback_label(blueprint_position_validity)
	_update_blueprint_color(blueprint_position_validity == BlueprintPositionValidity.VALID)


func _structure_placement_started():
	return _active_blueprint_node != null


func _blueprint_rotation_started():
	return _blueprint_rotating == true


func _calculate_blueprint_position_validity():
	if (
		_player.get_meta("skirmish", false)
		and _player.structure_count() >= Factions.Bastion.STRUCTURE_LIMIT
	):
		return BlueprintPositionValidity.STRUCTURE_LIMIT
	if _active_bluprint_out_of_map():
		return BlueprintPositionValidity.OUT_OF_MAP
	if not _player_has_enough_resources():
		return BlueprintPositionValidity.NOT_ENOUGH_RESOURCES
	if not _pending_structure_outline.is_empty():
		return _footprint_validity()
	return _radius_validity()


func _radius_validity():
	var placement_validity = Utils.Match.Unit.Placement.validate_agent_placement_position(
		_active_blueprint_node.global_position,
		_pending_structure_radius,
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units"),
		_pending_structure_navmap_rid,
		_match.map
	)
	if placement_validity == Utils.Match.Unit.Placement.COLLIDES_WITH_AGENT:
		return BlueprintPositionValidity.COLLIDES_WITH_OBJECT
	if (
		placement_validity
		in [Utils.Match.Unit.Placement.NOT_NAVIGABLE, Utils.Match.Unit.Placement.NOT_LEVEL]
	):
		return BlueprintPositionValidity.NOT_NAVIGABLE
	return BlueprintPositionValidity.VALID


func _footprint_validity():
	var polygon = Footprint.outline_at(
		_pending_structure_outline, _active_blueprint_node.global_transform
	)
	var map_polygon = _match.map.get_topdown_polygon_2d()
	for point in polygon:
		if not Geometry2D.is_point_in_polygon(point, map_polygon):
			return BlueprintPositionValidity.OUT_OF_MAP
	var validity = Utils.Match.Unit.Placement.validate_footprint_placement(
		polygon,
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units"),
		_pending_structure_navmap_rid,
		_match.map
	)
	if validity == Utils.Match.Unit.Placement.COLLIDES_WITH_AGENT:
		return BlueprintPositionValidity.COLLIDES_WITH_OBJECT
	if validity in [Utils.Match.Unit.Placement.NOT_NAVIGABLE, Utils.Match.Unit.Placement.NOT_LEVEL]:
		return BlueprintPositionValidity.NOT_NAVIGABLE
	return BlueprintPositionValidity.VALID


func _player_has_enough_resources():
	var construction_cost = Factions.cost(
		_player, _pending_structure_prototype.resource_path.get_file().get_basename(), true
	)
	return (
		_player.has_resources(construction_cost)
		and Factions.available(
			_player, _pending_structure_prototype.resource_path.get_file().get_basename(), true
		)
	)


func _active_bluprint_out_of_map():
	return not Geometry2D.is_point_in_polygon(
		Vector2(
			_active_blueprint_node.global_transform.origin.x,
			_active_blueprint_node.global_transform.origin.z
		),
		_match.map.get_topdown_polygon_2d()
	)


func _update_feedback_label(blueprint_position_validity):
	var reason = ""
	match blueprint_position_validity:
		BlueprintPositionValidity.STRUCTURE_LIMIT:
			reason = tr("Structure limit reached (%d).") % 40
		BlueprintPositionValidity.COLLIDES_WITH_OBJECT:
			reason = tr("Something already occupies that spot.")
		BlueprintPositionValidity.NOT_NAVIGABLE:
			reason = tr("Choose clear, level ground.")
		BlueprintPositionValidity.NOT_ENOUGH_RESOURCES:
			reason = tr("Not enough resources.")
		BlueprintPositionValidity.OUT_OF_MAP:
			reason = tr("Outside the battlefield.")
	if reason.is_empty():
		_feedback.clear()
	else:
		_feedback.show_reason(reason, _active_blueprint_node.global_position)


func _start_structure_placement(structure_prototype):
	if _structure_placement_started():
		return
	_pending_structure_prototype = structure_prototype
	_active_blueprint_node = (
		load(Constants.Match.Units.STRUCTURE_BLUEPRINTS[structure_prototype.resource_path])
		. instantiate()
	)
	if _player.faction in ["helix", "frontier"]:
		var reference = structure_prototype.instantiate()
		var faction_model = Factions.model_geometry(
			_player.faction, reference.type, reference.radius
		)
		reference.free()
		if faction_model != null:
			_active_blueprint_node.free()
			_active_blueprint_node = Node3D.new()
			_active_blueprint_node.add_child(faction_model)
	var blueprint_origin = Vector3(-999, 0, -999)
	var camera_direction_yless = (
		(get_viewport().get_camera_3d().project_ray_normal(Vector2(0, 0)) * Vector3(1, 0, 1))
		. normalized()
	)
	var rotate_towards = blueprint_origin + camera_direction_yless.rotated(Vector3.UP, PI * 0.75)
	_active_blueprint_node.global_transform = Transform3D(Basis(), blueprint_origin).looking_at(
		rotate_towards, Vector3.UP
	)
	add_child(_active_blueprint_node)
	var temporary_structure_instance = _pending_structure_prototype.instantiate()
	_pending_structure_radius = temporary_structure_instance.radius
	_pending_structure_outline = Footprint.local_outline(temporary_structure_instance)
	_footprint = load("res://source/match/effects/BlueprintFootprint.gd").new()
	_footprint.name = "BlueprintFootprint"
	_footprint.map = _match.map
	_footprint.radius = _pending_structure_radius
	_footprint.outline = _pending_structure_outline
	add_child(_footprint)
	var role = temporary_structure_instance.type
	_footprint.has_portal = (
		role in ["CommandCenter", "Barracks", "VehicleFactory", "AircraftFactory"]
	)
	var geometry = _active_blueprint_node
	var bounds = Factions._bounds(geometry, geometry.transform.affine_inverse())
	var portal = preload("res://source/match/effects/StructureActivity.gd").portal_layout(
		role, _player.faction, bounds
	)
	_footprint.portal = portal.position
	_footprint.portal_direction = portal.direction
	_pending_structure_navmap_rid = (
		find_parent("Match")
		. navigation
		. get_navigation_map_rid_by_domain(temporary_structure_instance.movement_domain)
	)
	var properties = Constants.Match.Units.DEFAULT_PROPERTIES.get(
		structure_prototype.resource_path, {}
	)
	_placement_range = preload("res://source/match/effects/TacticalRangeRing.gd").create(
		properties.get("attack_range")
	)
	if _placement_range != null:
		add_child(_placement_range)
		_placement_range.position = blueprint_origin
	temporary_structure_instance.free()
	_set_blueprint_position(get_viewport().get_mouse_position())
	var validity = _calculate_blueprint_position_validity()
	_update_feedback_label(validity)
	_update_blueprint_color(validity == BlueprintPositionValidity.VALID)


func _set_blueprint_position(mouse_pos_2d):
	var mouse_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(mouse_pos_2d)
	if mouse_pos_3d == null:
		return
	_active_blueprint_node.global_transform.origin = mouse_pos_3d
	_feedback.world_position = mouse_pos_3d
	if is_instance_valid(_placement_range):
		_placement_range.global_position = mouse_pos_3d + Vector3.UP * .065


func _update_blueprint_color(blueprint_position_is_valid):
	var material_to_set = _blueprint_materials[1 if blueprint_position_is_valid else 0]
	if "material_override" in _active_blueprint_node:
		_active_blueprint_node.material_override = material_to_set
	for child in _active_blueprint_node.find_children("*", "", true, false):
		if "material_override" in child:
			child.material_override = material_to_set
	if is_instance_valid(_footprint):
		_footprint.refresh(_active_blueprint_node.global_transform, blueprint_position_is_valid)


func _cancel_structure_placement():
	if _structure_placement_started():
		_feedback.clear()
		_active_blueprint_node.queue_free()
		_active_blueprint_node = null
		if is_instance_valid(_placement_range):
			_placement_range.queue_free()
		_placement_range = null
		if is_instance_valid(_footprint):
			_footprint.queue_free()
		_footprint = null


func _finish_structure_placement():
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(
		_player,
		{
			"kind": "build",
			"role": _pending_structure_prototype.resource_path.get_file().get_basename(),
			"point": gate.Protocol.quantize(_active_blueprint_node.global_position),
			"angle": roundi(rad_to_deg(_active_blueprint_node.global_rotation.y) * 1000.0)
		}
	):
		_cancel_structure_placement()
		return
	if _player_has_enough_resources():
		var structure_name = _pending_structure_prototype.resource_path.get_file().get_basename()
		var construction_cost = Factions.cost(_player, structure_name, true)
		_player.subtract_resources(construction_cost)
		MatchSignals.setup_and_spawn_unit.emit(
			_pending_structure_prototype.instantiate(),
			_active_blueprint_node.global_transform,
			_player
		)
		if Input.is_key_pressed(KEY_SHIFT) and _player_has_enough_resources():
			# Continuous shift-building keeps blueprint active for repeated placement
			return
	_cancel_structure_placement()


func _start_blueprint_rotation():
	_blueprint_rotating = true


func _try_rotating_blueprint_by(degrees):
	if not _structure_placement_started():
		return
	_active_blueprint_node.global_transform.basis = (
		_active_blueprint_node.global_transform.basis.rotated(Vector3.UP, deg_to_rad(degrees))
	)
	var validity = _calculate_blueprint_position_validity()
	_update_feedback_label(validity)
	_update_blueprint_color(validity == BlueprintPositionValidity.VALID)


func _rotate_blueprint_towards_mouse_pos():
	var mouse_pos_2d = get_viewport().get_mouse_position()
	var mouse_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(mouse_pos_2d)
	if mouse_pos_3d == null:
		return
	var mouse_pos_yless = mouse_pos_3d * Vector3(1, 0, 1)
	var blueprint_pos_3d = _active_blueprint_node.global_transform.origin
	var blueprint_pos_yless = blueprint_pos_3d * Vector3(1, 0, 1)
	if mouse_pos_yless.distance_to(blueprint_pos_yless) < ROTATION_DEAD_ZONE_DISTANCE:
		return
	var rotation_target = Vector3(mouse_pos_yless.x, blueprint_pos_3d.y, mouse_pos_yless.z)
	if rotation_target.is_equal_approx(_active_blueprint_node.global_transform.origin):
		return
	_active_blueprint_node.global_transform = _active_blueprint_node.global_transform.looking_at(
		rotation_target, Vector3.UP
	)


func _finish_blueprint_rotation():
	_blueprint_rotating = false


func _on_structure_placement_request(structure_prototype):
	_start_structure_placement(structure_prototype)
