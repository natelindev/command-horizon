extends "res://tests/headless/SaveRestoreEdges.gd"

var _seen = {}
var _latin = RegEx.new()
var _allowed = RegEx.new()
var _voice_count = 0


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"language": "zh_CN", "edge_scrolling": false, "screen": 1})
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	root.get_node("SaveManager").autosaves_enabled = false
	_latin.compile("[A-Za-z]{3,}")
	# Product/language names and the actual printed keyboard keys remain recognizable.
	_allowed.compile(
		"\\b(OPEN RTS|English|MSAA|Shift|Ctrl|Space|Esc|Escape|Tab|Alt|Enter|Backspace|Delete)\\b"
	)
	for scene_name in ["Main", "World", "Play", "Campaign"]:
		var scene = load("res://source/main-menu/%s.tscn" % scene_name).instantiate()
		root.add_child(scene)
		await _frames(5)
		_scan(scene)
		if scene_name == "Main":
			var dialog = root.get_node("Globals").open_settings()
			await _frames(3)
			_scan(dialog)
			dialog._finish(false)
			await _frames(3)
		scene.queue_free()
		await _frames(3)
	var factions = ["bastion", "helix", "frontier"]
	var maps = ["AlpineRelay", "IndustrialCrossroads", "battlefields/AlpineRelayMap"]
	for index in factions.size():
		await _skirmish(factions[index], "res://source/match/maps/%s.tscn" % maps[index])
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = true
		for locale in ["en", "zh_CN"]:
			TranslationServer.set_locale(locale)
			await _frames(3)
			var markers = game.find_child("RelayMarkers", true, false)
			_check(markers != null, "Relay marker fixture missing")
			if markers != null:
				for marker in markers._markers:
					_check(
						(
							marker.label.text
							== "◆  " + str(TranslationServer.translate(marker.relay.label_title))
						),
						"Relay locator did not update after language switch: " + locale
					)
		paused = false
		_scan(game)
		for role in ["Worker", "Infantry", "Tank", "Barracks", "VehicleFactory", "CommandLab"]:
			root.get_node("MatchSignals").deselect_all_units.emit()
			_units(game._get_human_player(), role)[0].get_node("Selection").select()
			await _frames(3)
			_scan(game)
		_production_text(game._get_human_player())
		for panel in ["open_technology", "open_relays", "open_sites", "_open_menu"]:
			game.hud.call(panel)
			await _frames(3)
			_scan(game.hud)
			game.hud._close_menu()
		if index == 0 and DisplayServer.get_name() != "headless":
			root.get_node("MatchSignals").deselect_all_units.emit()
			var camera = game.get_node("IsometricCamera3D")
			camera.set_position_safely(game.map.relays[1].position)
			camera.set_size_safely(25)
			await _screenshot("relay-marker-zh")
			game.hud.open_relays()
			await _screenshot("relay-overview-zh")
			game.hud._close_menu()
		game.queue_free()
		await _frames(5)
	var operations = load("res://source/match/campaign/CampaignCatalog.gd").OPERATIONS
	for id in operations:
		await _campaign(id, operations[id])
		_scan(game)
		if game.campaign_story != null and game.campaign_story.cinematic:
			game.campaign_story.skip_briefing()
		game.queue_free()
		await _frames(5)
	_voice(
		JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/catalog.json"))
	)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print(
		(
			"Chinese UI: %d unique strings, %d voice captions, %d failures"
			% [_seen.size(), _voice_count, errors.size()]
		)
	)
	quit(0 if errors.is_empty() else 1)


func _production_text(human):
	var factory = _units(human, "VehicleFactory")[0]
	var queue = factory.production_queue
	var job = queue.ProductionQueueElement.new()
	job.unit_prototype = load("res://source/match/units/Tank.tscn")
	job.time_total = 1.0
	job.time_left = 1.0
	var button = load("res://source/match/hud/ProductionQueueElement.tscn").instantiate()
	button.queue = queue
	button.queue_element = job
	game.hud.add_child(button)
	_check_text(button.tooltip_text, "production queue tooltip")
	button.queue_free()
	var Factions = load("res://source/match/FactionCatalog.gd")
	for reason in [
		"Finish construction to resume this queue.",
		"Rebuild %s to resume this queue." % Factions.title(human.faction, "RepairDepot"),
		"Research Coordination to resume this queue.",
	]:
		_check_text(reason, "production blocked reason")


func _campaign(id, entry):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = id
	settings.map_path = entry.map
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load(entry.scene).instantiate()
	game.settings = settings
	game.map = load(entry.map).instantiate()
	game.progress_path = "user://chinese-ui-%d.json" % OS.get_process_id()
	root.add_child(game)
	current_scene = game
	await _frames(10)
	for side in get_nodes_in_group("players"):
		side.set_process(false)


func _scan(node):
	if node.name == "Debug":
		return
	if node is Label or node is Button or node is RichTextLabel:
		_check_text(node.text, str(node.get_path()))
	if node is Label3D and node.is_visible_in_tree():
		_check_text(node.text, str(node.get_path()))
	if node is OptionButton:
		for index in node.item_count:
			_check_text(node.get_item_text(index), str(node.get_path()))
	if node is Control:
		_check_text(node.tooltip_text, str(node.get_path()) + " tooltip")
	for child in node.get_children():
		_scan(child)


func _check_text(value, origin):
	if value.is_empty() or _seen.has(value):
		return
	_seen[value] = true
	var translated = str(TranslationServer.translate(value))
	var remaining = _allowed.sub(translated, "", true)
	_check(
		_latin.search(remaining) == null,
		"Untranslated UI: %s => %s (%s)" % [value, translated, origin]
	)


func _voice(value):
	if value is Dictionary:
		if value.has("text"):
			_voice_count += 1
			_check_text(value.text, "voice catalog")
		for child in value.values():
			_voice(child)
	elif value is Array:
		for child in value:
			_voice(child)


func _screenshot(label):
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://docs/playtests/2026-10-15/battle-polish/%s.png" % label
	)
