extends "res://tests/headless/ResourceMapEconomyRegression.gd"

# The skirmish picker: it offers the sixteen rebuilt battlefields, previews
# their fields and facilities, remembers the chosen map by path, and opens the
# successor of any retired map named by an older preference.


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	await _menu()
	for message in _errors:
		push_error(message)
	print("Skirmish picker: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _menu():
	var preferences = "user://skirmish-picker-%d.cfg" % OS.get_process_id()
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	setup.preferences_path = preferences
	root.add_child(setup)
	_check(setup._get_selected_map_path() == setup.MAPS[0][0], "Fresh setup skips the default map")
	_check(setup._map_paths.size() == 16, "Skirmish roster must offer sixteen maps")
	var registry = load("res://source/match/maps/terrain/BattlefieldRegistry.gd")
	for path in setup._map_paths:
		var index = setup._map_paths.find(path)
		setup._map_list.select(index)
		setup._on_map_list_item_selected(index)
		if registry.is_authored(path):
			var layout = registry.layout(path)
			_check(
				setup._preview.deposits.size() == layout.bases.size() + layout.expansions.size(),
				"Preview omits resource fields: " + path
			)
			_check(
				(
					setup._preview.points_of_interest.size()
					== (
						load("res://source/match/world/PointOfInterestCatalog.gd")
						. definitions(path)
						. size()
					)
				),
				"Preview omits facilities: " + path
			)
		setup._save_preferences()
		var config = ConfigFile.new()
		config.load(preferences)
		_check(config.get_value("setup", "map") == path, "Map preference lacks stable path")
		setup._map_list.select(0)
		setup._load_preferences()
		_check(setup._get_selected_map_path() == path, "Map preference restore changed selection")
	# Old numeric and path preferences open the map that replaced theirs.
	var legacy = ConfigFile.new()
	for old_name in setup.LEGACY_MAP_NAMES + setup.SUCCESSORS.keys():
		legacy.set_value("setup", "map", "res://source/match/maps/%s.tscn" % old_name)
		legacy.save(preferences)
		setup._load_preferences()
		var saved = "res://source/match/maps/%s.tscn" % old_name
		var expected = (
			saved if saved in setup._map_paths else setup.SUCCESSORS.get(old_name, setup.MAPS[0][0])
		)
		_check(setup._get_selected_map_path() == expected, "Legacy map routing failed: " + old_name)
	legacy.set_value("setup", "map", 5)
	legacy.save(preferences)
	setup._load_preferences()
	_check(
		setup._get_selected_map_path() == setup.SUCCESSORS.CoastalFoundry,
		"Legacy numeric preference did not select its replacement"
	)
	# Position selection via preview circle clicks
	setup._on_map_list_item_selected(0)
	_check(setup._slots[0].location == 0, "Default player position should be 0")
	_check(setup._slots[1].location == 1, "Default AI position should be 1")

	# Click circle 2 on preview
	setup._preview.start_selected.emit(1)
	_check(setup._slots[0].location == 1, "Player did not move to start 2 after preview click")
	_check(setup._slots[1].location == 0, "AI did not swap to start 1 after preview click")

	# Click circle 1 on preview
	setup._preview.start_selected.emit(0)
	_check(setup._slots[0].location == 0, "Player did not move back to start 1")
	_check(setup._slots[1].location == 1, "AI did not swap back to start 2")

	# Keyboard selection uses the same occupied-start swap as map clicks.
	var key = InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	setup._preview._gui_input(key)
	_check(setup._slots[0].location == 1, "Arrow key did not select the next start")
	_check(setup._slots[1].location == 0, "Arrow key duplicated an occupied start")

	# Test GUI mouse click event on the start circle coordinates
	setup._preview.size = Vector2(400, 300)
	var xform = setup._preview._map_transform()
	var start0 = setup._preview.starts[0]
	var map_pos0 = Vector2(start0.x, start0.z) if start0 is Vector3 else Vector2(start0.x, start0.y)
	var screen_pos0 = xform.origin + map_pos0 * xform.scale
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = screen_pos0
	setup._preview._gui_input(click_event)
	_check(setup._slots[0].location == 0, "GUI input click on circle 1 failed to select position 0")

	# Test 4-player map circle clicks
	var four_player_index = -1
	for idx in setup.MAPS.size():
		if constants.Match.MAPS[setup.MAPS[idx][0]].players == 4:
			four_player_index = idx
			break
	if four_player_index >= 0:
		setup._map_list.select(four_player_index)
		setup._on_map_list_item_selected(four_player_index)
		_check(setup._slots.size() == 4, "Expected 4 slots for 4-player map")
		setup._preview.start_selected.emit(2)
		_check(setup._slots[0].location == 2, "Player did not move to start 3 on 4-player map")
		_check(setup._slots[2].location == 0, "AI 2 did not swap to start 1 on 4-player map")
		setup._preview.start_selected.emit(3)
		_check(setup._slots[0].location == 3, "Player did not move to start 4 on 4-player map")
		_check(setup._slots[3].location == 2, "AI 3 did not swap to start 3 on 4-player map")

	setup.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(preferences)
