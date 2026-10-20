extends "res://tests/headless/SaveRestoreEdges.gd"

# Rendered review captures for the faction battle consoles in English and Chinese:
# closed deck, full visibility, worker, tank, producer with a full paid queue while other buildings
# produce, the production overview with nothing selected, multi-selection, lit
# alerts beacon, pause menu and technology; eight-player and true spectator
# resource rosters at 720p with large UI, including both scroll endpoints.
# Run without --headless: Godot --path . --script tests/rendered/HudConsolePreview.gd
# Use -- --rosters [bastion helix frontier] for only the eight-player matrix.

const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const OUTPUT = "res://art/hud-console/"
var _full_visibility_only = false
var _roster_cases = 0


class RenderErrorLog:
	extends Logger

	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("HUD console preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	var factions = Array(OS.get_cmdline_user_args())
	_full_visibility_only = factions.has("--full-visibility")
	factions.erase("--full-visibility")
	var rosters_only = factions.has("--rosters")
	factions.erase("--rosters")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for setup in [
		["bastion", "battlefields/DesertFrontierMap", Vector2i(1280, 720), 1.5, "720p", "en"],
		["helix", "battlefields/AlpineRelayMap", Vector2i(1920, 1080), 1.0, "1080p", "en"],
		["frontier", "CoastalFoundry", Vector2i(1280, 720), 1.5, "720p", "en"],
		["bastion", "battlefields/DesertFrontierMap", Vector2i(1280, 720), 1.5, "720p-zh", "zh_CN"],
		["helix", "battlefields/AlpineRelayMap", Vector2i(1920, 1080), 1.0, "1080p-zh", "zh_CN"],
		["frontier", "CoastalFoundry", Vector2i(1280, 720), 1.5, "720p-zh", "zh_CN"],
	]:
		if rosters_only or (not factions.is_empty() and setup[0] not in factions):
			continue
		await _configure(preferences, setup[2], setup[3], setup[5])
		await _battle(setup[0], setup[1], setup[4])
	var expected_rosters = 0
	if rosters_only or not _full_visibility_only:
		for faction in ["bastion", "helix", "frontier"]:
			if not factions.is_empty() and faction not in factions:
				continue
			for language in ["en", "zh_CN"]:
				await _configure(preferences, Vector2i(1280, 720), 1.5, language)
				for spectator in [false, true]:
					expected_rosters += 1
					await _many_players(faction, language, spectator)
	_check(
		_roster_cases == expected_rosters,
		"Only %d of %d resource roster cases completed" % [_roster_cases, expected_rosters]
	)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("HUD console preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _configure(preferences, resolution, scale_value, language):
	(
		preferences
		. restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"day_cycle": false,
				"weather": 1,
				"subtitles": true,
				"interface_scale": scale_value,
				"language": language,
			}
		)
	)
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = resolution
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


