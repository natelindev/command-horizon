extends "res://tests/headless/SaveRestoreEdges.gd"

# Rendered review captures for the faction battle consoles in English and Chinese:
# closed deck, full visibility, worker, tank, producer with a full paid queue while other buildings
# produce, the production overview with nothing selected, multi-selection, lit
# alerts beacon, pause menu and technology; eight-player and true spectator
# resource rosters at 720p with large UI, including both scroll endpoints.
# Run without --headless: Godot --path . --script tests/rendered/HudConsolePreview.gd
# Use -- --console-only to skip the independent eight-player resource matrix.
# Use -- --rosters [bastion helix frontier] for only the eight-player matrix.
# Use -- --elimination [bastion helix frontier] for commander status and announcement review.

const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const OUTPUT = "res://art/hud-console/"
var _full_visibility_only = false
var _research_only = false
var _roster_cases = 0
var _elimination_cases = 0
var _match_settings_script
var _player_settings_script


class RenderErrorLog:
	extends Logger

	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("HUD console preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	_match_settings_script = load("res://source/data-model/MatchSettings.gd")
	_player_settings_script = load("res://source/data-model/PlayerSettings.gd")
	var factions = Array(OS.get_cmdline_user_args())
	_full_visibility_only = factions.has("--full-visibility")
	factions.erase("--full-visibility")
	_research_only = factions.has("--research")
	factions.erase("--research")
	var console_only = factions.has("--console-only")
	factions.erase("--console-only")
	var rosters_only = factions.has("--rosters")
	factions.erase("--rosters")
	var elimination_only = factions.has("--elimination")
	factions.erase("--elimination")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for setup in [
		["bastion", "battlefields/DesertFrontierMap", Vector2i(1280, 720), 1.5, "720p", "en"],
		["helix", "battlefields/AlpineRelayMap", Vector2i(1920, 1080), 1.0, "1080p", "en"],
		["frontier", "CoastalFoundry", Vector2i(1280, 720), 1.5, "720p", "en"],
		["bastion", "battlefields/DesertFrontierMap", Vector2i(1280, 720), 1.5, "720p-zh", "zh_CN"],
		["helix", "battlefields/AlpineRelayMap", Vector2i(1920, 1080), 1.0, "1080p-zh", "zh_CN"],
		["frontier", "CoastalFoundry", Vector2i(1280, 720), 1.5, "720p-zh", "zh_CN"],
	]:
		if rosters_only or (not factions.is_empty() and setup[0] not in factions):
			continue
		if elimination_only:
			await _configure(preferences, Vector2i(1280, 720), 1.5, setup[5])
			var review_options = preferences.capture()
			review_options.reduced_motion = true
			review_options.reduced_flashes = true
			preferences.restore(review_options)
			await _elimination_review(setup[0], setup[5])
		else:
			await _configure(preferences, setup[2], setup[3], setup[5])
			await _battle(setup[0], setup[1], setup[4])
	var expected_rosters = 0
	if (
		rosters_only
		or (
			not console_only
			and not elimination_only
			and not _full_visibility_only
			and not _research_only
		)
	):
		for faction in ["bastion", "helix", "frontier"]:
			if not factions.is_empty() and faction not in factions:
				continue
			for language in ["en", "zh_CN"]:
				await _configure(preferences, Vector2i(1280, 720), 1.5, language)
				for spectator in [false, true]:
					expected_rosters += 1
					await _many_players(faction, language, spectator)
	_check(
		_roster_cases == expected_rosters,
		"Only %d of %d resource roster cases completed" % [_roster_cases, expected_rosters]
	)
	if elimination_only:
		var expected = 12 if factions.is_empty() else factions.size() * 4
		_check(_elimination_cases == expected, "Commander elimination preview cases did not finish")
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("HUD console preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _elimination_review(faction, language):
	for count in [4, 8]:
		var settings = _match_settings_script.new()
		settings.skirmish = true
		settings.map_path = "res://source/match/maps/BigArena.tscn"
		settings.visibility = (
			settings.Visibility.FULL if count == 8 else settings.Visibility.PER_PLAYER
		)
		var constants = root.get_node("Constants")
		for index in count:
			var side = _player_settings_script.new()
			side.controller = (
				constants.PlayerType.HUMAN
				if index == 0
				else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
			)
			side.faction = faction
			side.color = constants.Player.COLORS[index]
			settings.players.append(side)
		game = load("res://source/match/Skirmish.tscn").instantiate()
		game.settings = settings
		game.map = load(settings.map_path).instantiate()
		root.add_child(game)
		current_scene = game
		var players = get_nodes_in_group("players")
		for player in players:
			player.set_process(false)
			if count == 8:
				player.resource_a = 10000 + player.get_index() * 750
				player.resource_b = 5000 + player.get_index() * 125
		var camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_position_safely(_units(players[0], "CommandCenter")[0].global_position)
		await _frames(12)
		paused = true
		var roster = game.hud.commander_roster
		_check(root.size == Vector2i(1280, 720), "Elimination review lost 720p resolution")
		_check(
			root.get_node("Globals").options.interface_scale == 1.5,
			"Elimination review lost 150% interface scale"
		)
		_check(
			TranslationServer.get_locale() == language, "Elimination review has the wrong language"
		)
		var rival = players[-1]
		_units(rival, "CommandCenter")[0].hp = 0
		await _frames(3)
		game._check_outcome(59.5)
		roster.refresh()
		await _frames(3)
		var label = "%s-720p-%s-%d-commanders" % [faction, language, count]
		if count == 4:
			_check(not roster._announcement.visible, "HQ grace announced elimination: " + label)
			await _shot(label + "-hq-grace")
		game._check_outcome(0.5)
		if count == 8:
			roster.scroll_vertical = 10000
		await _frames(3)
		_check(not game.finished, "Early elimination ended free-for-all: " + label)
		_check(roster._announcement.visible, "Elimination has no announcement: " + label)
		_check(
			roster.rows[rival].status.text == tr("Eliminated"),
			"Elimination has no persistent status: " + label
		)
		_check(
			roster.get_global_rect().encloses(roster.rows[rival].row.get_global_rect()),
			"Eliminated commander is clipped: " + label
		)
		_check(
			root.get_visible_rect().encloses(roster._announcement.get_global_rect()),
			"Elimination announcement exceeds viewport: " + label
		)
		_check(
			not roster._announcement.get_global_rect().intersects(
				game.hud._resources.get_global_rect()
			),
			"Elimination announcement covers the resource roster: " + label
		)
		await _shot(label + "-eliminated")
		roster._process(7.0)
		await _frames(3)
		_check(not roster._announcement.visible, "Elimination toast never clears: " + label)
		await _shot(label + "-persistent")
		_elimination_cases += 1
		paused = false
		game.queue_free()
		await _frames(5)


func _configure(preferences, resolution, scale_value, language):
	(
		preferences
		. restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"day_cycle": false,
				"weather": 1,
				"subtitles": true,
				"interface_scale": scale_value,
				"language": language,
			}
		)
	)
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = resolution
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


