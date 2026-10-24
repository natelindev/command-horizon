extends "res://tests/rendered/HudConsolePreview.gd"

# Review the production order/research glyphs and service-site legend in both locales.
const SYMBOL_OUTPUT = "res://art/symbol-review/"
var _symbol_captures = 0


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("NeutralSymbolsPreview needs a graphical renderer")
		quit(1)
		return
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SYMBOL_OUTPUT))
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for language in ["en", "zh_CN"]:
		await _configure(preferences, Vector2i(1280, 720), 1.5, language)
		await _map_legend(language)
		for faction in ["bastion", "helix", "frontier"]:
			await _skirmish(faction)
			for player in get_nodes_in_group("players"):
				player.set_process(false)
			paused = true
			var human = game._get_human_player()
			var tank = _units(human, "Tank")[0]
			tank.hp = int(tank.hp_max * .55)
			var camera = game.get_node("IsometricCamera3D")
			camera.set_position_safely(tank.global_position)
			camera.set_size_safely(22)
			await _select([tank])
			if faction == "bastion" and language == "en":
				_write_cursor_assets()
			await _symbol_capture(faction + "-orders-" + language)
			await _select([_units(human, "CommandLab")[0]])
			await _symbol_capture(faction + "-research-" + language)
			paused = false
			game.queue_free()
			await _frames(5)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	preferences.restore(original)
	_check(_symbol_captures == 14, "The symbol review capture matrix is incomplete")
	for message in errors:
		push_error(message)
	print("Neutral symbols preview: %d failures, %d captures" % [errors.size(), _symbol_captures])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _write_cursor_assets():
	var feedback = game.find_child("CommandFeedback", true, false)
	for kind in ["attack", "repair"]:
		var destination = SYMBOL_OUTPUT + "cursor-%s.png" % kind
		_check(
			feedback._cursors[kind].get_image().save_png(destination) == OK,
			"Cannot save " + destination
		)


func _map_legend(language):
	var menu = load("res://source/main-menu/Play.tscn").instantiate()
	menu.preferences_path = "user://symbol-review-%d.cfg" % OS.get_process_id()
	root.add_child(menu)
	current_scene = menu
	await _frames(15)
	var toggle = _legend_button(menu)
	_check(toggle != null, "The map legend toggle is missing")
	if toggle != null:
		toggle.button_pressed = true
	await _frames(10)
	await _symbol_capture("map-legend-" + language)
	menu.queue_free()
	await _frames(5)


func _legend_button(node):
	if node is Button and node.text == "Map legend":
		return node
	for child in node.get_children():
		var found = _legend_button(child)
		if found != null:
			return found
	return null


func _symbol_capture(label):
	Input.warp_mouse(Vector2(1260, 360))
	await _frames(6)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels.get_size() == Vector2i(1280, 720), "Unexpected symbol-review size: " + label)
	_check(pixels.save_png(SYMBOL_OUTPUT + label + ".png") == OK, "Cannot save " + label)
	_symbol_captures += 1
	print("Captured ", label)
