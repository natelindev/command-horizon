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
	for combo in [["bastion", "DesertFrontier"], ["helix", "ExpandedDesertFrontier"]]:
		await _skirmish(combo[0], "res://source/match/maps/%s.tscn" % combo[1])
		game.hud._toggle_pause()
		_check_kit()
		var refinery = game.map.points_of_interest.filter(func(site): return site.kind == "refinery")[0]
		refinery.captured_by = game._get_human_player()
		refinery._update_presentation()
		game.find_child("ResourcesBar")._refresh()
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
				label = "%s %s scale=%s %s" % [combo[0], combo[1], scale_value, role]
				root.get_node("MatchSignals").deselect_all_units.emit()
				if role != "":
					_units(human, role)[0].get_node("Selection").select()
				game.subtitles._on_line({"speaker": "Command", "text": "Battle control online."})
				await _frames(12)
				_check_console(role != "")
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
	options.restore(original)
	for error in errors:
		push_error(error)
	_check(_checked == 16, "Only %d of 16 console states were checked" % _checked)
	print("HUD console: %d failures over %d console states" % [errors.size(), _checked])
	quit(0 if errors.is_empty() else 1)


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
	var resources = game.find_child("ResourcesBar").get_global_rect()
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
