extends Node3D

## A filled, footprint-sized placement ghost; simulation remains authoritative.
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready():
	_mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = Vector3(2.5, .8, .55)
	_mesh.mesh = shape
	_mesh.position.y = .4
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(.9, .93, .88, .4)
	_material.render_priority = 10
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func update_placement(unit, angle):
	var camera = get_viewport().get_camera_3d()
	var point = camera.get_ray_intersection(get_viewport().get_mouse_position())
	visible = point is Vector3 and point.is_finite()
	if not visible:
		return
	position = unit._match.map.ground_point(Vector2(point.x, point.z))
	rotation.y = angle
	var legal = (
		unit._match.engineering.placement_error(unit, "barricade", position, angle).is_empty()
	)
	_material.albedo_color = Color(.9, .93, .88, .4) if legal else Color(.75, .35, .27, .3)
