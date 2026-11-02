extends RefCounted

## Battle console kit: one futuristic console language with a material and accent
## per faction (Bastion armoured gunmetal + amber, Helix graphite glass + cyan,
## Frontier salvaged metal + orange). Textures come from
## tools/ui/generate_hud_kit.py and are drawn through HudStyle at 2x density.
## Selected and active states use fills, insets and glow, never coloured borders.

const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const Cache = preload("res://source/utils/RuntimeCache.gd")
const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")
const KIT = "res://assets/ui/hud/"
const BODY_FONT = preload("res://assets/fonts/NotoSansSC.ttf")
const DISPLAY_FACE = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const NUMERAL_FACE = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")

const IVORY = Color("f1eee4")
const MUTED = Color("b0b9ba")
const COPPER = Color("d8bc80")
## Accent and ink (text on accent fills) per faction kit.
const PALETTES = {
	"bastion": {"accent": Color("e8b04a"), "ink": Color("1d1609")},
	"helix": {"accent": Color("5fd8e8"), "ink": Color("06171c")},
	"frontier": {"accent": Color("f08c3e"), "ink": Color("1f1007")},
}
const SIGNAL_OK = Color("79d3c5")
const SIGNAL_WARN = Color("e7c578")
const SIGNAL_BAD = Color("ff9a66")
const HEALTH_OK = Color("9fd27a")

## Shared themes and fonts follow the autoload's lifetime. Static resource fields
## keep their scripts and GPU resources alive past renderer shutdown.


static func _state() -> Dictionary:
	return Cache.bucket("battle_theme")


static func use_faction(name: String):
	_state().faction = name if PALETTES.has(name) else "bastion"


static func accent() -> Color:
	return PALETTES[_state().get("faction", "bastion")].accent


static func ink() -> Color:
	return PALETTES[_state().get("faction", "bastion")].ink


# --- fonts ---------------------------------------------------------------------


static func display_font() -> Font:
	# Condensed industrial face for keys, tabs and labels; CJK falls back to Noto.
	var state = _state()
	if not state.has("display_font"):
		var font = FontVariation.new()
		font.base_font = DISPLAY_FACE
		font.fallbacks = [BODY_FONT]
		state.display_font = font
	return state.display_font


static func heading_font() -> Font:
	# Tracked-out capitals for engraved nameplates.
	var state = _state()
	if not state.has("heading_font"):
		var font = FontVariation.new()
		font.base_font = DISPLAY_FACE
		font.fallbacks = [BODY_FONT]
		font.spacing_glyph = 1
		state.heading_font = font
	return state.heading_font


static func numeral_font() -> Font:
	var state = _state()
	if not state.has("numeral_font"):
		var font = FontVariation.new()
		font.base_font = NUMERAL_FACE
		font.fallbacks = [BODY_FONT]
		# Tabular figures keep counters from jittering as values change.
		font.opentype_features = {"tnum": 1}
		state.numeral_font = font
	return state.numeral_font


# --- styles --------------------------------------------------------------------


static func kit(name: String, slice, horizontal = 0.0, vertical = 0.0) -> StyleBox:
	var style = HudStyle.new()
	var faction = _state().get("faction", "bastion")
	var own = KIT + faction + "/" + name + ".png"
	# State overlays (glow, focus, bar cells) are shared and tinted by the accent.
	style.texture = load(own if ResourceLoader.exists(own) else KIT + name + ".png")
	var slices = slice if slice is Vector4 else Vector4(slice, slice, slice, slice)
	style.slice_left = slices.x
	style.slice_top = slices.y
	style.slice_right = slices.z
	style.slice_bottom = slices.w
	_margins(style, horizontal, vertical)
	return style


static func _margins(style: StyleBox, horizontal, vertical, bottom = null):
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical if bottom == null else bottom


static func surface(color: Color, horizontal = 8, vertical = 4) -> StyleBoxFlat:
	# Plain fill for layout wrappers and transparent groupings.
	var style = StyleBoxFlat.new()
	style.bg_color = color
	_margins(style, horizontal, vertical)
	return style


static func panel(horizontal = 18, vertical = 16) -> StyleBox:
	# Floating briefings and dialogs: a bolted frame around a recessed field.
	return kit("plate_panel", 16, maxf(horizontal, 14), maxf(vertical, 12))


static func housing(horizontal = 24, vertical = 22) -> StyleBox:
	# Heavy console housings (minimap, command deck, top plates).
	return kit("plate_heavy", 24, maxf(horizontal, 20), maxf(vertical, 18))