func _battle(faction, map_name, suffix):
	await _skirmish(faction, "res://source/match/maps/%s.tscn" % map_name, true)
	for player in get_nodes_in_group("players"):
		if player != game._get_human_player():
			player.set_process(false)
	var human = game._get_human_player()
	var camera = game.get_node("IsometricCamera3D")
	var tank = _units(human, "Tank")[0]
	camera.set_size_safely(30)
	camera.set_position_safely(tank.global_position)
	game.subtitles._on_line({"speaker": "Command", "text": "Battle control online."})
	await _frames(40)
	var label = "%s-%s" % [faction, suffix]
	if _research_only:
		human.resource_a += 2000
		human.resource_b += 2000
		paused = true
		await _review_research(human, label)
		paused = false
		game.queue_free()
		await _frames(5)
		return
	if not _full_visibility_only:
		await _shot(label + "-closed")
	var resource_stack = game.get_node("HUD/MarginContainer2/Resources")
	game.settings.visibility = game.settings.Visibility.FULL
	resource_stack._show_player_bars(get_nodes_in_group("players"))
	await _frames(12)
	await _shot(label + "-full-visibility")
	if _full_visibility_only:
		paused = false
		game.queue_free()
		await _frames(5)
		return
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	resource_stack._hide_all_bars()
	resource_stack._show_player_bars([human])
	await _frames(12)
	var refineries = load("res://source/match/world/PointOfInterestCatalog.gd").sites(game).filter(
		func(site): return site.kind == "refinery"
	)
	if not refineries.is_empty():
		var refinery = refineries[0]
		refinery.captured_by = human
		refinery._update_presentation()
		game.find_child("ResourcesBar")._refresh()
		camera.set_position_safely(refinery.global_position)
		await _frames(20)
		await _shot(label + "-refinery")
		camera.set_position_safely(tank.global_position)
	await _select([_units(human, "Worker")[0]])
	await _shot(label + "-worker")
	game.find_child("UnitMenus").open_page("Build")
	await _frames(10)
	await _shot(label + "-build")
	tank.hp = int(tank.hp_max * .55)
	await _select([tank])
	await _shot(label + "-tank")
	await _review_commander(human, label)
	# A full factory queue while the barracks and HQ produce and a generator rises.
	human.resource_a += 2000
	human.resource_b += 2000
	var factory = _units(human, "VehicleFactory")[0]
	var hq = _units(human, "CommandCenter")[0]
	for index in root.get_node("Constants").Match.Units.PRODUCTION_QUEUE_LIMIT:
		factory.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	for index in 3:
		_units(human, "Barracks")[0].production_queue.produce(
			load("res://source/match/units/Infantry.tscn")
		)
	hq.production_queue.produce(load("res://source/match/units/Worker.tscn"))
	var site = load("res://source/match/units/PowerPlant.tscn").instantiate()
	var spot = hq.global_position + Vector3(-10, 0, 8)
	game._setup_and_spawn_unit(site, Transform3D(Basis(), spot), human)
	site.construct(.4)
	await _select([factory])
	await _shot(label + "-factory")
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(20)
	await _shot(label + "-production")
	await _select(_units(human, "Tank") + _units(human, "Worker"))
	await _shot(label + "-multi")
	root.get_node("MatchSignals").deselect_all_units.emit()
	# Incoming fire on the HQ lights the alerts beacon.
	game.alerts._hit(hq, null)
	await _frames(30)
	await _shot(label + "-alerts")
	game.hud._open_menu()
	await _frames(20)
	await _shot(label + "-pause")
	game.hud._close_menu()
	await _review_research(human, label)
	paused = false
	game.queue_free()
	await _frames(5)


