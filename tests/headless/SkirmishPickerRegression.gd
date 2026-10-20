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
	quit(0 if _errors.is_empty() else 1)


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
				setup._preview.points_of_interest.size() == layout.sites.size(),
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
	setup.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(preferences)
