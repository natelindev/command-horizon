extends Node3D

const SPARK_COUNT = 24
const CHARGE_SHADER = preload("res://source/shaders/3d/weapon_charge.gdshader")

var _orb
var _label
var _sparks
var _focus_material
var _phase = 0.0
var _feet = []
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
	if _unit.type == "AdvancedTank" and _unit.player.faction == "helix":
		var steel = StandardMaterial3D.new()
		steel.albedo_color = Color("617d8b")
		steel.metallic = 0.65
		for x in [-1, 1]:
			for z in [-1, 1]:
				var foot = MeshInstance3D.new()
				var mesh = BoxMesh.new()
				mesh.size = Vector3(0.45, 0.1, 0.18)
				foot.mesh = mesh
				foot.material_override = steel
				foot.position = Vector3(x * 0.55, 0.05, z * 0.43)
				add_child(foot)
				_feet.append(foot)
	refresh()


func refresh():
	var progress = _unit.weapon_charge_progress
	_orb.visible = progress >= 0
	set_process(progress >= 0)
	if progress < 0:
		_phase = 0.0
	_update_focus(maxf(0.0, progress))
	var show_info = _label.diagnostics_enabled()
	if show_info:
		# Keep selected-soldier filtering inside diagnostic mode as well.
		_label.content_visible = (
			progress >= 0 and (not _lock or _unit.is_in_group("selected_units"))
		)
		_label.text = ("LOCK %d%%" if _lock else "CHARGE %d%%") % roundi(maxf(progress, 0) * 100)
	if not _feet.is_empty():
		var setup = 1.0 - _unit.deployment_left / _unit.DEPLOY_SECONDS
		for foot in _feet:
			foot.scale.x = 0.1 + setup * 0.9
		if show_info and progress < 0:
			_label.content_visible = (
				_unit.is_in_group("selected_units") or _unit.deployment_left > 0
			)
			_label.text = "DEPLOY %.1f" % _unit.deployment_left if setup < 1 else "DEPLOYED"


func _setup_sparks(tint):
	# One fixed-size draw call per charging weapon, with no particle tails on cancel.
	_sparks = MultiMeshInstance3D.new()
	_sparks.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.022, 0.022, 0.11)
	var glow = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = tint
	glow.emission_enabled = true
	glow.emission = tint
	glow.emission_energy_multiplier = 1.5
	mesh.material = glow
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = SPARK_COUNT
	_sparks.multimesh = batch
	add_child(_sparks)


func _process(delta):
	_phase += delta
	_update_focus(clampf(_unit.weapon_charge_progress, 0.0, 1.0))


func _update_focus(progress):
	var reduced = Globals.options.reduced_flashes
	_focus_material.set_shader_parameter("charge", progress)
	_focus_material.set_shader_parameter("phase", _phase)
	_focus_material.set_shader_parameter("reduced_motion", reduced)
	var jitter = Vector3.ZERO
	if not _lock and progress > 0.75 and not reduced:
		var strength = (progress - 0.75) * 0.12
		jitter = Vector3(sin(_phase * 173), sin(_phase * 211), cos(_phase * 157)) * strength
	_orb.global_position = _marker.global_position + jitter
	if _sparks == null:
		return
	_sparks.visible = _orb.visible and not reduced
	if not _sparks.visible:
		return
	_sparks.global_transform = Transform3D(Basis.IDENTITY, _marker.global_position)
	_sparks.multimesh.visible_instance_count = 8 + roundi(progress * (SPARK_COUNT - 8))
	for index in _sparks.multimesh.visible_instance_count:
		# Golden-angle distribution and independent cycles avoid a rotating dotted ball.
		var angle = index * 2.399963
		var y = 1.0 - 2.0 * (index + 0.5) / SPARK_COUNT
		var radial = sqrt(1.0 - y * y)
		var direction = Vector3(cos(angle) * radial, y, sin(angle) * radial)
		var travel = fposmod(_phase * (1.4 + progress) + index * 0.618034, 1.0)
		var radius = 0.07 + (1.0 - travel) * (1.0 - travel) * (0.85 + progress * 0.3)
		var size = sin(travel * PI) * (0.65 + progress * 0.55)
		var basis = Basis.looking_at(-direction).scaled(Vector3.ONE * size)
		_sparks.multimesh.set_instance_transform(index, Transform3D(basis, direction * radius))
