extends "res://tests/rendered/TerrainLayersPreview.gd"

const FEATURE_OUTPUT = "res://art/presentation-features/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Presentation preview requires a renderer")
		quit(1)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	(
		options
		. restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"day_cycle": false,
				"weather": 1,
				"time_of_day": 2,
				"area_lighting": true,
			}
		)
	)
	Engine.max_fps = 60
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FEATURE_OUTPUT))
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	var cases = 0
	for faction in ["bastion", "helix", "frontier"]:
		paused = false
		await _skirmish(faction, "res://source/match/maps/battlefields/DesertFrontierMap.tscn")
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		var hq = _units(game._get_human_player(), "CommandCenter")[0]
		var center = hq.global_position + Vector3(5, 0, 4)
		var camera = game.get_node("IsometricCamera3D")
		camera.set_position_safely(center)
		camera.set_size_safely(23)
		await _frames(12)
		paused = true
		var wear = game.battlefield_wear
		wear.restore([])
		options.area_lighting = false
		options.apply()
		var off = await _shot(faction + "-off")
		for index in 24:
			wear.add_mark(Vector2(center.x - 5 + index * .45, center.z + 2), .85, 0.0, 0)
		wear.scar(center, 2.5)
		wear.scar(center + Vector3(-4, 0, 3), 1.4)
		await _frames(4)
		_check(wear._drawn == wear.marks.size(), "Drawable ground did not update while paused")
		var marked = await _shot(faction + "-wear")
		_check(_difference(off, marked) > .00001, "Ground texture did not change rendered pixels")
		options.area_lighting = true
		options.apply()
		_check(game.base_area_lighting.lights.size() <= 4, "Area light budget exceeded")
		_check(
			game.base_area_lighting.lights.any(func(light): return light.visible),
			"No visible base lights"
		)
		var on = await _shot(faction + "-lights")
		_check(_difference(marked, on) > .00001, "Area lights did not change rendered pixels")
		if faction == "bastion":
			await _benchmark(options)
			await _hdr_settings(options)
		# Exercise real GPU material compilation and per-axis rotation/scale.
		paused = false
		var impact = Vector3(
			center.x, game.map.height_at(Vector2(center.x, center.z)) + .2, center.z
		)
		game.combat_effects._explosion(impact, 1.5, true, true)
		for index in 10:
			game.combat_effects.trail(impact + Vector3(index * .3, 1.5, 0), Vector3.RIGHT)
		await _frames(5)
		await _shot(faction + "-combat")
		paused = true
		await _frames(2)
		var shards = game.combat_effects._emitters.debris
		_check(
			shards.amount == 192 and shards.process_material.use_rotation_velocity_3d,
			"Shard material lost 3D rotation"
		)
		_check(shards.speed_scale == 0, "Particles did not pause")
		await _tooltips(faction, options)
		if faction == "bastion":
			await _wear_rebuild()
		cases += 1
		paused = false
		game.queue_free()
		await _frames(5)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	options.restore(original)
	_check(cases == 3, "Not all factions rendered")
	for error in errors:
		push_error(error)
	print(
		(
			"Presentation rendered preview: %d failures; HDR support=%s"
			% [errors.size(), options.hdr_supported()]
		)
	)
	quit(0 if errors.is_empty() else 1)


func _shot(label):
	await _frames(8)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty capture: " + label)
	if pixels != null:
		pixels.save_png(FEATURE_OUTPUT + label + ".png")
	print("Captured ", label)
	return pixels


func _difference(first, second):
	var total = 0.0
	for x in range(30, first.get_width() - 30, 7):
		for y in range(100, first.get_height() - 100, 7):
			var a = first.get_pixel(x, y)
			var b = second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	return total / (first.get_width() * first.get_height())


func _benchmark(options):
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for enabled in [false, true]:
		options.area_lighting = enabled
		options.battlefield_wear = enabled
		options.apply()
		await _frames(30)
		var start = Time.get_ticks_usec()
		await _frames(120)
		print(
			(
				"Presentation frame sample: enabled=%s %.2f ms/frame (paused base scene)"
				% [enabled, (Time.get_ticks_usec() - start) / 120000.0]
			)
		)
	options.area_lighting = true
	options.battlefield_wear = true
	options.apply()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60


