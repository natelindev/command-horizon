extends RefCounted


# Shared native controls: warm ivory typography, slate surfaces and copper fills.
static func panel(
	color = Color("0c1419fa"),
	padding = 18,
	radius = 0,
	border_color = Color("1e2f3bc8"),
	border_width = 1
):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0, 0, 0, .35)
	style.shadow_size = 8
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border_color
	return style


static func create():
	# One native control system across the front end, settings and battle HUD.
	return preload("res://source/match/hud/BattleTheme.gd").create()


static func primary_button_style() -> StyleBoxFlat:
	return panel(Color("d8a846"), 10, 0, Color("f3c562"), 1)


static func primary_button_hover_style() -> StyleBoxFlat:
	return panel(Color("ebba57"), 10, 0, Color("ffe08b"), 1)


static func primary_button_pressed_style() -> StyleBoxFlat:
	return panel(Color("ba8b32"), 10, 0, Color("d8a846"), 1)


static func secondary_button_style() -> StyleBoxFlat:
	return panel(Color("101a20"), 10, 0, Color("233642"), 1)


static func secondary_button_hover_style() -> StyleBoxFlat:
	return panel(Color("1c2b36"), 10, 0, Color("38505e"), 1)


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
