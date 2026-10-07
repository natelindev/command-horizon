extends "res://tests/rendered/ProgramPreview.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "helix" if side == 0 else "bastion"
		player.color = Color("38c8ce") if side == 0 else Color("e3ad48")
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(18, 0, 20))
	await _frames(60)
	var human = _game._get_human_player()
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	for tank in tanks.slice(0, 1):
		_check(
			tank.program.installed and tank.program.ready_to_run(),
			"Advanced tank missing active chip"
		)
		tank.get_node("Selection").select()
	await _frames(3)
	var tank = tanks[0]
	var source = """return function(s,m)
    m.ticks=(m.ticks or 0)+1
    return {intent={kind='hold',status='Lua guard: watching for contacts.'},state=m}
end"""
	_check(tank.program.configure_lua(source, "Lua guard · test v1").ok, "Lua rejected preview")
	_check(tank.program.run(), "Lua did not run")
	await _frames(50)
	var panel = _game.find_child("UnitMenus")._program_panel
	_check("Running" in panel._status.text, "Lua state not visible")
	await _capture("lua-running-720p")
	tank.program.configure_lua("return function() while true do end end", "Fault test · v1")
	tank.program.run()
	await _frames(50)
	_check(
		"Error" in panel._status.text and "budget" in panel._reason.text,
		"Lua fault is not visible in program UI"
	)
	_check(panel.get_global_rect().end.y <= 720, "Lua fault exceeds 720p panel")
	await _capture("lua-fault-720p")
	var long_error = "return function() error('" + "Bad instruction ".repeat(40) + "') end"
	tank.program.configure_lua(long_error, "Long diagnostic")
	tank.program.run()
	await _frames(40)
	_check(panel._reason.get_line_count() > 2, "Long diagnostic fixture did not wrap")
	_check(
		panel.get_global_rect().end.y <= 720 and panel.get_global_rect().position.y >= 0,
		"Long Lua error pushed controls off screen"
	)
	_check("Bad instruction" in panel._reason.tooltip_text, "Full diagnostic missing from trace")
	await _capture("lua-long-error-720p")
	panel._manual()
	await _frames(4)
	_check(tank.program.mode == "Manual", "Fault UI prevented direct control")
	tank.program.configure_lua(source, "Lua guard · test v2")
	_game.hud._toggle_pause()
	panel._resume()
	await _frames(20)
	_check(tank.program.mode == "Ready", "Paused Lua Resume executed")
	_game.hud._toggle_pause()
	await _frames(40)
	_check(tank.program.mode == "Running", "Lua Resume failed")
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print("PASS: rendered Lua running/fault states; Manual and paused Resume; 720p")
	quit(0 if _errors.is_empty() else 1)
