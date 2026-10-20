extends "res://tests/headless/SaveRestoreEdges.gd"

## The battle HUD is one console per faction: plates hang flush from the top rail,
## the minimap housing and command deck sit flush in the bottom corners, and the
## caption keeps a fixed gap between them whatever is selected.

const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
var label = ""
## Counts completed console checks, so a script error cannot pass silently.
var _checked = 0


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	for combo in [
		["bastion", "DesertFrontier"],
		["helix", "battlefields/DesertFrontierMap"],
		["frontier", "CoastalFoundry"],
	]:
		await _skirmish(combo[0], "res://source/match/maps/%s.tscn" % combo[1])
		game.hud._toggle_pause()
		_check_kit()
		var refinery = game.map.points_of_interest.filter(func(site): return site.kind == "refinery")[0]
		refinery.captured_by = game._get_human_player()
		refinery._update_presentation()
		game.find_child("ResourcesBar")._refresh()
		for full_visibility in [false, true]:
			var resource_stack = game.get_node("HUD/MarginContainer2/Resources")
			resource_stack._hide_all_bars()
			resource_stack._show_player_bars(
				get_nodes_in_group("players") if full_visibility else [game._get_human_player()]
			)
			for scale_value in [1.5, 1.0]:
				options.restore(
					{
						"screen": 1,
						"edge_scrolling": false,
						"subtitles": true,
						"interface_scale": scale_value
					}
				)
				root.size = Vector2i(1280, 720) if scale_value == 1.5 else Vector2i(1920, 1080)
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
				root.content_scale_size = Vector2i(1920, 1080)
				var human = game._get_human_player()
				var deck_width = -1.0
				var caption = Rect2()
				for role in ["", "Worker", "Tank", "VehicleFactory"]:
					label = (
						"%s %s scale=%s full=%s %s"
						% [combo[0], combo[1], scale_value, full_visibility, role]
					)
					root.get_node("MatchSignals").deselect_all_units.emit()
					if role != "":
						_units(human, role)[0].get_node("Selection").select()
					game.subtitles._on_line(
						{"speaker": "Command", "text": "Battle control online."}
					)
					await _frames(12)
					_check_console(role != "")
					var bars = resource_stack.get_node("Bars")
					var visible_bars = bars.get_children().filter(func(bar): return bar.visible)
					var plate_height = (
						bars.get_theme_constant("separation") * (visible_bars.size() - 1)
					)
					for bar in visible_bars:
						plate_height += bar.get_combined_minimum_size().y
					_check(
						is_equal_approx(resource_stack.size.y, plate_height),
						label + ": the normal resource plates changed height"
					)
					_check(
						not resource_stack.get_v_scroll_bar().visible,
						label + ": the normal resource plates need scrolling"
					)
					var deck = game.find_child("UnitMenus")
					if role != "":
						if deck_width < 0:
							deck_width = deck.size.x
						_check(deck.size.x == deck_width, label + ": deck width follows selection")
					var card = game.subtitles._card.get_global_rect()
					if caption.has_area():
						_check(card == caption, label + ": selection moved the caption")
					caption = card
		paused = false
		game.queue_free()
		await _frames(5)
	for faction in ["bastion", "helix", "frontier"]:
		await _many_players(faction, false)
		for scale_value in [1.5, 1.0]:
			_set_resolution(options, scale_value)
			for selected in [false, true]:
				label = "%s eight players scale=%s selected=%s" % [faction, scale_value, selected]
				root.get_node("MatchSignals").deselect_all_units.emit()
				if selected:
					_units(game._get_human_player(), "Worker")[0].get_node("Selection").select()
				game.subtitles._on_line({"speaker": "Command", "text": "Battle control online."})
				await _frames(12)
				_check_console(selected)
				await _check_roster_scroll(scale_value == 1.5)
		# Returning to one visible player must shrink the scroller and reset its offset.
		var resources = game.get_node("HUD/MarginContainer2/Resources")
		resources._hide_all_bars()
		resources._show_player_bars([game._get_human_player()])
		await _frames(12)
		_check(is_equal_approx(resources.size.y, 70), label + ": roster did not shrink")
		_check(resources.scroll_vertical == 0, label + ": hidden roster retained its offset")
		paused = false
		game.queue_free()
		await _frames(5)
	# A normal Match without a human has the same roster but no mission briefing.
	await _many_players("bastion", true)
	for scale_value in [1.5, 1.0]:
		_set_resolution(options, scale_value)
		label = "eight-player spectator scale=%s" % scale_value
		await _frames(12)
		var resources = game.get_node("HUD/MarginContainer2/Resources").get_global_rect()
		var minimap = game.find_child("Minimap").get_global_rect()
		_check(resources.end.y + HudLayout.GAP <= minimap.position.y, label + ": covers minimap")
		await _check_roster_scroll(scale_value == 1.5)
		_checked += 1
	paused = false
	game.queue_free()
	await _frames(5)
	options.restore(original)
	_check(_checked == 62, "Only %d of 62 console states were checked" % _checked)
	for error in errors:
		push_error(error)
	print("HUD console: %d failures over %d console states" % [errors.size(), _checked])
	quit(0 if errors.is_empty() else 1)


func _many_players(faction, spectator):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = not spectator
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	# PER_PLAYER without a human still shows the whole spectator roster.
	settings.visibility = settings.Visibility.PER_PLAYER if spectator else settings.Visibility.FULL
	var controllers = root.get_node("Constants").PlayerType
	for index in range(8):
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			controllers.HUMAN if index == 0 and not spectator else controllers.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = faction
		settings.players.append(side)
	var scene = "Match" if spectator else "Skirmish"
	game = load("res://source/match/%s.tscn" % scene).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	paused = true
	await _frames(12)