static func strip(horizontal = 16, vertical = 8) -> StyleBox:
	# Frameless raised plate for compact bars hanging from the top rail.
	return kit("plate_strip", 16, horizontal, vertical)


static func card(horizontal = 12, vertical = 10) -> StyleBox:
	# Inline cards inside a panel (recommendations, research, tooltips).
	return kit("plate_card", 10, horizontal, vertical)


static func socket(horizontal = 10, vertical = 6) -> StyleBox:
	# A recessed screen for readouts, portraits and text fields.
	return kit("socket", 12, horizontal, vertical)


static func socket_frame() -> StyleBox:
	# Edge-only recess drawn over live content such as the minimap.
	var style = kit("socket_frame", 12)
	return style


static func nameplate(horizontal = 14, vertical = 4) -> StyleBox:
	var style = kit("nameplate", Vector4(16, 8, 8, 8), horizontal, vertical)
	style.content_margin_left = horizontal + 6
	return style


static func key(state = "normal", horizontal = 12, vertical = 5) -> StyleBox:
	var name = {
		"normal": "key_normal",
		"hover": "key_hover",
		"pressed": "key_pressed",
		"hover_pressed": "key_pressed",
		"disabled": "key_disabled",
		"primary": "key_primary",
		"primary_hover": "key_primary_hover",
		"primary_pressed": "key_primary_pressed",
	}[state]
	var style = kit(name, 12)
	# The lip shows the key's thickness; centre text on the face, which drops when pressed.
	var pressed = "pressed" in state
	_margins(style, horizontal, vertical + (1 if pressed else 0), vertical + (2 if pressed else 3))
	return style


static func glow(alpha = 1.0, horizontal = 8, vertical = 4) -> StyleBox:
	var style = kit("glow", 12, horizontal, vertical)
	style.modulate = Color(accent(), alpha)
	return style


static func focus() -> StyleBox:
	# A visible keyboard-focus indicator: amber corner brackets outside the control.
	var style = kit("focus", 8)
	style.modulate = accent()
	style.expand = 3
	style.draw_center = false
	return style


static func rail() -> StyleBox:
	var style = kit("rail", 0)
	style.horizontal_mode = RenderingServer.NINE_PATCH_TILE_FIT
	return style


static func stripe() -> StyleBox:
	# Faction warning stripe: chevrons, data dashes or hazard bands.
	var style = kit("stripe", 0)
	style.horizontal_mode = RenderingServer.NINE_PATCH_TILE_FIT
	return style


static func bar_track() -> StyleBox:
	return kit("socket", 4, 0, 0)


static func bar_fill(color: Color) -> StyleBox:
	# Segmented cells; colour carries the state (ok / warning / critical).
	var style = kit("bar_segment", Vector4(0, 4, 0, 4), 0, 0)
	style.horizontal_mode = RenderingServer.NINE_PATCH_TILE
	style.modulate = color
	return style


static func apply(control: Control, horizontal = 16, vertical = 12):
	control.theme = create()
	control.add_theme_stylebox_override("panel", panel(horizontal, vertical))


static func apply_housing(control: Control, horizontal = 24, vertical = 22):
	control.theme = create()
	control.add_theme_stylebox_override("panel", housing(horizontal, vertical))


# --- theme ---------------------------------------------------------------------


static func create() -> Theme:
	var state = _state()
	var faction = state.get("faction", "bastion")
	var themes = state.get_or_add("themes", {})
	if themes.has(faction):
		return themes[faction]
	var theme = Theme.new()
	theme.default_font = BODY_FONT
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
		theme.set_color("font_hover_color", type, Color("fff6e2"))
		theme.set_color("font_pressed_color", type, Color("ffe7b0"))
		theme.set_color("font_focus_color", type, Color("fff6e2"))
		theme.set_color("font_hover_pressed_color", type, Color("ffe7b0"))
		theme.set_color("font_disabled_color", type, Color("6f7674"))
		theme.set_color("font_selected_color", type, IVORY)
		theme.set_color("font_outline_color", type, Color("050607"))
	_keys(theme)
	_panels(theme)
	_fields(theme)
	_tabs(theme)
	_chrome(theme)
	themes[faction] = theme
	return theme


