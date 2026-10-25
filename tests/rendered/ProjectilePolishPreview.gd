extends SceneTree

# Native rendered review: enlarged geometry, live 35 m/s exhaust, and cooling smoke.
# Captures are written to art/projectile-polish/. Run without --headless.
const OUTPUT = "res://art/projectile-polish/"
var stage
var renderer
var camera
var errors = []


class Ground:
	extends RefCounted

	func height_at(_point):
		return 0.0


class Stage:
	extends Node3D
	var map = Ground.new()
	var restoring = false
	var combat_effects


func _initialize():
	_run.call_deferred()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("ProjectilePolishPreview requires a graphical renderer")
		quit(1)
		return
	Engine.max_fps = 60
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.mode = Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	stage = Stage.new()
	root.add_child(stage)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("111b26")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b2c4d2")
	world.environment.ambient_light_energy = .65
	world.environment.glow_enabled = true
	stage.add_child(world)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.7
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	stage.add_child(camera)
	camera.position = Vector3(7, 11, 17)
	camera.look_at(Vector3(0, 1, 0))
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(100, 100)
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color("28333d")
	floor_mesh.material_override = floor_material
	stage.add_child(floor_mesh)
	renderer = load("res://source/match/effects/ProjectileRenderer.gd").new()
	stage.add_child(renderer)
	var gallery = Node3D.new()
	stage.add_child(gallery)
	var index = 0
	for visual in renderer.SHAPES:
		var mesh = MeshInstance3D.new()
		mesh.mesh = renderer._pools[visual].node.multimesh.mesh
		gallery.add_child(mesh)
		mesh.position = Vector3((index % 3 - 1) * 4.2, 1.5, (index / 3 - .5) * 5)
		mesh.basis = (
			Basis.looking_at(Vector3(-1, .12, -.4).normalized())
			* Basis.from_scale(Vector3(.7, .7, 2.8))
		)
		var label = Label3D.new()
		label.text = visual.replace("_", " ").to_upper()
		label.font_size = 46
		label.pixel_size = .006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		gallery.add_child(label)
		label.position = mesh.position + Vector3(0, 1.0, 0)
		index += 1
	await _capture("geometry")
	gallery.hide()
	camera.position = Vector3(0, 10, 20)
	camera.look_at(Vector3(0, 2, 0))
	camera.size = 9
	var effects = load("res://source/match/effects/CombatEffects.gd").new()
	stage.add_child(effects)
	stage.combat_effects = effects
	var system = load("res://source/match/combat/ProjectileSystem.gd").new()
	stage.add_child(system)
	system.set_physics_process(false)
	var round = system.Round.new()
	round.kind = "missile"
	round.weapon = {"visual": "missile"}
	round.shot = {"player": {"faction": "bastion"}}
	round.shown = true
	round.velocity = Vector3.RIGHT * 35
	round.position = Vector3(-9, 2, 0)
	var baseline = await _capture("trail-baseline")
	renderer.add(round)
	for tick in 30:
		var start = round.position
		round.position += round.velocity / 60.0
		system._trail_segment(round, start, round.position)
		renderer.update(round)
		await _draw()
		if tick == 20:
			var plume = await _capture("continuous-exhaust")
			_check(_changed_pixels(baseline, plume) > 1500, "Continuous exhaust was not rendered")
	renderer.remove(round)
	for tick in 20:
		await _draw()
	var cooling = await _capture("cooling-smoke")
	_check(_changed_pixels(baseline, cooling) > 1000, "Cooling smoke was not rendered")
	options.reduced_flashes = reduced
	stage.free()
	await process_frame
	for error in errors:
		push_error(error)
	print("Projectile polish preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _draw():
	# Native windows may stop automatic draws when another test takes focus.
	# Connect before forcing the draw, and explicitly advance GPU particle time.
	var state = {"drawn": false}
	var drawn = func(): state.drawn = true
	RenderingServer.frame_post_draw.connect(drawn, CONNECT_ONE_SHOT)
	await process_frame
	RenderingServer.force_draw(true, 1.0 / 60.0)
	while not state.drawn:
		await process_frame


func _capture(label):
	await _draw()
	await _draw()
	var picture = root.get_texture().get_image()
	picture.save_png(OUTPUT + label + ".png")
	return picture


func _changed_pixels(before, after):
	var count = 0
	for y in range(0, before.get_height(), 2):
		for x in range(0, before.get_width(), 2):
			var a = before.get_pixel(x, y)
			var b = after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > .06:
				count += 1
	return count


func _check(condition, message):
	if not condition:
		errors.append(message)
