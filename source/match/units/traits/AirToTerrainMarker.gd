extends Node3D

const CONTROLLED_UNIT_MATERIAL = preload(
	"res://source/match/resources/materials/controlled_unit_air_to_terrain_marker.material.tres"
)
const ADVERSARY_UNIT_MATERIAL = preload(
	"res://source/match/resources/materials/adversary_unit_air_to_terrain_marker.material.tres"
)

@onready var _unit = get_parent()
@onready var _mesh_instance = find_child("MeshInstance3D")


func _ready():
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mesh_instance.visible = _unit.is_in_group("selected_units")
	_unit.selected.connect(_on_unit_selected)
	_unit.deselected.connect(_mesh_instance.hide)


func _update_material():
	if _unit.is_in_group("controlled_units"):
		_mesh_instance.material_override = CONTROLLED_UNIT_MATERIAL
	elif _unit.is_in_group("adversary_units"):
		_mesh_instance.material_override = ADVERSARY_UNIT_MATERIAL
	else:
		assert(false, "unexpected flow")


func _on_unit_selected():
	_update_material()
	_mesh_instance.show()


func _process(_delta):
	if not _mesh_instance.visible:
		return
	var movement = _unit.get_node_or_null("Movement")
	if movement != null and movement.has_method("on_ground") and movement.on_ground():
		_mesh_instance.hide()
		return
	var ground = 0.0
	if (
		is_instance_valid(_unit)
		and "_match" in _unit
		and _unit._match != null
		and _unit._match.map != null
		and _unit._match.map.has_method("height_at")
	):
		ground = _unit._match.map.height_at(
			Vector2(_unit.global_position.x, _unit.global_position.z)
		)
	var height = maxf(0.0, _unit.global_position.y - ground)
	if height < 0.25:
		_mesh_instance.hide()
		return
	_mesh_instance.show()
	_mesh_instance.position.y = -height * 0.5
	_mesh_instance.scale.y = height / 1.6
