extends Node3D

var _ring
var _crown
var _clock = 0.0
@onready var _unit = get_parent()


func _ready():
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("ffdb82")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color("ffca62")
	glow.emission_energy_multiplier = 1.2
	_ring = MeshInstance3D.new()
	_ring.name = "AuraRing"
	var torus = TorusMesh.new()
	torus.inner_radius = .65
	torus.outer_radius = .71
	torus.rings = 48
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.material_override = glow
	_ring.position.y = .045
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_crown = Node3D.new()
	_crown.name = "HeroCrown"
	_crown.position.y = 1.75
	add_child(_crown)
	for index in 3:
		var diamond = MeshInstance3D.new()
		var mesh = PrismMesh.new()
		mesh.size = Vector3(.11, .18 if index == 1 else .13, .055)
		diamond.mesh = mesh
		diamond.position.x = (index - 1) * .13
		diamond.material_override = glow
		diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_crown.add_child(diamond)


func _physics_process(delta):
	visible = _unit.hp != null and _unit.hp > 0 and not _unit.has_meta("garrison_host")
	_clock += delta
	_ring.scale = Vector3.ONE * (1.0 + .045 * sin(_clock * 2.5))
	_crown.position.y = 1.75 + .05 * sin(_clock * 2)
	_crown.rotation.y = -_unit.rotation.y + .6
