extends RefCounted


# Shared native controls: warm ivory typography, slate surfaces and copper fills.
static func panel(color = Color("17252bea"), padding = 18, radius = 6, border_color = Color(0, 0, 0, 0), border_width = 0):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0, 0, 0, .28)
	style.shadow_size = 12
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border_color
	return style


static func create():
	var theme = Theme.new()
	theme.default_font_size = 18
	for type in ["Label", "Button", "OptionButton", "CheckBox", "TabContainer", "PopupMenu"]:
		theme.set_color("font_color", type, Color("e9e5d8"))
		theme.set_color("font_hover_color", type, Color("fff6df"))
		theme.set_color("font_pressed_color", type, Color("fff6df"))
	for type in ["Button", "OptionButton", "CheckBox"]:
		theme.set_stylebox("normal", type, panel(Color("213139dc"), 12, 4))
		theme.set_stylebox("hover", type, panel(Color("405052"), 12, 4))
		theme.set_stylebox("pressed", type, panel(Color("665440"), 12, 4))
		theme.set_stylebox("disabled", type, panel(Color("19232899"), 12, 4))
		var focus = panel(Color(0, 0, 0, 0), 12, 4)
		focus.set_border_width_all(2)
		focus.border_color = Color("e7d9b8")
		theme.set_stylebox("focus", type, focus)
	for state in ["normal", "pressed"]:
		theme.set_stylebox(state, "CheckBox", panel(Color("21313980"), 6, 3))
	theme.set_stylebox("hover", "CheckBox", panel(Color("405052"), 6, 3))
	theme.set_stylebox("hover_pressed", "CheckBox", panel(Color("405052"), 6, 3))
	theme.set_stylebox("panel", "PanelContainer", panel(Color("101820ea"), 18, 8, Color("2f404e59"), 1))
	theme.set_stylebox("panel", "PopupMenu", panel(Color("111a22"), 10, 6, Color("2f404e66"), 1))
	theme.set_stylebox("hover", "PopupMenu", panel(Color("243644"), 8, 4))
	theme.set_stylebox("panel", "TabContainer", panel(Color("0d141cea"), 16, 8, Color("27384666"), 1))
	theme.set_stylebox("tab_selected", "TabContainer", panel(Color("263947"), 12, 4))
	theme.set_stylebox("tab_unselected", "TabContainer", panel(Color("131c24"), 12, 4))
	theme.set_stylebox("tab_hovered", "TabContainer", panel(Color("1c2b36"), 12, 4))

	var slider_bg = StyleBoxFlat.new()
	slider_bg.bg_color = Color("141e26")
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)

	var slider_fill = StyleBoxFlat.new()
	slider_fill.bg_color = Color("d8af67")
	slider_fill.set_corner_radius_all(3)
	slider_fill.content_margin_top = 4
	slider_fill.content_margin_bottom = 4
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	return theme


static func primary_button_style() -> StyleBoxFlat:
	return panel(Color("d8af67"), 10, 6)


static func primary_button_hover_style() -> StyleBoxFlat:
	return panel(Color("f0c37b"), 10, 6)


static func primary_button_pressed_style() -> StyleBoxFlat:
	return panel(Color("c59c55"), 10, 6)


static func secondary_button_style() -> StyleBoxFlat:
	return panel(Color("1c2b36d9"), 10, 6, Color("364b5b66"), 1)


static func secondary_button_hover_style() -> StyleBoxFlat:
	return panel(Color("283d4ce6"), 10, 6, Color("4a647780"), 1)


static func animate_buttons(node):
	for child in node.get_children():
		if child is Button:
			child.mouse_entered.connect(func(): _fade(child, Color("ffe4b4")))
			child.mouse_exited.connect(func(): _fade(child, Color.WHITE))
		animate_buttons(child)


static func _fade(control, color):
	if control.has_meta("hover_tween"):
		var previous = control.get_meta("hover_tween")
		if previous.is_valid():
			previous.kill()
	var tween = control.create_tween()
	control.set_meta("hover_tween", tween)
	tween.tween_property(control, "modulate", color, .18)
