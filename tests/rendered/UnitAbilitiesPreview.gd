extends "res://tests/headless/UnitAbilitiesRegression.gd"

## Run with a renderer: Godot --path . --script tests/rendered/UnitAbilitiesPreview.gd
## Captures the arc, detonation, lingering smoke, sprint trail and active card.
const OUTPUT = "res://art/unit-abilities/"


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
		push_error("Ability preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore(
		{
			"screen": 1,
			"interface_scale": 1.0,
			"edge_scrolling": false,
			"reduced_flashes": false,
			"reduced_motion": false
		}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for faction in ["bastion", "helix", "frontier"]:
		await _preview(faction)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	preferences.restore(original)
	for message in _errors:
		push_error(message)
	print("Unit abilities preview: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _preview(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction
		settings.players.append(side)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var infantry = _spawn("Infantry", _human, Vector3(40, 0, 22))
	var tank = _spawn("Tank", _human, Vector3(35, 0, 18))
	var siege = _spawn("AdvancedTank", _human, Vector3(45, 0, 18))
	var assault = _spawn("AssaultInfantry", _human, Vector3(43, 0, 24))
	await _frames(12)
	for unit in [infantry, tank, siege, assault]:
		unit.abilities.process_mode = Node.PROCESS_MODE_PAUSABLE
	_game.hud.select_units([infantry, assault, siege], Vector3(40, 0, 20))
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_size_safely(26)
	camera.set_physics_process(false)
	await _frames(12)
	_check(
		infantry.abilities.trigger("frag_grenade", Vector3(46, 0, 24)), "Preview grenade rejected"
	)
	_check(tank.abilities.trigger("smoke_screen"), "Preview smoke rejected")
	_check(siege.abilities.trigger("siege_anchor"), "Preview anchor rejected")
	_check(assault.abilities.trigger("combat_sprint"), "Preview sprint rejected")
	assault.process_mode = Node.PROCESS_MODE_PAUSABLE
	assault.manual_orders.submit({"kind": "move", "point": Vector3(48, 0, 24)}, false, false)
	await _advance(.3)
	var effects = _game.combat_effects
	_check(effects._grenades.size() == 1, "Grenade arc presentation missing")
	if effects._grenades.size() == 1:
		var arc = effects._grenades[0]
		_check(arc.node.position.y > 1.0, "Grenade arc did not rise")
	_check(effects._ability_effects.size() == 3, "Persistent ability presentations missing")
	await _capture(faction + "-arc")
	await _advance(.45)
	_check(
		effects._grenades.is_empty() and not effects._shockwaves.is_empty(),
		"Grenade did not detonate with a shockwave"
	)
	await _capture(faction + "-detonation")
	await _advance(2.0)
	await _capture(faction + "-smoke")
	await _advance(4.6)
	_check(not tank.abilities.is_active("smoke_screen"), "Smoke did not expire at seven seconds")
	_check(not assault.abilities.is_active("combat_sprint"), "Sprint did not expire")
	_check(effects._ability_effects.size() == 1, "Expired particles retained active presentations")
	siege.abilities.trigger("siege_anchor")
	await _frames(2)
	_check(effects._ability_effects.is_empty(), "Anchor lock survived deactivation")
	await _capture(faction + "-expired")
	await _clear()
	_game.queue_free()
	await _frames(5)


func _capture(label):
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUTPUT + label + ".png")
	paused = false
	print("Captured " + label)


func _advance(seconds):
	await _frames(ceili(seconds * Engine.physics_ticks_per_second / Engine.time_scale))