func _battle(faction, map_name, suffix):
	await _skirmish(faction, "res://source/match/maps/%s.tscn" % map_name, true)
	for player in get_nodes_in_group("players"):
		if player != game._get_human_player():
			player.set_process(false)
	var human = game._get_human_player()
	var camera = game.get_node("IsometricCamera3D")
	var tank = _units(human, "Tank")[0]
	camera.set_size_safely(30)
	camera.set_position_safely(tank.global_position)
	game.subtitles._on_line({"speaker": "Command", "text": "Battle control online."})
	await _frames(40)
	var label = "%s-%s" % [faction, suffix]
	if not _full_visibility_only:
		await _shot(label + "-closed")
	var resource_stack = game.get_node("HUD/MarginContainer2/Resources")
	game.settings.visibility = game.settings.Visibility.FULL
	resource_stack._show_player_bars(get_nodes_in_group("players"))
	await _frames(12)
	await _shot(label + "-full-visibility")
	if _full_visibility_only:
		paused = false
		game.queue_free()
		await _frames(5)
		return
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	resource_stack._hide_all_bars()
	resource_stack._show_player_bars([human])
	await _frames(12)
	var refineries = load("res://source/match/world/PointOfInterestCatalog.gd").sites(game).filter(
		func(site): return site.kind == "refinery"
	)
	if not refineries.is_empty():
		var refinery = refineries[0]
		refinery.captured_by = human
		refinery._update_presentation()
		game.find_child("ResourcesBar")._refresh()
		camera.set_position_safely(refinery.global_position)
		await _frames(20)
		await _shot(label + "-refinery")
		camera.set_position_safely(tank.global_position)
	await _select([_units(human, "Worker")[0]])
	await _shot(label + "-worker")
	tank.hp = int(tank.hp_max * .55)
	await _select([tank])
	await _shot(label + "-tank")
	# A full factory queue while the barracks and HQ produce and a generator rises.
	human.resource_a += 2000
	human.resource_b += 2000
	var factory = _units(human, "VehicleFactory")[0]
	var hq = _units(human, "CommandCenter")[0]
	for index in root.get_node("Constants").Match.Units.PRODUCTION_QUEUE_LIMIT:
		factory.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	for index in 3:
		_units(human, "Barracks")[0].production_queue.produce(
			load("res://source/match/units/Infantry.tscn")
		)
	hq.production_queue.produce(load("res://source/match/units/Worker.tscn"))
	var site = load("res://source/match/units/PowerPlant.tscn").instantiate()
	var spot = hq.global_position + Vector3(-10, 0, 8)
	game._setup_and_spawn_unit(site, Transform3D(Basis(), spot), human)
	site.construct(.4)
	await _select([factory])
	await _shot(label + "-factory")
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(20)
	await _shot(label + "-production")
	await _select(_units(human, "Tank") + _units(human, "Worker"))
	await _shot(label + "-multi")
	root.get_node("MatchSignals").deselect_all_units.emit()
	# Incoming fire on the HQ lights the alerts beacon.
	game.alerts._hit(hq, null)
	await _frames(30)
	await _shot(label + "-alerts")
	game.hud._open_menu()
	await _frames(20)
	await _shot(label + "-pause")
	game.hud._close_menu()
	game.hud.open_technology()
	await _frames(20)
	await _shot(label + "-technology")
	game.hud._close_menu()
	paused = false
	game.queue_free()
	await _frames(5)


func _select(units):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	await _frames(30)


func _many_players(faction, language, spectator):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = not spectator
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	# PER_PLAYER with no human exercises the real spectator roster path.
	settings.visibility = settings.Visibility.PER_PLAYER if spectator else settings.Visibility.FULL
	var constants = root.get_node("Constants")
	var controllers = constants.PlayerType
	for index in range(8):
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			controllers.HUMAN if index == 0 and not spectator else controllers.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = faction
		side.color = constants.Player.COLORS[index]
		settings.players.append(side)
	var scene = "Match" if spectator else "Skirmish"
	game = load("res://source/match/%s.tscn" % scene).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	var players = get_nodes_in_group("players")
	for index in players.size():
		var player = players[index]
		player.set_process(false)
		# Distinct readouts make the first and last plates recognizable in captures.
		player.resource_a = 1000 + index * 250
		player.resource_b = 500 + index * 125
	var human = game._get_human_player()
	_check((human == null) == spectator, "Eight-player fixture has the wrong viewer")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(_units(players[0], "CommandCenter")[0].global_position)
	# Visibility and fog revealers need their first physics updates. Pausing a
	# PER_PLAYER spectator at construction leaves the viewport artificially dark.
	for _tick in range(12):
		await physics_frame
	if spectator:
		var headquarters = _units(players[0], "CommandCenter")[0]
		_check(headquarters.visible, "Spectator cannot see its viewed side after initialization")
		_check(
			game.fog_of_war._unit_to_circles_mapping.has(headquarters),
			"Spectator has no fog reveal for its viewed headquarters"
		)
	paused = true
	await _frames(30)
	var label = (
		"%s-720p-%s-%s"
		% [
			faction,
			"zh" if language == "zh_CN" else "en",
			"spectator-eight-players" if spectator else "eight-players"
		]
	)
	for selected in [false] if spectator else [false, true]:
		root.get_node("MatchSignals").deselect_all_units.emit()
		if selected:
			_units(human, "Worker")[0].get_node("Selection").select()
		if not spectator:
			game.subtitles._on_line({"speaker": "Command", "text": "Battle control online."})
		await _frames(12)
		var state = label + ("-worker" if selected else "-closed")
		_check(
			game.find_child("UnitMenus").is_visible_in_tree() == selected,
			"Roster preview deck does not follow selection: " + state
		)
		await _capture_roster(state, spectator)
	if not spectator:
		# Shrinking the visible roster must clear a previously scrolled offset.
		var resources = game.get_node("HUD/MarginContainer2/Resources")
		resources._hide_all_bars()
		resources._show_player_bars([human])
		await _frames(12)
		_check(
			is_equal_approx(resources.size.y, HudLayout.TOP_PLATE),
			"Roster did not shrink: " + label
		)
		_check(resources.scroll_vertical == 0, "Shrunk roster retained its offset: " + label)
		_check(not resources.get_v_scroll_bar().visible, "Shrunk roster still scrolls: " + label)
		await _shot(label + "-single-player")
	_roster_cases += 1
	paused = false
	game.queue_free()
	await _frames(5)


