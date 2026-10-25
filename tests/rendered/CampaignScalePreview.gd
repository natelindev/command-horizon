extends "res://tests/rendered/SplitSignalPreview.gd"

const Campaigns = preload("res://source/match/campaign/CampaignCatalog.gd")
const VoiceLines = preload("res://source/match/audio/VoiceLines.gd")
var _context = ""


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "subtitle_size": 26})
	if DisplayServer.get_name() != "headless":
		await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://campaign-scale-%d.json" % OS.get_process_id()
	for mission in Campaigns.operations():
		await _campaign(mission)
		game.hud._toggle_pause()
		# This matrix isolates layout; SpeechRegression covers real caption timing.
		game._get_human_player().get_node("BattleVoice").set_process(false)
		var human = game._get_human_player()
		var role = "Infantry" if mission in ["supply_line", "first_orders"] else "Tank"
		_units(human, role)[0].get_node("Selection").select()
		for factor in [1.0, 1.25, 1.5]:
			_context = "%s %d%%" % [mission, roundi(factor * 100)]
			preferences.interface_scale = factor
			preferences.apply()
			await _frames(8)
			_check(
				root.get_visible_rect().size.is_equal_approx(Vector2(1920, 1080) / factor),
				_context + " logical size incorrect"
			)
			var objectives = (
				game.hud.objective_panel if "objective_panel" in game.hud else game.hud.lesson_panel
			)
			_inside(objectives, "objectives")
			_inside(game.find_child("UnitMenus"), "selected unit controls")
			_check(
				game.find_child("UnitMenus").get_global_rect().position.y >= 72,
				_context + " selection controls cover top HUD"
			)
			var minimap = game.find_child("Minimap")
			_check(
				not objectives.get_global_rect().intersects(minimap.get_global_rect()),
				_context + " objectives cover minimap"
			)
			for event in VoiceLines.TEXT:
				game.subtitles._on_line(VoiceLines.record(event))
				await _frames(2)
				_caption_clear(VoiceLines.TEXT[event])
				_check(
					(
						game.subtitles._card.visible
						and game.subtitles._card._text.text == VoiceLines.TEXT[event]
					),
					_context + " requested caption not displayed"
				)
			await _navigate(mission)
			game.subtitles._on_line(VoiceLines.record(VoiceLines.EVENTS.BASE_UNDER_ATTACK))
			await _frames(4)
			if factor == 1.5 or mission == "supply_line":
				await _scale_capture("campaign-scale-%s-%d-720p" % [mission, roundi(factor * 100)])
			print(
				"CHECKED ",
				_context,
				" caption=",
				game.subtitles._card.get_global_rect(),
				" minimap=",
				minimap.get_global_rect()
			)
		if mission == "command_horizon":
			await _selection_fits()
		if mission == "supply_line":
			await _caption_order()
			await _resize_caption()
		await _cleanup()
	preferences.restore(original)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Campaign scale preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _campaign(mission):
	var entry = Campaigns.operations()[mission]
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = mission
	settings.map_path = entry.map
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load(entry.scene).instantiate()
	game.settings = settings
	game.map = load(entry.map).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(12)


func _inside(control, description):
	_check(
		root.get_visible_rect().encloses(control.get_global_rect()),
		_context + " clipped " + description
	)


func _caption_clear(line):
	var card = game.subtitles._card
	_inside(card, "caption " + line)
	for name in ["Minimap", "UnitMenus", "ProductionQueue"]:
		var control = game.find_child(name)
		if control.is_visible_in_tree():
			_check(
				not card.get_global_rect().intersects(control.get_global_rect().grow(8)),
				_context + " caption covers " + name + ": " + line
			)
	_check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Caption intercepts orders")


func _navigate(mission):
	var button
	match mission:
		"supply_line":
			button = game.hud._view_buttons[1]
		"first_orders":
			button = _named_button(game.hud.lesson_panel, "View relay")
		"split_signal":
			button = game.hud._relay_buttons[1]
		"broken_foundry":
			button = _named_button(game.hud.objective_panel, "Foundry")
		"command_horizon":
			button = _named_button(game.hud.objective_panel, "Command")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(14, 0, 14))
	var before = camera.position
	var activations = [0]
	var callback = func(): activations[0] += 1
	button.pressed.connect(callback)
	await _click(button)
	button.pressed.disconnect(callback)
	_check(
		activations[0] == 1 and camera.position.distance_to(before) > 1,
		_context + " scaled navigation click failed"
	)


func _scale_capture(title, pixels = Vector2i(1280, 720)):
	if DisplayServer.get_name() == "headless":
		return
	await _capture(title)
	_check(
		root.get_texture().get_image().get_size() == pixels,
		"Caption capture has incorrect pixel dimensions"
	)


func _caption_order():
	var unit = _units(game._get_human_player(), "Infantry")[0]
	unit.manual_orders.cancel()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(game.map.size.x / 2, 0, game.map.size.y / 2))
	camera.set_size_safely(22)
	await _frames(3)
	var point = root.get_final_transform() * game.subtitles._card.get_global_rect().get_center()
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
		event.position = point
		event.pressed = pressed
		root.push_input(event, false)
	await _frames(4)
	_check(
		not unit.manual_orders.pending.is_empty(),
		"Scaled caption swallowed battlefield right-click"
	)


func _resize_caption():
	for dimensions in [Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(15)
		_caption_clear("live window resize")
		await _scale_capture("campaign-scale-supply-150-%dp" % dimensions.y, dimensions)
	root.size = Vector2i(1280, 720)
	await _frames(15)
	_caption_clear("return to 720p")


func _selection_fits():
	var menu = game.find_child("UnitMenus")
	_check(
		menu.find_children("*", "ScrollContainer", true, false).is_empty(),
		"Bottom menu still scrolls"
	)
	_check(
		root.get_visible_rect().encloses(menu.get_global_rect()), "Bottom menu exceeds the screen"
	)
	await _scale_capture("campaign-scale-horizon-focused-150-720p")
