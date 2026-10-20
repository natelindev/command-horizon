extends "res://tests/headless/SaveRestoreEdges.gd"

# Rendered review captures for the faction battle consoles in English and Chinese:
# closed deck, full visibility, worker, tank, producer with a full paid queue while other buildings
# produce, the production overview with nothing selected, multi-selection, lit
# alerts beacon, pause menu and technology.
# Run without --headless: Godot --path . --script tests/rendered/HudConsolePreview.gd

const OUTPUT = "res://art/hud-console/"
var _full_visibility_only = false


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
		if not factions.is_empty() and setup[0] not in factions:
			continue
		(
			preferences
			. restore(
				{
					"screen": 1,
					"edge_scrolling": false,
					"day_cycle": false,
					"weather": 1,
					"interface_scale": setup[3],
					"language": setup[5],
				}
			)
		)
		await create_timer(2).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = setup[2]
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await _battle(setup[0], setup[1], setup[4])
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("HUD console preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


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


func _shot(label):
	var resources = game.get_node("HUD/MarginContainer2/Resources").get_global_rect()
	_check(
		game.hud._briefing.position.y >= resources.end.y,
		"Objective covers resource stack: " + label
	)
	_check(
		resources.end.x + 8 <= game.hud.system_plate.get_global_rect().position.x,
		"Top plates overlap: " + label
	)
	var mini = game.find_child("Minimap", true, false).get_global_rect()
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
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
