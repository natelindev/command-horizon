extends SceneTree

# Deterministic video review of production geometry, gait, aiming and wrecks.
# Run graphically with --fixed-fps 30. Encode the frames at 30 fps afterward.
const OUTPUT = "res://tmp/infantry-animation-frames/"
const FPS = 30
const SECONDS = 9
const ROLES = ["Infantry", "RocketInfantry", "SniperInfantry"]
const FACTIONS = ["bastion", "helix", "frontier"]


class PreviewUnit:
	extends Node3D
	var type = "Infantry"
	var hp = 100
	var radius = .3


var stage: Node3D
var camera: Camera3D
var viewport: SubViewport
var soldiers = []
var motions = []
var wrecks = []
var state_label: Label


func _initialize():
	_run.call_deferred()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("InfantryAnimationPreview requires a graphical renderer")
		quit(1)
		return
	Engine.max_fps = FPS
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	# Render at a fixed size independently of native window sizing on macOS.
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	stage = Node3D.new()
	viewport.add_child(stage)
	_build_stage()
	_build_labels()
	var factions = load("res://source/match/FactionCatalog.gd")
	var motion_type = load("res://source/match/units/traits/InfantryMotion.gd")
	var profile_type = load("res://source/match/units/traits/UnitMotionProfile.gd")
	var effects = load("res://source/match/effects/CombatEffects.gd").new()
	for index in ROLES.size():
		var unit = PreviewUnit.new()
		unit.type = ROLES[index]
		var geometry = Node3D.new()
		geometry.name = "Geometry"
		unit.add_child(geometry)
		factions.prepare_model(unit, FACTIONS[index])
		stage.add_child(unit)
		unit.position.x = (index - 1) * 1.4
		unit.rotation.y = PI + .25
		var motion = motion_type.new()
		motion.setup(unit, index * .7, unit.type)
		soldiers.append(unit)
		motions.append(motion)
		var profile = profile_type.new(123 + index)
		(
			wrecks
			. append(
				{
					"node": geometry,
					"rotation": Vector3.ZERO,
					"origin": Vector3.ZERO,
					"age": 0.0,
					"motion": profile.death_motion(true, false, true, Vector3(0, 0, -1)),
				}
			)
		)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for warmup in range(8):
		await process_frame
	for frame in range(FPS * SECONDS):
		var time = float(frame) / FPS
		var speed = 0.0
		if time >= 1.0 and time < 3.5:
			speed = 1.7 * smoothstep(1.0, 1.3, time)
		elif time >= 3.5 and time < 4.0:
			speed = 1.7 * (1.0 - smoothstep(3.5, 4.0, time))
		var aiming = 1.0 if time >= 4.5 else 0.0
		var recoil = 0.0
		if time >= 5.6 and time < 7.0:
			recoil = maxf(0.0, 1.0 - fmod(time - 5.6, .45) / .18)
		for index in soldiers.size():
			var unit = soldiers[index]
			if time < 7.0:
				unit.position += -unit.basis.z * speed / FPS
				motions[index].advance(1.0 / FPS, speed / FPS, time, 0, recoil, aiming)
			else:
				wrecks[index].age = time - 7.0
				effects._update_wreck(wrecks[index])
		var center = soldiers[1].position + Vector3(0, .53, 0)
		camera.position = center + Vector3(4.5, 1.35, 6.8)
		camera.look_at(center)
		state_label.text = "%s  ·  %04.1f s" % [_state(time), time]
		await process_frame
		await RenderingServer.frame_post_draw
		var error = viewport.get_texture().get_image().save_png(OUTPUT + "%04d.png" % frame)
		if error != OK:
			push_error("Failed to save animation frame %d: %d" % [frame, error])
			effects.free()
			quit(1)
			return
		if frame % FPS == 0:
			print("Infantry animation: ", frame, "/", FPS * SECONDS)
	effects.free()
	print("Infantry animation: captured %d frames at %d fps" % [FPS * SECONDS, FPS])
	quit()


func _build_stage():
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
	camera.size = 3.1
	stage.add_child(camera)
	camera.make_current()


func _build_labels():
	var overlay = CanvasLayer.new()
	viewport.add_child(overlay)
	var title = Label.new()
	title.text = "INFANTRY  /  MOTION STUDY"
	title.position = Vector2(44, 34)
	title.add_theme_font_size_override("font_size", 25)
	title.modulate = Color("f1f0e8")
	overlay.add_child(title)
	var roles = Label.new()
	roles.text = "BASTION RIFLEMAN     ·     HELIX ROCKET TROOPER     ·     FRONTIER SNIPER"
	roles.position = Vector2(44, 72)
	roles.add_theme_font_size_override("font_size", 16)
	roles.modulate = Color("deded7")
	overlay.add_child(roles)
	state_label = Label.new()
	state_label.position = Vector2(44, 842)
	state_label.add_theme_font_size_override("font_size", 22)
	state_label.modulate = Color("f1f0e8")
	overlay.add_child(state_label)


func _state(time):
	if time < 1.0:
		return "Idle"
	if time < 3.5:
		return "Walk"
	if time < 4.5:
		return "Stop and settle"
	if time < 5.6:
		return "Raise weapon and brace"
	if time < 7.0:
		return "Fire and recoil"
	return "Collapse"
