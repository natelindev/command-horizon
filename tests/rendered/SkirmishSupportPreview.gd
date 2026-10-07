extends "res://tests/headless/SkirmishSupportRegression.gd"

var preview_deadline = 0


func _initialize():
	Engine.max_fps = 60
	preview_deadline = Time.get_ticks_msec() + 90000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > preview_deadline:
		push_error("Rendered AI support timed out")
		quit(1)
	return false


func _run():
	support_orders = load("res://source/match/units/actions/Repairing.gd")
	var options = root.get_node("Globals").options
	var saved_options = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		var human = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
		enemy.set_process(false)
		human.get_color_material().albedo_color = (
			Color("e3ad48") if faction == "bastion" else Color("38c8ce")
		)
		enemy.get_color_material().albedo_color = (
			Color("38c8ce") if faction == "bastion" else Color("e3ad48")
		)
		var infantry = _support_unit("Infantry", enemy, Vector3(63, 0, 45))
		var tank = _support_unit("Tank", enemy, Vector3(65, 0, 48))
		var robot = _support_unit("RepairRobot", enemy, Vector3(68, 0, 48))
		_support_unit("Drone", human, Vector3(59, 1.5, 48))
		tank.hp = tank.hp_max * 0.4
		await _frames(20)
		enemy._command_army([infantry, tank, robot])
		var camera = game.get_node("IsometricCamera3D")
		camera.set_size_safely(23)
		camera.set_position_safely(Vector3(62, 0, 48))
		var before = tank.hp
		await _frames(240)
		_check(tank.hp > before + 3, "Normal-clock AI support did not repair wounded armor")
		_check(
			is_instance_of(robot.action, support_orders) and robot.action.repair_target() == tank,
			"Rendered AI support chose infantry"
		)
		await _shot("ai-support-repair-" + enemy.faction)
		var attacker = _support_unit("Tank", human, Vector3(55, 0, 50))
		attacker.manual_orders.submit({"kind": "attack_move", "point": Vector3(66, 0, 48)})
		await _frames(180)
		await _shot("ai-support-combat-" + enemy.faction)
		_check(
			game.combat_effects.shots_emitted > 0, "Support preview did not exercise real combat"
		)
		game.hud._toggle_pause()
		var time = game.simulation_time
		var hp = tank.hp if is_instance_valid(tank) else 0
		var point = robot.position if is_instance_valid(robot) else Vector3.ZERO
		await _frames(60)
		await _shot("ai-support-paused-" + enemy.faction)
		_check(game.simulation_time == time, "Support combat clock advanced while paused")
		_check(not is_instance_valid(tank) or tank.hp == hp, "Support repair advanced while paused")
		_check(
			not is_instance_valid(robot) or robot.position == point,
			"Support travel advanced while paused"
		)
		print("PASS: ", enemy.faction, " normal-clock repair, observed combat and tactical pause")
		for actor in [infantry, tank, robot]:
			if is_instance_valid(actor):
				actor.queue_free()
		await _frames(5)
		await _service_ui(human, faction)
		paused = false
		game.queue_free()
		await _frames(5)
	manager.autosaves_enabled = autosaves
	options.restore(saved_options)
	for error in errors:
		push_error(error)
	print("Rendered AI support: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(title):
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == root.size, "AI support capture resolution changed")
	frame.save_png("res://art/skirmish/%s.png" % title)


func _service_ui(human, faction):
	var airfield = _support_unit("AircraftFactory", human, Vector3(65, 0, 48))
	airfield.construct(1.0)
	airfield.hp = airfield.hp_max * 0.5
	var robot = _support_unit("RepairRobot", human, Vector3(54, 0, 48))
	robot.issue_manual_order(support_orders.new(airfield))
	game.hud._toggle_pause()
	var before = airfield.hp
	await _frames(360)
	_check(airfield.hp > before + 5, "Rendered robot did not reach a large building for repair")
	game.hud._toggle_pause()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(30)
	camera.set_position_safely(Vector3(60, 0, 48))
	var menus = game.find_child("UnitMenus", true, false)
	var barracks = _units(human, "Barracks")[0]
	for row in [
		[robot, "building edge", "robot"],
		[airfield, "Aircraft service", "airfield"],
		[barracks, "Infantry recovery", "barracks"]
	]:
		root.get_node("MatchSignals").deselect_all_units.emit()
		row[0].get_node("Selection").select()
		await _frames(15)
		_check(row[1] in menus._status.text, "Service selection panel omitted " + row[1])
		await _shot("service-ui-%s-%s" % [row[2], faction])
	print(
		"PASS: ",
		faction,
		" normal-clock building repair and robot/airfield/barracks service information"
	)
