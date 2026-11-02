extends SceneTree

## Native roster portraits from the exact harvesters and receiver used in battle.
## Run with a renderer: Godot --path . --script art/common/render_economic_portraits.gd
var factions
const SUBJECTS = [
	["helix", "Worker", "res://assets/ui/helix/MuleEngineer.png"],
	["frontier", "Worker", "res://assets/ui/frontier/ScrapperRig.png"],
	["bastion", "ForwardRefinery", "res://assets/ui/bastion/structures-v2/ForwardRefinery.png"],
]


func _initialize():
	_run.call_deferred()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Economic portraits require a renderer")
		quit(1)
		return
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
	for subject in SUBJECTS:
		var unit = load(factions.scene_path(subject[0], subject[1])).instantiate()
		factions.prepare_model(unit, subject[0])
		var geometry = unit.get_node("Geometry")
		unit.remove_child(geometry)
		unit.free()
		viewport.add_child(geometry)
		await process_frame
		var bounds = factions._bounds(geometry, Transform3D.IDENTITY)
		camera.size = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.55
		camera.position = bounds.get_center() + Vector3(3.2, 2.7, -4.1)
		camera.look_at(bounds.get_center())
		for frame in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var image = viewport.get_texture().get_image()
		if image.get_used_rect().get_area() < 800 or image.save_png(subject[2]) != OK:
			push_error("Empty or unwritable economic portrait: " + subject[2])
			quit(1)
			return
		geometry.free()
		print("Rendered economic portrait: " + subject[2])
	viewport.queue_free()
	await process_frame
	quit(0)
