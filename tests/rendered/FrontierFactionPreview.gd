extends "res://tests/headless/FrontierGameplayRegression.gd"

var original_options
var options
var preference_file = ""


func _run():
	Engine.max_fps = 60
	factions = load("res://source/match/FactionCatalog.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	options = root.get_node("Globals").options
	original_options = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	preference_file = "user://frontier-menu-%d.cfg" % OS.get_process_id()
	_check(await _menu_flow() == true, "Frontier menu flow aborted")
	if is_instance_valid(game):
		_check(await _battle_flow() == true, "Frontier battle controls aborted")
		await _cleanup()
	DirAccess.remove_absolute(preference_file)
	options.restore(original_options)
	for message in errors:
		push_error(message)
	print("Frontier native controls: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _menu_flow():
	var config = ConfigFile.new()
	config.set_value("setup", "player", 0)
	config.set_value("setup", "enemy", 2)
	config.save(preference_file)
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	setup.preferences_path = preference_file
	root.add_child(setup)
	current_scene = setup
	await _frames(15)
	_check(setup._enemy_faction.selected == 3, "Old Random preference changed into Frontier")
	if "--manual-menu" in OS.get_cmdline_user_args():
		print("FRONTIER MANUAL MENU READY")
		while (
			setup._player_faction.selected != 2
			or setup._enemy_faction.selected != 1
			or setup._start_mode.selected != 1
		):
			await process_frame
		print("FRONTIER MANUAL MENU SELECTED")
	else:
		await _choose(setup._player_faction, 2)
		await _choose(setup._enemy_faction, 1)
		await _choose(setup._start_mode, 1)
	_check(setup._player_faction.selected == 2, "Faction selection did not retain Frontier")
	_check(
		setup._create_match_settings().players[0].faction == "frontier",
		"Menu resolved the wrong faction"
	)
	await _capture("setup")
	await _click(setup._start_button)
	for frame in range(900):
		await process_frame
		if (
			is_instance_valid(current_scene)
			and current_scene.has_method("_get_human_player")
			and current_scene.is_node_ready()
		):
			game = current_scene
			break
	if not is_instance_valid(game):
		_check(false, "Frontier Start never opened the match")
		return false
	config = ConfigFile.new()
	config.load(preference_file)
	_check(
		(
			config.get_value("setup", "player") == "frontier"
			and config.get_value("setup", "enemy") == "helix"
		),
		"Faction preferences are not stored as stable IDs"
	)
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(40)
	return true


func _battle_flow():
	var hq = _units(human, "CommandCenter")[0]
	var tank = _units(human, "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(23)
	camera.set_position_safely(hq.global_position_yless + Vector3(5, 0, 3))
	tank.global_position = hq.global_position + Vector3(0, 0, 3.5)
	for worker in _units(human, "Worker"):
		worker.issue_manual_order(null)
	game.hud._toggle_pause()
	human.coordination_unlocked = true
	var menu = game.find_child("UnitMenus")
	tank.get_node("Selection").select()
	await _frames(15)
	var signature = menu._signature_panel
	_check(
		signature != null and signature._activate.text == "Maneuver burst",
		"Frontier ability control is missing"
	)
	if signature == null:
		return false
	await _frames(5)
	var action = tank.action
	signature._activate.grab_focus()
	await _key(KEY_ENTER)
	_check(
		tank.signature.kind == "maneuver" and tank.action == action,
		"Keyboard maneuver activation failed or changed orders"
	)
	await _capture("maneuver")
	var clock = tank.signature.cooldown
	await _frames(15)
	_check(tank.signature.cooldown == clock, "Paused UI advanced maneuver")
	human.resource_a = 100
	human.resource_b = 100
	game.hud._technology_button.grab_focus()
	await _key(KEY_ENTER)
	var research = game.hud.technology_panel
	_check(research != null, "Tech control did not open")
	if research == null:
		return false
	game.hud._technology_scroll.ensure_control_visible(research._branches.doctrine.button)
	await _frames(6)
	_check(
		"Rapid redeployment" in research._branches.doctrine.button.title(),
		"Frontier doctrine uses another faction's title"
	)
	await _click(research._branches.doctrine.button)
	_check(
		human.technology.active == "doctrine" and human.resource_a == 55 and human.resource_b == 65,
		"Frontier paid doctrine UI failed"
	)
	await _capture("doctrine")
	await _click(research._cancel)
	await _key(KEY_ESCAPE)
	_check(paused, "Tech close lost prior tactical pause")
	var victim = _spawn_frontier("Tank", enemy, hq.global_position_yless + Vector3(5, 0, 1))
	await _frames(3)
	victim.hp = 0
	game.wreck_salvage.flush()
	var wreck = get_nodes_in_group("salvage_wrecks")[0]
	root.get_node("MatchSignals").deselect_all_units.emit()
	var worker = _units(human, "Worker")[0]
	worker.get_node("Selection").select()
	await _frames(10)
	await _mouse(
		camera.unproject_position(wreck.global_position + Vector3.UP * .25), MOUSE_BUTTON_RIGHT
	)
	_check(
		(
			worker.manual_orders.pending.size() == 1
			and worker.manual_orders.pending[0].kind == "gather"
		),
		"Right-click wreck did not queue harvesting while paused"
	)
	game.hud._toggle_pause()
	await _frames(10)
	_check(
		is_instance_valid(worker.action) and worker.action.get_script() == harvest,
		"Right-click wreck did not start harvesting after resume"
	)
	game.hud._toggle_pause()
	await _capture("salvage")
	return true


func _choose(choice, index):
	# Popup windows are selected through their signal contract; battle actions below
	# still enter through viewport mouse/keyboard events.
	choice.select(index)
	choice.item_selected.emit(index)
	await _frames(5)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
		await _frames(3)


func _click(control):
	control.grab_focus()
	await _key(KEY_ENTER)


func _mouse(logical_point, button = MOUSE_BUTTON_LEFT):
	var point = root.get_final_transform() * logical_point
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.button_mask = (
			(MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT)
			if pressed
			else 0
		)
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(3)


func _capture(label):
	await _frames(5)
	RenderingServer.force_draw()
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Frontier controls preview changed resolution")
	frame.save_png("res://art/frontier/v1/controls-%s.png" % label)
	print("FRONTIER CAPTURE ", label)
