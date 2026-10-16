extends "res://tests/headless/SaveRestoreEdges.gd"

var options
var label = ""


func _run():
	options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "subtitles": true})
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		for map_name in ["DesertFrontier", "AlpineRelay", "IndustrialCrossroads", "CoastalFoundry"]:
			await _skirmish(faction, "res://source/match/maps/%s.tscn" % map_name)
			game.hud._toggle_pause()
			game._get_human_player().get_node("BattleVoice").set_process(false)
			var human = game._get_human_player()
			var hq = _units(human, "CommandCenter")[0]
			var tank = _units(human, "Tank")[0]
			_check(
				hq.production_queue.produce(load("res://source/match/units/Worker.tscn")) != null,
				"Paid queue fixture failed"
			)
			for factor in [1.0, 1.25, 1.5]:
				for size in [18, 22, 26]:
					label = "%s %s scale=%s subtitle=%s" % [faction, map_name, factor, size]
					options.interface_scale = factor
					options.subtitle_size = size
					options.apply()
					root.get_node("MatchSignals").deselect_all_units.emit()
					game.subtitles._on_line(
						{"speaker": "Command", "text": "Your base is under attack."}
					)
					await _frames(6)
					_clearance()
					var empty = game.subtitles._card.get_global_rect()
					for unit in [hq, tank]:
						root.get_node("MatchSignals").deselect_all_units.emit()
						unit.get_node("Selection").select()
						await _frames(6)
						_clearance()
						_check(
							game.subtitles._card.get_global_rect() == empty,
							label + " selection moved caption"
						)
			await _live_bounds()
			print("PASS subtitle layout ", faction, " ", map_name)
			paused = false
			game.queue_free()
			await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Subtitle layout: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _clearance():
	var card = game.subtitles._card
	_check(card.visible, label + " caption is not displayed")
	_check(root.get_visible_rect().encloses(card.get_global_rect()), label + " caption clipped")
	for name in ["Minimap", "UnitMenus", "ProductionQueue"]:
		var control = game.find_child(name)
		if control.is_visible_in_tree():
			if name in ["UnitMenus", "ProductionQueue"]:
				_check(
					control.get_global_rect().position.y >= 72, label + " controls cover top HUD"
				)
			_check(
				not card.get_global_rect().intersects(control.get_global_rect().grow(8)),
				label + " caption covers " + name
			)
	_check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Caption intercepts orders")


func _live_bounds():
	# A live HUD resize must reposition an unchanged caption without a speech event.
	var minimap = game.find_child("Minimap")
	var original = minimap.custom_minimum_size
	minimap.custom_minimum_size.x = 410
	await _frames(6)
	_clearance()
	minimap.custom_minimum_size = original
	await _frames(6)
	_clearance()
	options.subtitles = false
	options.apply()
	_check(not game.subtitles._card.visible, "Subtitles toggle ignored")
	options.subtitles = true
	options.apply()
	_check(game.subtitles._card.visible, "Caption did not return with subtitles")
	game.subtitles._on_line({})
	_check(not game.subtitles._card.visible, "Finished line left a caption")
