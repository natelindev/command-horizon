extends "res://tests/headless/SaveRestoreEdges.gd"

var _sections = 0


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	options.restore({"screen": 1, "edge_scrolling": false})
	await _skirmish("bastion")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _motion(options)
	await _wear()
	await _completion()
	_check(_sections == 3, "Presentation regression did not complete all sections")
	options.restore(original)
	paused = false
	game.queue_free()
	await _frames(5)
	for error in errors:
		push_error(error)
	print("Presentation features: %d failures over %d sections" % [errors.size(), _sections])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _motion(options):
	var button = Button.new()
	button.text = "Event"
	button.position = Vector2(100, 100)
	button.size = Vector2(160, 40)
	root.add_child(button)
	button.grab_focus()
	var bounds = button.get_global_rect()
	var motion = load("res://source/match/hud/HudMotion.gd")
	motion.play(button, true)
	await _frames(3)
	_check(
		button.offset_transform_enabled and button.offset_transform_visual_only,
		"Motion moved layout"
	)
	_check(button.get_global_rect() == bounds, "Motion changed the hit target")
	_check(root.gui_get_focus_owner() == button, "Motion stole focus")
	options.reduced_flashes = true
	options.apply()
	_check(button.offset_transform_position == Vector2.ZERO, "Reduced flashes did not stop motion")
	motion.play(button)
	await _frames(3)
	_check(button.offset_transform_scale == Vector2.ONE, "Reduced flashes allowed a new pulse")
	options.reduced_flashes = false
	options.hud_motion = false
	options.apply()
	motion.play(button, true)
	_check(button.offset_transform_position == Vector2.ZERO, "HUD motion off allowed an entrance")
	options.hud_motion = true
	options.apply()
	var icons = load("res://source/match/hud/InlineIcons.gd")
	_check(icons.price(10, 5).count("height=1em") == 2, "Resource glyphs do not scale with text")
	_check(icons.escape("[img]attack") == "[lb]img]attack", "Tooltip BBCode was not escaped")
	var tile = load("res://source/match/hud/RosterButton.gd").new()
	root.add_child(tile)
	tile.set_meta("armed", true)
	tile.show_role(null, "Bastion tank", {"resource_a": 24, "resource_b": 6})
	var description = load("res://source/match/FactionCatalog.gd").description("bastion", "Tank")
	var locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var translated = TranslationServer.translate(
		load("res://source/match/FactionCatalog.gd").description("bastion", "Tank")
	)
	var tip = tile._make_custom_tooltip("Bastion tank\n" + translated + "\n24 M / 6 E")
	_check(translated != description, "Chinese tooltip fixture has no translation")
	_check(
		tip.get_child(0).get_child(1).text.contains(translated),
		"Inline weapon text lost translation"
	)
	tip.free()
	tile.queue_free()
	TranslationServer.set_locale(locale)
	button.queue_free()
	_sections += 1


func _wear():
	paused = true
	var wear = game.battlefield_wear
	wear.restore([])
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var before = tank.global_position
	wear.sample_vehicle(tank)
	tank.global_position.x += 1
	wear.sample_vehicle(tank)
	_check(wear.marks.size() == 1 and wear.marks[0].kind == 0, "Moving vehicle left no track")
	tank.hide()
	tank.global_position.x += 1
	wear.sample_vehicle(tank)
	_check(wear.marks.size() == 1, "Hidden vehicle left a track")
	tank.show()
	wear.sample_vehicle(tank)
	_check(wear.marks.size() == 1, "Track bridged unseen travel")
	tank.global_position.x += 10
	wear.sample_vehicle(tank)
	_check(wear.marks.size() == 1, "Track bridged a teleport")
	tank.global_position = before
	var options = root.get_node("Globals").options
	options.battlefield_wear = false
	options.apply()
	wear.scar(before, 2)
	_check(wear.marks.size() == 1, "Disabled wear recorded a blast")
	options.battlefield_wear = true
	options.apply()
	wear.scar(before, 2)
	var history = wear.capture()
	_check(history.size() == 2 and history[1].kind == 1, "Blast mark missing")
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	var hidden_hq = _units(enemy, "CommandCenter")[0]
	_check(not wear._observed_point(hidden_hq.global_position), "Fog fixture is already visible")
	wear.scar(hidden_hq.global_position, 2)
	_check(wear.capture() == history, "An unseen impact left persistent evidence")
	var clock = game.simulation_time
	await _frames(5)
	_check(wear.capture() == history and game.simulation_time == clock, "Paused wear advanced")
	var snapshot = Snapshot.new().capture(game)
	_check(snapshot != null, "Cannot save battlefield marks")
	if snapshot == null:
		return
	var restore = Restore.new()
	var result = await restore.restore(self, snapshot)
	_check(result.ok, "Cannot restore marks: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	wear = game.battlefield_wear
	_check(wear.capture() == history, "Save/load changed battlefield marks")
	_check(
		Snapshot.new().capture(game).battlefield_wear == history, "Recapture lost battlefield marks"
	)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	for invalid in [
		{"x": -1.0}, {"radius": 100.0}, {"kind": 2}, {"angle": NAN}, {"z": game.map.size.y}
	]:
		var bad = snapshot.duplicate(true)
		bad.battlefield_wear[0].merge(invalid, true)
		_check(not schema.validate(bad), "Invalid battlefield mark accepted: " + str(invalid))
	for index in 2200:
		wear.add_mark(Vector2(20, 20), 1.0, 0.0, 0)
	_check(wear.marks.size() <= wear.MAX_MARKS, "Battlefield history exceeded its budget")
	wear.restore(history)
	_check(not game.base_area_lighting.enabled(), "High-quality lights enabled by default")
	_sections += 1


func _completion():
	var human = game._get_human_player()
	var factory = _units(human, "VehicleFactory")[0]
	var tank = _units(human, "Tank")[0]
	factory.production_queue.cancel_all()
	var overview = game.hud.production_overview
	overview._production_finished(tank, factory)
	var entries = overview.entries().filter(func(item): return item.building == factory)
	_check(
		entries.size() == 1 and entries[0].get("completed", false),
		"Last completed job vanished before feedback"
	)
	overview._completed[factory].until = 0
	overview.refresh()
	_check(
		overview.entries().all(func(item): return item.building != factory),
		"Completed job never expired"
	)
	_sections += 1
