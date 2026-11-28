extends Control

const ThemeKit = preload("res://source/match/hud/BattleTheme.gd")
const FACTION_PALETTE = {
	"bastion":
	{
		"move": Color("f2be54"),
		"attack": Color("ff5c42"),
		"utility": Color("76d4be"),
		"rally": Color("f5c55a"),
		"hi": Color("fff4d1"),
		"ink": Color("0e161ee6"),
	},
	"helix":
	{
		"move": Color("5ce8fa"),
		"attack": Color("ff4f8b"),
		"utility": Color("68f0c8"),
		"rally": Color("6ef2ff"),
		"hi": Color("ecfeff"),
		"ink": Color("07151fe6"),
	},
	"frontier":
	{
		"move": Color("ff9238"),
		"attack": Color("ff4726"),
		"utility": Color("a6d65e"),
		"rally": Color("ff9c3b"),
		"hi": Color("ffeed8"),
		"ink": Color("17120de6"),
	},
}

var _phase := 0.0
var _preparing := false


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta):
	if not get_tree().paused and not Globals.options.reduced_flashes:
		_phase = fposmod(_phase + delta * .72, 1.0)
	queue_redraw()


func prepare_for_loading():
	_preparing = true
	_phase = .5


func _palette_for(faction: String) -> Dictionary:
	return FACTION_PALETTE.get(faction, FACTION_PALETTE["bastion"])


func _order_color(kind: String, faction: String, active: bool) -> Color:
	var pal = _palette_for(faction)
	var base: Color = pal.move
	if kind in ["attack", "attack_move", "force_attack"]:
		base = pal.attack
	elif kind in ["gather", "scavenge", "repair", "recover", "construct", "garrison", "guard"]:
		base = pal.utility
	base.a = 0.94 if active else 0.72
	return base


func _draw():
	if _preparing:
		# Draw the same immediate/deferred route primitives behind Loading,
		# without manufacturing a live unit order or changing selection.
		_draw_segment(Vector2(8, 8), Vector2(80, 8), 0, true, "move", "bastion")
		_draw_segment(Vector2(8, 32), Vector2(80, 32), 1, false, "attack_move", "helix")
		return
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	_draw_rallies(camera)
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units") or unit.manual_orders == null:
			continue
		var faction = unit.player.faction if is_instance_valid(unit.player) else "bastion"
		var orders = unit.manual_orders
		var points = []
		if orders.current.has("point"):
			var current = orders.current
			if (
				current.kind == "patrol"
				and is_instance_valid(unit.action)
				and "origin" in unit.action
			):
				current = current.duplicate()
				current.point = unit.action.destination
			points.append(current)
		points.append_array(orders.pending)
		if points.is_empty():
			continue
		if (
			orders.current.get("kind") == "patrol"
			and is_instance_valid(unit.action)
			and "origin" in unit.action
		):
			var pal = _palette_for(faction)
			var start = camera.unproject_position(unit.action.origin)
			var end = camera.unproject_position(unit.action.endpoint)
			draw_line(start, end, Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.55), 4.0, true)
			draw_dashed_line(start, end, Color(pal.move, 0.78), 2.0, 8.0, true)
			_draw_waypoint_badge(start, faction, pal.move, pal.ink, "")
			_draw_waypoint_badge(end, faction, pal.move, pal.ink, "")
		var previous = camera.unproject_position(unit.global_position)
		for index in range(points.size()):
			var entry = points[index]
			var point = camera.unproject_position(entry.point)
			var active = index == 0 and orders.current.has("point")
			_draw_segment(previous, point, index, active, entry.get("kind", "move"), faction)
			previous = point
		# Show a representative route, avoiding hundreds of overlapping group lines.
		break


func _draw_segment(
	previous: Vector2,
	point: Vector2,
	index: int,
	active: bool,
	kind: String = "move",
	faction: String = "bastion"
):
	var pal = _palette_for(faction)
	var color = _order_color(kind, faction, active)
	var ink = Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.62 if active else 0.42)
	draw_line(previous, point, ink, 4.2 if active else 3.2, true)
	if active:
		draw_line(previous, point, color, 2.0, true)
	else:
		draw_dashed_line(previous, point, color, 1.8, 7.0, true)
	_route_pulse(previous, point, color, pal.hi, faction)
	_draw_waypoint_badge(point, faction, color, pal.ink, str(index + 1))


