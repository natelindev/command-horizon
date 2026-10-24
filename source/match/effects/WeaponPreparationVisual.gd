extends Node3D

var _orb
var _label
var _feet = []
# Rocket infantry lock onto aircraft instead of charging a heavy weapon.
var _lock = false
@onready var _unit = get_parent()
@onready var _marker = _unit.get_node("ProjectileOrigin")


func _ready():
	_lock = _unit.type == "RocketInfantry"
	_orb = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 12
	sphere.rings = 6
	_orb.mesh = sphere
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("8bddf3") if _unit.player.faction == "helix" else Color("ffe1a1")
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 2.0
	_orb.material_override = glow
	add_child(_orb)
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
	_orb.global_position = _marker.global_position
	_orb.scale = Vector3.ONE * (0.35 + maxf(0, progress) * 1.2) * (0.45 if _lock else 1.0)
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
