extends Node2D

var map
var pixel_scale = 2.0
# Once the rendered terrain is available, ground, water, roads and ridges come from it
# and only tactical features are drawn.
var terrain
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
	if not (is_instance_valid(terrain) and terrain.is_captured):
		_draw_ground(layout)
	_draw_operations()
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
				"repair": tr("S", "map_repair")
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


func _draw_ground(layout):
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


func _draw_operations():
	var game = map.find_parent("Match")
	if game == null:
		return
	if game.commander_support != null:
		for record in game.commander_support.pending:
			var point = Vector2(record.point.x, record.point.z) * pixel_scale
			draw_circle(
				point,
				game.commander_support.RADII[record.kind] * pixel_scale,
				Color(1, .48, .2, .45)
			)
	var events = game.battlefield_events
	if events == null:
		return
	var player = game._get_human_player()
	if events.has_method("minimap_markers"):
		for marker in events.minimap_markers(player):
			var point = Vector2(marker.point.x, marker.point.z) * pixel_scale
			draw_colored_polygon(
				PackedVector2Array(
					[
						point + Vector2(0, -5),
						point + Vector2(5, 0),
						point + Vector2(0, 5),
						point + Vector2(-5, 0)
					]
				),
				Color("e3c48a")
			)
	if events.has_method("radar_blips"):
		for location in events.radar_blips(player):
			var point = Vector2(location.x, location.z) * pixel_scale
			draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color("eecf91"))
