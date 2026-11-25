extends Node3D

# Visual model of the runway airfield. Flat surfaces (runway, taxiway, stands,
# helipad) are built procedurally from the AircraftFactory layout so markings
# always match where aircraft actually roll; the faction's airfield building
# stands at the threshold end as tower and helipad.

const Layout = preload("res://source/match/units/AirfieldLayout.gd")
const SURFACE_Y = 0.02
const ASPHALT = Color("2c2f31")
const CONCRETE = Color("6d6f69")
const PAINT = Color("e8e4d6")
const TAXI_PAINT = Color("e3b23c")
const RUNWAY_LIGHT = Color(1.6, 1.5, 1.2)
const TAXI_LIGHT = Color(0.45, 0.8, 1.8)
const TOWER_SPAN = 4.4

@export var faction = "bastion"
var _materials = {}


func _ready():
	if get_child_count() == 0:
		build(self, faction)


static func create(faction_name):
	var root = new()
	root.name = "Geometry"
	root.faction = faction_name
	build(root, faction_name)
	return root


static func build(root, faction_name):
	var builder = new()
	builder.faction = faction_name
	builder._build_into(root)
	builder.free()


func _surface_palette() -> Dictionary:
	if faction == "helix":
		return {
			"runway": Color("24303a"),
			"pad": Color("4b5a64"),
			"stripe": Color("82e9f2"),
			"taxi": Color("2ad4e0"),
			"r_light": Color(0.25, 0.92, 1.45),
			"t_light": Color(0.25, 0.92, 1.45),
		}
	if faction == "frontier":
		return {
			"runway": Color("544938"),
			"pad": Color("6a5b44"),
			"stripe": Color("dfd4b2"),
			"taxi": Color("d87d36"),
			"r_light": Color(1.5, 0.72, 0.25),
			"t_light": Color(1.3, 0.65, 0.25),
		}
	return {
		"runway": ASPHALT,
		"pad": CONCRETE,
		"stripe": PAINT,
		"taxi": TAXI_PAINT,
		"r_light": RUNWAY_LIGHT,
		"t_light": TAXI_LIGHT,
	}


func _build_into(root):
	var pal = _surface_palette()
	var runway_length = Layout.THRESHOLD_Z - Layout.RUNWAY_END_Z + 1.2
	var runway_center = Vector3(
		Layout.RUNWAY_X, 0, (Layout.THRESHOLD_Z + Layout.RUNWAY_END_Z) * 0.5
	)
	_slab(root, runway_center, Vector2(Layout.RUNWAY_WIDTH, runway_length), pal.runway, 0.0)
	var taxi_length = (Layout.STAND_Z[-1] - Layout.STAND_Z[0]) + 6.2
	_slab(
		root, Vector3(Layout.TAXIWAY_X, 0, 0), Vector2(Layout.TAXIWAY_WIDTH, taxi_length), pal.runway
	)
	# Connectors from both runway ends to the taxiway.
	for z in [Layout.THRESHOLD_Z - 0.4, Layout.RUNWAY_END_Z + 0.4]:
		var from = Layout.RUNWAY_X + Layout.RUNWAY_WIDTH * 0.5
		var to = Layout.TAXIWAY_X + Layout.TAXIWAY_WIDTH * 0.5
		_slab(root, Vector3((from + to) * 0.5 - 0.3, 0, z), Vector2(to - from + 0.6, 1.4), pal.runway)
	_runway_markings(root, runway_length, pal)
	_taxiway_markings(root, taxi_length, pal)
	for z in Layout.STAND_Z:
		_stand(root, Vector3(Layout.STAND_X, 0, z), pal)
	_helipad(root, Layout.PAD_POINTS[1], pal)
	_tower(root)


func _runway_markings(root, runway_length, pal):
	var x = Layout.RUNWAY_X
	var half_width = Layout.RUNWAY_WIDTH * 0.5
	# Edge stripes and centerline dashes.
	for side in [-1, 1]:
		_slab(
			root,
			Vector3(
				x + side * (half_width - 0.12), 0, (Layout.THRESHOLD_Z + Layout.RUNWAY_END_Z) * 0.5
			),
			Vector2(0.08, runway_length - 0.4),
			pal.stripe,
			0.006
		)
	var z = Layout.RUNWAY_END_Z + 2.2
	while z < Layout.THRESHOLD_Z - 2.0:
		_slab(root, Vector3(x, 0, z), Vector2(0.09, 0.9), pal.stripe, 0.006)
		z += 1.6
	# Threshold piano keys at both ends, plus edge lights along the runway.
	for end_z in [Layout.THRESHOLD_Z, Layout.RUNWAY_END_Z]:
		var inward = -signf(end_z)
		for key in range(6):
			var offset = (key - 2.5) * 0.36
			_slab(
				root,
				Vector3(x + offset, 0, end_z + inward * 0.75),
				Vector2(0.18, 0.9),
				pal.stripe,
				0.006
			)
	for side in [-1, 1]:
		var light_z = Layout.RUNWAY_END_Z - 0.4
		while light_z <= Layout.THRESHOLD_Z + 0.5:
			_light(root, Vector3(x + side * (half_width + 0.12), 0, light_z), pal.r_light)
			light_z += 2.0


