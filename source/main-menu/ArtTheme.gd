extends RefCounted

# Front end and battle share the same console kit, controls and CJK font fallback.
const Console = preload("res://source/match/hud/BattleTheme.gd")
const IVORY = Console.IVORY
const MUTED = Console.MUTED
const COPPER = Console.COPPER


static func create() -> Theme:
	return Console.create()


static func panel(
	_color = Color("0c1419fa"),
	padding = 18,
	_radius = 0,
	_border_color = Color("1e2f3bc8"),
	_border_width = 1
) -> StyleBox:
	return Console.panel(padding, padding)


static func surface(color: Color, horizontal = 8, vertical = 4) -> StyleBoxFlat:
	return Console.surface(color, horizontal, vertical)


static func section(horizontal = 18, vertical = 16) -> StyleBox:
	return Console.panel(horizontal, vertical)


static func focus() -> StyleBox:
	return Console.focus()


static func primary_button_style() -> StyleBox:
	return Console.key("primary", 14, 10)


static func primary_button_hover_style() -> StyleBox:
	return Console.key("primary_hover", 14, 10)


static func primary_button_pressed_style() -> StyleBox:
	return Console.key("primary_pressed", 14, 10)


static func secondary_button_style() -> StyleBox:
	return Console.key("normal", 14, 10)


static func secondary_button_hover_style() -> StyleBox:
	return Console.key("hover", 14, 10)


static func animate_buttons(_node):
	# Native themed hover/focus states require no per-button tweens.
	pass
