extends MeshInstance3D

enum Mode { CONTACT, BREAK, RECHARGE, RESTORED }

const DURATION = .42
const SHADER = preload("res://source/shaders/3d/shield_contact.gdshader")
const LIFECYCLE_SHADER = preload("res://source/shaders/3d/shield_lifecycle.gdshader")
static var _shell: SphereMesh
var target: WeakRef
var age = 0.0
var mode = Mode.CONTACT
var duration = DURATION
var _local_pose = Transform3D.IDENTITY


func _init():
	name = "ShieldContact"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shell == null:
		_shell = SphereMesh.new()
		_shell.radius = 1.0
		_shell.height = 2.0
		_shell.radial_segments = 32
		_shell.rings = 16
	mesh = _shell
	material_override = ShaderMaterial.new()
	material_override.shader = SHADER


func setup(unit, point: Vector3, lifecycle = Mode.CONTACT):
	target = weakref(unit)
	mode = lifecycle
	if mode != Mode.CONTACT:
		material_override.shader = LIFECYCLE_SHADER
		material_override.set_shader_parameter("mode", mode)
		duration = .75 if mode == Mode.BREAK else (1.1 if mode == Mode.RECHARGE else .45)
	var radius = unit.radius if unit.radius != null else .65
	var extent = Vector3(radius, .7, radius)
	var center = Vector3.UP * .65
	var collider = unit.get_node_or_null("CollisionShape3D")
	if collider != null:
		center = collider.position
		if collider.shape is CylinderShape3D:
			extent = Vector3(
				collider.shape.radius, collider.shape.height * .5, collider.shape.radius
			)
		elif collider.shape is BoxShape3D:
			extent = collider.shape.size * .5
	# A little clearance keeps the contact wave outside the armor silhouette.
	extent = extent * 1.2 + Vector3.ONE * .08
	_local_pose = Transform3D(Basis.from_scale(extent), center)
	var direction = (_local_pose.affine_inverse() * unit.to_local(point)).normalized()
	if direction.is_zero_approx():
		direction = Vector3.UP
	if mode == Mode.CONTACT:
		material_override.set_shader_parameter("hit_direction", direction)
	follow()


func follow():
	var unit = target.get_ref() if target != null else null
	if is_instance_valid(unit):
		# Match the displayed vehicle between simulation ticks on fast displays.
		var pose = (
			unit.get_global_transform_interpolated()
			if get_tree().physics_interpolation and unit.can_process()
			else unit.global_transform
		)
		global_transform = pose * _local_pose


func advance(delta: float) -> bool:
	age += delta
	material_override.set_shader_parameter("progress", clampf(age / duration, 0.0, 1.0))
	follow()
	return age >= duration
