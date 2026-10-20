extends "res://tests/headless/BattleAlertsRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 150000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Alert preview exceeded deadline")
		quit(1)
	return false


func _run():
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "subtitle_size": 26})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	var manager = root.get_node("SaveManager")
	var directory = manager.slots.directory
	var autosaves = manager.autosaves_enabled
	manager.slots.directory = "user://alert-preview-%d" % OS.get_process_id()
	manager.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		print("Alert preview: " + faction)
		await _setup(faction)
		alerts = game.alerts
		panel = game.hud.alert_panel
		await _prepare_alerts()
		_check(await _input_preview(faction) == true, "Alert input suite aborted")
		await _clean_match()
	path = "user://alert-campaign-%d.json" % OS.get_process_id()
	await _make_match()
	alerts = game.alerts
	panel = game.hud.alert_panel
	for side in get_nodes_in_group("players"):
		if side != game._get_human_player():
			side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _prepare_alerts()
	if not paused:
		game.hud._toggle_pause()
	await _click(panel.toggle)
	await _capture("alerts-campaign-720p")
	_check(
		not panel.panel.get_global_rect().intersects(game.hud.lesson_panel.get_global_rect()),
		"Alerts cover campaign lesson"
	)
	await _key(KEY_ESCAPE)
	game.result = "Victory"
	game.finished = true
	game.hud.show_result("First Orders · Victory")
	await _frames(3)
	_check(
		not panel.panel.visible and not panel.toggle.visible,
		"Result leaves alerts above result controls"
	)
	await _clean_match()
	manager.slots.directory = directory
	manager.autosaves_enabled = autosaves
	preferences.restore(original)
	print("Battle alerts UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _prepare_alerts():
	var human = game._get_human_player()
	var enemy = _sides()[1]
	var victim = _spawn_weapon("Tank", human, Vector3(30, 0, 26))
	var attacker = _spawn_weapon("Infantry", enemy, Vector3(34, 0, 26))
	await _frames(3)
	victim.receive_weapon_hit(attacker)
	for index in range(3):
		var lost = _spawn_weapon("Infantry", human, Vector3(26 + index, 0, 25))
		lost.hp = 1
		lost.receive_weapon_hit(attacker)
	if game.settings.mission_id.is_empty():
		var factory = _units(human, "VehicleFactory")[0]
		# Lab-gated armor stalls visibly once the lab below is destroyed.
		human.coordination_unlocked = true
		_check(
			(
				factory.get_node("ProductionQueue").produce(
					load("res://source/match/units/AdvancedTank.tscn")
				)
				!= null
			),
			"Preview paid queue failed"
		)
		_units(human, "CommandLab")[0].hp = 0
		_units(human, "PowerPlant")[0].hp = 0
		for x in [44, 54]:
			var air_factory = _spawn_weapon("AircraftFactory", human, Vector3(x, 0, 38))
			air_factory.construct(1.0)
		var field = _deposit(Vector3(52, 0, 20))
		field.resource_b = 0
		_units(human, "Worker")[0].issue_manual_order(harvest.new(field))
		await _frames(3)
	# Advance only presentation-fixture simulation age; actual transitions are in the regression.
	alerts.scan()
	game.simulation_time += 7
	alerts.scan()
	game.get_node("IsometricCamera3D").set_position_safely(Vector3(30, 0, 26))
	await _frames(5)


func _input_preview(faction):
	if not paused:
		game.hud._toggle_pause()
	var clock = game.simulation_time
	# Allow one bounded half-second status refresh after the immediate pause.
	await _frames(40)
	var tank = _units(game._get_human_player(), "Tank")[0]
	tank.get_node("Selection").select()
	var action = tank.action
	await _click(panel.toggle)
	_check(panel.panel.visible and alerts.unread_count() == 0, "Mouse did not open/read alerts")
	await _capture("alerts-" + faction + "-720p")
	var totals = game._get_human_player().power_totals()
	_check(
		game.find_child("ResourcesBar", true, false)._power_title.text.contains(
			"%d used / %d supply" % [totals.y, totals.x]
		),
		"Rendered paused power display contradicts active alert"
	)
	var incoming = _kind("attack", true)[0]
	var first_order = panel._open_order.duplicate()
	var first_button = panel.rows[incoming.id].action
	first_button.grab_focus()
	# Another real loss updates history without moving the target under the pointer/focus.
	var victim = _spawn_weapon("Infantry", game._get_human_player(), Vector3(52, 0, 40))
	victim.hp = 0
	await _frames(16)
	_check(
		panel._open_order.slice(0, first_order.size()) == first_order,
		"New event moved open history rows"
	)
	_check(root.gui_get_focus_owner() == first_button, "History update stole keyboard focus")
	game.get_node("IsometricCamera3D").set_position_safely(Vector3(44, 0, 44))
	var before = game.get_node("IsometricCamera3D").position
	await _key(KEY_ENTER)
	_check(not panel.panel.visible, "Keyboard Show did not close the list")
	_check(game.get_node("IsometricCamera3D").position != before, "Keyboard Show did not navigate")
	_check(tank.action == action, "Alert input changed unrelated tank orders")
	_check(paused and game.simulation_time == clock, "Alert controls resumed simulation")
	var field_alerts = _kind("field_electronics", true)
	_check(field_alerts.size() == 1, "Rendered field alert missing")
	if not field_alerts.is_empty():
		await _click(panel.toggle)
		var field_button = panel.rows[field_alerts[0].id].action
		field_button.grab_focus()
		panel._list.get_parent().ensure_control_visible(field_button)
		await _capture("alerts-economy-" + faction + "-720p")
		await _click(field_button)
		_check(not panel.panel.visible, "Mouse field navigation did not close history")
		_check(
			get_nodes_in_group("selected_units").size() == 1,
			"Field navigation did not select affected engineer"
		)
		_check(
			(
				(
					game
					. get_node("IsometricCamera3D")
					. unproject_position(field_alerts[0].point)
					. distance_to(root.get_visible_rect().size / 2)
				)
				< 1
			),
			"Field navigation did not center assigned field"
		)
	await _click(panel.toggle)
	await _key(KEY_ESCAPE)
	_check(
		not panel.panel.visible and game.hud._overlay == null and paused,
		"Escape opened menu or resumed instead of closing alerts"
	)
	panel.toggle.grab_focus()
	await _key(KEY_ENTER)
	_check(panel.panel.visible, "Keyboard toggle did not open alerts")
	await _click(panel._clear)
	_check(
		_kind("loss").is_empty() and not _kind("attack", true).is_empty(),
		"Clear history erased active alerts"
	)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _frames(3)
	_check(
		game.hud._overlay != null and not panel.toggle.visible,
		"Battle menu leaves alert input available"
	)
	game.hud._close_menu()
	await _frames(3)
	await _click(panel.toggle)
	var manager = root.get_node("SaveManager")
	await manager.open_dialog("save")
	await _frames(3)
	_check(is_instance_valid(manager.dialog), "Archive did not open")
	var camera = game.get_node("IsometricCamera3D")
	var position = camera.position
	panel.navigate(incoming.id)
	_check(camera.position == position, "Archive allowed alert navigation")
	manager.close_dialog()
	await _frames(3)
	_check(paused, "Archive changed tactical pause state")
	if panel.panel.visible:
		await _click(panel._close)
	if faction == "helix":
		root.size = Vector2i(1440, 900)
		root.content_scale_size = root.size
		await _frames(5)
		await _click(panel.toggle)
		await _capture("alerts-900p")
		await _click(panel._close)
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
		await _frames(5)
	return true


func _capture(title):
	await _frames(8)
	_check(
		root.get_visible_rect().encloses(panel.panel.get_global_rect()),
		"Alert history exceeds viewport"
	)
	_check(
		panel.panel.size.x <= 392 and panel.panel.size.y <= 482,
		"Alert history lost its bounded layout"
	)
	_check(
		not panel.panel.get_global_rect().intersects(game.subtitles._card.get_global_rect()),
		"Alert history overlaps subtitle area"
	)
	for row in panel.rows.values():
		_check(row.panel.size.x <= 360, "Alert row overflowed scroll width")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _click(control):
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await _frames(3)
		ancestor = ancestor.get_parent()
	var motion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)
