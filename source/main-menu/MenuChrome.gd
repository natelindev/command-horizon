extends RefCounted

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")


class TacticalCrest:
	extends Control

	var accent: Color = Color("e8b04a")

	func _init(p_size = 48.0):
		custom_minimum_size = Vector2(p_size, p_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var c = size * 0.5
		var r = minf(size.x, size.y) * 0.45
		var rim_dark = Color(0.04, 0.06, 0.08, 0.92)
		var steel = Color(0.32, 0.38, 0.44, 0.92)
		var bright = Color(accent, 0.96)
		var glow = Color(accent, 0.24)
		# Shield backing disc + outer segmented orbital rings.
		draw_circle(c, r * 0.92, rim_dark)
		draw_arc(c, r, deg_to_rad(18), deg_to_rad(162), 32, Color(accent, 0.45), 1.6, true)
		draw_arc(c, r, deg_to_rad(198), deg_to_rad(342), 32, Color(accent, 0.45), 1.6, true)
		draw_arc(c, r * 0.80, 0.0, TAU, 36, steel, 2.0, true)
		draw_arc(c, r * 0.64, deg_to_rad(-165), deg_to_rad(-15), 24, bright, 2.0, true)
		# Subtle horizon core glow.
		draw_circle(c + Vector2(0, -r * 0.06), r * 0.34, glow)
		# Horizon baseline + sculpted rising chevron + center core diamond.
		draw_line(Vector2(c.x - r, c.y + r * 0.16), Vector2(c.x + r, c.y + r * 0.16), bright, 1.8)
		var wing_fill = PackedVector2Array(
			[
				Vector2(c.x - r * 0.54, c.y + r * 0.12),
				Vector2(c.x, c.y - r * 0.48),
				Vector2(c.x + r * 0.54, c.y + r * 0.12),
				Vector2(c.x, c.y - r * 0.18),
			]
		)
		draw_colored_polygon(wing_fill, Color("eef2f5"))
		var d = r * 0.17
		var diamond = PackedVector2Array(
			[
				Vector2(c.x, c.y - d),
				Vector2(c.x + d, c.y),
				Vector2(c.x, c.y + d),
				Vector2(c.x - d, c.y),
			]
		)
		draw_colored_polygon(diamond, bright)


class HorizonRule:
	extends Control

	var accent: Color = Color("e8b04a")

	func _init(p_height = 4.0):
		custom_minimum_size = Vector2(0, p_height)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var w = size.x
		var y = size.y * 0.5
		if w <= 0:
			return
		# Crisp leading accent bar tapering into a fine machined steel rail.
		var lead = minf(w * 0.34, 150.0)
		draw_line(Vector2(0, y), Vector2(lead, y), Color(accent, 0.95), 2.5, true)
		draw_line(
			Vector2(lead, y),
			Vector2(w * 0.85, y),
			Color(accent.lerp(Color("455360"), 0.72), 0.7),
			1.4,
			true
		)
		draw_line(Vector2(w * 0.85, y), Vector2(w, y), Color(0.25, 0.32, 0.38, 0.25), 1.0, true)
		draw_rect(Rect2(0, y - 2.0, 12.0, 4.0), Color(accent, 1.0))


static func stripe_bar(height = 4.0) -> Control:
	var rule = HorizonRule.new(height)
	rule.accent = ArtTheme.accent()
	return rule


static func brand_lockup(parent: Control, subtitle_text: String = "") -> Dictionary:
	var root_box = VBoxContainer.new()
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_theme_constant_override("separation", 6)
	parent.add_child(root_box)

	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	root_box.add_child(row)

	var crest = TacticalCrest.new(52.0)
	crest.accent = ArtTheme.accent()
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)

	var titles = VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_theme_constant_override("separation", 2)
	row.add_child(titles)

	var title = Label.new()
	title.text = "COMMAND HORIZON"
	title.add_theme_font_override("font", ArtTheme.heading_font())
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("f4f1ea"))
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.07, 0.9))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	titles.add_child(title)

	var sub_label: Label = null
	if not subtitle_text.is_empty():
		sub_label = Label.new()
		sub_label.text = subtitle_text
		sub_label.add_theme_font_override("font", ArtTheme.display_font())
		sub_label.add_theme_font_size_override("font_size", 12)
		sub_label.add_theme_color_override(
			"font_color", ArtTheme.accent().lerp(ArtTheme.IVORY, 0.35)
		)
		sub_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		sub_label.add_theme_constant_override("shadow_offset_y", 1)
		titles.add_child(sub_label)

	var stripe = HorizonRule.new(4.0)
	stripe.accent = ArtTheme.accent()
	root_box.add_child(stripe)
	return {
		"root": root_box, "crest": crest, "title": title, "subtitle": sub_label, "stripe": stripe
	}


static func screen_header(
	parent: Control, title_text: String, subtitle_text: String = "", right_control: Control = null
) -> Dictionary:
	var header_plate = PanelContainer.new()
	header_plate.theme_type_variation = "HudStrip"
	header_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var strip_style = ArtTheme.Console.strip(16, 6)
	strip_style.content_margin_bottom = 6
	header_plate.add_theme_stylebox_override("panel", strip_style)
	parent.add_child(header_plate)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	header_plate.add_child(outer)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	outer.add_child(row)

	var crest = TacticalCrest.new(30.0)
	crest.accent = ArtTheme.accent()
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)

	var name_col = VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 0)
	row.add_child(name_col)

	var title = Label.new()
	title.text = title_text
	title.add_theme_font_override("font", ArtTheme.heading_font())
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ArtTheme.IVORY)
	name_col.add_child(title)

	var sub: Label = null
	if not subtitle_text.is_empty():
		sub = Label.new()
		sub.text = subtitle_text
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", ArtTheme.MUTED)
		name_col.add_child(sub)

	if right_control != null:
		right_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right_control)

	var stripe = HorizonRule.new(3.0)
	stripe.accent = ArtTheme.accent()
	outer.add_child(stripe)
	return {
		"plate": header_plate, "crest": crest, "title": title, "subtitle": sub, "stripe": stripe
	}


static func sync_header_accent(header: Dictionary, accent_col: Color):
	if header.has("crest") and is_instance_valid(header.crest):
		header.crest.accent = accent_col
		header.crest.queue_redraw()
	if header.has("stripe") and is_instance_valid(header.stripe):
		header.stripe.accent = accent_col
		header.stripe.queue_redraw()


static func nameplate_heading(parent: Control, text_value: String) -> PanelContainer:
	var plate = PanelContainer.new()
	plate.theme_type_variation = "HudNameplate"
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(plate)
	var label = Label.new()
	label.text = text_value
	label.uppercase = true
	label.add_theme_font_override("font", ArtTheme.heading_font())
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ArtTheme.accent())
	plate.add_child(label)
	return plate


static func animate_entrance(node: Control, _offset_y: float = 10.0, duration: float = 0.20):
	if not Globals.options.menu_motion:
		return
	node.modulate.a = 0.0
	var tween = node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration)
