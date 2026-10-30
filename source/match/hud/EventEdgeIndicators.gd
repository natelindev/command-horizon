# gdlint: disable=max-returns
extends Control

## Displays edge pointers around the screen perimeter pointing towards active
## battlefield world events (e.g. supply aircraft, freight deliveries, radar terminals)
## when they are outside the current camera viewport.
## Clicking an edge indicator centers the camera directly on the target cargo.
## Indicators automatically expire and vanish when the cargo is claimed or expires.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const BattlefieldEvents = preload("res://source/match/world/BattlefieldEvents.gd")

var hud = null
var _indicators = {}


class EventPointerArrow:
	extends Control

	var angle: float = 0.0:
		set(value):
			if not is_equal_approx(angle, value):
				angle = value
				queue_redraw()

	func _draw():
		var c = size * 0.5
		var points = PackedVector2Array(
			[
				c + Vector2(6.0, 0.0).rotated(angle),
				c + Vector2(-4.0, -4.5).rotated(angle),
				c + Vector2(-1.5, 0.0).rotated(angle),
				c + Vector2(-4.0, 4.5).rotated(angle)
			]
		)
		draw_colored_polygon(points, Color("ffd152"))


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta):
	_update_indicators()


func _clear_all():
	for entry in _indicators.values():
		if is_instance_valid(entry.button):
			entry.button.queue_free()
	_indicators.clear()


func _update_indicators():
	if hud == null:
		return
	var game = hud.get_parent()
	if game == null or not is_instance_valid(game):
		_clear_all()
		return
	var events = game.battlefield_events
	if events == null or not is_instance_valid(events) or not "occurrences" in events:
		_clear_all()
		return

	var camera = get_viewport().get_camera_3d()
	if camera == null:
		_clear_all()
		return

	# Collect all currently active and available event cargos
	var active_cargos = {}
	for event in events.occurrences:
		if event.state != "active":
			continue
		var title = event.kind
		if BattlefieldEvents.TITLES.has(event.kind):
			title = BattlefieldEvents.TITLES[event.kind]
		var seconds = maxi(0, ceili(event.expires_at - game.simulation_time))
		for cargo in event.cargos:
			if cargo.status != "available":
				continue
			if not is_instance_valid(cargo.node) or cargo.node.consumed:
				continue
			active_cargos[cargo.id] = {
				"cargo": cargo, "event": event, "title": title, "seconds": seconds
			}

	# Clean up indicators for cargos that are claimed, expired, or cancelled
	for id in _indicators.keys():
		if not active_cargos.has(id):
			if is_instance_valid(_indicators[id].button):
				_indicators[id].button.queue_free()
			_indicators.erase(id)

	if active_cargos.is_empty():
		return

	var vp_size = get_viewport().get_visible_rect().size
	var pad_left = 40.0
	var pad_right = 40.0
	var pad_top = HudLayout.TOP_PLATE + 45.0
	var pad_bottom = HudLayout.CONSOLE_HEIGHT + 35.0

	var safe_bounds = Rect2(
		pad_left,
		pad_top,
		maxf(100.0, vp_size.x - pad_left - pad_right),
		maxf(100.0, vp_size.y - pad_top - pad_bottom)
	)

	for id in active_cargos:
		var info = active_cargos[id]
		var cargo = info.cargo
		if not _indicators.has(id):
			_indicators[id] = _create_indicator(cargo, info.event, info.title)

		var entry = _indicators[id]
		var world_pos = cargo.node.global_position if is_instance_valid(cargo.node) else cargo.point
		var is_behind = camera.is_position_behind(world_pos)
		var screen_pos = camera.unproject_position(world_pos)
		var in_view = not is_behind and safe_bounds.has_point(screen_pos)

		if in_view:
			entry.button.visible = false
			continue

		entry.button.visible = true

		var center = safe_bounds.position + safe_bounds.size * 0.5
		var dir = screen_pos - center
		if is_behind:
			dir = -dir
		if dir.is_zero_approx():
			dir = Vector2.UP

		var half = safe_bounds.size * 0.5
		var t_x = half.x / absf(dir.x) if absf(dir.x) > 0.0001 else 1e9
		var t_y = half.y / absf(dir.y) if absf(dir.y) > 0.0001 else 1e9
		var t = minf(t_x, t_y)
		var edge_pos = center + dir * t

		var btn_size = entry.button.size
		if btn_size == Vector2.ZERO:
			btn_size = entry.button.custom_minimum_size

		entry.button.position = Vector2(
			clampf(
				edge_pos.x - btn_size.x * 0.5,
				safe_bounds.position.x,
				safe_bounds.end.x - btn_size.x
			),
			clampf(
				edge_pos.y - btn_size.y * 0.5,
				safe_bounds.position.y,
				safe_bounds.end.y - btn_size.y
			)
		)

		entry.arrow.angle = dir.angle()

		var time_str = "%d:%02d" % [info.seconds / 60, info.seconds % 60]
		entry.label.text = "%s · %s" % [tr(info.title), time_str]
		entry.button.tooltip_text = tr("Jump to %s (%s)") % [tr(info.title), time_str]

	# Handle gentle stacking offset if multiple indicators overlap
	var visible_entries = _indicators.values().filter(func(e): return e.button.visible)
	for i in range(visible_entries.size()):
		for j in range(i + 1, visible_entries.size()):
			var b1 = visible_entries[i].button
			var b2 = visible_entries[j].button
			if b1.get_rect().intersects(b2.get_rect()):
				b2.position.y = clampf(
					b1.position.y + b1.size.y + 4.0,
					safe_bounds.position.y,
					safe_bounds.end.y - b2.size.y
				)


func _create_indicator(cargo, event, title) -> Dictionary:
	var button = Button.new()
	button.name = "EventEdgeIndicator_%s" % cargo.id
	button.custom_minimum_size = Vector2(164, 30)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.13, 0.16, 0.92)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.28, 0.35, 0.40, 0.7)
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	normal_style.content_margin_left = 6
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 3
	normal_style.content_margin_bottom = 3

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.16, 0.20, 0.25, 0.95)
	hover_style.border_color = Color(0.40, 0.48, 0.54, 0.85)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.08, 0.10, 0.12, 0.98)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 6
	hbox.offset_right = -6
	button.add_child(hbox)

	var arrow = EventPointerArrow.new()
	arrow.name = "Arrow"
	arrow.custom_minimum_size = Vector2(14, 14)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(arrow)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = BattleTheme.icon("sites" if event.kind == "alpine" else "cargo")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var label = Label.new()
	label.name = "Label"
	label.add_theme_font_override("font", BattleTheme.display_font())
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", BattleTheme.accent().lerp(BattleTheme.IVORY, 0.3))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = tr(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	hbox.add_child(label)

	var cargo_point = cargo.point
	button.pressed.connect(
		func():
			if hud != null:
				var game = hud.get_parent()
				if game != null and is_instance_valid(game) and "_camera" in game:
					if is_instance_valid(game._camera):
						game._camera.set_position_safely(cargo_point)
	)

	add_child(button)

	return {
		"button": button,
		"arrow": arrow,
		"icon": icon,
		"label": label,
		"cargo_id": cargo.id,
		"cargo_point": cargo.point
	}
