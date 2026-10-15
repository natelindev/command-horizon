extends Button

## A console keycap: a centred glyph with an engraved hotkey badge in the corner
## and an optional caption underneath. The full action name and binding live in
## the tooltip and accessibility name, so the key itself can stay compact.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var glyph: Texture2D:
	set(value):
		glyph = value
		if is_instance_valid(_glyph):
			_glyph.texture = value
var badge := "":
	set(value):
		badge = value
		if is_instance_valid(_badge):
			_badge.text = short_key(value)
			_badge.visible = not value.is_empty()
		_layout_glyph()
var caption := "":
	set(value):
		caption = value
		if is_instance_valid(_caption):
			_caption.text = value
			_caption.visible = not value.is_empty()
		_layout_glyph()

var _glyph: TextureRect
var _badge: Label
var _caption: Label


func _init():
	theme_type_variation = "HudSlotButton"
	clip_text = true
	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph, false, Node.INTERNAL_MODE_FRONT)
	_badge = Label.new()
	_badge.name = "Badge"
	_badge.theme_type_variation = "HudCaption"
	_badge.add_theme_font_size_override("font_size", 10)
	_badge.add_theme_color_override("font_color", BattleTheme.accent())
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_badge.position = Vector2(5, 1)
	_badge.visible = false
	add_child(_badge, false, Node.INTERNAL_MODE_FRONT)
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.add_theme_font_override("font", BattleTheme.display_font())
	_caption.add_theme_font_size_override("font_size", 11)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	add_child(_caption, false, Node.INTERNAL_MODE_FRONT)


static func short_key(label: String) -> String:
	# Engraved badges are tiny: abbreviate long key names the way keycaps print them.
	var short = label
	for pair in [
		["Escape", "Esc"],
		["Space", "Spc"],
		["Backspace", "Bksp"],
		["Delete", "Del"],
		["Enter", "Ent"],
		["Ctrl+", "^"],
		["Shift+", "⇧"],
	]:
		short = short.replace(pair[0], pair[1])
	return short.to_upper()


func _ready():
	resized.connect(_layout_glyph.bind(0.0))
	_layout_glyph()


func _notification(what):
	if what in [NOTIFICATION_THEME_CHANGED, NOTIFICATION_ENTER_TREE]:
		_layout_glyph()


func _draw():
	# Keys dim with their state; the glyph follows the theme's icon colours and
	# sinks with the key face when pressed.
	var state = (
		{
			DRAW_DISABLED: "disabled",
			DRAW_PRESSED: "pressed",
			DRAW_HOVER_PRESSED: "pressed",
			DRAW_HOVER: "hover",
		}
		. get(get_draw_mode(), "normal")
	)
	_glyph.modulate = get_theme_color("icon_%s_color" % state)
	var faded = Color(1, 1, 1, .45) if state == "disabled" else Color.WHITE
	_caption.modulate = faded
	_badge.modulate = faded
	_layout_glyph(1.0 if state == "pressed" else 0.0)


func _layout_glyph(lift = 0.0):
	if not is_instance_valid(_glyph):
		return
	var style = get_theme_stylebox("normal")
	var top = style.content_margin_top if style != null else 4.0
	var bottom = style.content_margin_bottom if style != null else 6.0
	# The badge owns a slim row at the top; the glyph centres in what remains.
	var badge_row = 9.0 if _badge.visible else 0.0
	var caption_height = 14.0 if _caption.visible else 0.0
	var room = Vector2(size.x - 12, size.y - top - bottom - caption_height - badge_row)
	var side = clampf(minf(room.x, room.y), 12.0, 24.0)
	_glyph.size = Vector2(side, side)
	_glyph.position = Vector2(
		(size.x - side) / 2, top + badge_row + lift + maxf(0, (room.y - side) / 2)
	)
	_caption.position = Vector2(2, size.y - bottom - caption_height + lift)
	_caption.size = Vector2(size.x - 4, caption_height)