func _review_commander(human, label):
	var menus = game.find_child("UnitMenus")
	var before = get_nodes_in_group("selected_units").duplicate()
	menus.open_commander()
	await _frames(12)
	await _shot(label + "-commander")
	_check(get_nodes_in_group("selected_units") == before, "Commander menu changed selection")
	menus.close_commander()
	if human.faction == "helix":
		var generators = _units(human, "PowerPlant")
		if not generators.is_empty():
			var generator = generators[0]
			await _select([generator])
			await _shot(label + "-overdrive")
			var was_paused = paused
			paused = true
			var completed = human.technology.completed.duplicate()
			if "plasma_shields" not in human.technology.completed:
				human.technology.completed.append("plasma_shields")
			var support = game.helix_support
			var ability = generator.abilities.get_ability("power_overdrive")
			var was_requested = ability.is_active
			var temporary = []
			while human.power_totals().x < human.power_totals().y + support.OVERDRIVE_DEMAND:
				var reserve = load(generator.scene_file_path).instantiate()
				game._setup_and_spawn_unit(
					reserve,
					Transform3D(
						Basis.IDENTITY,
						generator.global_position + Vector3(18 + temporary.size() * 6, 0, 12)
					),
					human,
					false
				)
				temporary.append(reserve)
			if not ability.is_active:
				_check(
					support.toggle_overdrive(ability, generator), "Overdrive preview cannot enable"
				)
			_check(support.operating(generator), "Overdrive preview has no operating field")
			var camera = game.get_node("IsometricCamera3D")
			var camera_transform = camera.global_transform
			camera.set_position_safely(generator.global_position)
			support._refresh_generator_visuals(generator)
			menus._refresh_buttons()
			menus._command_card._refresh_abilities()
			await _shot(label + "-overdrive-operating")
			var supply_progress = {}
			for supplier in _units(human, "PowerPlant"):
				if supplier != generator:
					supply_progress[supplier] = supplier._construction_progress
					supplier._construction_progress = 0.0
			var consumer = load("res://source/match/units/AntiGroundTurret.tscn").instantiate()
			game._setup_and_spawn_unit(
				consumer,
				Transform3D(Basis.IDENTITY, generator.global_position + Vector3(18, 0, -12)),
				human,
				false
			)
			consumer.process_mode = Node.PROCESS_MODE_DISABLED
			temporary.append(consumer)
			human.emit_changed()
			_check(
				support.overdrive_status(generator) == "suspended",
				"Overdrive low-power preview did not suspend the field"
			)
			support._refresh_generator_visuals(generator)
			menus._refresh_buttons()
			menus._command_card._refresh_abilities()
			_check(
				menus._status.text.contains(tr("Overdrive suspended · low power")),
				"Overdrive preview omitted its low-power status"
			)
			await _shot(label + "-overdrive-suspended")
			for supplier in supply_progress:
				supplier._construction_progress = supply_progress[supplier]
			ability.is_active = was_requested
			support._refresh_generator_visuals(generator)
			for reserve in temporary:
				reserve.queue_free()
			human.technology.completed.assign(completed)
			human.emit_changed()
			camera.global_transform = camera_transform
			camera.reset_physics_interpolation()
			paused = was_paused
	var infantry = _units(human, "Infantry")
	if not infantry.is_empty():
		infantry[0].suppression.add_pressure(95)
		await _select([infantry[0]])
		await _shot(label + "-suppression")
	await _select(before)


