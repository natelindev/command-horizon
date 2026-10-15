extends RefCounted

const IVORY = Color("f1eee4")
const MUTED = Color("95a4aa")
const COPPER = Color("d8bc80")
static var _theme: Theme


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


static func surface(color: Color, horizontal = 8, vertical = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_border_width_all(1)
	style.border_color = Color("233642b0")
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


static func section(horizontal = 18, vertical = 16) -> StyleBoxFlat:
	# Slightly translucent so the backdrop stays present behind docked panels.
	var style = surface(Color("0a1216e8"), horizontal, vertical)
	style.border_color = Color("1e2f3bc8")
	style.shadow_color = Color("00000050")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style


static func focus() -> StyleBoxFlat:
	var style = surface(Color.TRANSPARENT)
	# A visible keyboard-focus indicator, never a decorative selected border.
	style.border_color = Color("d8a846")
	return style


static func create() -> Theme:
	# The front end (menus, setup, settings, archive outside battle). The battle HUD
	# uses the industrial console kit in BattleTheme instead.
	if _theme != null:
		return _theme
	var theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansSC.ttf")
	theme.default_font_size = 16
	for type in [
		"Label",
		"Button",
		"OptionButton",
		"CheckBox",
		"CheckButton",
		"PopupMenu",
		"TabContainer",
		"TabBar",
		"LineEdit",
		"TextEdit",
		"CodeEdit",
		"ItemList",
		"RichTextLabel"
	]:
		theme.set_color("font_color", type, IVORY)
		theme.set_color("font_hover_color", type, Color("fff4dc"))
		theme.set_color("font_pressed_color", type, Color("fff4dc"))
		theme.set_color("font_focus_color", type, Color("fff4dc"))
		theme.set_color("font_disabled_color", type, Color("798481"))
		theme.set_color("font_selected_color", type, IVORY)
	for type in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, surface(Color("101a20")))
		theme.set_stylebox("hover", type, surface(Color("1c2b36")))
		theme.set_stylebox("pressed", type, surface(Color("2d2719")))
		theme.set_stylebox("hover_pressed", type, surface(Color("3b321f")))
		theme.set_stylebox("disabled", type, surface(Color("0b1318")))
		theme.set_stylebox("focus", type, focus())
		theme.set_constant("h_separation", type, 8)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			theme.set_color("icon_" + state + "_color", type, IVORY)
		theme.set_color("icon_disabled_color", type, Color("7b8587"))
	# Check controls keep their native icons and keyboard semantics.
	for type in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, surface(Color.TRANSPARENT, 4, 3))
		theme.set_stylebox("disabled", type, surface(Color.TRANSPARENT, 4, 3))
	theme.set_type_variation("BattlePrimaryButton", "Button")
	var prim_norm = surface(Color("d8a846"))
	prim_norm.border_color = Color("f3c562")
	theme.set_stylebox("normal", "BattlePrimaryButton", prim_norm)
	var prim_hov = surface(Color("ebba57"))
	prim_hov.border_color = Color("ffe08b")
	theme.set_stylebox("hover", "BattlePrimaryButton", prim_hov)
	var prim_press = surface(Color("ba8b32"))
	prim_press.border_color = Color("d8a846")
	theme.set_stylebox("pressed", "BattlePrimaryButton", prim_press)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "BattlePrimaryButton", Color("0b1318"))
	theme.set_type_variation("BattleQuietButton", "Button")
	theme.set_stylebox("normal", "BattleQuietButton", surface(Color.TRANSPARENT))
	theme.set_stylebox("disabled", "BattleQuietButton", surface(Color.TRANSPARENT))
	theme.set_color("font_color", "BattleQuietButton", COPPER)
	theme.set_type_variation("BattleCardButton", "Button")
	theme.set_stylebox("normal", "BattleCardButton", surface(Color("1b2930"), 8, 8))
	theme.set_stylebox("disabled", "BattleCardButton", surface(Color("152127"), 8, 8))
	theme.set_stylebox("panel", "PanelContainer", section())
	theme.set_stylebox("panel", "Panel", section())
	theme.set_stylebox("panel", "PopupMenu", section(12, 10))
	theme.set_stylebox("hover", "PopupMenu", surface(Color("1c2b36")))
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	theme.set_stylebox("panel", "TooltipPanel", surface(Color("0b1318"), 12, 10))
	theme.set_color("font_color", "TooltipLabel", IVORY)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	for type in ["LineEdit", "TextEdit", "CodeEdit", "ItemList"]:
		theme.set_stylebox("normal", type, surface(Color("0a1216"), 8, 5))
		theme.set_stylebox("read_only", type, surface(Color("0c141a"), 8, 5))
		theme.set_stylebox("focus", type, focus())
		theme.set_color("font_readonly_color", type, MUTED)
		theme.set_color("font_placeholder_color", type, Color("869592"))
		theme.set_color("caret_color", type, IVORY)
		theme.set_color("selection_color", type, Color("494431"))
	theme.set_stylebox("selected", "ItemList", surface(Color("494431")))
	theme.set_stylebox("selected_focus", "ItemList", surface(Color("494431")))
	theme.set_stylebox("panel", "TabContainer", surface(Color("0a1216"), 12, 10))
	for type in ["TabContainer", "TabBar"]:
		# Selected tabs read through a lighter fill, not a coloured border.
		var selected_tab = surface(Color("24363f"), 14, 8)
		selected_tab.border_color = Color("2c404b")
		theme.set_stylebox("tab_selected", type, selected_tab)
		var unselected_tab = surface(Color("0c141a"), 14, 8)
		unselected_tab.border_color = Color("18252e")
		theme.set_stylebox("tab_unselected", type, unselected_tab)
		var hovered_tab = surface(Color("16242c"), 14, 8)
		hovered_tab.border_color = Color("38505e")
		theme.set_stylebox("tab_hovered", type, hovered_tab)
		theme.set_stylebox("tab_focus", type, focus())
		theme.set_color("font_unselected_color", type, MUTED)
		theme.set_color("font_selected_color", type, Color("ffffff"))
	for type in ["HSeparator", "VSeparator"]:
		var line = StyleBoxLine.new()
		line.color = Color("ffffff18")
		line.thickness = 1
		line.vertical = type == "VSeparator"
		theme.set_stylebox("separator", type, line)
		theme.set_constant("separation", type, 8)
	for type in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type, surface(Color("091014"), 3, 3))
		theme.set_stylebox("grabber", type, surface(Color("3b4e57"), 3, 3))
		theme.set_stylebox("grabber_highlight", type, surface(COPPER, 3, 3))
		theme.set_stylebox("grabber_pressed", type, surface(Color("dac08f"), 3, 3))
		theme.set_stylebox("scroll_focus", type, focus())
	theme.set_stylebox("background", "ProgressBar", surface(Color("091014"), 0, 2))
	theme.set_stylebox("fill", "ProgressBar", surface(COPPER, 0, 2))
	_theme = theme
	return theme


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
