extends Control

const MAP_FONT = preload("res://assets/fonts/NotoSansSC.ttf")

var map_size = Vector2(64, 64)
var starts = []
var deposits = []
var rocks = []
var ridge_radius = 0.0
var relays = []
var points_of_interest = []
var roads = []
var road_width = 4.0
var buildings = []
var land = []
var _terrain: ImageTexture
var _biome = "desert"
var _terrain_cache = {}


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func set_map(path):
	starts.clear()
	deposits.clear()
	rocks.clear()
	relays.clear()
	points_of_interest.clear()
	roads.clear()
	buildings.clear()
	land.clear()
	ridge_radius = 0.0
	road_width = 4.0
	_biome = (
		"alpine"
		if "Alpine" in path
		else ("urban" if "Industrial" in path or "Coastal" in path else "desert")
	)
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
		road_width = overview.get("road_width", 4.0)
		buildings = overview.get("buildings", []).duplicate()
		land = overview.get("land", []).duplicate()
		points_of_interest = overview.get("points_of_interest", []).duplicate()
	else:
		for resource in scene.find_child("Resources").get_children():
			deposits.append(Vector2(resource.position.x, resource.position.z))
	scene.free()
	if not _terrain_cache.has(path):
		_make_terrain()
		_terrain_cache[path] = _terrain
	else:
		_terrain = _terrain_cache[path]
	queue_redraw()


func _make_terrain():
	var noise = FastNoiseLite.new()
	noise.seed = 481
	noise.frequency = .025
	var image = Image.create(384, 384, false, Image.FORMAT_RGB8)
	var low = Color("554f3e")
	var high = Color("89816a")
	if _biome == "alpine":
		low = Color("3e555b")
		high = Color("8c9c96")
	elif _biome == "urban":
		low = Color("354648")
		high = Color("607271")
	for y in 384:
		for x in 384:
			var value = noise.get_noise_2d(x, y) * .5 + .5
			var contour = .035 if fposmod(value, .105) < .008 else 0.0
			var color = low.lerp(high, value + contour)
			var point = Vector2(x, y) / 383.0 * map_size
			var distance = INF
			for road in roads:
				var closest = Geometry2D.get_closest_point_to_segment(
					point, Vector2(road.x, road.y), Vector2(road.z, road.w)
				)
				distance = minf(distance, point.distance_to(closest))
			var edge = distance + noise.get_noise_2d(x * 4.0, y * 4.0) * .45
			var track = 1.0 - smoothstep(road_width * .36, road_width * .62, edge)
			color = color.lerp(high.lerp(low, .12 + value * .16), track * .85)
			image.set_pixel(x, y, color)
	_terrain = ImageTexture.create_from_image(image)


func _draw():
	var available = size - Vector2(48, 48)
	var scale_factor = minf(available.x / map_size.x, available.y / map_size.y)
	var extent = map_size * scale_factor
	var origin = (size - extent) / 2
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	if _terrain == null:
		return
	draw_texture_rect(_terrain, Rect2(origin, extent), false)
	if not land.is_empty():
		draw_rect(Rect2(origin, extent), Color("233e4b"))
		var polygon = PackedVector2Array()
		for point in land:
			polygon.append(origin + point * scale_factor)
		var uv = PackedVector2Array()
		for point in land:
			uv.append(point / map_size)
		draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, _terrain)
		draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color("9caaa57a"), 2, true)
	for index in range(1, 8):
		var offset = extent * index / 8.0
		draw_line(
			origin + Vector2(offset.x, 0),
			origin + Vector2(offset.x, extent.y),
			Color("ffffff09"),
			1,
			true
		)
		draw_line(
			origin + Vector2(0, offset.y),
			origin + Vector2(extent.x, offset.y),
			Color("ffffff09"),
			1,
			true
		)
	for building in buildings:
		var rect = Rect2(origin + building.position * scale_factor, building.size * scale_factor)
		draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color("14212988"))
		draw_rect(rect, Color("8c9690"))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("c1c4af"), 1, true)
	for index in rocks.size():
		var center = origin + rocks[index] * scale_factor
		var radius = ridge_radius * scale_factor if ridge_radius > 0 else 11.0
		for layer in 3:
			var contour = PackedVector2Array()
			for vertex in 12:
				var angle = TAU * vertex / 12.0
				var irregular = 1.0 + .17 * sin(vertex * 2.4 + index * 1.7)
				contour.append(
					(
						center
						+ Vector2(cos(angle), sin(angle)) * radius * irregular * (1.0 - layer * .23)
						+ Vector2(-layer, -layer)
					)
				)
			var colors = [Color("3d403b"), Color("727365"), Color("9d9a82")]
			if _biome == "alpine":
				colors = [Color("495b60"), Color("8a9a9a"), Color("c3cecb")]
			draw_colored_polygon(contour, colors[layer])
			draw_polyline(contour + PackedVector2Array([contour[0]]), Color("d8d4b32a"), 1, true)
	for relay in relays:
		var point = origin + relay * scale_factor
		draw_circle(point, 10, Color("111e29cc"), true, -1, true)
		draw_colored_polygon(
			PackedVector2Array(
				[
					point + Vector2(0, -5),
					point + Vector2(5, 0),
					point + Vector2(0, 5),
					point + Vector2(-5, 0)
				]
			),
			Color("e4e6dc")
		)
	for site in points_of_interest:
		var point = origin + site.position * scale_factor
		draw_circle(point, 8, Color("111e29cc"), true, -1, true)
		var symbol = (
			{
				"refinery": tr("R", "map_refinery"),
				"mercenary": tr("M", "map_mercenary"),
				"repair": "+"
			}
			. get(site.kind, "+")
		)
		draw_string(
			MAP_FONT,
			point + Vector2(-4, 4),
			symbol,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color("e4e6dc")
		)
	for deposit in deposits:
		var point = origin + deposit * scale_factor
		draw_circle(point, 8, Color("16262aaa"), true, -1, true)
		for offset in [Vector2(-3, 1), Vector2(2, -3), Vector2(4, 3)]:
			draw_circle(point + offset, 2.5, Color("bed1a2"), true, -1, true)
	for index in starts.size():
		var point = origin + Vector2(starts[index].x, starts[index].z) * scale_factor
		var color = Color("e2c180") if index == 0 else Color("dd8d81")
		draw_circle(point, 24, Color(color, .12), true, -1, true)
		draw_circle(point + Vector2(0, 2), 15, Color("0d191ecc"), true, -1, true)
		draw_circle(point, 13, color, true, -1, true)
		draw_string(
			MAP_FONT,
			point + Vector2(-4, 5),
			str(index + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("101b25")
		)
	draw_string(
		MAP_FONT,
		origin + Vector2(0, -9),
		tr("N ↑"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color("a7b6bc")
	)
	var ruler = origin + Vector2(extent.x - 20 * scale_factor, extent.y + 12)
	draw_line(ruler, ruler + Vector2(20 * scale_factor, 0), Color("a7b6bc"), 2, true)
	draw_string(
		MAP_FONT,
		ruler - Vector2(36, -4),
		tr("%d m") % 20,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color("a7b6bc")
	)


func _background():
	var box = StyleBoxFlat.new()
	box.bg_color = Color("081016")
	box.set_corner_radius_all(0)
	box.set_border_width_all(1)
	box.border_color = Color("1e2f3bc0")
	return box
