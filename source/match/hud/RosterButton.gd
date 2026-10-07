extends Button


func _make_custom_tooltip(for_text):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("19212b")
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
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
			"font_color", Color("bcc7d3") if index == 1 else Color("edf1f5")
		)
		label.text = lines[index] if index < 2 else "\n".join(lines.slice(2))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	return panel
