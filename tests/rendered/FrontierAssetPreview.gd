extends SceneTree

var stage
var camera
var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	stage = Node3D.new()
	root.add_child(stage)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("252e32")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9c6d0")
	environment.environment.ambient_light_energy = .7
	stage.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	stage.add_child(camera)
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://art/frontier/roster.json"))
	var catalog = load("res://source/match/FactionCatalog.gd")
	for category in ["units", "buildings"]:
		var display = Node3D.new()
		stage.add_child(display)
		var index = 0
		var models = []
		var spacing = 3.2 if category == "units" else 7.5
		var columns = 4 if category == "units" else 3
		for role in roster:
			var mobile = (
				role
				in [
					"Worker",
					"Infantry",
					"Tank",
					"RepairRobot",
					"CombatRobot",
					"AdvancedTank",
					"Drone",
					"Helicopter"
				]
			)
			if mobile != (category == "units"):
				continue
			var model = load("res://assets/models/frontier/v1/%s.glb" % roster[role]).instantiate()
			var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
			var bounds = catalog._bounds(model, Transform3D.IDENTITY)
			var factor = unit.radius * 1.85 / max(bounds.size.x, bounds.size.z)
			if role == "Infantry":
				factor = 1.15 / bounds.size.y
			elif role in ["Drone", "Helicopter"]:
				factor *= 1.35
			var center = Vector3(
				(index % columns - (columns - 1) * .5) * spacing,
				0,
				(index / columns - .5) * spacing
			)
			model.scale = Vector3.ONE * factor
			model.position = (
				center
				- Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
			)
			if role in ["Drone", "Helicopter"]:
				model.position.y += .65
			display.add_child(model)
			models.append(model)
			var label = Label3D.new()
			label.text = roster[role]
			label.font_size = 40
			label.pixel_size = .006 if mobile else .011
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.position = center + Vector3(0, .04, spacing * .42)
			display.add_child(label)
			unit.free()
			index += 1
		var floor_mesh = MeshInstance3D.new()
		floor_mesh.mesh = PlaneMesh.new()
		floor_mesh.mesh.size = Vector2.ONE * 70
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("39483d")
		floor_mesh.material_override = material
		floor_mesh.position.y = -.02
		display.add_child(floor_mesh)
		camera.size = 15 if category == "units" else 42
		camera.position = Vector3(0, 18, 14)
		camera.look_at(Vector3(0, 0, 0 if category == "units" else 3))
		for frame in range(15):
			await process_frame
		for model in models:
			var bounds = catalog._bounds(model, Transform3D.IDENTITY)
			for corner in range(8):
				var screen_point = camera.unproject_position(bounds.get_endpoint(corner))
				if not root.get_visible_rect().grow(-5).has_point(screen_point):
					errors.append("Clipped review model: " + str(model.name))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/frontier/v1/godot-%s.png" % category)
		display.free()
	for error in errors:
		push_error(error)
	print("Frontier native asset review: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