func _review_research(human, label):
	var was_paused = paused
	paused = true
	await _select([_units(human, "CommandLab")[0]])
	await _shot(label + "-research")
	var research = game.find_child("UnitMenus")._research_panel
	var research_tile = research._branches.weapons.button
	var motion = InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * research_tile.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, false)
	await create_timer(.9, true).timeout
	_check(
		_research_tooltip(root, research_tile.tooltip_text) != null, "Research hover has no tooltip"
	)
	await _shot(label + "-research-tooltip")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(640, 350)
	motion.global_position = motion.position
	root.push_input(motion, false)
	game.hud.open_technology()
	await _frames(20)
	await _shot(label + "-technology")
	game.hud._close_menu()
	await _frames(8)
	research = game.find_child("UnitMenus")._research_panel
	research_tile = research._branches.weapons.button
	var funds = Vector2i(human.resource_a, human.resource_b)
	research_tile.grab_focus()
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(2)
	_check(human.technology.active == "weapons_1", "Enter did not start research")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(30, 20),
		"Keyboard research charged the wrong price"
	)
	await _shot(label + "-research-active")
	research._cancel.pressed.emit()
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Research refund differs")
	if human.faction == "helix":
		await _review_plasma_shields(human, label)
	paused = was_paused


func _review_plasma_shields(human, label):
	human.coordination_unlocked = true
	var lab = _units(human, "CommandLab")[0]
	_check(human.technology.start("plasma_shields", lab), "Plasma shield research refused")
	human.technology._physics_process(1000.0)
	var tank = _units(human, "Tank")[0]
	await _select([tank])
	var menus = game.find_child("UnitMenus")
	_check(menus._shields.is_visible_in_tree(), "Shield gauge is missing")
	_check(menus._shields.value == 30.0, "Full shield gauge differs")
	await _shot(label + "-shields-full")
	# Damage changes the gauge while the selection stays in place.
	tank.shields = 18.0
	tank.shields_changed.emit()
	await _frames(8)
	_check(menus._shields.value == 18.0, "Shield gauge did not refresh")
	await _shot(label + "-shields-partial")
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var impacts = game.combat_effects.shield_impacts_emitted
	var options = root.get_node("Globals").options
	var reduced_flashes = options.reduced_flashes
	options.reduced_flashes = false
	paused = false
	tank.receive_damage(_units(enemy, "Tank")[0], 6.0)
	paused = true
	_check(
		game.combat_effects._hit_flashes.any(
			func(entry): return entry.unit.get_ref() == tank and entry.color == Color("68cee8")
		),
		"Shield impact omitted its blue material shimmer"
	)
	await _shot(label + "-shields-impact")
	options.reduced_flashes = reduced_flashes
	_check(game.combat_effects.shield_impacts_emitted == impacts + 1, "Shield impact missing")
	tank.shields = 0.0
	tank.shields_changed.emit()
	await _frames(8)
	_check(menus._shields.is_visible_in_tree(), "Depleted shield gauge disappeared")
	await _shot(label + "-shields-depleted")
	await _select([_units(human, "Worker")[0]])
	_check(not menus._shields.is_visible_in_tree(), "Worker shows a shield gauge")
	await _shot(label + "-shields-worker")


