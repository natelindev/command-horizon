extends RefCounted

const PANORAMA = preload("res://assets/ui/art/battle/frontier-pause-v2.png")
const IVORY = Color("f1eee4")
const MUTED = Color("95a4aa")
const COPPER = Color("d8bc80")
static var _theme: Theme


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


static func panel(horizontal = 18, vertical = 16) -> StyleBoxFlat:
	var style = surface(Color("0a1216f6"), horizontal, vertical)
	style.set_corner_radius_all(0)
	style.set_border_width_all(1)
	style.border_color = Color("1e2f3bc8")
	style.shadow_color = Color("00000050")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style


static func apply(control: Control, horizontal = 16, vertical = 12):
	control.theme = create()
	control.add_theme_stylebox_override("panel", panel(horizontal, vertical))


static func create() -> Theme:
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
	var card = surface(Color("1b2930"), 8, 8)
	theme.set_stylebox("normal", "BattleCardButton", card)
	theme.set_stylebox("disabled", "BattleCardButton", surface(Color("152127"), 8, 8))
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_stylebox("panel", "Panel", panel())
	theme.set_stylebox("panel", "PopupMenu", panel(12, 10))
	theme.set_stylebox("hover", "PopupMenu", surface(Color("1c2b36")))
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	var tooltip = surface(Color("0b1318"), 12, 10)
	tooltip.set_border_width_all(1)
	tooltip.border_color = Color("1e2f3bc8")
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
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
		var selected_tab = surface(Color("1c2c36"), 14, 8)
		selected_tab.border_color = Color("d8a846")
		selected_tab.border_width_bottom = 2
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


static func focus() -> StyleBoxFlat:
	var style = surface(Color.TRANSPARENT)
	# A visible keyboard-focus indicator, never a decorative selected border.
	style.set_border_width_all(1)
	style.border_color = Color("d8a846")
	return style


static func heading(
	parent: Control, title: Label, height = 60, portrait: Texture2D = null
) -> Control:
	var header = HBoxContainer.new()
	header.name = "ArtworkHeader"
	header.custom_minimum_size.y = height
	header.add_theme_constant_override("separation", 16)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(header)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_color", IVORY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	if portrait != null:
		title.add_theme_font_size_override("font_size", 24)
		var plate = PanelContainer.new()
		plate.custom_minimum_size = Vector2(104, 96)
		plate.add_theme_stylebox_override("panel", surface(Color.TRANSPARENT, 4, 4))
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(plate)
		var icon = TextureRect.new()
		icon.texture = portrait
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(icon)
	else:
		title.add_theme_color_override("font_color", COPPER)
	return header


static func artwork(parent: Control, width = 270):
	var art = TextureRect.new()
	art.texture = PANORAMA
	art.custom_minimum_size.x = width
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art
