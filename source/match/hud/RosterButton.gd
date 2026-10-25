extends Button

## A production or construction tile: the role's portrait in a recessed socket, its
## name, and its price as resource glyphs with numbers, so the tile reads the same in
## every language. The description, timing and availability live in the tooltip.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const MATERIALS_ICON = preload("res://assets/ui/economy/materials.svg")
const ELECTRONICS_ICON = preload("res://assets/ui/economy/electronics.svg")
const FALLBACK_ICON = preload("res://assets/ui/economy/units.svg")
const MATERIALS_TINT = Color("e3c48a")
const ELECTRONICS_TINT = Color("8fd3c6")
const InlineIcons = preload("res://source/match/hud/InlineIcons.gd")
const PORTRAIT_SIZE = 36.0

var _compact = false
var _icon_size = 64.0
var _badge: Label
var _body: HBoxContainer
var _portrait: TextureRect
var _title: Label
var _materials: Label
var _electronics: Label


func _init():
	theme_type_variation = "BattleCardButton"
	var margins = MarginContainer.new()
	margins.name = "Tile"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 6)
	add_child(margins, false, Node.INTERNAL_MODE_FRONT)
	_body = HBoxContainer.new()
	_body.minimum_size_changed.connect(_fit_contents)
	_body.add_theme_constant_override("separation", 7)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(_body)
	var socket = PanelContainer.new()
	socket.name = "Portrait"
	socket.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	socket.add_theme_stylebox_override("panel", BattleTheme.socket(2, 2))
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(socket)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket.add_child(_portrait)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(column)
	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_override("font", BattleTheme.display_font())
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_constant_override("line_spacing", -3)
	# Stable one-line names keep full mixed rosters inside the console. The full
	# name and description remain available in the tooltip at narrow UI sizes.
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.max_lines_visible = 1
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)
	var price = HBoxContainer.new()
	price.name = "Price"
	price.add_theme_constant_override("separation", 7)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(price)
	_materials = _price(price, MATERIALS_ICON, MATERIALS_TINT)
	_electronics = _price(price, ELECTRONICS_ICON, ELECTRONICS_TINT)


func _fit_contents():
	if _compact:
		custom_minimum_size = Vector2.ONE * _icon_size
		return
	# Button does not derive its minimum from the internal caption/price controls.
	# Include their wrapped height so two-line names cannot push prices off the tile.
	custom_minimum_size = Vector2(112, 56).max(_body.get_combined_minimum_size() + Vector2(12, 12))


## Picture-only console key. Names, costs and rules remain in its tooltip.
func compact_layout(side = 64.0):
	_compact = true
	_icon_size = side
	for edge in ["left", "top", "right", "bottom"]:
		get_node("Tile").add_theme_constant_override("margin_" + edge, 4)
	_body.get_node("Portrait").custom_minimum_size = Vector2.ONE * (side - 8)
	_body.get_node("Portrait").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.get_node("Portrait").size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title.get_parent().hide()
	_fit_contents()


func show_hotkey(value: String):
	if not is_instance_valid(_badge):
		_badge = Label.new()
		_badge.name = "Hotkey"
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge.add_theme_font_size_override("font_size", 11)
		_badge.add_theme_color_override("font_color", BattleTheme.IVORY)
		_badge.add_theme_constant_override("outline_size", 3)
		_badge.add_theme_color_override("font_outline_color", Color("070a0c"))
		_badge.position = Vector2(5, 1)
		add_child(_badge)
	_badge.text = value
	_badge.visible = not value.is_empty()


func _price(parent, texture, tint):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var glyph = TextureRect.new()
	glyph.texture = texture
	glyph.modulate = tint
	glyph.custom_minimum_size = Vector2(12, 12)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var amount = Label.new()
	amount.add_theme_font_override("font", BattleTheme.numeral_font())
	amount.add_theme_font_size_override("font_size", 13)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Numbers only: nothing to translate, and the price reads the same in every locale.
	amount.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(amount)
	return amount


## Shows the role's portrait, name and price. A missing portrait falls back to a
## neutral unit glyph instead of leaving the socket empty.
func show_role(portrait: Texture2D, title: String, cost: Dictionary):
	_portrait.texture = portrait if portrait != null else FALLBACK_ICON
	_portrait.modulate = Color.WHITE if portrait != null else BattleTheme.MUTED
	_title.text = title
	_materials.text = str(cost.get("resource_a", 0))
	_electronics.text = str(cost.get("resource_b", 0))
	# A free resource stays legible but recedes behind the one that is spent.
	_materials.get_parent().modulate.a = 1.0 if cost.get("resource_a", 0) > 0 else .5
	_electronics.get_parent().modulate.a = 1.0 if cost.get("resource_b", 0) > 0 else .5


func portrait() -> Texture2D:
	return null if _portrait.texture == FALLBACK_ICON else _portrait.texture


func title() -> String:
	return _title.text


func _draw():
	# Unavailable roles dim as a whole; the key face carries hover and press states.
	_body.modulate = Color(1, 1, 1, .45) if disabled else Color.WHITE


func _make_custom_tooltip(for_text):
	var panel = PanelContainer.new()
	panel.theme = BattleTheme.create()
	# The native tooltip window owns the frame and padding.
	panel.add_theme_stylebox_override("panel", BattleTheme.surface(Color.TRANSPARENT, 0, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("roster_tooltip", for_text)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var lines = for_text.split("\n")
	for index in 3:
		if index == 2:
			var details = InlineIcons.label(14)
			details.custom_minimum_size.x = minf(370, get_viewport_rect().size.x - 48)
			details.text = InlineIcons.price(int(_materials.text), int(_electronics.text))
			for line in lines.slice(3):
				details.text += "\n" + InlineIcons.escape(tr(line))
			details.accessibility_description = for_text
			box.add_child(details)
			continue
		if index == 1 and get_meta("armed", false):
			var description = InlineIcons.label(14)
			description.custom_minimum_size.x = minf(370, get_viewport_rect().size.x - 48)
			description.text = (
				InlineIcons.icon(InlineIcons.WEAPONS) + " " + InlineIcons.escape(tr(lines[1]))
			)
			description.accessibility_description = tr(lines[1])
			box.add_child(description)
			continue
		var label = Label.new()
		label.custom_minimum_size.x = minf(370, get_viewport_rect().size.x - 48)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16 if index == 0 else 14)
		label.add_theme_color_override(
			"font_color", Color("a9b4b3") if index == 1 else Color("eee8da")
		)
		label.text = lines[index] if index < 2 else "\n".join(lines.slice(2))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	return panel
