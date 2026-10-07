extends Control


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta):
	queue_redraw()


func _draw():
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units") or unit.manual_orders == null:
			continue
		var orders = unit.manual_orders
		var points = []
		if orders.current.has("point"):
			points.append(orders.current)
		points.append_array(orders.pending)
		if points.is_empty():
			continue
		var previous = camera.unproject_position(unit.global_position)
		for index in range(points.size()):
			var point = camera.unproject_position(points[index].point)
			var active = index == 0 and orders.current.has("point")
			var color = Color(1, 1, 1, 0.9 if active else 0.65)
			if active:
				draw_line(previous, point, color, 2, true)
			else:
				draw_dashed_line(previous, point, color, 1.5, 6, true)
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
