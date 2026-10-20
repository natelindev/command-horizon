extends "res://tests/headless/SaveRestoreEdges.gd"

## Battle HUD production and guidance:
## - every producible unit and structure has a faction portrait, and production and
##   build tiles show it with a name and price that fit in English and Chinese;
## - the retired skirmish Battle plan stays absent, including with old preferences;
## - producers accept a twelve-job queue that reserves and refunds exact costs, and
##   the selected producer's rack shows every job without scrolling;
## - the production overview follows queued, completed and cancelled jobs and
##   construction sites across buildings, whatever is selected.

const MAP = "res://source/match/maps/DesertFrontier.tscn"
var factions
var catalog
var roster_button
## Counts completed sections, so a script error cannot pass silently.
var _sections = 0


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	roster_button = load("res://source/match/hud/RosterButton.gd")
	var options = root.get_node("Globals").options
	var original = options.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	options.restore({"screen": 1, "edge_scrolling": false, "interface_scale": 1.0})
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280, 720)
	_portraits()
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, MAP)
		_hold_players()
		await _tiles(faction)
		if faction == "bastion":
			await _queue_and_overview()
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	TranslationServer.set_locale(options.language)
	_check(_sections == 6, "Only %d of 6 sections completed" % _sections)
	for message in errors:
		push_error(message)
	print("Battle HUD production: %d failures over %d sections" % [errors.size(), _sections])
	quit(0 if errors.is_empty() else 1)


func _hold_players():
	for player in get_nodes_in_group("players"):
		player.set_process(false)


func _portraits():
	var roles = catalog.STRUCTURES.duplicate()
	for produced in catalog.PRODUCES.values():
		for role in produced:
			if role not in roles:
				roles.append(role)
	for faction in ["bastion", "helix", "frontier"]:
		for role in roles:
			var texture = factions.portrait(faction, role)
			_check(texture != null, "%s %s has no portrait" % [faction, role])
			if texture != null:
				_check(
					texture.resource_path.contains("/%s/" % faction),
					"%s %s borrows another faction's portrait" % [faction, role]
				)
	# Roles without art degrade to an empty portrait instead of failing.
	_check(factions.portrait("frontier", "SupplyTruck") == null, "Missing art invented a portrait")
	var tile = roster_button.new()
	tile.show_role(null, "Supply truck", {"resource_a": 3, "resource_b": 0})
	_check(tile._portrait.texture != null, "Missing portrait left an empty socket")
	_check(tile.portrait() == null, "Fallback glyph reported as a portrait")
	tile.free()
	_sections += 1


func _tiles(faction):
	var human = game._get_human_player()
	if _units(human, "AircraftFactory").is_empty():
		var hq = _units(human, "CommandCenter")[0]
		_spawn("AircraftFactory", human, hq.global_position + Vector3(-9, 0, 9), false)
	var menus = game.find_child("UnitMenus")
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		for producer in [
			"CommandCenter", "Barracks", "VehicleFactory", "AircraftFactory", "Worker"
		]:
			_select([_units(human, producer)[0]])
			await _frames(4)
			var roles = catalog.STRUCTURES if producer == "Worker" else catalog.PRODUCES[producer]
			var label = "%s %s %s" % [faction, locale, producer]
			_check(menus._buttons.size() == roles.size(), label + ": roster is incomplete")
			for entry in menus._buttons:
				var tile = entry.button
				var expected = factions.portrait(faction, entry.type)
				_check(
					tile.portrait() != null and tile.portrait() == expected,
					"%s: %s tile lacks its portrait" % [label, entry.type]
				)
				_check(not tile.title().is_empty(), "%s: %s tile has no name" % [label, entry.type])
				_check(tile.text.is_empty(), "%s: %s tile draws button text" % [label, entry.type])
				var column = tile._title.get_parent()
				var price = column.get_node("Price")
				_check(
					tile.get_global_rect().encloses(price.get_global_rect()),
					"%s: %s price extends below its tile" % [label, entry.type]
				)
				_check(
					tile._title.get_line_count() <= 2,
					"%s: %s name needs %d lines" % [label, entry.type, tile._title.get_line_count()]
				)
				_check(
					price.get_combined_minimum_size().x <= column.size.x + 0.5,
					"%s: %s price is clipped" % [label, entry.type]
				)
				_check(
					tile._portrait.get_global_rect().size.x >= 36,
					"%s: %s portrait is squeezed" % [label, entry.type]
				)
	TranslationServer.set_locale("en")
	_sections += 1


