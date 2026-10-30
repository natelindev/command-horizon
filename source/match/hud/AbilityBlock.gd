# gdlint: disable=max-returns
extends Button

## A modular ability block displayed in the dynamic ability tray.
## Represents a commander support power, faction signature, or active unit ability.
## Features an action glyph, engraved hotkey badge, cost readout, and cooldown overlay.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var ability_id: String = ""
var kind: String = ""  # "commander", "signature", "unit", "hero"
var action: Callable = Callable()

var _glyph: TextureRect
var _badge: Label
var _cost: Label
var _cooldown_overlay: ColorRect
var _cooldown_label: Label
var _highlight: Panel


func _init():
	theme_type_variation = "HudSlotButton"
	clip_text = true
	custom_minimum_size = Vector2(50, 44)
	focus_mode = Control.FOCUS_NONE

	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph, false, Node.INTERNAL_MODE_FRONT)

	_badge = Label.new()
	_badge.name = "HotkeyBadge"
	_badge.theme_type_variation = "HudCaption"
	_badge.add_theme_font_override("font", BattleTheme.display_font())
	_badge.add_theme_font_size_override("font_size", 10)
	_badge.add_theme_color_override("font_color", BattleTheme.accent())
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_badge.position = Vector2(4, 2)
	add_child(_badge, false, Node.INTERNAL_MODE_FRONT)

	_cost = Label.new()
	_cost.name = "CostBadge"
	_cost.theme_type_variation = "HudCaption"
	_cost.add_theme_font_override("font", BattleTheme.display_font())
	_cost.add_theme_font_size_override("font_size", 9)
	_cost.add_theme_color_override("font_color", BattleTheme.MUTED)
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cost.position = Vector2(10, 28)
	_cost.size = Vector2(36, 14)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_cost, false, Node.INTERNAL_MODE_FRONT)

	_cooldown_overlay = ColorRect.new()
	_cooldown_overlay.name = "CooldownOverlay"
	_cooldown_overlay.color = Color(0, 0, 0, 0.7)
	_cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_overlay.visible = false
	add_child(_cooldown_overlay, false, Node.INTERNAL_MODE_FRONT)

	_cooldown_label = Label.new()
	_cooldown_label.name = "CooldownLabel"
	_cooldown_label.add_theme_font_override("font", BattleTheme.numeral_font())
	_cooldown_label.add_theme_font_size_override("font_size", 12)
	_cooldown_label.add_theme_color_override("font_color", BattleTheme.IVORY)
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_overlay.add_child(_cooldown_label)

	pressed.connect(_on_pressed)
	resized.connect(_layout_components)


func _ready():
	_layout_components()


func _layout_components():
	if not is_instance_valid(_glyph):
		return
	var style = get_theme_stylebox("normal")
	var top = style.content_margin_top if style != null else 4.0
	var bottom = style.content_margin_bottom if style != null else 6.0
	var room = Vector2(size.x - 12, size.y - top - bottom)
	var side = clampf(minf(room.x, room.y), 16.0, 24.0)
	_glyph.size = Vector2(side, side)
	_glyph.position = Vector2((size.x - side) / 2.0, (size.y - side) / 2.0 + 1.0)
	_cost.position = Vector2(2, size.y - 15)
	_cost.size = Vector2(size.x - 6, 13)


func update_data(data: Dictionary):
	ability_id = data.get("id", "")
	kind = data.get("kind", "unit")
	action = data.get("action", Callable())

	var glyph_texture = data.get("glyph")
	if glyph_texture is Texture2D:
		_glyph.texture = glyph_texture

	var hotkey = data.get("hotkey", "")
	_badge.text = hotkey
	_badge.visible = not hotkey.is_empty()

	var cost_text = data.get("cost_text", "")
	_cost.text = cost_text
	_cost.visible = not cost_text.is_empty()

	var is_armed = bool(data.get("is_armed", false))
	var is_active = bool(data.get("is_active", false))
	var is_ready = bool(data.get("is_ready", true))
	var cooldown_left = float(data.get("cooldown_left", 0.0))

	# Cooldown presentation
	if cooldown_left > 0.0:
		_cooldown_overlay.visible = true
		_cooldown_label.text = (
			"%.1fs" % cooldown_left if cooldown_left < 10.0 else "%.0fs" % cooldown_left
		)
		disabled = true
	else:
		_cooldown_overlay.visible = false
		_cooldown_label.text = ""
		disabled = not is_ready

	set_pressed_no_signal(is_armed or is_active)
	if is_active or is_armed:
		_glyph.modulate = BattleTheme.accent()
	elif disabled:
		_glyph.modulate = Color(1, 1, 1, 0.4)
	else:
		_glyph.modulate = Color.WHITE

	# Tooltip and accessibility
	var title = data.get("name", "")
	var description = data.get("description", "")
	var issue = data.get("issue", "")
	var tooltip_lines = []
	if not hotkey.is_empty():
		tooltip_lines.append("%s [%s]" % [tr(title), hotkey])
	else:
		tooltip_lines.append(tr(title))

	if not cost_text.is_empty():
		tooltip_lines.append(cost_text)

	if not description.is_empty():
		tooltip_lines.append(tr(description))

	var extra = data.get("extra", "")
	if not extra.is_empty():
		tooltip_lines.append(extra)

	if not is_ready and not issue.is_empty():
		tooltip_lines.append(tr(issue))
	elif is_active:
		tooltip_lines.append(tr("Active"))
	elif is_armed:
		tooltip_lines.append(tr("Armed · Select target on map"))

	tooltip_text = "\n".join(tooltip_lines)
	accessibility_name = tr(title) + (" [%s]" % hotkey if not hotkey.is_empty() else "")
	accessibility_description = tooltip_text


func _on_pressed():
	if action.is_valid():
		action.call()
