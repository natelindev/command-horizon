extends "res://tests/headless/SaveRestoreEdges.gd"


class MarkerSubject:
	extends Node3D
	var player
	var hp = 100.0
	var color = Color.WHITE


class MarkerSight:
	extends RefCounted
	var calls = 0
	var seen = {}
	var mines_visible = false

	func is_observed(observer, target):
		calls += 1
		if target.is_in_group("field_mines"):
			return mines_visible
		return target.player == observer or seen.has(target)


class MarkerWorld:
	extends Node3D
	var settings = {"visibility": 0, "Visibility": {"FULL": 2}}
	var restoring = false
	var battlefield = MarkerSight.new()
	var visible_player
	var observers = []
	var observer_reads = 0
	var units = []
	var visible_players:
		get:
			observer_reads += 1
			return observers

	func _get_human_player():
		return null

	func get_units():
		return units

	func get_cached_group(_group):
		return []


func _identity_script():
	return load("res://source/match/hud/Ownership.gd")


func _new_settings():
	return load("res://source/data-model/MatchSettings.gd").new()


func _run():
	TranslationServer.set_locale("en")
	root.get_node("SaveManager").autosaves_enabled = false
	_observer_refresh_contract()
	for faction in ["bastion", "helix"]:
		await _ownership(faction)
	await _spectator()
	await _mobile_marker_contract()
	for error in errors:
		push_error(error)
	print("Ownership readability: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _observer_refresh_contract():
	var stage = MarkerWorld.new()
	root.add_child(stage)
	var first = Node.new()
	var second = Node.new()
	stage.add_child(first)
	stage.add_child(second)
	stage.visible_player = first
	stage.observers = [first]
	var background = Node2D.new()
	stage.add_child(background)
	var mini = load("res://source/match/hud/Minimap.gd").new()
	mini._match = stage
	mini._viewport_background = background
	for index in 6:
		var unit = MarkerSubject.new()
		unit.player = first
		stage.add_child(unit)
		stage.units.append(unit)
	mini._sync_real_units_with_minimap_representations()
	_check(stage.observer_reads == 1, "Minimap resolved its observers separately for each unit")
	_check(stage.battlefield.calls == 0, "Known own forces repeated combat sight queries")
	var subject = stage.units[0]
	subject.player = second
	mini._sync_real_units_with_minimap_representations()
	_check(not mini._unit_is_mapped(subject), "Live ownership change retained owning-side sight")
	stage.battlefield.seen[subject] = true
	mini._sync_real_units_with_minimap_representations()
	_check(
		mini._unit_to_corresponding_node_mapping[subject].kind == "opponent",
		"Observed captured force retained its previous minimap identity"
	)
	stage.visible_player = second
	stage.observers = [second]
	stage.battlefield.seen.clear()
	mini._sync_real_units_with_minimap_representations()
	_check(
		mini._unit_to_corresponding_node_mapping[subject].kind == "own",
		"Spectator-side switch reused its previous observer context"
	)
	_check(not mini._unit_is_mapped(stage.units[1]), "Spectator switch retained unobserved forces")
	var retired = Node.new()
	stage.observers.append(retired)
	retired.free()
	stage.observer_reads = 0
	mini._sync_real_units_with_minimap_representations()
	_check(stage.observer_reads == 1, "Freed observer changed refresh-local observer resolution")
	var ownership = _identity_script()
	subject.add_to_group("field_mines")
	_check(not ownership.known_now(subject, stage, [second]), "Own mine bypassed engineering sight")
	stage.battlefield.mines_visible = true
	_check(ownership.known_now(subject, stage, [second]), "Detected own mine lost its marker")
	subject.remove_from_group("field_mines")
	subject.hide()
	_check(not ownership.known_now(subject, stage, [second]), "Own shortcut exposed a hidden body")
	subject.show()
	subject.hp = 0
	_check(not ownership.known_now(subject, stage, [second]), "Own shortcut exposed a dead body")
	subject.add_to_group("resource_units")
	_check(ownership.known_now(subject, stage, []), "Resource markers acquired a combat HP gate")
	subject.remove_from_group("resource_units")
	subject.hp = 100
	stage.restoring = true
	_check(not ownership.known_now(subject, stage, [second]), "Own shortcut exposed restore work")
	stage.restoring = false
	stage.settings.visibility = stage.settings.Visibility.FULL
	_check(ownership.known_now(subject, stage, []), "Full vision acquired an observer requirement")
	mini.free()
	stage.free()
	print(
		"PASS refresh-local observers, live capture/viewer switch, freed viewers and sight guards"
	)


func _mobile_marker_contract():
	await _same_color_match("frontier")
	game.settings.visibility = game.settings.Visibility.FULL
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var human = game._get_human_player()
	var rig = _spawn_owned("AdvancedTank", human, Vector3(58, 0, 52))
	var troop = _spawn_owned("Infantry", human, Vector3(59, 0, 52))
	await _frames(12)
	_require_native_binding(troop)
	paused = true
	var mini = game.find_child("Minimap")
	mini._sync_real_units_with_minimap_representations()
	var phase = troop.get_instance_id() % mini.MARKER_PHASES
	for repeat in 2:
		_check(rig.enter(troop), "Mobile marker fixture could not embark infantry")
		mini._sync_real_units_with_minimap_representations((phase + 1) % mini.MARKER_PHASES)
		_check(
			not troop.visible and not mini._unit_to_corresponding_node_mapping[troop].visible,
			"Hidden vehicle passenger retained an off-phase minimap marker"
		)
		rig.leave(troop)
		_check(not troop.has_meta("garrison_host"), "Marker fixture could not unload infantry")
		mini._sync_real_units_with_minimap_representations(phase)
		_check(
			troop.visible and mini._unit_to_corresponding_node_mapping[troop].visible,
			"Unloaded passenger lost its normal phased minimap marker"
		)
	paused = false
	game.queue_free()
	await _frames(5)
	print("PASS hidden carrier passengers, unload and immediate remount minimap presentation")


func _require_native_binding(unit):
	var flags = OS.get_cmdline_user_args()
	if "--native-unit-state" in flags:
		_check(unit._native_state != null, "Native ownership run silently used script unit state")
	if "--native-crowd-runtime" in flags:
		_check(
			unit.get_node("Movement")._native_handle >= 0,
			"Native ownership run silently used script movement"
		)
	if "--native-visibility-runtime" in flags:
		_check(
			game.battlefield._native_visibility != null,
			"Native ownership run silently used script visibility"
		)


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
	await _avoid_edge_controls(overlay)
	var clock = game.simulation_time
	own.get_node("Selection").select()
	own.hp *= .7
	await _review(faction, overlay, own, target)
	_check(game.simulation_time == clock, "Ownership inspection advanced pause")
	if faction == "helix":
		_cloaked_identity_contract(human, enemy)
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


func _cloaked_identity_contract(human, enemy):
	var infiltrator = _spawn_owned("SniperInfantry", human, Vector3(78, 0, 52))
	var witness = _spawn_owned("Tank", enemy, Vector3(88, 0, 52))
	infiltrator.optical_cloak._previous = infiltrator.global_position
	infiltrator.optical_cloak.advance(3.0)
	game.battlefield.invalidate()
	var ownership = _identity_script()
	_check(infiltrator.optical_cloak.concealed, "Ownership cloak fixture did not conceal")
	_check(
		ownership.known_now(infiltrator, game, [human]),
		"Owner identity shortcut hid its own cloaked infantry"
	)
	_check(
		not ownership.known_now(infiltrator, game, [enemy]),
		"Refresh-local observers bypassed hostile optical camouflage"
	)
	witness.global_position = infiltrator.global_position + Vector3(2, 0, 0)
	game.battlefield.invalidate()
	_check(
		ownership.known_now(infiltrator, game, [enemy]),
		"Live close-range detector failed to reveal the cloaked identity"
	)
	infiltrator.queue_free()
	witness.queue_free()


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


func _avoid_edge_controls(overlay):
	var point = get_root().get_visible_rect().get_center()
	var dimensions = Vector2(180, 88)
	var original: Rect2 = overlay.caption_rect(point, dimensions)
	_check(original.has_area(), "Hover fixture has no available caption space")
	var button = Button.new()
	button.text = "Supply delivery"
	button.position = original.position + Vector2(8, 8)
	button.size = Vector2(80, 24)
	game.hud.event_edge_indicators.add_child(button)
	await _frames(2)
	var relocated: Rect2 = overlay.caption_rect(point, dimensions)
	_check(relocated.has_area(), "Edge indicator suppressed the hover card entirely")
	_check(
		not relocated.intersects(button.get_global_rect().grow(6)),
		"Hover caption overlaps an interactive edge indicator"
	)
	button.position = Vector2(0, point.y - dimensions.y - 10)
	button.size = Vector2(get_root().get_visible_rect().size.x, dimensions.y * 2 + 22)
	var beyond_rows: Rect2 = overlay.caption_rect(point, dimensions)
	_check(beyond_rows.has_area(), "Both blocked nearest rows suppressed a readable hover card")
	_check(
		not beyond_rows.intersects(button.get_global_rect().grow(6)),
		"Fallback caption overlaps the obstruction"
	)
	button.queue_free()


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
