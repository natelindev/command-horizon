extends Control

var map_size = Vector2(64, 64)
var starts = []
var deposits = []
var rocks = []
var ridge_radius = 0.0
var relays = []
var roads = []
var buildings = []
var land = []


func set_map(path):
	starts.clear()
	deposits.clear()
	rocks.clear()
	relays.clear()
	roads.clear()
	buildings.clear()
	land.clear()
	ridge_radius = 0.0
	var scene = load(path).instantiate()
	map_size = Vector2(scene.size)
	var markers = scene.find_child("SpawnPoints").get_children()
	starts = [markers[0].position, markers[markers.size() / 2].position]
	if scene.has_method("overview"):
		var overview = scene.overview()
		deposits = overview.fields.duplicate()
		rocks = overview.ridges.duplicate()
		relays = overview.relays.duplicate()
		ridge_radius = overview.radius
		roads = overview.get("roads", []).duplicate()
		buildings = overview.get("buildings", []).duplicate()
		land = overview.get("land", []).duplicate()
	elif "BastionDesert" in path:
		for anchor in [Vector2(9, 26), Vector2(54, 38), Vector2(30, 17), Vector2(34, 48)]:
			deposits.append(anchor)
		rocks = [
			Vector2(27, 30),
			Vector2(37, 35),
			Vector2(6, 43),
			Vector2(55, 20),
			Vector2(32, 5),
			Vector2(31, 60)
		]
	else:
		for resource in scene.find_child("Resources").get_children():
			deposits.append(Vector2(resource.position.x, resource.position.z))
	scene.free()
	queue_redraw()


func _draw():
	var side = min(size.x, size.y) - 24
	var extent = map_size / maxf(map_size.x, map_size.y) * side
	var origin = (size - extent) / 2
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	if not land.is_empty():
		draw_rect(Rect2(origin, extent), Color("255b72"))
		var polygon = PackedVector2Array()
		for point in land:
			polygon.append(origin + point / map_size * extent)
		draw_colored_polygon(polygon, Color("344648"))
	for index in range(9):
		var offset = extent * index / 8.0
		draw_line(
			origin + Vector2(offset.x, 0), origin + Vector2(offset.x, extent.y), Color("293b47")
		)
		draw_line(
			origin + Vector2(0, offset.y), origin + Vector2(extent.x, offset.y), Color("293b47")
		)
	for road in roads:
		draw_line(
			origin + Vector2(road.x, road.y) / map_size * extent,
			origin + Vector2(road.z, road.w) / map_size * extent,
			Color("3f535c"),
			8.0 / map_size.x * extent.x
		)
	for building in buildings:
		draw_rect(
			Rect2(
				origin + building.position / map_size * extent, building.size / map_size * extent
			),
			Color("879493")
		)
	for rock in rocks:
		draw_circle(
			origin + rock / map_size * extent,
			ridge_radius / map_size.x * extent.x if ridge_radius > 0 else 11,
			Color("7e969f")
		)
	for relay in relays:
		var point = origin + relay / map_size * extent
		draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color("d4e2e4"))
	for deposit in deposits:
		draw_circle(origin + deposit / map_size * extent, 3, Color("b4c6ad"))
	for index in range(starts.size()):
		var point = origin + Vector2(starts[index].x, starts[index].z) / map_size * extent
		draw_circle(point, 11, Color("e0ad46") if index == 0 else Color("dd7169"))
		draw_string(
			ThemeDB.fallback_font,
			point + Vector2(-4, 5),
			str(index + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("101b25")
		)


func _background():
	var box = StyleBoxFlat.new()
	box.bg_color = Color("15232f")
	box.set_corner_radius_all(10)
	return box
