extends Node2D

var map
var pixel_scale = 2.0
var _elapsed = 0.0


func _process(delta):
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		queue_redraw()


func _draw():
	if not is_instance_valid(map):
		return
	var layout = map.overview()
	if layout.has("land"):
		draw_rect(Rect2(Vector2.ZERO, map.size * pixel_scale), Color("255b72"))
		var polygon = PackedVector2Array()
		for point in layout.land:
			polygon.append(point * pixel_scale)
		draw_colored_polygon(polygon, Color("344648"))
	for road in layout.get("roads", []):
		draw_line(
			Vector2(road.x, road.y) * pixel_scale,
			Vector2(road.z, road.w) * pixel_scale,
			Color("3f5058"),
			layout.get("road_width", 8.0) * pixel_scale
		)
	for building in layout.get("buildings", []):
		draw_rect(
			Rect2(building.position * pixel_scale, building.size * pixel_scale), Color("879493")
		)
	for point in layout.ridges:
		draw_circle(point * pixel_scale, layout.radius * pixel_scale, Color("657c89"))
	for index in layout.relays.size():
		var point = layout.relays[index] * pixel_scale
		var color = Color("dae3e3")
		if map.relays[index].captured_by != null:
			color = map.relays[index].captured_by.color
		draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), color)
	if "points_of_interest" in map:
		for site in map.points_of_interest:
			var point = Vector2(site.position.x, site.position.z) * pixel_scale
			var color = Color("dae3e3") if site.player == null else site.player.color
			draw_circle(point, 4, color)
			var glyph = {
				"refinery": tr("R", "map_refinery"),
				"mercenary": tr("M", "map_mercenary"),
				"repair": "+"
			}[site.kind]
			draw_string(
				load("res://assets/fonts/NotoSansSC.ttf"),
				point + Vector2(5, 4),
				glyph,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				color
			)
