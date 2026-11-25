extends RefCounted

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")


class TacticalCrest:
	extends Control

	var accent: Color = Color("e8b04a")

	func _init(p_size = 44.0):
		custom_minimum_size = Vector2(p_size, p_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var c = size * 0.5
		var r = minf(size.x, size.y) * 0.44
		var dim = Color(accent, 0.34)
		var bright = Color(accent, 0.92)
		# Outer tactical ring with open cardinal notches.
		draw_arc(c, r, deg_to_rad(20), deg_to_rad(160), 28, dim, 1.5, true)
		draw_arc(c, r, deg_to_rad(200), deg_to_rad(340), 28, dim, 1.5, true)
		# Inner horizon arc.
		draw_arc(c, r * 0.66, deg_to_rad(-165), deg_to_rad(-15), 24, bright, 1.8, true)
		# Horizon baseline + rising chevron + center core diamond.
		draw_line(Vector2(c.x - r, c.y + r * 0.16), Vector2(c.x + r, c.y + r * 0.16), bright, 1.6)
		var wing = PackedVector2Array(
			[
				Vector2(c.x - r * 0.48, c.y + r * 0.08),
				Vector2(c.x, c.y - r * 0.42),
				Vector2(c.x + r * 0.48, c.y + r * 0.08),
			]
		)
		draw_polyline(wing, Color("f1eee4"), 2.0, true)
		var d = r * 0.16
		var diamond = PackedVector2Array(
			[
				Vector2(c.x, c.y - d),
				Vector2(c.x + d, c.y),
				Vector2(c.x, c.y + d),
				Vector2(c.x - d, c.y),
			]
		)
		draw_colored_polygon(diamond, bright)


static func stripe_bar(height = 4.0) -> Panel:
	var bar = Panel.new()
	bar.custom_minimum_size.y = height
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", ArtTheme.stripe())
	return bar


static func brand_lockup(parent: Control, subtitle_text: String = "") -> Dictionary:
	var root_box = VBoxContainer.new()
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_theme_constant_override("separation", 6)
	parent.add_child(root_box)

	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	root_box.add_child(row)

	var crest = TacticalCrest.new(44.0)
	crest.accent = ArtTheme.accent()
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)

	var titles = VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_theme_constant_override("separation", 1)
	row.add_child(titles)

	var title = Label.new()
	title.text = "COMMAND HORIZON"
	title.add_theme_font_override("font", ArtTheme.heading_font())
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ArtTheme.IVORY)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	titles.add_child(title)

	var sub_label: Label = null
	if not subtitle_text.is_empty():
		sub_label = Label.new()
		sub_label.text = subtitle_text
		sub_label.add_theme_font_override("font", ArtTheme.display_font())
		sub_label.add_theme_font_size_override("font_size", 13)
		sub_label.add_theme_color_override("font_color", ArtTheme.accent().lerp(ArtTheme.IVORY, 0.35))
		titles.add_child(sub_label)

	var stripe = stripe_bar(4.0)
	root_box.add_child(stripe)
	return {"root": root_box, "crest": crest, "title": title, "subtitle": sub_label, "stripe": stripe}


static func screen_header(
	parent: Control, title_text: String, subtitle_text: String = "", right_control: Control = null
) -> Dictionary:
	var header_plate = PanelContainer.new()
	header_plate.theme_type_variation = "HudStrip"
	header_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header_plate)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	header_plate.add_child(outer)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	outer.add_child(row)

	var crest = TacticalCrest.new(32.0)
	crest.accent = ArtTheme.accent()
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)

	var name_col = VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 1)
	row.add_child(name_col)

	var title = Label.new()
	title.text = title_text
	title.add_theme_font_override("font", ArtTheme.heading_font())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ArtTheme.IVORY)
	name_col.add_child(title)

	var sub: Label = null
	if not subtitle_text.is_empty():
		sub = Label.new()
		sub.text = subtitle_text
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", ArtTheme.MUTED)
		name_col.add_child(sub)

	if right_control != null:
		right_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right_control)

	var stripe = stripe_bar(3.0)
	outer.add_child(stripe)
	return {"plate": header_plate, "crest": crest, "title": title, "subtitle": sub, "stripe": stripe}


static func nameplate_heading(parent: Control, text_value: String) -> PanelContainer:
	var plate = PanelContainer.new()
	plate.theme_type_variation = "HudNameplate"
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(plate)
	var label = Label.new()
	label.text = text_value
	label.uppercase = true
	label.add_theme_font_override("font", ArtTheme.heading_font())
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", ArtTheme.accent())
	plate.add_child(label)
	return plate


static func animate_entrance(node: Control, _offset_y: float = 10.0, duration: float = 0.20):
	if not Globals.options.menu_motion:
		return
	node.modulate.a = 0.0
	var tween = node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration)
