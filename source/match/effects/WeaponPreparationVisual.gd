extends Node3D

const SPARK_COUNT = 24
const CHARGE_SHADER = preload("res://source/shaders/3d/weapon_charge.gdshader")
const SPARK_SHADER = preload("res://source/shaders/3d/weapon_charge_sparks.gdshader")

var _orb
var _label
var _sparks
var _focus_material
var _spark_material: ShaderMaterial
var _phase = 0.0
var _spark_phase = 0.0
var _last_progress = 0.0
var _spark_directions = PackedVector3Array()
# Rocket infantry lock onto aircraft instead of charging a heavy weapon.
var _lock = false
@onready var _unit = get_parent()
@onready var _marker = _unit.get_node("ProjectileOrigin")


func _ready():
	_lock = _unit.type == "RocketInfantry"
	_orb = MeshInstance3D.new()
	_orb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var focus = QuadMesh.new()
	focus.size = Vector2.ONE * (1.05 if _lock else 1.6)
	_orb.mesh = focus
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_focus_material = ShaderMaterial.new()
	_focus_material.shader = CHARGE_SHADER
	var tint = Color("72dfff") if _unit.player.faction == "helix" else Color("ffc16a")
	_focus_material.set_shader_parameter("tint", tint)
	_focus_material.set_shader_parameter("lock_on", _lock)
	var optical = _unit.player.faction == "helix"
	_focus_material.set_shader_parameter(
		"focus_style",
		(1 if _unit.type in ["AdvancedTank", "AntiGroundTurret"] else 2) if optical else 0
	)
	_orb.material_override = _focus_material
	add_child(_orb)
	if not _lock:
		_setup_sparks(tint)
	_label = load("res://source/match/debug/UnitInfoLabel.gd").new()
	_label.position = Vector3(0, 2.45, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 26
	_label.pixel_size = 0.012
	_label.refresh_requested.connect(refresh)
	add_child(_label)
	_unit.selected.connect(refresh)
	_unit.deselected.connect(refresh)
	Globals.options.changed.connect(refresh)
	refresh()


func refresh():
	var progress = _unit.weapon_charge_progress
	_orb.visible = progress >= 0
	set_process(progress >= 0)
	if progress < 0:
		_phase = 0.0
		_spark_phase = 0.0
		_last_progress = 0.0
	_update_focus(maxf(0.0, progress))
	var show_info = _label.diagnostics_enabled()
	if show_info:
		# Keep selected-soldier filtering inside diagnostic mode as well.
		_label.content_visible = (
			progress >= 0 and (not _lock or _unit.is_in_group("selected_units"))
		)
		_label.text = ("LOCK %d%%" if _lock else "CHARGE %d%%") % roundi(maxf(progress, 0) * 100)
		if progress < 0 and _unit.type == "AdvancedTank" and _unit.player.faction == "bastion":
			_label.content_visible = (
				_unit.is_in_group("selected_units") or _unit.deployment_left > 0
			)
			_label.text = (
				"DEPLOY %.1f" % _unit.deployment_left if _unit.deployment_left > 0 else "DEPLOYED"
			)


func _setup_sparks(tint):
	# One fixed-size draw call per charging weapon, with no particle tails on cancel.
	_sparks = MultiMeshInstance3D.new()
	_sparks.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.022, 0.022, 0.11)
	_spark_material = ShaderMaterial.new()
	_spark_material.shader = SPARK_SHADER
	_spark_material.set_shader_parameter("tint", tint)
	mesh.material = _spark_material
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = SPARK_COUNT
	_sparks.multimesh = batch
	# Shader displacement must remain inside the CPU culling bounds at every phase.
	_sparks.custom_aabb = AABB(-Vector3.ONE * 1.2, Vector3.ONE * 2.4)
	add_child(_sparks)
	for index in SPARK_COUNT:
		# Angular directions and orientation do not depend on charge or time.
		var angle = index * 2.399963
		var y = 1.0 - 2.0 * (index + 0.5) / SPARK_COUNT
		var radial = sqrt(1.0 - y * y)
		var direction = Vector3(cos(angle) * radial, y, sin(angle) * radial)
		_spark_directions.append(direction)
		batch.set_instance_transform(index, Transform3D(Basis.looking_at(-direction), Vector3.ZERO))


func _process(delta):
	if get_tree().paused:
		return
	var progress = clampf(_unit.weapon_charge_progress, 0.0, 1.0)
	_phase += delta
	# Integrate speed instead of multiplying the entire elapsed time by the
	# latest charge. Progress updates must never teleport a spark along its path.
	_spark_phase += delta * (1.4 + (_last_progress + progress) * .5)
	_last_progress = progress
	_update_focus(progress)


func _update_focus(progress):
	var reduced = Globals.options.reduced_flashes
	_focus_material.set_shader_parameter("charge", progress)
	_focus_material.set_shader_parameter("phase", _phase)
	_focus_material.set_shader_parameter("reduced_motion", reduced)
	# Keep the focus attached to the lens; energy breathes inside the shader.
	_orb.global_position = _marker.global_position
	if _sparks == null:
		return
	_sparks.visible = _orb.visible and not reduced
	if not _sparks.visible:
		return
	_sparks.global_transform = Transform3D(Basis.IDENTITY, _marker.global_position)
	_spark_material.set_shader_parameter("phase", _spark_phase)
	_spark_material.set_shader_parameter("charge", progress)
