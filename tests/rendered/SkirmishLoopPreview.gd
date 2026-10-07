extends "res://tests/rendered/LuaEditorPreview.gd"

var _deadline = 0


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 90000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Skirmish loop UI timed out")
		quit(1)
	return false


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	for faction in ["bastion", "helix"]:
		await _start_loop(faction, false)
		var human = _game._get_human_player()
		var plan = _game.hud.battle_plan
		_check(plan != null and plan.visible, "Skirmish battle plan is missing")
		await _click(plan._action)
		_check(get_nodes_in_group("selected_units").size() == 4, "Guide did not select engineers")
		var worker = get_nodes_in_group("selected_units")[0]
		_check(worker.action == null, "Selection shortcut issued an order")
		_check(plan.get_global_rect().end.y < 495, "Battle plan overlaps minimap at 720p")
		_check(
			not plan.get_global_rect().intersects(_game.find_child("UnitMenus").get_global_rect()),
			"Guide covers construction controls"
		)
		await _capture("loop-%s-economy-720p" % faction)
		plan._toggle.grab_focus()
		_key(KEY_ENTER)
		await _frames(4)
		_check(not plan._body.visible and plan.size.y < 85, "Keyboard collapse failed")
		await _click(plan._toggle)
		var camera = _game.get_node("IsometricCamera3D")
		var materials = get_nodes_in_group("resource_units").filter(
			func(unit): return "resource_a" in unit
		)
		var deposit = materials[0]
		camera.set_position_safely(deposit.global_position)
		await _frames(4)
		await _right_click(camera.unproject_position(deposit.global_position + Vector3.UP * 0.5))
		await _frames(20)
		_check(worker.action != null, "World right-click failed to start harvesting")
		plan.refresh()
		_check("production" in plan._title.text, "Economy orders did not advance guidance")
		await _click(plan._army)
		_check(
			get_nodes_in_group("selected_units").size() == 2,
			"Army shortcut selected noncombat units"
		)
		_game.hud._toggle_pause()
		var time = _game.simulation_time
		await _click(plan._action)
		await _frames(8)
		_check(_game.simulation_time == time, "Guide advanced a paused battle")
		_game.hud._toggle_pause()
		_game.queue_free()
		await _frames(6)
		await _start_loop(faction, true)
		plan = _game.hud.battle_plan
		# Assign the opening economy through ordinary orders so advanced guidance
		# can show the program/assault step without manufacturing any unlock.
		human = _game._get_human_player()
		var engineers = human.get_children().filter(
			func(unit): return "type" in unit and unit.type == "Worker"
		)
		var engineer = engineers[0]
		deposit = get_nodes_in_group("resource_units")[0]
		engineer.issue_manual_order(
			load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposit)
		)
		plan.refresh()
		await _frames(4)
		await _click(plan._action)
		_check(
			_game.find_child("UnitMenus")._program_panel != null,
			"Guide did not expose chip-unit programs"
		)
		_check(plan.get_global_rect().end.y < 495, "Assault guidance covers minimap")
		await _capture("loop-%s-programs-720p" % faction)
		var panel = _game.find_child("UnitMenus")._program_panel
		if panel != null:
			var tank = get_nodes_in_group("selected_units")[0]
			panel._preset.select(panel._preset_ids.find("guard"))
			panel._preset.item_selected.emit(panel._preset.selected)
			await _click(_button_named(panel, "Assign area / route"))
			camera = _game.get_node("IsometricCamera3D")
			await _mouse_click(
				camera.unproject_position(tank.global_position_yless), MOUSE_BUTTON_LEFT
			)
			await _click(_button_named(panel, "Set safe point"))
			await _mouse_click(camera.unproject_position(Vector3(18, 0, 26)), MOUSE_BUTTON_LEFT)
			await _click(panel._run)
			await _frames(30)
			_check(tank.program.mode == "Running", "Guide route failed to start a built-in guard")
			plan.refresh()
			_check("Scout" in plan._title.text, "Guide skipped scouting after programming")
			await _capture("loop-%s-scout-720p" % faction)
			await _click(_button_named(panel, "Manual hold"))
			plan.refresh()
			_check(
				"Scout" in plan._title.text,
				"Manual override incorrectly repeated the program setup lesson"
			)
		_game.queue_free()
		await _frames(6)
	options.restore(original)
	for error in _errors:
		push_error(error)
	print("Skirmish loop UI: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _start_loop(faction, advanced):
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(setup)
	setup._player_faction.select(0 if faction == "bastion" else 1)
	setup._enemy_faction.select(1 if faction == "bastion" else 0)
	setup._start_mode.select(1 if advanced else 0)
	setup._map_list.select(0)
	var settings = setup._create_match_settings()
	setup.queue_free()
	await _frames(2)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)


func _right_click(point):
	await _mouse_click(point, MOUSE_BUTTON_RIGHT)


func _mouse_click(point, button):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(4)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)
