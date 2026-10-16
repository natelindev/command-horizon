extends "res://tests/headless/SaveRestoreEdges.gd"

# Rendered review captures for the faction battle consoles in English and Chinese:
# closed deck, worker, tank, producer with a full paid queue while other buildings
# produce, the production overview with nothing selected, a hidden battle plan,
# multi-selection, lit alerts beacon, pause menu and technology.
# Run without --headless: Godot --path . --script tests/rendered/HudConsolePreview.gd

const OUTPUT = "res://art/hud-console/"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for setup in [
		["bastion", "ExpandedDesertFrontier", Vector2i(1280, 720), 1.5, "720p", "en"],
		["helix", "AlpineRelay", Vector2i(1920, 1080), 1.0, "1080p", "en"],
		["frontier", "CoastalFoundry", Vector2i(1280, 720), 1.5, "720p", "en"],
		["bastion", "ExpandedDesertFrontier", Vector2i(1280, 720), 1.5, "720p-zh", "zh_CN"],
		["helix", "AlpineRelay", Vector2i(1920, 1080), 1.0, "1080p-zh", "zh_CN"],
		["frontier", "CoastalFoundry", Vector2i(1280, 720), 1.5, "720p-zh", "zh_CN"],
	]:
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
		await create_timer(.5).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = setup[2]
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await _battle(setup[0], setup[1], setup[4])
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
	# Hiding the plan for a capture must not touch the reviewer's settings file.
	var preference_path = "user://hud-preview-options-%d.tres" % OS.get_process_id()
	game.hud.battle_plan.options_path = preference_path
	var human = game._get_human_player()
	var camera = game.get_node("IsometricCamera3D")
	var tank = _units(human, "Tank")[0]
	camera.set_size_safely(30)
	camera.set_position_safely(tank.global_position)
	game.subtitles._on_line({"speaker": "Command", "text": "Battle control online."})
	await _frames(40)
	var label = "%s-%s" % [faction, suffix]
	await _shot(label + "-closed")
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
	game.hud.battle_plan.set_dismissed(true)
	await _frames(10)
	await _shot(label + "-plan-hidden")
	game.hud.battle_plan.set_dismissed(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preference_path))
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
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