func _tooltips(faction, options):
	var factory = _units(game._get_human_player(), "VehicleFactory")[0]
	game.hud.select_units([factory])
	await _frames(5)
	var menus = game.find_child("UnitMenus")
	var button = menus._buttons[0].button
	var original_language = options.language
	for locale in ["en", "zh_CN"]:
		options.language = locale
		for scale_value in [1.25, 1.5]:
			options.interface_scale = scale_value
			options.apply()
			var tip = button._make_custom_tooltip(button.tooltip_text)
			var layer = CanvasLayer.new()
			layer.layer = 30
			root.add_child(layer)
			var frame = PanelContainer.new()
			var battle_theme = load("res://source/match/hud/BattleTheme.gd")
			frame.theme = battle_theme.create()
			frame.add_theme_stylebox_override(
				"panel", battle_theme.surface(Color("10191ef5"), 12, 12)
			)
			layer.add_child(frame)
			frame.add_child(tip)
			frame.position = Vector2(40, 150)
			await _frames(5)
			for rich in tip.find_children("*", "RichTextLabel", true, false):
				_check(rich.get_content_height() <= rich.size.y + 1, "Inline tooltip text clipped")
			await _shot("%s-tooltip-%s-%d" % [faction, locale, scale_value * 100])
			layer.queue_free()
			await _frames(2)
	options.language = original_language
	options.interface_scale = 1.0
	options.apply()


func _hdr_settings(options):
	var before = options.capture()
	var dialog = root.get_node("Globals").open_settings()
	dialog._tabs.current_tab = 1
	dialog._preview("hdr_output", true)
	dialog._preview("hdr_peak_nits", 1000.0)
	var calibration = dialog.find_child("HDRCalibration", true, false)
	var scroll = dialog._tabs.get_child(1)
	await _frames(10)
	scroll.ensure_control_visible(calibration)
	await _frames(30)
	var supported = options.hdr_supported()
	print(
		(
			"HDR request: supported=%s requested=%s enabled=%s"
			% [
				supported,
				DisplayServer.window_is_hdr_output_requested(),
				DisplayServer.window_is_hdr_output_enabled()
			]
		)
	)
	if supported:
		_check(
			DisplayServer.window_is_hdr_output_enabled(), "HDR-capable window did not enable output"
		)
	if OS.get_name() == "macOS":
		_check(
			not dialog.controls.hdr_paper_white.editable,
			"Unsupported paper-white control is enabled"
		)
	_check(
		scroll.get_global_rect().encloses(calibration.get_global_rect()),
		"HDR calibration is outside the visible settings area"
	)
	await _shot("hdr-settings")
	dialog._finish(false)
	await _frames(20)
	_check(options.capture() == before, "Cancel lost original graphics preferences")
	_check(
		DisplayServer.window_is_hdr_output_requested() == before.hdr_output,
		"Cancel left HDR requested"
	)


func _wear_rebuild():
	var wear = game.battlefield_wear
	var saved = wear.capture()
	var previous = wear.material.get_shader_parameter("wear_map")
	var full = []
	for index in wear.MAX_MARKS:
		full.append({"x": 20.0, "z": 20.0, "radius": 1.0, "angle": 0.0, "kind": 0})
	wear.restore(full)
	wear._paint()
	_check(wear._drawn == wear.DRAW_BUDGET, "Repaint exceeded its per-frame budget")
	_check(
		wear.material.get_shader_parameter("wear_map") == previous, "Repaint flashed clean terrain"
	)
	await _frames(70)
	_check(not wear._repainting, "Repaint did not finish")
	_check(
		wear.material.get_shader_parameter("wear_map") == wear.texture,
		"Repaint did not swap textures"
	)
	previous = wear.texture
	wear.add_mark(Vector2(21, 20), 1.0, 0.0, 1)
	_check(wear.marks.size() <= wear.MAX_MARKS, "Rendered history exceeded its budget")
	_check(
		wear.material.get_shader_parameter("wear_map") == previous, "Eviction cleared visible marks"
	)
	await _frames(70)
	_check(not wear._repainting, "History eviction never finished repainting")
	wear.restore(saved)
	await _frames(5)