static func _keys(theme: Theme):
	for type in ["Button", "OptionButton"]:
		theme.set_font("font", type, display_font())
		theme.set_font_size("font_size", type, 16)
		theme.set_stylebox("normal", type, key("normal"))
		theme.set_stylebox("hover", type, key("hover"))
		theme.set_stylebox("pressed", type, key("pressed"))
		theme.set_stylebox("hover_pressed", type, key("hover_pressed"))
		theme.set_stylebox("disabled", type, key("disabled"))
		theme.set_stylebox("focus", type, focus())
		theme.set_constant("h_separation", type, 8)
		theme.set_constant("outline_size", type, 0)
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			theme.set_color("icon_" + state + "_color", type, IVORY)
		theme.set_color("icon_hover_color", type, Color("ffe7b0"))
		theme.set_color("icon_disabled_color", type, Color("6f7674"))
	# Check controls keep their native icons and keyboard semantics.
	for type in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, surface(Color.TRANSPARENT, 4, 3))
		theme.set_stylebox("pressed", type, surface(Color.TRANSPARENT, 4, 3))
		theme.set_stylebox("hover", type, glow(.45, 4, 3))
		theme.set_stylebox("hover_pressed", type, glow(.45, 4, 3))
		theme.set_stylebox("disabled", type, surface(Color.TRANSPARENT, 4, 3))
		theme.set_stylebox("focus", type, focus())
	theme.set_type_variation("BattlePrimaryButton", "Button")
	theme.set_stylebox("normal", "BattlePrimaryButton", key("primary"))
	theme.set_stylebox("hover", "BattlePrimaryButton", key("primary_hover"))
	theme.set_stylebox("pressed", "BattlePrimaryButton", key("primary_pressed"))
	theme.set_stylebox("hover_pressed", "BattlePrimaryButton", key("primary_pressed"))
	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color"
	]:
		theme.set_color(state, "BattlePrimaryButton", ink())
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		theme.set_color(state, "BattlePrimaryButton", ink())
	# Quiet keys: engraved text on the plate that lights up on hover.
	theme.set_type_variation("BattleQuietButton", "Button")
	theme.set_stylebox("normal", "BattleQuietButton", surface(Color.TRANSPARENT, 10, 5))
	theme.set_stylebox("hover", "BattleQuietButton", glow(.55, 10, 5))
	theme.set_stylebox("pressed", "BattleQuietButton", socket(10, 5))
	theme.set_stylebox("hover_pressed", "BattleQuietButton", socket(10, 5))
	theme.set_stylebox("disabled", "BattleQuietButton", surface(Color.TRANSPARENT, 10, 5))
	theme.set_color("font_color", "BattleQuietButton", accent().lerp(IVORY, .3))
	theme.set_color("font_hover_color", "BattleQuietButton", Color("ffe0a0"))
	theme.set_type_variation("BattleCardButton", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "BattleCardButton", key(state, 8, 6))
	# Square command keys on the command card.
	theme.set_type_variation("HudSlotButton", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "HudSlotButton", key(state, 4, 3))


static func _panels(theme: Theme):
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_stylebox("panel", "Panel", panel())
	theme.set_type_variation("HudHousing", "PanelContainer")
	theme.set_stylebox("panel", "HudHousing", housing())
	theme.set_type_variation("HudStrip", "PanelContainer")
	theme.set_stylebox("panel", "HudStrip", strip())
	theme.set_type_variation("HudCard", "PanelContainer")
	theme.set_stylebox("panel", "HudCard", card())
	theme.set_type_variation("HudSocket", "PanelContainer")
	theme.set_stylebox("panel", "HudSocket", socket())
	theme.set_type_variation("HudNameplate", "PanelContainer")
	theme.set_stylebox("panel", "HudNameplate", nameplate())
	theme.set_stylebox("panel", "PopupMenu", card(12, 10))
	theme.set_stylebox("hover", "PopupMenu", glow(.6))
	theme.set_color("font_separator_color", "PopupMenu", MUTED)
	theme.set_font("font", "PopupMenu", display_font())
	theme.set_stylebox("panel", "TooltipPanel", card(14, 10))
	theme.set_color("font_color", "TooltipLabel", IVORY)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	# Label variations: engraved headings and large tabular readouts.
	theme.set_type_variation("HudHeading", "Label")
	theme.set_font("font", "HudHeading", heading_font())
	theme.set_font_size("font_size", "HudHeading", 18)
	theme.set_color("font_color", "HudHeading", accent())
	theme.set_type_variation("HudCaption", "Label")
	theme.set_font("font", "HudCaption", heading_font())
	theme.set_font_size("font_size", "HudCaption", 12)
	theme.set_color("font_color", "HudCaption", MUTED)
	theme.set_type_variation("HudNumeral", "Label")
	theme.set_font("font", "HudNumeral", numeral_font())
	theme.set_font_size("font_size", "HudNumeral", 24)
	theme.set_color("font_color", "HudNumeral", Color("f6ead0"))


