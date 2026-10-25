extends Control

var _phase := 0.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta):
	if not get_tree().paused and not Globals.options.reduced_flashes:
		_phase = fposmod(_phase + delta * .65, 1.0)
	queue_redraw()


func _draw():
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	_draw_rallies(camera)
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units") or unit.manual_orders == null:
			continue
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
			var start = camera.unproject_position(unit.action.origin)
			var end = camera.unproject_position(unit.action.endpoint)
			draw_dashed_line(start, end, Color(1, 1, 1, 0.65), 2, 7, true)
			draw_arc(start, 7, 0, TAU, 20, Color.WHITE, 1.5, true)
			draw_arc(end, 7, 0, TAU, 20, Color.WHITE, 1.5, true)
		var previous = camera.unproject_position(unit.global_position)
		for index in range(points.size()):
			var point = camera.unproject_position(points[index].point)
			var active = index == 0 and orders.current.has("point")
			var color = Color(1, 1, 1, 0.9 if active else 0.65)
			if active:
				draw_line(previous, point, color, 2, true)
			else:
				draw_dashed_line(previous, point, color, 1.5, 6, true)
			_route_pulse(previous, point, color)
			draw_circle(point, 9, Color("172330e8"))
			draw_string(
				ThemeDB.fallback_font,
				point + Vector2(-4, 4),
				str(index + 1),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				color
			)
			previous = point
		# Show a representative route, avoiding hundreds of overlapping group lines.
		break


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
		var direction = (destination - unit.global_position).normalized()
		var start = camera.unproject_position(unit.global_position + direction * unit.radius)
		var end = camera.unproject_position(destination)
		var ink = Color("17232a")
		var color = Color("f7d58a")
		# Screen-space strokes keep the order legible at every gameplay zoom.
		draw_line(start, end, Color(0.06, 0.09, 0.10, 0.6), 3.5, true)
		draw_dashed_line(start, end, color, 2.0, 9.0, true)
		_route_pulse(start, end, color)
		var forward = (end - start).normalized()
		var side = forward.orthogonal()
		if start.distance_to(end) > 40:
			var tip = end - forward * 13
			draw_colored_polygon(
				PackedVector2Array(
					[tip, tip - forward * 10 + side * 5, tip - forward * 10 - side * 5]
				),
				color
			)
		draw_circle(end, 4.0, ink)
		draw_circle(end, 2.0, color)
		draw_line(end, end + Vector2(0, -32), ink, 5, true)
		draw_line(end, end + Vector2(0, -32), Color("f6f0df"), 2, true)
		var flag = PackedVector2Array(
			[
				end + Vector2(2, -32),
				end + Vector2(23, -32),
				end + Vector2(17, -24),
				end + Vector2(23, -17),
				end + Vector2(2, -17)
			]
		)
		draw_colored_polygon(flag, color)


func _route_pulse(start: Vector2, end: Vector2, color: Color):
	if Globals.options.reduced_flashes or start.distance_to(end) < 32.0:
		return
	var direction := (end - start).normalized()
	var tip := start.lerp(end, _phase)
	color.a *= sin(_phase * PI) * .8
	draw_line(tip - direction * 9.0, tip, color, 3.0, true)
