extends RefCounted


# Shared native controls: warm ivory typography, slate surfaces and copper fills.
static func panel(
	color = Color("17252bea"),
	padding = 18,
	radius = 6,
	border_color = Color(0, 0, 0, 0),
	border_width = 0
):
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
	# One native control system across the front end, settings and battle HUD.
	return preload("res://source/match/hud/BattleTheme.gd").create()


static func primary_button_style() -> StyleBoxFlat:
	return panel(Color("d8af67"), 10, 6)


static func primary_button_hover_style() -> StyleBoxFlat:
	return panel(Color("f0c37b"), 10, 6)


static func primary_button_pressed_style() -> StyleBoxFlat:
	return panel(Color("c59c55"), 10, 6)


static func secondary_button_style() -> StyleBoxFlat:
	return panel(Color("1c2b36"), 10, 6)


static func secondary_button_hover_style() -> StyleBoxFlat:
	return panel(Color("354349"), 10, 6)


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