func _draw_waypoint_badge(center: Vector2, faction: String, rim: Color, ink: Color, label: String):
	var radius = 9.5
	if faction == "helix":
		var pts = PackedVector2Array(
			[
				center + Vector2(0, -radius - 1.5),
				center + Vector2(radius + 1.5, 0),
				center + Vector2(0, radius + 1.5),
				center + Vector2(-radius - 1.5, 0),
			]
		)
		draw_colored_polygon(pts, ink)
		pts.append(pts[0])
		draw_polyline(pts, rim, 1.6, true)
	elif faction == "frontier":
		draw_circle(center, radius, ink)
		draw_arc(center, radius, 0.25, PI - 0.25, 16, rim, 1.8, true)
		draw_arc(center, radius, PI + 0.25, TAU - 0.25, 16, rim, 1.8, true)
	else:
		var pts = PackedVector2Array()
		for i in 8:
			var a = PI * 0.125 + i * TAU / 8.0
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, ink)
		pts.append(pts[0])
		draw_polyline(pts, rim, 1.6, true)
	if not label.is_empty():
		var font = ThemeKit.numeral_font()
		var size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(
			font,
			center + Vector2(-size.x * 0.5, font.get_ascent(12) * 0.42),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			rim
		)


func _draw_rallies(camera):
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units"):
			continue
		var rally = unit.get_node_or_null("RallyPoint")
		if rally == null or not rally.is_assigned() or not rally.visible:
			continue
		var destination = rally.global_position
		if is_instance_valid(rally.target_unit):
			destination = rally.target_unit.global_position
		if (
			camera.is_position_behind(destination)
			or camera.is_position_behind(unit.global_position)
		):
			continue
		var faction = unit.player.faction if is_instance_valid(unit.player) else "bastion"
		var pal = _palette_for(faction)
		var color: Color = pal.rally
		var hi: Color = pal.hi
		var ink: Color = pal.ink
		var direction = (destination - unit.global_position).normalized()
		var start = camera.unproject_position(unit.global_position + direction * unit.radius)
		var end = camera.unproject_position(destination)

		# Screen-space high-contrast route tether with faction pulse.
		draw_line(start, end, Color(ink.r, ink.g, ink.b, 0.68), 4.2, true)
		if faction == "helix":
			draw_line(start, end, Color(color, 0.35), 2.8, true)
			draw_dashed_line(start, end, color, 1.7, 10.0, true)
		else:
			draw_dashed_line(start, end, color, 2.2, 9.0, true)
		_route_pulse(start, end, color, hi, faction)

		var forward = (end - start).normalized()
		var side = forward.orthogonal()
		if start.distance_to(end) > 42.0:
			var tip = end - forward * 15.0
			draw_colored_polygon(
				PackedVector2Array(
					[tip, tip - forward * 10.0 + side * 5.2, tip - forward * 10.0 - side * 5.2]
				),
				hi
			)

		match faction:
			"helix":
				_draw_helix_rally_beacon(end, color, hi, ink)
			"frontier":
				_draw_frontier_rally_beacon(end, color, hi, ink)
			_:
				_draw_bastion_rally_beacon(end, color, hi, ink)


func _draw_bastion_rally_beacon(end: Vector2, color: Color, hi: Color, ink: Color):
	# Armored command standard: octagonal anchor, bolted steel mast, notched banner.
	var anchor = PackedVector2Array()
	for i in 8:
		var a = PI * 0.125 + i * TAU / 8.0
		anchor.append(end + Vector2(cos(a) * 9.0, sin(a) * 4.5))
	draw_colored_polygon(anchor, ink)
	anchor.append(anchor[0])
	draw_polyline(anchor, color, 1.8, true)
	draw_circle(end, 2.6, hi)
	# Steel mast with dark silhouette
	draw_line(end, end + Vector2(0, -37), ink, 6.0, true)
	draw_line(end, end + Vector2(0, -36), Color("d5dde4"), 2.4, true)
	draw_circle(end + Vector2(0, -37), 3.2, ink)
	draw_circle(end + Vector2(0, -37), 1.9, hi)
	# Notched tactical banner with dark trim + crisp chevron emblem
	var flag_bg = PackedVector2Array(
		[
			end + Vector2(1.5, -36),
			end + Vector2(27, -36),
			end + Vector2(21, -27.5),
			end + Vector2(27, -19),
			end + Vector2(1.5, -19),
		]
	)
	draw_colored_polygon(flag_bg, ink)
	var flag = PackedVector2Array(
		[
			end + Vector2(3, -34.5),
			end + Vector2(24.5, -34.5),
			end + Vector2(19, -27.5),
			end + Vector2(24.5, -20.5),
			end + Vector2(3, -20.5),
		]
	)
	draw_colored_polygon(flag, color)
	draw_polyline(
		PackedVector2Array(
			[end + Vector2(7, -31.5), end + Vector2(12.5, -27.5), end + Vector2(7, -23.5)]
		),
		ink,
		2.2,
		true
	)