func _research_tooltip(node, content):
	if node.get_meta("roster_tooltip", "") == content:
		return node
	for child in node.get_children(true):
		var found = _research_tooltip(child, content)
		if found != null:
			return found
	return null


func _select(units):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	await _frames(30)


func _many_players(faction, language, spectator):
	var settings = _match_settings_script.new()
	settings.skirmish = not spectator
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	# PER_PLAYER with no human exercises the real spectator roster path.
	settings.visibility = settings.Visibility.PER_PLAYER if spectator else settings.Visibility.FULL
	var constants = root.get_node("Constants")
	var controllers = constants.PlayerType
	for index in range(8):
		var side = _player_settings_script.new()
		side.controller = (
			controllers.HUMAN if index == 0 and not spectator else controllers.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = faction
		side.color = constants.Player.COLORS[index]
		settings.players.append(side)
	var scene = "Match" if spectator else "Skirmish"
	game = load("res://source/match/%s.tscn" % scene).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	var players = get_nodes_in_group("players")
	for index in players.size():
		var player = players[index]
		player.set_process(false)
		# Distinct readouts make the first and last plates recognizable in captures.
		player.resource_a = 1000 + index * 250
		player.resource_b = 500 + index * 125
	var human = game._get_human_player()
	_check((human == null) == spectator, "Eight-player fixture has the wrong viewer")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(_units(players[0], "CommandCenter")[0].global_position)
	# Visibility and fog revealers need their first physics updates. Pausing a
	# PER_PLAYER spectator at construction leaves the viewport artificially dark.
	for _tick in range(12):
		await physics_frame
	if spectator:
		var headquarters = _units(players[0], "CommandCenter")[0]
		_check(headquarters.visible, "Spectator cannot see its viewed side after initialization")
		_check(
			game.fog_of_war._unit_to_circles_mapping.has(headquarters),
			"Spectator has no fog reveal for its viewed headquarters"
		)
	paused = true
	await _frames(30)
	var label = (
		"%s-720p-%s-%s"
		% [
			faction,
			"zh" if language == "zh_CN" else "en",
			"spectator-eight-players" if spectator else "eight-players"
		]
	)
	for selected in [false] if spectator else [false, true]:
		root.get_node("MatchSignals").deselect_all_units.emit()
		if selected:
			_units(human, "Worker")[0].get_node("Selection").select()
		if not spectator:
			game.subtitles._on_line({"speaker": "Command", "text": "Battle control online."})
		await _frames(12)
		var state = label + ("-worker" if selected else "-closed")
		_check(
			game.find_child("UnitMenus").is_visible_in_tree() == selected,
			"Roster preview deck does not follow selection: " + state
		)
		await _capture_roster(state, spectator)
	if not spectator:
		# Shrinking the visible roster must clear a previously scrolled offset.
		var resources = game.get_node("HUD/MarginContainer2/Resources")
		resources._hide_all_bars()
		resources._show_player_bars([human])
		await _frames(12)
		_check(
			is_equal_approx(resources.size.y, HudLayout.TOP_PLATE),
			"Roster did not shrink: " + label
		)
		_check(resources.scroll_vertical == 0, "Shrunk roster retained its offset: " + label)
		_check(not resources.get_v_scroll_bar().visible, "Shrunk roster still scrolls: " + label)
		await _shot(label + "-single-player")
	_roster_cases += 1
	paused = false
	game.queue_free()
	await _frames(5)


func _capture_roster(label, spectator):
	var resources = game.get_node("HUD/MarginContainer2/Resources")
	var scrollbar = resources.get_v_scroll_bar()
	var bars = resources.get_node("Bars").get_children()
	_check(
		bars.size() == 8 and bars.all(func(bar): return bar.visible),
		"Roster omits players: " + label
	)
	_check(scrollbar.visible, "Eight-player roster does not scroll at 720p large UI: " + label)
	_check(
		scrollbar.focus_mode == Control.FOCUS_ALL and resources.follow_focus,
		"Roster scrolling lacks keyboard access: " + label
	)
	_check(resources.theme != null, "Roster scrollbar has no battle theme: " + label)
	for bottom in [false, true]:
		resources.scroll_vertical = 10000 if bottom else 0
		await _frames(3)
		var endpoint = bars[-1] if bottom else bars[0]
		_check(
			resources.get_global_rect().encloses(endpoint.get_global_rect()),
			"Roster scroll endpoint is clipped: " + label
		)
		await _shot(label + ("-bottom" if bottom else "-top"), spectator)


func _shot(label, spectator = false):
	var resources = game.get_node("HUD/MarginContainer2/Resources").get_global_rect()
	var mini = game.find_child("Minimap", true, false).get_global_rect()
	_check(
		resources.position == Vector2.ZERO, "Resource stack is not flush to the corner: " + label
	)
	_check(root.get_visible_rect().encloses(resources), "Resource stack exceeds viewport: " + label)
	_check(
		resources.end.y + HudLayout.GAP <= mini.position.y,
		"Resource stack covers minimap: " + label
	)
	if not spectator:
		var briefing = game.hud._briefing.get_global_rect()
		_check(briefing.position.y >= resources.end.y, "Objective covers resource stack: " + label)
		_check(not briefing.intersects(mini), "Objective covers minimap: " + label)
		_check(
			resources.end.x + HudLayout.GAP <= game.hud.system_plate.get_global_rect().position.x,
			"Top plates overlap: " + label
		)
		if game.subtitles._card.is_visible_in_tree():
			_check(
				not game.subtitles._card.get_global_rect().intersects(resources),
				"Caption covers resource stack: " + label
			)
	var deck = game.find_child("UnitMenus", true, false)
	_check(
		not game.find_child("ConsoleFrame", true, false).empty_deck.visible,
		"Empty console covers battlefield: " + label
	)
	if deck.is_visible_in_tree():
		var rect = deck.get_global_rect()
		_check(rect.position.y >= mini.position.y - .5, "Console exceeds height budget: " + label)
		_check(absf(rect.position.x - mini.end.x) < .5, "Console/minimap gap: " + label)
		_check(
			absf(rect.end.x - root.get_visible_rect().end.x) < .5,
			"Console does not span bottom: " + label
		)
		_check(
			absf(rect.end.y - root.get_visible_rect().end.y) < .5,
			"Console does not sit at bottom: " + label
		)
	# Keep an unrelated OS cursor hover from leaving a tooltip over the capture.
	Input.warp_mouse(root.get_visible_rect().size - Vector2(16, 280))
	await _frames(2)
	RenderingServer.force_draw(false)
	var saved = root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	_check(saved == OK, "Could not save HUD capture: " + label)
	print("Captured ", label)