func _capture_roster(label, spectator):
	var resources = game.get_node("HUD/MarginContainer2/Resources")
	var scrollbar = resources.get_v_scroll_bar()
	var bars = resources.get_node("Bars").get_children()
	_check(
		bars.size() == 8 and bars.all(func(bar): return bar.visible),
		"Roster omits players: " + label
	)
	_check(scrollbar.visible, "Eight-player roster does not scroll at 720p large UI: " + label)
	_check(
		scrollbar.focus_mode == Control.FOCUS_ALL and resources.follow_focus,
		"Roster scrolling lacks keyboard access: " + label
	)
	_check(resources.theme != null, "Roster scrollbar has no battle theme: " + label)
	for bottom in [false, true]:
		resources.scroll_vertical = 10000 if bottom else 0
		await _frames(3)
		var endpoint = bars[-1] if bottom else bars[0]
		_check(
			resources.get_global_rect().encloses(endpoint.get_global_rect()),
			"Roster scroll endpoint is clipped: " + label
		)
		await _shot(label + ("-bottom" if bottom else "-top"), spectator)


func _shot(label, spectator = false):
	var resources = game.get_node("HUD/MarginContainer2/Resources").get_global_rect()
	var mini = game.find_child("Minimap", true, false).get_global_rect()
	_check(
		resources.position == Vector2.ZERO, "Resource stack is not flush to the corner: " + label
	)
	_check(root.get_visible_rect().encloses(resources), "Resource stack exceeds viewport: " + label)
	_check(
		resources.end.y + HudLayout.GAP <= mini.position.y,
		"Resource stack covers minimap: " + label
	)
	if not spectator:
		var briefing = game.hud._briefing.get_global_rect()
		_check(briefing.position.y >= resources.end.y, "Objective covers resource stack: " + label)
		_check(not briefing.intersects(mini), "Objective covers minimap: " + label)
		_check(
			resources.end.x + HudLayout.GAP <= game.hud.system_plate.get_global_rect().position.x,
			"Top plates overlap: " + label
		)
		if game.subtitles._card.is_visible_in_tree():
			_check(
				not game.subtitles._card.get_global_rect().intersects(resources),
				"Caption covers resource stack: " + label
			)
	var deck = game.find_child("UnitMenus", true, false)
	_check(
		not game.find_child("ConsoleFrame", true, false).empty_deck.visible,
		"Empty console covers battlefield: " + label
	)
	if deck.is_visible_in_tree():
		var rect = deck.get_global_rect()
		_check(rect.position.y >= mini.position.y - .5, "Console exceeds height budget: " + label)
		_check(absf(rect.position.x - mini.end.x) < .5, "Console/minimap gap: " + label)
		_check(
			absf(rect.end.x - root.get_visible_rect().end.x) < .5,
			"Console does not span bottom: " + label
		)
		_check(
			absf(rect.end.y - root.get_visible_rect().end.y) < .5,
			"Console does not sit at bottom: " + label
		)
	# Keep an unrelated OS cursor hover from leaving a tooltip over the capture.
	Input.warp_mouse(root.get_visible_rect().size - Vector2(16, 280))
	await _frames(2)
	RenderingServer.force_draw(false)
	var saved = root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	_check(saved == OK, "Could not save HUD capture: " + label)
	print("Captured ", label)