func _queue_and_overview():
	var human = game._get_human_player()
	human.resource_a = 5000
	human.resource_b = 5000
	var overview = game.hud.production_overview
	var factory = _units(human, "VehicleFactory")[0]
	var hq = _units(human, "CommandCenter")[0]
	var second = _spawn("VehicleFactory", human, hq.global_position + Vector3(10, 0, -10), false)
	var barracks = _units(human, "Barracks")[0]
	for unit in human.get_children():
		if "production_queue" in unit and unit.production_queue != null:
			unit.production_queue.cancel_all()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(15)
	_check(overview.entries().is_empty() and not overview.visible, "Idle overview is shown")
	# A producer accepts twelve paid jobs and reserves their exact cost.
	var limit = root.get_node("Constants").Match.Units.PRODUCTION_QUEUE_LIMIT
	_check(limit >= 12, "Production queue is shorter than twelve jobs")
	var tank = load(catalog.scene_path("Tank"))
	var cost = factions.cost(human, "Tank")
	var funds = Vector2i(human.resource_a, human.resource_b)
	for index in limit:
		_check(factory.production_queue.produce(tank) != null, "Job %d was refused" % index)
	_check(factory.production_queue.produce(tank) == null, "Queue accepted a job past its limit")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b) * limit
		),
		"Full queue reserved the wrong amount"
	)
	for index in 2:
		second.production_queue.produce(tank)
	for index in 3:
		barracks.production_queue.produce(load(catalog.scene_path("Infantry")))
	await _frames(15)
	_check_overview(overview, {factory: limit, second: 2, barracks: 3}, "queued")
	# The selected producer's rack shows all twelve jobs without scrolling.
	_select([factory])
	await _frames(6)
	var rack = game.find_child("ProductionQueue")
	var jobs = rack.find_child("QueueElements")
	var scroll = rack.find_child("QueueScroll")
	_check(
		jobs.get_child_count() == limit,
		"Rack shows %d of %d jobs" % [jobs.get_child_count(), limit]
	)
	_check(
		scroll.size.x + 0.5 >= jobs.get_combined_minimum_size().x,
		"A full queue scrolls in the rack"
	)
	_check(root.get_visible_rect().encloses(rack.get_global_rect()), "Queue rack leaves the screen")
	# Cancelling one building's jobs refunds them and drops its overview key.
	funds = Vector2i(human.resource_a, human.resource_b)
	second.production_queue.cancel_all()
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds + Vector2i(cost.resource_a, cost.resource_b) * 2
		),
		"Cancelled jobs were not refunded exactly"
	)
	await _frames(15)
	_check_overview(overview, {factory: limit, barracks: 3}, "cancelled")
	# A completed job leaves the count; the next one starts.
	var frames = 0
	while barracks.production_queue.size() == 3 and frames < 3000:
		await _frames(10)
		frames += 10
	_check(barracks.production_queue.size() == 2, "Infantry did not finish production")
	await _frames(15)
	_check_overview(overview, {factory: limit, barracks: 2}, "completed")
	# Construction sites join the overview.
	var site = _spawn("PowerPlant", human, hq.global_position + Vector3(-12, 0, -12), true)
	await _frames(15)
	var building = overview.entries().filter(func(entry): return entry.building == site)
	_check(
		building.size() == 1 and building[0].construction, "Construction site missing from overview"
	)
	# Pressing a key selects that building, whatever was selected before.
	_select([_units(human, "Worker")[0]])
	await _frames(3)
	var key = overview.keys().filter(func(item): return item.get_meta("building") == barracks)[0]
	key.pressed.emit()
	await _frames(3)
	var selected = get_nodes_in_group("selected_units")
	_check(selected == [barracks], "Overview key did not select its building")
	_check(
		key.tooltip_text.contains("Producer:") and key.tooltip_text.contains("2"),
		"Overview tooltip lacks producer or queue size: " + key.tooltip_text
	)
	await _frames(3)
	_check_layout(overview)
	for unit in [factory, barracks]:
		unit.production_queue.cancel_all()
	site.cancel_construction()
	await _frames(15)
	_check(not overview.visible, "Overview stays after all work ended")
	_sections += 1
	await _overview_survives_restore()


func _check_overview(overview, expected, label):
	var entries = overview.entries().filter(func(entry): return not entry.construction)
	_check(
		entries.size() == expected.size(),
		"%s: overview lists %d producers" % [label, entries.size()]
	)
	for entry in entries:
		_check(
			expected.get(entry.building, -1) == entry.jobs,
			"%s: %s shows %d jobs" % [label, entry.building.type, entry.jobs]
		)
	_check(overview.keys().size() == overview.entries().size(), label + ": keys out of date")
	for key in overview.keys():
		var jobs = expected.get(key.get_meta("building"), 0)
		var badge = key.get_node("Count").text
		_check(
			badge == (str(jobs) if jobs > 1 else ""),
			"%s: badge %s for %d jobs" % [label, badge, jobs]
		)
		_check(key.icon != null, label + ": overview key lacks a portrait")
	_check(overview.visible, label + ": overview hidden while producing")


func _check_layout(overview):
	var rect = overview.get_global_rect()
	var viewport = root.get_visible_rect()
	_check(viewport.encloses(rect), "Overview leaves the screen")
	_check(is_equal_approx(rect.end.x, viewport.end.x), "Overview is not docked right")
	_check(
		rect.position.y >= game.hud.system_plate.get_global_rect().end.y,
		"Overview covers the system plate"
	)
	for other in [
		game.find_child("ResourcesBar"),
		game.find_child("Minimap"),
		game.find_child("UnitMenus"),
		game.hud.get_child(0),
	]:
		if is_instance_valid(other) and other.is_visible_in_tree():
			_check(
				not rect.intersects(other.get_global_rect()), "Overview overlaps " + str(other.name)
			)


func _overview_survives_restore():
	var human = game._get_human_player()
	var factory = _units(human, "VehicleFactory")[0]
	factory.production_queue.produce(load(catalog.scene_path("Tank")))
	game.hud._toggle_pause()
	await _frames(2)
	var snapshot = Snapshot.new().capture(game)
	_check(snapshot != null, "Overview fixture snapshot failed")
	if snapshot == null:
		return
	var loaded = await Restore.new().restore(self, snapshot)
	_check(loaded.ok, "Overview fixture restore failed: " + str(loaded.get("error", "")))
	if not loaded.ok:
		return
	game = loaded.game
	_hold_players()
	await _frames(15)
	var overview = game.hud.production_overview
	_check(overview.entries().size() == 1, "Restored overview lost the paid job")
	_check(overview.visible and overview.keys().size() == 1, "Restored overview is hidden")
	_sections += 1


func _select(units):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()


func _spawn(role, player, point, under_construction):
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, under_construction)
	return unit