func _set_resolution(options, scale_value):
	options.restore(
		{"screen": 1, "edge_scrolling": false, "subtitles": true, "interface_scale": scale_value}
	)
	root.size = Vector2i(1280, 720) if scale_value == 1.5 else Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)


func _check_roster_scroll(needed):
	var resources = game.get_node("HUD/MarginContainer2/Resources")
	var scrollbar = resources.get_v_scroll_bar()
	_check(scrollbar.visible == needed, label + ": roster scrolling does not fit the viewport")
	_check(
		scrollbar.focus_mode == Control.FOCUS_ALL and resources.follow_focus,
		label + ": roster scrolling lacks keyboard access"
	)
	_check(resources.theme != null, label + ": roster scrolling has no battle theme")
	_check(
		resources.get_node("Bars").get_children().all(func(bar): return bar.visible),
		label + ": some players are missing from the roster"
	)
	resources.scroll_vertical = 10000
	await _frames(3)
	var last_bar = resources.get_node("Bars/ResourcesBar8").get_global_rect()
	_check(
		resources.get_global_rect().encloses(last_bar),
		label + ": the final player cannot be reached by scrolling"
	)
	resources.scroll_vertical = 0
	await _frames(3)
	var first_bar = resources.get_node("Bars/ResourcesBar").get_global_rect()
	_check(
		resources.get_global_rect().encloses(first_bar),
		label + ": the first player cannot be reached by scrolling"
	)


func _check_kit():
	# Console surfaces are drawn from the industrial kit, not flat web panels.
	for control in [
		game.find_child("ResourcesBar"),
		game.find_child("Minimap"),
		game.find_child("UnitMenus"),
		game.hud.system_plate,
		game.hud.get_child(0),
	]:
		_check(
			control.get_theme_stylebox("panel") is HudStyle,
			"%s is not drawn from the console kit" % control.name
		)
	# Each faction wears its own console kit and accent.
	var faction = game._get_human_player().faction
	var deck = game.find_child("UnitMenus").get_theme_stylebox("panel")
	_check(
		deck.texture.resource_path.contains("/hud/%s/" % faction),
		"Console does not wear the %s kit: %s" % [faction, deck.texture.resource_path]
	)
	_check(
		(
			game.hud._pause_button.get_theme_color("font_color", "HudHeading")
			== preload("res://source/match/hud/BattleTheme.gd").PALETTES[faction].accent
		),
		"Headings do not use the %s accent" % faction
	)
	var key = game.hud._pause_button
	_check(key.get_theme_stylebox("normal") is HudStyle, "System keys are not keycaps")
	_check(
		key.get_theme_font("font").base_font.resource_path.contains("Barlow"),
		"Keys do not use the console typeface"
	)
	_check(not key.badge.is_empty() and key.glyph != null, "Pause key lacks glyph or hotkey badge")


func _check_console(selected):
	var viewport = root.get_visible_rect().size
	var resources = game.get_node("HUD/MarginContainer2/Resources").get_global_rect()
	var system = game.hud.system_plate.get_global_rect()
	_check(resources.position == Vector2.ZERO, label + ": resources plate is not flush")
	_check(
		is_equal_approx(system.end.x, viewport.x) and system.position.y == 0,
		label + ": system plate is not flush"
	)
	_check(resources.end.x + 8 <= system.position.x, label + ": top plates overlap")
	var beacon = game.hud.alert_panel.toggle.get_global_rect()
	_check(system.encloses(beacon), label + ": alerts beacon is not docked in the system plate")
	var minimap = game.find_child("Minimap").get_global_rect()
	_check(not resources.intersects(minimap), label + ": resources cover the minimap")
	_check(
		minimap.position.x == 0 and is_equal_approx(minimap.end.y, viewport.y),
		label + ": minimap housing is not flush"
	)
	var deck = game.find_child("UnitMenus")
	var shutter = game.find_child("EmptyDeck", true, false)
	_check(deck.visible == selected, label + ": deck visibility does not follow selection")
	_check(not shutter.visible, label + ": empty deck obscures the battlefield")
	var bay = deck.get_global_rect() if selected else shutter.get_global_rect()
	if selected:
		_check(
			is_equal_approx(bay.end.x, viewport.x) and is_equal_approx(bay.end.y, viewport.y),
			label + ": command deck is not flush"
		)
		_check(
			bay.position.y >= HudLayout.DECK_TOP_LIMIT, label + ": deck rises over the top plates"
		)
		_check(bay.size.y <= HudLayout.CONSOLE_HEIGHT, label + ": deck exceeds its height budget")
	var caption = game.subtitles._card.get_global_rect()
	_check(caption.position.x >= minimap.end.x, label + ": caption overlaps the minimap")
	if selected:
		_check(not caption.intersects(bay), label + ": caption overlaps the deck")
	_check(caption.end.x <= viewport.x, label + ": caption extends beyond the viewport")
	_check(caption.size.x >= 240, label + ": caption gap is too narrow " + str(caption.size))
	var rail = game.find_child("BottomRail", true, false).get_global_rect()
	_check(
		is_equal_approx(rail.end.y, viewport.y) and caption.end.y <= rail.position.y,
		label + ": caption does not sit on the bottom rail"
	)
	for panel in [game.hud.get_child(0)]:
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			var rect = panel.get_global_rect()
			_check(rect.position.x == 0, label + ": %s is not docked left" % panel.name)
			_check(
				rect.position.y >= resources.end.y - 1, label + ": %s covers resources" % panel.name
			)
			_check(not rect.intersects(minimap), label + ": %s covers the minimap" % panel.name)
			if selected:
				_check(not rect.intersects(bay), label + ": %s is under the deck" % panel.name)
	_checked += 1
