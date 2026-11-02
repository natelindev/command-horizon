extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/menu-campaign-art/review/"
var _artwork
var _options


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Menu art preview requires a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	_options = root.get_node("Globals").options
	var original = _options.capture()
	_options.restore(
		{
			"screen": 1,
			"menu_motion": false,
			"edge_scrolling": false,
			"language": "en",
			"interface_scale": 1.0
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	await _frames(2)
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await _frames(30)
	_artwork = load("res://source/main-menu/ArtworkCatalog.gd")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for artwork_path in _artwork.BACKGROUNDS:
		for child in main.get_children():
			if child.has_method("show_art"):
				child.show_art(artwork_path)
		await _shot("main-" + artwork_path.get_file().get_basename())
	main.queue_free()
	await _frames(3)
	await _portraits()
	await _campaign()
	await _briefings()
	await _hub()
	await _dialogue()
	await _pause()
	_options.restore(original)
	for message in errors:
		push_error(message)
	print("Menu campaign art preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _portraits():
	var page = PanelContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.theme = load("res://source/main-menu/ArtTheme.gd").create()
	root.add_child(page)
	var grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 20)
	page.add_child(grid)
	for speaker in _artwork.SPEAKERS:
		var cell = VBoxContainer.new()
		grid.add_child(cell)
		var portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(150, 150)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = load(_artwork.portrait_path(speaker))
		cell.add_child(portrait)
		var label = Label.new()
		label.text = speaker.capitalize()
		cell.add_child(label)
	await _shot("all-speaker-portraits")
	page.queue_free()
	await _frames(3)


func _campaign():
	var menu = load("res://source/main-menu/Campaign.tscn").instantiate()
	menu.progress_path = "user://art-review-no-progress.json"
	root.add_child(menu)
	current_scene = menu
	for index in 3:
		menu._select_faction(index)
		await _shot("campaign-" + menu._faction)
	_options.language = "zh_CN"
	_options.interface_scale = 1.5
	_options.apply()
	await _shot("campaign-compact-zh")
	menu.queue_free()
	await _frames(3)
	_options.language = "en"
	_options.interface_scale = 1.0
	_options.apply()


func _briefings():
	var narration = load("res://source/match/campaign/CampaignNarration.gd")
	for setup in [
		["bastion", "supply_line"],
		["helix", "helix_quiet_streets"],
		["frontier", "frontier_drainage"]
	]:
		var briefing = load("res://source/match/campaign/CampaignBriefing.tscn").instantiate()
		root.add_child(briefing)
		briefing.configure(setup[1])
		for locale in ["en", "zh_CN"]:
			_options.language = locale
			_options.interface_scale = 1.5 if locale == "zh_CN" else 1.0
			_options.apply()
			await _frames(5)
			briefing.configure(setup[1])
			var line = narration.scene(setup[1] + ".briefing", locale)[0]
			briefing.caption.set_line(line.speaker, line.text, 26)
			briefing.caption.set_portrait(line.portrait)
			briefing.seek(12)
			await _shot("briefing-" + setup[0] + "-" + locale)
			_check(
				root.get_visible_rect().encloses(briefing.dialogue_panel.get_global_rect()),
				"Briefing dialogue clipped: " + setup[0] + "/" + locale
			)
		briefing.queue_free()
		await _frames(3)
	_options.language = "en"
	_options.interface_scale = 1.0
	_options.apply()


func _hub():
	var hub = load("res://source/main-menu/CampaignHub.tscn").instantiate()
	hub.hub_state_path = "user://art-review-hub.json"
	hub.progress_path = "user://art-review-no-progress.json"
	root.add_child(hub)
	current_scene = hub
	for index in 3:
		hub._select_faction(index)
		hub._open_station(2)
		hub._play_transmission(hub.Catalog.ORDER[hub.faction][0])
		await _shot("archive-" + hub.faction)
	hub.queue_free()
	await _frames(3)
	DirAccess.remove_absolute("user://art-review-hub.json")


func _pause():
	await _skirmish("bastion")
	for locale in ["en", "zh_CN"]:
		_options.language = locale
		_options.interface_scale = 1.5 if locale == "zh_CN" else 1.0
		_options.apply()
		game.hud._open_menu()
		var picture = game.hud._overlay.find_child("PauseArtwork", true, false)
		for path in _artwork.BACKGROUNDS.slice(0, 3):
			picture.show_art(path)
			await _shot("pause-" + path.get_file().get_basename() + "-" + locale)
		for button in game.hud._overlay.find_children("*", "Button", true, false):
			_check(
				root.get_visible_rect().encloses(button.get_global_rect()),
				"Pause button clipped: " + button.text
			)
		game.hud._close_menu()
	paused = false
	game.queue_free()
	await _frames(4)


func _dialogue():
	var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
	for id in ["supply_line", "helix_quiet_streets", "frontier_drainage"]:
		paused = false
		var entry = catalog.operations()[id]
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.mission_id = id
		settings.map_path = entry.map
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			side.faction = entry.faction if index == 0 else entry.enemy
			settings.players.append(side)
		game = load(entry.scene).instantiate()
		game.settings = settings
		game.map = load(entry.map).instantiate()
		game.progress_path = "user://art-review-no-progress.json"
		root.add_child(game)
		current_scene = game
		await _frames(60)
		game.campaign_story.skip_briefing()
		game.set_physics_process(false)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		if game.campaign_story._voice != null:
			game.campaign_story._voice._clear()
		var camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_position_safely(game.campaign_hero.unit.global_position)
		camera.set_size_safely(30)
		game.campaign_hero.unit.get_node("Selection").select()
		game.campaign_story._play(id + ".intro")
		for locale in ["en", "zh_CN"]:
			_options.language = locale
			_options.interface_scale = 1.5 if locale == "zh_CN" else 1.0
			_options.apply()
			game.campaign_story._refresh_language()
			await _shot("dialogue-" + entry.faction + "-" + locale)
			var card = game.get_node("CampaignSubtitles")._card
			_check(card._portrait.is_visible_in_tree(), "Battle dialogue lost portrait: " + id)
			_check(
				root.get_visible_rect().encloses(card.get_global_rect()),
				"Battle dialogue clipped: " + id + "/" + locale
			)
		game.queue_free()
		await _frames(4)
	_options.language = "en"
	_options.interface_scale = 1.0
	_options.apply()


func _shot(label):
	# Window transitions on macOS can settle after Options.apply(). Keep the
	# physical review at 720p, including large-interface Chinese layouts.
	var deadline = Time.get_ticks_msec() + 5000
	var stable_since = Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1280, 720):
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280, 720)
			stable_since = Time.get_ticks_msec()
		if Time.get_ticks_msec() - stable_since >= 500:
			break
		await process_frame
	await _frames(8)
	await RenderingServer.frame_post_draw
	_check(root.size == Vector2i(1280, 720), "Capture resolution changed: " + label)
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