func _draw_helix_rally_beacon(end: Vector2, color: Color, hi: Color, ink: Color):
	# Floating holographic crystalline prism beacon hovering over a luminous energy emitter.
	var bob = 0.0 if Globals.options.reduced_flashes else sin(_phase * TAU) * 3.0
	# Ground phase ellipse
	var ring_pts = PackedVector2Array()
	for i in 12:
		var a = i * TAU / 12.0
		ring_pts.append(end + Vector2(cos(a) * 10.5, sin(a) * 5.0))
	ring_pts.append(ring_pts[0])
	draw_polyline(ring_pts, ink, 3.6, true)
	draw_polyline(ring_pts, color, 1.7, true)
	draw_circle(end, 2.5, hi)
	# Energy tether spire
	draw_line(end, end + Vector2(0, -24 + bob), Color(color, 0.38), 5.0, true)
	draw_line(end, end + Vector2(0, -24 + bob), hi, 1.5, true)
	# Hovering crystalline diamond prism
	var c = end + Vector2(0, -33 + bob)
	var outer = PackedVector2Array(
		[c + Vector2(0, -11), c + Vector2(9, 0), c + Vector2(0, 11), c + Vector2(-9, 0)]
	)
	draw_colored_polygon(outer, ink)
	var inner = PackedVector2Array(
		[c + Vector2(0, -8.5), c + Vector2(6.8, 0), c + Vector2(0, 8.5), c + Vector2(-6.8, 0)]
	)
	draw_colored_polygon(inner, color)
	var core = PackedVector2Array(
		[c + Vector2(0, -4.5), c + Vector2(3.4, 0), c + Vector2(0, 4.5), c + Vector2(-3.4, 0)]
	)
	draw_colored_polygon(core, hi)
	# Delicate orbiting wing brackets
	draw_polyline(
		PackedVector2Array([c + Vector2(-12, -4), c + Vector2(-15, 0), c + Vector2(-12, 4)]),
		hi,
		1.5,
		true
	)
	draw_polyline(
		PackedVector2Array([c + Vector2(12, -4), c + Vector2(15, 0), c + Vector2(12, 4)]),
		hi,
		1.5,
		true
	)


func _draw_frontier_rally_beacon(end: Vector2, color: Color, hi: Color, ink: Color):
	# Rugged field-flare triangular signal pennant with bolted anchor cross & hazard mast.
	draw_circle(end, 6.5, ink)
	draw_arc(end, 6.5, 0, TAU, 16, color, 1.8, true)
	draw_line(end + Vector2(-10, 0), end + Vector2(10, 0), color, 1.4, true)
	draw_circle(end, 2.2, hi)
	# Heavy field mast
	draw_line(end, end + Vector2(0, -36), ink, 6.0, true)
	draw_line(end, end + Vector2(0, -35), Color("e6d4be"), 2.4, true)
	# Diagonal hazard stripes on mast
	for y in [-10, -18, -26]:
		draw_line(end + Vector2(-2.2, y), end + Vector2(2.2, y - 2.5), color, 1.6, true)
	# Bold triangular field pennant with stenciled stripe
	var pen_bg = PackedVector2Array(
		[end + Vector2(1.5, -36), end + Vector2(28, -27.5), end + Vector2(1.5, -19)]
	)
	draw_colored_polygon(pen_bg, ink)
	var pen = PackedVector2Array(
		[end + Vector2(3, -34), end + Vector2(24.5, -27.5), end + Vector2(3, -21)]
	)
	draw_colored_polygon(pen, color)
	draw_line(end + Vector2(6.5, -32.2), end + Vector2(6.5, -22.8), hi, 2.2, true)


func _route_pulse(start: Vector2, end: Vector2, color: Color, hi: Color, faction: String):
	if Globals.options.reduced_flashes or start.distance_to(end) < 32.0:
		return
	var direction := (end - start).normalized()
	var side := direction.orthogonal()
	var tip := start.lerp(end, _phase)
	var fade := sin(_phase * PI)
	if faction == "helix":
		var glow = Color(hi, fade * 0.9)
		draw_line(tip - direction * 13.0, tip, Color(color, fade * 0.65), 4.0, true)
		draw_circle(tip, 3.0, glow)
	else:
		var chevron_c = Color(hi, fade * 0.92)
		draw_polyline(
			PackedVector2Array(
				[tip - direction * 6.5 + side * 4.2, tip, tip - direction * 6.5 - side * 4.2]
			),
			chevron_c,
			2.2,
			true
		)
