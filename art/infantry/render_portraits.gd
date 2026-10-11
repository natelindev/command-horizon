extends SceneTree

# Rebuild portraits from the same faction models and equipment used in battle.
var factions


func _initialize():
	_run.call_deferred()


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	var viewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c8d4de")
	world.environment.ambient_light_energy = .65
	viewport.add_child(world)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	for faction in factions.IDS:
		DirAccess.make_dir_recursive_absolute("res://assets/ui/infantry/" + faction)
		for role in ["Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero"]:
			var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
			factions.prepare_model(unit, faction)
			var geometry = unit.get_node("Geometry")
			unit.remove_child(geometry)
			unit.free()
			viewport.add_child(geometry)
			var bounds = factions._bounds(geometry, Transform3D.IDENTITY)
			var center = bounds.get_center()
			camera.size = maxf(bounds.size.y, bounds.size.z) * 1.12
			camera.position = center + Vector3(2.7, 1.8, -3.7)
			camera.look_at(center)
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(
				"res://assets/ui/infantry/%s/%s.png" % [faction, role]
			)
			geometry.free()
	print("Rendered 15 faction infantry portraits")
	quit()
