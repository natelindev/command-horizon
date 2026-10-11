extends RefCounted

const PANORAMA = preload("res://assets/ui/art/battle/frontier-pause-v2.png")
const IVORY = Color("f1eee4")
const MUTED = Color("95a4aa")
const COPPER = Color("d8bc80")
static var _theme: Theme


static func surface(color: Color, horizontal = 8, vertical = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


static func panel(horizontal = 18, vertical = 16) -> StyleBoxFlat:
	var style = surface(Color("10191ff5"), horizontal, vertical)
	style.set_corner_radius_all(9)
	style.set_border_width_all(1)
	style.border_color = Color("ffffff14")
	style.shadow_color = Color("00000045")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
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
		theme.set_stylebox("normal", type, surface(Color("1d2a30")))
		theme.set_stylebox("hover", type, surface(Color("2e3b3f")))
		theme.set_stylebox("pressed", type, surface(Color("494431")))
		theme.set_stylebox("hover_pressed", type, surface(Color("61553a")))
		theme.set_stylebox("disabled", type, surface(Color("162228")))
		theme.set_stylebox("focus", type, focus())
		theme.set_constant("h_separation", type, 6)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			theme.set_color("icon_" + state + "_color", type, IVORY)
		theme.set_color("icon_disabled_color", type, Color("7b8587"))
	# Check controls keep their native icons and keyboard semantics.
	for type in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, surface(Color.TRANSPARENT, 4, 3))
		theme.set_stylebox("disabled", type, surface(Color.TRANSPARENT, 4, 3))
	theme.set_type_variation("BattlePrimaryButton", "Button")
	theme.set_stylebox("normal", "BattlePrimaryButton", surface(Color("cfb478")))
	theme.set_stylebox("hover", "BattlePrimaryButton", surface(Color("e5cc95")))
	theme.set_stylebox("pressed", "BattlePrimaryButton", surface(Color("b39760")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "BattlePrimaryButton", Color("151c20"))
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
	theme.set_stylebox("hover", "PopupMenu", surface(Color("494431")))
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	var tooltip = surface(Color("10191f"), 12, 10)
	tooltip.set_border_width_all(1)
	tooltip.border_color = Color("ffffff14")
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", IVORY)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	for type in ["LineEdit", "TextEdit", "CodeEdit", "ItemList"]:
		theme.set_stylebox("normal", type, surface(Color("101c20"), 8, 5))
		theme.set_stylebox("read_only", type, surface(Color("111c22"), 8, 5))
		theme.set_stylebox("focus", type, focus())
		theme.set_color("font_readonly_color", type, MUTED)
		theme.set_color("font_placeholder_color", type, Color("869592"))
		theme.set_color("caret_color", type, IVORY)
		theme.set_color("selection_color", type, Color("494431"))
	theme.set_stylebox("selected", "ItemList", surface(Color("494431")))
	theme.set_stylebox("selected_focus", "ItemList", surface(Color("494431")))
	theme.set_stylebox("panel", "TabContainer", surface(Color("111a20"), 12, 10))
	for type in ["TabContainer", "TabBar"]:
		var selected_tab = surface(Color("354349"), 12, 8)
		theme.set_stylebox("tab_selected", type, selected_tab)
		theme.set_stylebox("tab_unselected", type, surface(Color.TRANSPARENT, 12, 8))
		theme.set_stylebox("tab_hovered", type, surface(Color("2e3b3f"), 12, 6))
		theme.set_stylebox("tab_focus", type, focus())
		theme.set_color("font_unselected_color", type, MUTED)
	for type in ["HSeparator", "VSeparator"]:
		var line = StyleBoxLine.new()
		line.color = Color("ffffff18")
		line.thickness = 1
		line.vertical = type == "VSeparator"
		theme.set_stylebox("separator", type, line)
		theme.set_constant("separation", type, 8)
	for type in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type, surface(Color("0e191d"), 3, 3))
		theme.set_stylebox("grabber", type, surface(Color("52615c"), 3, 3))
		theme.set_stylebox("grabber_highlight", type, surface(COPPER, 3, 3))
		theme.set_stylebox("grabber_pressed", type, surface(Color("dac08f"), 3, 3))
		theme.set_stylebox("scroll_focus", type, focus())
	theme.set_stylebox("background", "ProgressBar", surface(Color("0d181c"), 0, 2))
	theme.set_stylebox("fill", "ProgressBar", surface(COPPER, 0, 2))
	_theme = theme
	return theme


static func focus() -> StyleBoxFlat:
	var style = surface(Color.TRANSPARENT)
	# A visible keyboard-focus indicator, never a decorative selected border.
	style.set_border_width_all(2)
	style.border_color = Color("e8ddc4")
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
