extends MeshInstance3D

const Cache = preload("res://source/utils/RuntimeCache.gd")
const SHADER = preload("res://source/shaders/3d/unit_contact_shadow.gdshader")

# Contact shadow size multiplier relative to unit movement radius
const SPREAD = 2.1

var _unit = null
var _last_position := Vector3.INF


func _init(unit):
	name = "UnitContactShadow"
	_unit = unit
	var meshes = Cache.bucket("unit_contact_shadow_meshes")
	if not meshes.has("plane"):
		var plane = PlaneMesh.new()
		plane.size = Vector2.ONE
		meshes.plane = plane
	mesh = meshes.plane
	var materials = Cache.bucket("unit_contact_shadow_materials")
	if not materials.has("shadow"):
		var mat = ShaderMaterial.new()
		mat.shader = SHADER
		materials.shadow = mat
	material_override = materials.shadow
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var diameter = maxf(0.5, unit.radius * SPREAD)
	scale = Vector3(diameter, 1.0, diameter)


func _ready():
	# The mark inherits unit visibility and root interpolation. Only a changed
	# simulation transform can change its height relative to the terrain.
	set_notify_transform(true)
	_update_ground_height()


func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		_update_ground_height()


func _update_ground_height():
	if not is_instance_valid(_unit) or _unit.is_queued_for_deletion():
		return
	var current_pos = _unit.global_position
	if current_pos.distance_squared_to(_last_position) > 0.001:
		_last_position = current_pos
		var ground = 0.0
		if (
			"_match" in _unit
			and is_instance_valid(_unit._match)
			and is_instance_valid(_unit._match.map)
		):
			ground = _unit._match.map.height_at(Vector2(current_pos.x, current_pos.z))
		position.y = ground - current_pos.y + 0.012
