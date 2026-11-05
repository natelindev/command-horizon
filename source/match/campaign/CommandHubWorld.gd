extends Node3D

signal station_selected(index)

@export_enum("bastion", "helix", "frontier") var faction = "bastion"
var camera: Camera3D
var stations = []
var _moving = []
var _floating = []
var _clock = 0.0
var _fire_light: OmniLight3D = null
var _fire_mesh: MeshInstance3D = null
var _focus = Vector3(0, 1, 0)
var _accent = Color("dab47a")


func _ready():
	var accents = {
		"bastion": Color("dab47a"), "helix": Color("57ddeb"), "frontier": Color("f09d55")
	}
	_accent = accents[faction]
	var environment = WorldEnvironment.new()
	var sky = Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("101c29") if faction == "helix" else Color("563d31")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("9aaebf")
	sky.ambient_light_energy = .6
	sky.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = sky
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -25, 0)
	sun.light_color = Color("b4ebff") if faction == "helix" else Color("ffce99")
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(11, 9, 13)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	add_child(camera)
	camera.look_at(Vector3(0, 1, 0))
	match faction:
		"bastion":
			_war_train()
		"helix":
			_nexus()
		"frontier":
			_outpost()
	var names = {
		"bastion": ["Command table", "Motor pool", "Radio console"],
		"helix": ["Harmonic spire", "Nanite foundry", "Data archive"],
		"frontier": ["The workbench", "Scrap yard", "The barricade"]
	}[faction]
	for index in 3:
		_station(index, Vector3((index - 1) * 5, .6, 0), names[index])
	var ambience = AudioStreamPlayer.new()
	ambience.name = "HubAmbience"
	ambience.bus = "Ambience"
	ambience.volume_db = -22
	var path = {"bastion": "war-train", "helix": "nexus-core", "frontier": "outpost-campfire"}[faction]
	ambience.stream = load("res://assets/audio/environment/%s.wav" % path).duplicate()
	ambience.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambience.stream.loop_end = int(ambience.stream.get_length() * ambience.stream.mix_rate)
	add_child(ambience)
	ambience.play()


