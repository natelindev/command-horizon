extends Button

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")


func _make_custom_tooltip(for_text):
	var panel = PanelContainer.new()
	panel.theme = BattleTheme.create()
	# The native tooltip window owns the frame and padding.
	panel.add_theme_stylebox_override("panel", BattleTheme.surface(Color.TRANSPARENT, 0, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("roster_tooltip", for_text)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var lines = for_text.split("\n")
	for index in 3:
		var label = Label.new()
		label.custom_minimum_size.x = minf(370, get_viewport_rect().size.x - 48)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16 if index == 0 else 14)
		label.add_theme_color_override(
			"font_color", Color("a9b4b3") if index == 1 else Color("eee8da")
		)
		label.text = lines[index] if index < 2 else "\n".join(lines.slice(2))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	return panel
