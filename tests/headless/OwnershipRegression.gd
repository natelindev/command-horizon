extends "res://tests/headless/SaveRestoreEdges.gd"


func _identity_script():
	return load("res://source/match/hud/Ownership.gd")


func _new_settings():
	return load("res://source/data-model/MatchSettings.gd").new()


func _run():
	TranslationServer.set_locale("en")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _ownership(faction)
	await _spectator()
	for error in errors:
		push_error(error)
	print("Ownership readability: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _ownership(faction):
	await _same_color_match(faction)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var overlay = game.get_node_or_null("OwnershipLayer/OwnershipOverlay")
	_check(overlay != null, faction + ": battlefield has no non-color ownership indicators")
	if overlay == null:
		game.queue_free()
		await _frames(5)
		return
	await _exercise(faction, overlay)
	paused = false
	game.queue_free()
	await _frames(5)


func _exercise(faction, overlay):
	var ownership = _identity_script()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.ownership_symbols = true
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.color = human.color
	enemy.faction = faction
	enemy.get_color_material().albedo_color = enemy.color
	paused = false
	var own = _spawn_owned("Tank", human, Vector3(58, 0, 52))
	var target = _spawn_owned("Tank", enemy, Vector3(64, 0, 52))
	var aircraft = _spawn_owned("Drone", human, Vector3(58, 5, 56))
	var hidden = _units(enemy, "CommandCenter")[0]
	await _frames(30)
	game.hud._toggle_pause()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(61, 0, 52))
	camera.set_size_safely(32)
	game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(target)
	var mini = game.find_child("Minimap")
	mini._sync_real_units_with_minimap_representations()
	for unit in [own, target, aircraft]:
		unit.get_node("Selection").select()
		var circle = unit.get_node("Selection")._circle
		_check(
			circle.visible and circle.color == unit.player.color, "Player-colored outline missing"
		)
	_check(not ownership.known_now(hidden, game), "Hidden enemy has live identity")
	_check(ownership.caption(own, game).begins_with("Your forces"), "Own nameplate ambiguous")
	_check(ownership.caption(target, game).begins_with("Opponent"), "Opponent nameplate ambiguous")
	_check(mini._unit_to_corresponding_node_mapping[own].kind == "own", "Own minimap shape wrong")
	_check(
		mini._unit_to_corresponding_node_mapping[target].kind == "opponent",
		"Opponent minimap shape wrong"
	)
	_check(
		not mini._unit_to_corresponding_node_mapping.has(hidden),
		"Hidden enemy minimap marker leaked"
	)
	var deposit = get_nodes_in_group("resource_units")[0]
	_check(ownership.kind(deposit, game) == "resource", "Resource classified as combatant")
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "World overlay intercepts commands")
	var clock = game.simulation_time
	own.get_node("Selection").select()
	own.hp *= .7
	await _review(faction, overlay, own, target)
	_check(game.simulation_time == clock, "Ownership inspection advanced pause")
	var saved_position = target.position
	target.position = Vector3(110, 0, 90)
	game.battlefield.invalidate()
	# Presentation can be one frame old; symbols must use current observation immediately.
	target.show()
	_check(not ownership.known_now(target, game), "Stale visible flag leaks current enemy symbol")
	mini._sync_real_units_with_minimap_representations()
	_check(
		not mini._unit_to_corresponding_node_mapping.has(target),
		"Minimap marker persisted after lost sight"
	)
	game.settings.visibility = game.settings.Visibility.ALL_PLAYERS
	_check(ownership.known_now(target, game), "All-player observation lost marker")
	game.settings.visibility = game.settings.Visibility.FULL
	_check(ownership.known_now(target, game), "Full-vision viewer lost marker")
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	var own_position = own.position
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	own.position = hidden.position + Vector3(-7, 0, 0)
	game.battlefield.invalidate()
	visibility._recalculate_unit_visibility(hidden)
	_check(hidden.visible, "Structure memory fixture never observed HQ")
	own.position = own_position
	game.battlefield.invalidate()
	visibility._recalculate_unit_visibility(hidden)
	_check(visibility._structure_to_dummy_mapping.has(hidden), "Structure memory fixture missing")
	_check(
		not ownership.known_now(hidden, game), "Remembered enemy acquired a live ownership marker"
	)
	target.position = saved_position
	game.battlefield.invalidate()
	game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(target)
	options.ownership_symbols = false
	_check(overlay.hover_card().is_empty(), "Disabled owner hover remains")
	mini._sync_real_units_with_minimap_representations()
	_check(
		mini._unit_to_corresponding_node_mapping[target].kind == "opponent",
		"World toggle removed minimap identity"
	)
	var preference_path = "user://ownership-options-%d.tres" % OS.get_process_id()
	_check(options.persist(preference_path) == OK, "Ownership preference write failed")
	var saved_options = ResourceLoader.load(preference_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(not saved_options.ownership_symbols, "Ownership preference did not persist")
	DirAccess.remove_absolute(preference_path)
	options.restore({"ownership_symbols": "invalid", "screen": 1})
	_check(options.ownership_symbols, "Invalid ownership preference did not use default")
	options.restore(original)
	options.ownership_symbols = true
	await _archive_ownership(own, target)
	options.restore(original)


func _spawn_owned(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _archive_ownership(own, target):
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Ownership archive failed: " + snapshot.error)
	if data == null:
		return
	var own_id = snapshot._reference(own)
	var target_id = snapshot._reference(target)
	var store_file = FileStore.new()
	var archive = "user://ownership-battle-%d.json" % OS.get_process_id()
	_check(store_file.write_file(archive, data), "Ownership battle write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, store_file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(result.ok, "Ownership battle restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(61, 0, 52))
	camera.set_size_safely(32)
	await _frames(12)
	var mini = game.find_child("Minimap")
	mini._sync_real_units_with_minimap_representations()
	_check(
		mini._unit_to_corresponding_node_mapping[restore.entities[own_id]].kind == "own",
		"Loaded own identity wrong"
	)
	_check(
		mini._unit_to_corresponding_node_mapping[restore.entities[target_id]].kind == "opponent",
		"Loaded opponent identity wrong"
	)
	var target_unit = restore.entities[target_id]
	target_unit.hp = 0
	_check(not _identity_script().known_now(target_unit, game), "Dead unit retained symbol")
	print(
		"PASS same-color ownership, current fog, aircraft, pause, preference and disk reconstruction"
	)


func _review(_faction, _overlay, _own, _target):
	await _frames(3)


func _same_color_match(faction):
	var settings = _new_settings()
	settings.skirmish = true
	settings.advanced_start = false
	settings.map_path = "res://source/match/maps/IndustrialCrossroads.tscn"
	for index in range(2):
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(60)


func _spectator():
	game = load("res://source/match/Match.tscn").instantiate()
	game.settings = _new_settings()
	game.map = load("res://source/match/maps/PlainAndSimple.tscn").instantiate()
	for index in 2:
		game.get_node("Players").add_child(
			load("res://source/match/players/Player.tscn").instantiate()
		)
	root.add_child(game)
	current_scene = game
	await _frames(30)
	var sides = game.get_node("Players").get_children()
	var ownership = _identity_script()
	var first = _units(sides[0], "CommandCenter")[0]
	_check(
		ownership.caption(first, game).begins_with("Side 1"),
		"Spectator caption claims human ownership"
	)
	_check(ownership.kind(first, game) == "own", "Spectator viewed side incorrect")
	game.visible_player = sides[1]
	_check(ownership.kind(first, game) == "opponent", "Spectator side change left stale identity")
	_check(
		game.find_child("Minimap")._texture_rect.tooltip_text.contains("Viewed side"),
		"Spectator legend claims human ownership"
	)
	game.queue_free()
	await _frames(5)
	print("PASS observer-only legacy match identity")