func _material(color: Color, emission = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .65
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material


func _box(point: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = point
	add_child(mesh)
	return mesh


func _cylinder(point: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 1.1
	cylinder.height = height
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	mesh.material_override = _material(color)
	mesh.position = point
	add_child(mesh)
	return mesh


func _station(index: int, point: Vector3, title: String):
	var base = _box(point, Vector3(2.4, 1.1, 1.7), Color("2c3538"))
	var console = _box(point + Vector3(0, .62, 0), Vector3(2.1, .12, 1.4), _accent.darkened(.5))
	console.material_override = _material(_accent.darkened(.35), true)
	for key in 7:
		_box(
			point + Vector3((key - 3) * .23, .71, .42),
			Vector3(.13, .035, .12),
			_accent.darkened(.2)
		)
	if index == 0:
		for marker in 5:
			_cylinder(
				point + Vector3((marker - 2) * .3, .77, -.2 + marker % 2 * .3), .055, .12, _accent
			)
	elif index == 1:
		_box(point + Vector3(-.9, 1.05, -.55), Vector3(.12, .85, .12), Color("68747b"))
		_box(point + Vector3(0, 1.4, -.55), Vector3(1.9, .12, .12), Color("68747b"))
		_cylinder(point + Vector3(.6, 1.03, -.55), .15, .5, _accent.darkened(.3))
	else:
		for rack in 2:
			_box(
				point + Vector3((rack - .5) * .8, 1.05, -.5), Vector3(.65, .85, .5), Color("29343c")
			)
			for light in 3:
				var diode = _box(
					point + Vector3((rack - .5) * .8 - .2 + light * .18, 1.2, -.22),
					Vector3(.07, .07, .02),
					_accent
				)
				diode.material_override = _material(_accent, true)
		_cylinder(point + Vector3(1, 1.5, -.6), .035, 2, Color("7c8586"))
	stations.append(base)
	var area = Area3D.new()
	area.position = point + Vector3.UP * .3
	area.input_ray_pickable = true
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.1, 2.3, 2.3)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(
		func(_camera, event, _position, _normal, _shape):
			if (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed
			):
				station_selected.emit(index)
	)
	var label = Label3D.new()
	label.text = tr(title)
	if index == 0:
		label.text += (
			"\n"
			+ tr(
				{
					"bastion": "Field Marshal Aegis",
					"helix": "Spectre Nyx",
					"frontier": "Pathfinder Rook"
				}[faction]
			)
		)
	label.position = point + Vector3(0, 2.05, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.pixel_size = .007
	label.outline_size = 7
	add_child(label)
	var advisor_path = {
		"bastion": "res://assets/models/bastion/demo/Infantry.glb",
		"helix": "res://assets/models/helix/v1/VectorOperator.glb",
		"frontier": "res://assets/models/frontier/v1/RidgeRanger.glb"
	}[faction]
	var advisor = _model(advisor_path, point + Vector3(-1.45, -.55, .45), .85)
	advisor.rotation.y = -.4


func _war_train():
	var deck = _box(Vector3(0, -.25, 0), Vector3(19, .5, 9), Color("697372"))
	_surface(deck, "concrete", .7)
	_box(Vector3(0, -.8, 0), Vector3(19.7, .8, 9.4), Color("2a3032"))
	for x in [-6.5, 6.5]:
		for z in [-4.1, 4.1]:
			var wheel = _cylinder(Vector3(x, -1.5, z), .8, .45, Color("22292c"))
			wheel.rotation.x = PI / 2
	for z in [-2.8, 2.8]:
		_box(Vector3(0, -2.3, z), Vector3(180, .18, .13), Color("77766d"))
	for index in 50:
		var sleeper = _box(
			Vector3(index * 2.6 - 65, -2.5, 0), Vector3(.28, .18, 7.5), Color("52453a")
		)
		_moving.append(sleeper)
	for x in range(-9, 10, 3):
		_box(Vector3(x, 2.5, -4), Vector3(.35, 5, .4), Color("292f31"))
	_box(Vector3(0, .5, -4), Vector3(19, 1, .4), Color("454443"))
	_box(Vector3(0, 4.8, -4), Vector3(19, .4, .5), Color("292f31"))
	for x in [-9.2, 9.2]:
		_box(Vector3(x, 1.5, 0), Vector3(.4, 3, 9), Color("353e40"))
		_box(Vector3(x * .99, 3.4, -2), Vector3(.7, .4, 4.5), Color("252d31"))
	for x in range(-8, 9, 2):
		_box(Vector3(x, .8, -3.75), Vector3(1.5, .1, .12), Color("b69a5c"))
		var lamp = _box(Vector3(x, 4.45, -3.7), Vector3(1.3, .1, .12), _accent)
		lamp.material_override = _material(_accent, true)
	for z in [-2.5, -1.0, .5, 2.0, 3.5]:
		_box(Vector3(0, .025, z), Vector3(18, .02, .05), Color("a88a54"))
	var desert = _box(Vector3(0, -2.9, -20), Vector3(400, .5, 400), Color("d4a980"))
	_surface(desert, "sand", .2)
	for index in 12:
		var rock = _model(
			"res://assets/models/environment/drylands/GypsumBoulderB.glb",
			Vector3(index * 11 - 60, -2.6, -10 - index % 4 * 4),
			1.1
		)
		rock.rotation.y = index * .7
		_moving.append(rock)
	_model("res://assets/models/environment/desert/CanyonMesa1.glb", Vector3(-12, -3, -45), 1.7)
	_model("res://assets/models/environment/cold/SupplyCrates.glb", Vector3(-7.4, 0, 2), .6)
	_model("res://assets/models/bastion/demo/Tank.glb", Vector3(0, .02, 2.5), .65)


func _nexus():
	for index in 7:
		var floor = _box(
			Vector3((index - 3) * 2.8, -.4 + abs(index - 3) * .06, 0),
			Vector3(2.65, .25, 7),
			Color("263f49")
		)
		floor.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor.material_override.albedo_color.a = .6
		_floating.append({"node": floor, "origin": floor.position, "phase": index})
		for side in [-1, 1]:
			var light = _box(
				floor.position + Vector3(0, .15, side * 3.3), Vector3(2.3, .035, .035), _accent
			)
			light.material_override = _material(_accent, true)
	for index in 3:
		var spire = _cylinder(Vector3((index - 1) * 5, 3.8, -2.7), .18, 6.8, Color("b9d7df"))
		_floating.append({"node": spire, "origin": spire.position, "phase": index * 2})
		for ring in 3:
			var torus = MeshInstance3D.new()
			var mesh = TorusMesh.new()
			mesh.inner_radius = .8 + ring * .15
			mesh.outer_radius = .9 + ring * .15
			torus.mesh = mesh
			torus.material_override = _material(_accent, true)
			torus.position = Vector3((index - 1) * 5, 2 + ring, -2.7)
			add_child(torus)
			_floating.append({"node": torus, "origin": torus.position, "phase": ring + index})
	_model("res://assets/models/helix/v1/PrismSkimmer.glb", Vector3(0, 1, 2.7), .6)
	for index in 22:
		var orbital = _box(
			Vector3((index % 6 - 3) * 8, -4 - index % 3 * 3, -12 - index / 6 * 9),
			Vector3(.4, 6 + index % 4 * 3, .4),
			Color("315264")
		)
		_floating.append({"node": orbital, "origin": orbital.position, "phase": index})


func _outpost():
	var ground = _box(Vector3(0, -.25, 0), Vector3(180, .5, 180), Color("b18d6c"))
	_surface(ground, "sand", .35)
	for index in 5:
		_model(
			"res://assets/models/environment/desert/SandstoneShelfA.glb",
			Vector3((index - 2) * 12, -.5, -12 - index % 2 * 4),
			1.2
		)
	for x in [-8, 7]:
		_box(Vector3(x, 1.2, -2.6), Vector3(3.5, 2.4, .2), Color("514f46"))
		var roof = _box(Vector3(x, 2.5, -2.6), Vector3(4.2, .12, 2.5), Color("7d5744"))
		roof.rotation.z = -.08
	var fire = OmniLight3D.new()
	fire.position = Vector3(0, 1, 3.5)
	fire.light_color = Color("ff9b4a")
	fire.light_energy = 3
	fire.omni_range = 8
	add_child(fire)
	_fire_light = fire
	var flame = _cylinder(Vector3(0, .35, 3.5), .45, .7, Color("ff9a3d"))
	flame.material_override = _material(Color("ff9a3d"), true)
	_fire_mesh = flame
	_floating.append({"node": flame, "origin": flame.position, "phase": 0})
	_model("res://assets/models/frontier/v1/Outrider.glb", Vector3(4, .05, 3), .8)
	_model("res://assets/models/environment/drylands/DerelictBoxcar.glb", Vector3(-9, 0, 3), .6)
	_model("res://assets/models/environment/cold/SupplyCrates.glb", Vector3(-4, 0, 3), .6)
	for index in 8:
		_box(Vector3((index - 3) * .45, .12, 4.3), Vector3(.4, .24, .6), Color("655b4e"))


func _model(path: String, point: Vector3, model_scale: float):
	if not ResourceLoader.exists(path):
		return
	var model = load(path).instantiate()
	model.position = point
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	return model


func _surface(mesh: MeshInstance3D, kind: String, texture_scale: float):
	var material = mesh.material_override
	material.albedo_texture = load("res://assets/textures/terrain/%s_color.jpg" % kind)
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/terrain/%s_normal.jpg" % kind)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * texture_scale
	material.roughness = .9


func focus_station(index: int):
	_focus = Vector3((index - 1) * 2.5, 1, 0)


func _process(delta):
	if not is_instance_valid(camera):
		return
	if not Globals.options.menu_motion:
		return
	_clock += delta
	if _fire_light != null and not Globals.options.reduced_flashes:
		var flicker = .92 + .08 * sin(_clock * 17) * sin(_clock * 9.3)
		_fire_light.light_energy = 3 * flicker
		_fire_mesh.scale.y = flicker
	var target = _focus + Vector3(11, 8, 13)
	camera.position = camera.position.lerp(target, 1 - exp(-delta * 3))
	camera.look_at(_focus)
	for rock in _moving:
		rock.position.x -= delta * 8
		if rock.position.x < -70:
			rock.position.x += 145
	for item in _floating:
		item.node.position.y = item.origin.y + sin(_clock * .7 + item.phase) * .1