static func _fields(theme: Theme):
	for type in ["LineEdit", "TextEdit", "CodeEdit", "ItemList"]:
		theme.set_stylebox("normal", type, socket(10, 6))
		var read_only = socket(10, 6)
		read_only.modulate = Color(.85, .85, .85)
		theme.set_stylebox("read_only", type, read_only)
		theme.set_stylebox("focus", type, focus())
		theme.set_color("font_readonly_color", type, MUTED)
		theme.set_color("font_placeholder_color", type, Color("7e8a87"))
		theme.set_color("caret_color", type, accent())
		theme.set_color("selection_color", type, Color("5a4a26"))
	theme.set_stylebox("panel", "ItemList", socket(8, 6))
	theme.set_stylebox("selected", "ItemList", glow(.75))
	theme.set_stylebox("selected_focus", "ItemList", glow(.9))
	theme.set_stylebox("hovered", "ItemList", glow(.35))


static func _tabs(theme: Theme):
	theme.set_stylebox("panel", "TabContainer", card(12, 10))
	for type in ["TabContainer", "TabBar"]:
		var slices = Vector4(12, 10, 12, 4)
		var selected = kit("tab_selected", slices)
		_margins(selected, 16, 7, 6)
		theme.set_stylebox("tab_selected", type, selected)
		var unselected = kit("tab_unselected", slices)
		_margins(unselected, 16, 7, 6)
		theme.set_stylebox("tab_unselected", type, unselected)
		var hovered = kit("tab_hover", slices)
		_margins(hovered, 16, 7, 6)
		theme.set_stylebox("tab_hovered", type, hovered)
		theme.set_stylebox("tab_focus", type, focus())
		theme.set_font("font", type, display_font())
		theme.set_font_size("font_size", type, 16)
		theme.set_color("font_unselected_color", type, MUTED)
		theme.set_color("font_hovered_color", type, Color("e4dccb"))
		theme.set_color("font_selected_color", type, accent())
		theme.set_constant("side_margin", type, 4)


static func _chrome(theme: Theme):
	for type in ["HSeparator", "VSeparator"]:
		# An engraved seam: a dark cut above a faint lit edge.
		var line = StyleBoxLine.new()
		line.color = Color("0000008c")
		line.thickness = 2
		line.vertical = type == "VSeparator"
		theme.set_stylebox("separator", type, line)
		theme.set_constant("separation", type, 10)
	for type in ["HScrollBar", "VScrollBar"]:
		var track = surface(Color("0a0e10"), 4, 4)
		track.set_corner_radius_all(2)
		theme.set_stylebox("scroll", type, track)
		var grabber = surface(Color("4d5458"), 4, 4)
		grabber.set_corner_radius_all(2)
		grabber.border_width_top = 1
		grabber.border_color = Color("737b7e")
		theme.set_stylebox("grabber", type, grabber)
		var lit = grabber.duplicate()
		lit.bg_color = Color("8a7448")
		lit.border_color = Color("c9a560")
		theme.set_stylebox("grabber_highlight", type, lit)
		theme.set_stylebox("grabber_pressed", type, lit)
		theme.set_stylebox("scroll_focus", type, focus())
	theme.set_stylebox("background", "ProgressBar", bar_track())
	theme.set_stylebox("fill", "ProgressBar", bar_fill(accent()))
	theme.set_font("font", "ProgressBar", numeral_font())


# --- builders ------------------------------------------------------------------


static func heading(
	parent: Control, title: Label, height = 60, portrait: Texture2D = null
) -> Control:
	var header = HBoxContainer.new()
	header.name = "ArtworkHeader"
	header.custom_minimum_size.y = height
	header.add_theme_constant_override("separation", 14)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(header)
	var plate = PanelContainer.new()
	plate.name = "Nameplate"
	plate.add_theme_stylebox_override("panel", nameplate(12, 3))
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(plate)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.uppercase = true
	title.add_theme_font_override("font", heading_font())
	title.add_theme_color_override("font_color", accent())
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(title)
	if portrait != null:
		title.add_theme_color_override("font_color", IVORY)
		var frame = PanelContainer.new()
		frame.name = "Portrait"
		frame.custom_minimum_size = Vector2(104, 96)
		frame.add_theme_stylebox_override("panel", socket(6, 6))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(frame)
		var icon = TextureRect.new()
		icon.texture = portrait
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
	return header


static func artwork(parent: Control, width = 270):
	var frame = PanelContainer.new()
	frame.name = "Artwork"
	frame.custom_minimum_size.x = width
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", socket(4, 4))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var art = TextureRect.new()
	art.texture = load(Artwork.next_background())
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	return art


static func icon(name: String) -> Texture2D:
	return load(KIT + "icons/" + name + ".svg")
