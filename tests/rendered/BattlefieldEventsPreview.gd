extends "res://tests/headless/BattlefieldEventsRegression.gd"

const OUTPUT = "res://art/battlefield-events/"
var _output = OUTPUT


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Battlefield events preview needs a renderer")
		quit(1)
		return
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	var language = "zh_CN" if "--chinese" in OS.get_cmdline_user_args() else "en"
	_output = OUTPUT + ("zh_CN/" if language == "zh_CN" else "")
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"language": language
		}
	)
	Engine.max_fps = 60
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var maps = ["DesertFrontier", "Emberworks", "CoastalFoundry", "AlpineRelay"]
	if "--desert-only" in OS.get_cmdline_user_args():
		maps = ["DesertFrontier"]
	if "--industrial-only" in OS.get_cmdline_user_args():
		maps = ["Emberworks"]
	for map_name in maps:
		await _event_fixture(map_name)
		var camera = _game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_size_safely(26)
		_advance(255)
		camera.set_position_safely(_game.battlefield_events.occurrences[0].cargos[0].point)
		await _capture(map_name + "-warning")
		_advance(306 if map_name == "DesertFrontier" else 307 if map_name == "Emberworks" else 310)
		_check(
			_game.battlefield_events._actors.size() == (0 if map_name == "AlpineRelay" else 2),
			"Missing automatic transport performance"
		)
		for actor in _game.battlefield_events._actors:
			actor.node.reset_physics_interpolation()
		var point = _game.battlefield_events.occurrences[0].cargos[0].point
		camera.set_position_safely(point)
		_spawn("Worker", 0, point + Vector3(0, 0, 4))
		await _capture(map_name + "-active", map_name in ["DesertFrontier", "Emberworks"])
		await _close()
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Battlefield events preview: %d captures" % (maps.size() * 2))
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _capture(label, frame_transport = false):
	await _frames(20)
	if frame_transport:
		_frame_transport()
	var manager = _game.battlefield_events
	if label.ends_with("-active") and manager.occurrences[0].kind != "alpine":
		var cargo = manager.occurrences[0].cargos[0]
		var camera = _game.get_node("IsometricCamera3D")
		var motion = InputEventMouseMotion.new()
		motion.position = (
			root.get_final_transform() * camera.unproject_position(cargo.point + Vector3.UP * .5)
		)
		motion.global_position = motion.position
		root.push_input(motion, false)
		await _frames(5)
		var overlay = _game.find_child("OwnershipOverlay", true, false)
		var card = overlay.hover_card()
		if card.is_empty():
			var hit = overlay._hovered_unit(camera)
			print(
				label,
				" hover target=",
				hit,
				" expected=",
				cargo.node,
				" gui=",
				root.gui_get_hovered_control(),
				" pointer=",
				overlay._pointer
			)
			if is_instance_valid(hit):
				print(
					"Hover script=",
					hit.get_script(),
					" position=",
					hit.global_position,
					" description=",
					hit.pickup_description() if hit.has_method("pickup_description") else []
				)
		_check(
			not card.is_empty() and card.unit == cargo.node,
			label + ": event supplies do not produce their actual hovered cargo card"
		)
		if not card.is_empty():
			_check(
				card.lines.has(tr("Supplies · %d M / %d E") % [cargo.materials, cargo.electronics]),
				label + ": supply hover omits the cash windfall"
			)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels.save_png(_output + label + ".png") == OK, "Could not save " + label)


func _frame_transport():
	var camera = _game.get_node("IsometricCamera3D")
	var manager = _game.battlefield_events
	var actors = manager._actors.filter(func(record): return record.site == 0)
	_check(not actors.is_empty(), "Event framing has no transport")
	if actors.is_empty():
		return
	var aircraft = _mesh_corners(actors[0].node)
	_check(not aircraft.is_empty(), "Event transport has no renderable bounds")
	if aircraft.is_empty():
		return
	var cargo = manager.occurrences[0].cargos[0]
	var points = aircraft + _mesh_corners(cargo.node)
	for offset in [Vector3(-3, 0, -3), Vector3(3, 0, 5)]:
		points.append(cargo.point + offset)
	var screen = camera.get_viewport().get_visible_rect().size
	# Keep actual airborne mesh bounds and its ground reward clear of the HUD.
	# This only moves the preview camera; simulation time and actors stay fixed.
	var safe = Rect2(screen * Vector2(.27, .18), screen * Vector2(.70, .68))
	var bounds = _projected_bounds(camera, points)
	var scale = maxf(bounds.size.x / safe.size.x, bounds.size.y / safe.size.y)
	camera.set_size_safely(maxf(camera.size, camera.size * scale * 1.12))
	bounds = _projected_bounds(camera, points)
	camera.global_position += (
		camera.project_position(bounds.get_center(), 1.0)
		- camera.project_position(safe.get_center(), 1.0)
	)
	camera.reset_physics_interpolation()
	for point in aircraft:
		_check(camera.is_position_in_frustum(point), "Event transport is outside the frustum")
		_check(safe.has_point(camera.unproject_position(point)), "Event transport is under HUD")
	print(
		"Event framing: %d transport bounds points inside unobstructed viewport" % aircraft.size()
	)


func _mesh_corners(node):
	var points = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var bounds = mesh.get_aabb()
		for corner in 8:
			points.append(mesh.global_transform * bounds.get_endpoint(corner))
	return points


func _projected_bounds(camera, points):
	var bounds = Rect2(camera.unproject_position(points[0]), Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(camera.unproject_position(point))
	return bounds
