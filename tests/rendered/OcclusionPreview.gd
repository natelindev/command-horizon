extends "res://tests/rendered/WorldFeedbackPreview.gd"

## Pixel comparisons cover live unselected geometry, renderer batching, fog and
## cloak visibility. The scene retains the normal -30 degree tactical camera.


func _abilities_gallery():
	_output = "res://art/occlusion/" + RenderingServer.get_current_rendering_method() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_camera_node.set_process(false)
	_camera_node.set_size_safely(22)
	_camera_node.set_position_safely(ORIGIN + Vector3(0, 1, 0))
	var behind = _actor("Tank", _human, Vector3(-4, 0, -3))
	var exposed = _actor("Tank", _human, Vector3(4, 0, -3))
	var soldier = _actor("Infantry", _human, Vector3(-2, 0, -3))
	var cloak = _actor("SniperInfantry", _helix, Vector3(-5.7, 0, -3))
	cloak.optical_cloak.concealed = true
	cloak.get_node("OpticalCloakVisual").refresh(1.0)
	_wall(Vector3(-4, 2.8, 1), Vector3(7, 5.6, 1.5))
	await _frames(12)
	var batch = game.get_node("UnitBatchRenderer")
	if batch._native != null:
		_check(batch._units.has(behind), "Occluded tank bypassed native batching")
		_check(batch._units.has(soldier), "Occluded infantry bypassed native batching")
	paused = true
	_set_silhouettes(false)
	await _frames(3)
	var without = await _pixels("01-opaque")
	_set_silhouettes(true)
	await _frames(3)
	var shown = await _pixels("02-silhouettes")
	var hidden_area = _screen_rect(behind, Vector2i(80, 90))
	var soldier_area = _screen_rect(soldier, Vector2i(32, 75))
	var cloak_area = _screen_rect(cloak, Vector2i(32, 75))
	var clear_area = _screen_rect(exposed, Vector2i(80, 90))
	_check(_changed(without, shown, hidden_area) > 60, "Tank silhouette missing behind wall")
	_check(_changed(without, shown, soldier_area) > 12, "Infantry silhouette missing behind wall")
	_check(_changed(without, shown, cloak_area) > 12, "Observed cloaked unit lost its silhouette")
	_check(_changed(without, shown, clear_area) < 8, "Unoccluded model draws its own silhouette")
	# A unit hidden by visibility authority must contribute no x-ray fragments.
	behind.hide()
	soldier.hide()
	cloak.hide()
	if batch._native != null:
		batch._upload_poses()
	await _frames(3)
	var fogged = await _pixels("03-hidden-units")
	_check(_changed(without, fogged, hidden_area) < 8, "Fog-hidden tank leaks a silhouette")
	_check(_changed(without, fogged, soldier_area) < 8, "Fog-hidden infantry leaks a silhouette")
	_check(_changed(without, fogged, cloak_area) < 8, "Concealed hidden unit leaks a silhouette")
	paused = false
	await _clear_gallery()
	await _scenery_gallery()
	await _clear_gallery()
	await _terrain_gallery()


func _terrain_gallery():
	for obstacle in [
		["environment/alpine/AlpineMassifA", 36, -12.0], ["bastion/demo/CliffCluster", 22, -5.0]
	]:
		_camera_node.set_size_safely(obstacle[1])
		_camera_node.set_position_safely(ORIGIN + Vector3(0, 3, 0))
		var mountain = load("res://assets/models/%s.glb" % obstacle[0]).instantiate()
		game.add_child(mountain)
		mountain.position = ORIGIN
		_props.append(mountain)
		var tank = _actor("Tank", _human, Vector3(0, 0, obstacle[2]))
		await _frames(12)
		paused = true
		_set_silhouettes(false)
		await _frames(3)
		var label = obstacle[0].get_file()
		var opaque = await _pixels(label + "-opaque")
		_set_silhouettes(true)
		await _frames(3)
		var silhouette = await _pixels(label + "-silhouette")
		_check(
			_changed(opaque, silhouette, _screen_rect(tank, Vector2i(80, 80))) > 25,
			label + ": mountain/cliff hides the unit without an occlusion cue"
		)
		paused = false
		await _clear_gallery()


func _set_silhouettes(enabled):
	var cache = load("res://source/utils/RuntimeCache.gd").bucket("unit_occlusion_passes")
	for material in cache.values():
		var color: Color = material.get_shader_parameter("silhouette_color")
		color.a = 1.0 if enabled else 0.0
		material.set_shader_parameter("silhouette_color", color)


func _wall(offset, size):
	var wall = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	wall.mesh = box
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("686d72")
	material.roughness = .95
	wall.material_override = material
	game.add_child(wall)
	wall.position = ORIGIN + offset
	_props.append(wall)


func _screen_rect(unit, extent):
	var center = Vector2i(_camera_node.unproject_position(unit.global_position + Vector3.UP * .6))
	return Rect2i(center - extent / 2, extent)


func _changed(before: Image, after: Image, region: Rect2i):
	var count = 0
	region = region.intersection(Rect2i(Vector2i.ZERO, before.get_size()))
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var a = before.get_pixel(x, y)
			var b = after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > .035:
				count += 1
	return count


func _pixels(label):
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels.save_png(_output + label + ".png") == OK, "Failed occlusion capture")
	return pixels


func _scenery_gallery():
	_camera_node.set_size_safely(34)
	_camera_node.set_position_safely(ORIGIN + Vector3(0, 1.6, 0))
	var assets = ["temperate/Farmhouse", "temperate/Barn", "cold/FjordHouseRed"]
	for index in assets.size():
		var model = load("res://assets/models/environment/%s.glb" % assets[index]).instantiate()
		game.add_child(model)
		model.position = ORIGIN + Vector3((index - 1) * 11, 0, 0)
		_props.append(model)
		_actor("Tank", _human, Vector3((index - 1) * 11, 0, 6))
		_actor("Infantry", _human, Vector3((index - 1) * 11 + 2, 0, 6))
	_label("Civilian architecture at tactical scale", Vector3(0, 5.5, 0))
	await _frames(8)
	await _pixels("04-civilian-scale")


func _ground_gallery():
	pass


func _building_gallery(_faction):
	pass