func _taxiway_markings(root, taxi_length, pal):
	_slab(
		root, Vector3(Layout.TAXIWAY_X, 0, 0), Vector2(0.07, taxi_length - 0.6), pal.taxi, 0.006
	)
	for side in [-1, 1]:
		var z = -taxi_length * 0.5 + 0.4
		while z < taxi_length * 0.5:
			_light(
				root,
				Vector3(Layout.TAXIWAY_X + side * (Layout.TAXIWAY_WIDTH * 0.5 + 0.1), 0, z),
				pal.t_light
			)
			z += 2.4


func _stand(root, point, pal):
	_slab(root, point + Vector3(0.15, 0, 0), Vector2(2.5, 3.1), pal.pad)
	# Lead-in line from the taxiway and a stop bar.
	_slab(root, point + Vector3(-0.6, 0, 0), Vector2(1.6, 0.07), pal.taxi, 0.006)
	_slab(root, point + Vector3(0.95, 0, 0), Vector2(0.07, 1.2), pal.taxi, 0.006)


func _helipad(root, point, pal):
	var pad = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 1.25
	disc.bottom_radius = 1.25
	disc.height = 0.06
	disc.radial_segments = 32
	pad.mesh = disc
	pad.material_override = _material(pal.pad)
	pad.position = point + Vector3.UP * (SURFACE_Y + 0.03)
	root.add_child(pad)
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.05
	torus.rings = 32
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.material_override = _material(pal.taxi)
	ring.position = point + Vector3.UP * (SURFACE_Y + 0.065)
	root.add_child(ring)
	# The "H".
	for offset in [-0.28, 0.28]:
		_slab(root, point + Vector3(offset, 0.05, 0), Vector2(0.1, 0.8), pal.stripe, 0.006)
	_slab(root, point + Vector3(0, 0.05, 0), Vector2(0.56, 0.1), pal.stripe, 0.006)


func _tower(root):
	var model = _faction_building()
	if model == null:
		return
	var holder = Node3D.new()
	holder.name = "Tower"
	holder.position = Layout.TOWER_POINT
	# Face the runway so the building's apron opens toward the taxiway.
	holder.rotation.y = PI * 0.5
	holder.add_child(model)
	root.add_child(holder)


func _faction_building():
	var model = null
	# Loaded at runtime: the faction catalog also loads this builder.
	var factions = load("res://source/match/FactionCatalog.gd")
	if faction == "helix" or faction == "frontier":
		var models = factions.Frontier.MODELS if faction == "frontier" else factions.HELIX_MODELS
		model = load("res://assets/models/%s/v1/%s.glb" % [faction, models.AircraftFactory])
		model = model.instantiate()
		if faction == "frontier":
			factions.FrontierSurfaces.apply(model)
	else:
		model = load("res://assets/models/bastion/structures-v2/AircraftFactory.glb").instantiate()
	var bounds = factions._bounds(model, Transform3D.IDENTITY)
	var factor = TOWER_SPAN / maxf(bounds.size.x, bounds.size.z)
	model.scale = Vector3.ONE * factor
	model.position = (
		-Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	)
	return model


func _slab(root, center, size, color, lift = 0.0):
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(size.x, 0.04, size.y)
	mesh_instance.mesh = box
	mesh_instance.material_override = _material(color)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = Vector3(center.x, center.y + SURFACE_Y + lift, center.z)
	root.add_child(mesh_instance)


func _light(root, point, color):
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.1, 0.08, 0.1)
	mesh_instance.mesh = box
	mesh_instance.material_override = _glow(color)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = point + Vector3.UP * (SURFACE_Y + 0.05)
	root.add_child(mesh_instance)


func _material(color):
	if not _materials.has(color):
		var material = StandardMaterial3D.new()
		material.resource_name = (
			"Runway asphalt"
			if color == ASPHALT
			else "Runway concrete" if color == CONCRETE else "Markings / runway"
		)
		material.albedo_color = color
		material.roughness = 0.92
		_materials[color] = material
	return _materials[color]


func _glow(color):
	var key = "glow" + str(color)
	if not _materials.has(key):
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[key] = material
	return _materials[key]
