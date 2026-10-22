extends SceneTree

# Neutral visual review using the production model, surface treatment and motion.
# Does not change or save user graphics preferences.
const OUTPUT = "res://art/infantry/redesign/"
const ROLES = ["Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero"]


class PreviewUnit:
	extends Node3D
	var type = "Infantry"
	var hp = 100
	var radius = .3


var stage: Node3D
var camera: Camera3D
var soldiers = []
var motions = []


func _initialize():
	call_deferred("_run")


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("InfantryStudioPreview requires a graphical renderer")
		quit(1)
		return
	Engine.max_fps = 60
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("777c7b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce4e8")
	environment.ambient_light_energy = .38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = .2
	environment.ssao_intensity = 2.5
	world.environment = environment
	stage.add_child(world)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_color = Color("fff0dd")
	key.light_energy = 1.4
	key.shadow_enabled = true
	key.light_angular_distance = 2.5
	key.directional_shadow_max_distance = 20
	stage.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("c9d9e5")
	fill.light_energy = .45
	stage.add_child(fill)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("777873")
	material.roughness = .95
	ground.material_override = material
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var factions = load("res://source/match/FactionCatalog.gd")
	var motion_script = load("res://source/match/units/traits/InfantryMotion.gd")
	for faction in factions.IDS:
		for index in range(ROLES.size()):
			var unit = PreviewUnit.new()
			unit.type = ROLES[index]
			var geometry = Node3D.new()
			geometry.name = "Geometry"
			unit.add_child(geometry)
			factions.prepare_model(unit, faction)
			stage.add_child(unit)
			var aura = unit.get_node_or_null("HeroAura")
			if aura != null:
				aura.hide()
				aura.set_physics_process(false)
			unit.position.x = index * .9
			unit.rotation.y = PI + .22
			var motion = motion_script.new()
			motion.setup(unit, 0, unit.type)
			soldiers.append(unit)
			motions.append(motion)
		camera.size = 5.4
		camera.position = Vector3(1.8, 1.9, 5.2)
		camera.look_at(Vector3(1.8, .6, 0))
		await _pose(0, 0)
		await _capture("studio-" + faction + "-lineup")
		await _pose(0, 1)
		await _capture("studio-" + faction + "-aim")
		for index in range(1, soldiers.size()):
			soldiers[index].hide()
		camera.size = 1.48
		camera.position = Vector3(1.7, 1.05, 3.5)
		camera.look_at(Vector3(0, .57, 0))
		await _pose(0, 0)
		await _capture("studio-" + faction + "-detail")
		await _pose(0, 1)
		await _capture("studio-" + faction + "-aim-detail")
		for unit in soldiers:
			unit.queue_free()
		soldiers.clear()
		motions.clear()
		await process_frame
	print("Infantry studio preview complete")
	quit()


func _pose(speed_value, aiming):
	for frame in range(90):
		for motion in motions:
			motion.advance(1.0 / 60, speed_value / 60, frame / 60.0, 0, 0, aiming)


func _capture(label):
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
