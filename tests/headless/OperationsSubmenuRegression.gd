extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = true
		var player = game._get_human_player()
		player.resource_a = 1000
		player.resource_b = 1000
		var worker = _units(player, "Worker")[0]
		root.get_node("MatchSignals").deselect_all_units.emit()
		worker.get_node("Selection").select()
		await _frames(8)
		var menus = game.find_child("UnitMenus")
		_check(
			menus._pages.get_current_tab_control().name == "Orders", "Worker does not start at root"
		)
		_check(not menus._pages.tabs_visible, "Operation tree still uses tabs")
		var placement = player.get_node("StructurePlacementHandler")
		await _key(KEY_B)
		_check(menus._pages.get_current_tab_control().name == "Build", "First B did not open Build")
		_check(not placement._structure_placement_started(), "First B placed a structure")
		for entry in menus._buttons:
			_check(
				not entry.button._title.is_visible_in_tree(), "Building key displays a text label"
			)
			_check(entry.button._portrait.is_visible_in_tree(), "Building key has no picture")
		var funds = Vector2i(player.resource_a, player.resource_b)
		await _key(KEY_B)
		_check(placement._structure_placement_started(), "Second B did not start placement")
		_check(
			placement._pending_structure_prototype.resource_path.ends_with("Barracks.tscn"),
			"B B chose another building"
		)
		_check(
			Vector2i(player.resource_a, player.resource_b) == funds, "Opening placement spent funds"
		)
		await _key(KEY_ESCAPE)
		_check(not placement._structure_placement_started(), "Escape did not cancel placement")
		_check(game.hud._overlay == null, "Escape opened a floating menu")
		# Clicks use the same submenu tree as B B, including its Back key.
		await _click(menus._navigation.get_child(0))
		_check(menus._pages.get_current_tab_control().name == "Build", "Build click failed")
		await _click(menus._navigation.get_child(0))
		_check(menus._pages.get_current_tab_control().name == "Orders", "Back click failed")
		await _key(KEY_B)
		var echo_key = InputEventKey.new()
		echo_key.keycode = KEY_B
		echo_key.physical_keycode = KEY_B
		echo_key.pressed = true
		echo_key.echo = true
		root.push_input(echo_key, true)
		await _frames(3)
		_check(not placement._structure_placement_started(), "Held B skipped the submenu")
		player.resource_a = 0
		player.resource_b = 0
		menus._refresh_buttons()
		await _key(KEY_B)
		_check(
			not placement._structure_placement_started(), "Unaffordable hotkey started placement"
		)
		player.resource_a = funds.x
		player.resource_b = funds.y
		menus._refresh_buttons()
		var barracks = menus._buttons.filter(func(entry): return entry.type == "Barracks")[0]
		await _click(barracks.button)
		_check(placement._structure_placement_started(), "Barracks picture click failed")
		await _key(KEY_ESCAPE)
		for before_paused in [true, false]:
			paused = before_paused
			game.hud.open_technology()
			await _frames(8)
			_check(paused == before_paused, "Opening docked research changed pause state")
			_check(game.hud._overlay == null, "Research created a floating overlay")
			var panel = game.hud.technology_panel
			game.hud._open_menu()
			game.hud._close_menu()
			_check(game.hud.technology_panel == panel, "Battle menu lost docked research reference")
			_check(menus.is_ancestor_of(panel), "Research is outside the bottom HUD")
			_check(get_nodes_in_group("selected_units") == [worker], "Research changed selection")
			_check(
				menus.get_global_rect().grow(1).encloses(panel.get_global_rect()),
				"Research exceeds its dock"
			)
			await _key(KEY_ESCAPE)
			_check(game.hud.technology_panel == null, "Escape did not leave research")
			_check(paused == before_paused, "Closing research changed pause state")
		paused = true
		game.hud.open_technology()
		var panel = game.hud.technology_panel
		panel._branches.weapons.button.pressed.emit()
		panel._start.pressed.emit()
		_check(panel._queue_rows.size() == 1, "Docked research omitted its queued icon")
		panel._queue_rows[0].cancel.pressed.emit()
		panel._cancel.pressed.emit()
		_check(
			Vector2i(player.resource_a, player.resource_b) == funds,
			"Docked research refund differs"
		)
		_units(player, "Tank")[0].get_node("Selection").select()
		await _frames(8)
		_check(game.hud.technology_panel == null, "New selection retained the research view")
		game.hud.open_technology()
		await _frames(5)
		panel = game.hud.technology_panel
		panel._branches.weapons.button.pressed.emit()
		panel._start.pressed.emit()
		panel._branches.armor.button.pressed.emit()
		panel._queue_rows[0].cancel.grab_focus()
		var last = panel._queue_rows[1].cancel
		await _key(KEY_TAB)
		_check(get_nodes_in_group("selected_units").size() == 2, "Research Tab cycled army classes")
		_check(root.gui_get_focus_owner() == last, "Research Tab did not reach next queued project")
		_check(game.hud.technology_panel == panel, "Research Tab rebuilt its bottom panel")
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Operations submenus: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _key(code):
	for down in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await _frames(3)


func _click(control):
	var point = control.get_global_rect().get_center()
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await _frames(4)
