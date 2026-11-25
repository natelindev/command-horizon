extends Control

signal start_selected(start_index)

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const MAP_FONT = preload("res://assets/fonts/NotoSansSC.ttf")
const PreviewData = preload("res://source/main-menu/MapPreviewData.gd")
const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const AuthoredPreview = preload("res://source/main-menu/AuthoredMapPreview.gd")
const Cache = preload("res://source/utils/RuntimeCache.gd")
const PREVIEW_FIELDS = [
	"map_size",
	"starts",
	"deposits",
	"rocks",
	"ridge_radius",
	"relays",
	"points_of_interest",
	"roads",
	"road_width",
	"buildings",
	"land",
	"water",
	"water_radius",
	"water_color",
	"terrain_low",
	"terrain_high",
	"_biome"
]

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
var water = []
var water_radius = 0.0
var water_color = Color("315e68")
var terrain_low = Color("554f3e")
var terrain_high = Color("89816a")
var _terrain: ImageTexture
var _biome = "desert"
var _terrain_cache = {}
var _slot_assignments = []
var _hovered_start = -1


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	accessibility_description = tr("Choose a starting location · click or arrow keys")
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		if _hovered_start >= 0:
			_hovered_start = -1
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()


func set_slot_assignments(assignments):
	_slot_assignments = assignments
	queue_redraw()


func _map_transform():
	var available = size - Vector2(48, 48)
	var scale_factor = 1.0
	if map_size.x > 0 and map_size.y > 0:
		scale_factor = minf(available.x / map_size.x, available.y / map_size.y)
	var extent = map_size * scale_factor
	var origin = (size - extent) / 2
	return {"scale": scale_factor, "origin": origin, "extent": extent}


func get_start_at_position(local_position, hit_radius = 26.0):
	if starts.is_empty():
		return -1
	var xform = _map_transform()
	var origin = xform.origin
	var scale_factor = xform.scale
	var closest_index = -1
	var closest_distance = hit_radius
	for index in starts.size():
		var start = starts[index]
		var map_pos = (
			Vector2(start.x, start.z)
			if start is Vector3
			else Vector2(start.x, start.y if "y" in start else 0.0)
		)
		var center = origin + map_pos * scale_factor
		var distance = local_position.distance_to(center)
		if distance <= closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _gui_input(event):
	if event is InputEventKey and event.pressed and not event.echo and not starts.is_empty():
		var direction = 0
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			direction = -1
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			direction = 1
		if direction != 0:
			var current = 0
			for assignment in _slot_assignments:
				if assignment.get("slot") == 0:
					current = assignment.location
			start_selected.emit(posmod(current + direction, starts.size()))
			accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var index = get_start_at_position(event.position)
			if index >= 0:
				grab_focus()
				start_selected.emit(index)
				accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			var index = get_start_at_position(event.position)
			if index >= 0:
				start_selected.emit(index)
				accept_event()
	elif event is InputEventMouseMotion:
		var hovered = get_start_at_position(event.position)
		if hovered != _hovered_start:
			_hovered_start = hovered
			mouse_default_cursor_shape = (
				Control.CURSOR_POINTING_HAND if _hovered_start >= 0 else Control.CURSOR_ARROW
			)
			queue_redraw()


func _get_tooltip(at_position):
	var index = get_start_at_position(at_position)
	if index >= 0:
		for assignment in _slot_assignments:
			if assignment.get("location") == index:
				return tr("Start %d · %s") % [index + 1, assignment.get("name", "")]
		return tr("Start %d") % (index + 1)
	return ""


func set_map(path):
	var baked_previews = Cache.bucket("map_previews")
	var baked_path = "res://assets/ui/map-previews/%s.res" % path.get_file().get_basename()
	if not baked_previews.has(path) and ResourceLoader.exists(baked_path):
		var baked = load(baked_path)
		if baked is PreviewData and baked.source_path == path:
			baked_previews[path] = baked
	if baked_previews.has(path):
		var baked = baked_previews[path]
		for key in PREVIEW_FIELDS:
			set(key, baked.data[key])
		_terrain = baked.terrain
		queue_redraw()
		return
	# Custom/legacy maps can still generate a preview without a baked asset.
	_generate_map(path)


func _generate_map(path):
	if Registry.is_authored(path):
		_generate_authored(path)
		return
	starts.clear()
	deposits.clear()
	rocks.clear()
	relays.clear()
	points_of_interest.clear()
	roads.clear()
	buildings.clear()
	land.clear()
	water.clear()
	water_radius = 0.0
	water_color = Color("315e68")
	terrain_low = Color("554f3e")
	terrain_high = Color("89816a")
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
	starts = markers.map(func(marker): return marker.position)
	if scene.has_method("overview"):
		var overview = scene.overview()
		water = overview.get("water", []).duplicate()
		water_radius = overview.get("water_radius", 0.0)
		water_color = overview.get("water_color", Color("315e68"))
		terrain_low = overview.get("low", terrain_low)
		terrain_high = overview.get("high", terrain_high)
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


# Authored battlefields preview their real terrain; markers come from the layout.
func _generate_authored(path):
	var layout = Registry.layout(path)
	map_size = layout.size
	starts = layout.bases.map(func(base): return Vector3(base.start.x, 0, base.start.y))
	deposits = layout.bases.map(func(base): return base.field)
	deposits.append_array(layout.expansions.map(func(expansion): return expansion.field))
	points_of_interest = (
		load("res://source/match/world/PointOfInterestCatalog.gd").definitions(path).duplicate()
	)
	for list in [rocks, relays, roads, buildings, land, water]:
		list.clear()
	water_radius = 0.0
	ridge_radius = 0.0
	road_width = 4.0
	water_color = Color("315e68")
	_biome = layout.biome
	# The map's own ground colours, never those left by the previous preview.
	var palette = AuthoredPreview.Palettes.PALETTES.get(layout.get("ground", layout.biome), {})
	terrain_low = palette.get("ground_low", Color("554f3e"))
	terrain_high = palette.get("ground_high", Color("89816a"))
	if not _terrain_cache.has(path):
		_terrain_cache[path] = ImageTexture.create_from_image(AuthoredPreview.image(path))
	_terrain = _terrain_cache[path]
	queue_redraw()


func _make_terrain():
	var noise = FastNoiseLite.new()
	noise.seed = 481
	noise.frequency = .02
	noise.fractal_octaves = 3
	var grain = FastNoiseLite.new()
	grain.seed = 919
	grain.frequency = .09
	var tex_size = 512
	var image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGB8)
	var low = terrain_low
	var high = terrain_high
	if _biome == "alpine":
		low = Color("3e555b")
		high = Color("8c9c96")
	elif _biome == "urban":
		low = Color("354648")
		high = Color("607271")
	var light = Vector2(-0.6, -0.8)
	for y in tex_size:
		for x in tex_size:
			var value = noise.get_noise_2d(x * 0.75, y * 0.75) * .5 + .5
			var gx = (
				(noise.get_noise_2d((x + 2.0) * 0.75, y * 0.75) - noise.get_noise_2d((x - 2.0) * 0.75, y * 0.75))
				* 3.2
			)
			var gy = (
				(noise.get_noise_2d(x * 0.75, (y + 2.0) * 0.75) - noise.get_noise_2d(x * 0.75, (y - 2.0) * 0.75))
				* 3.2
			)
			var fine = grain.get_noise_2d(x * 0.75, y * 0.75) * 0.03
			var contour = -0.025 if fposmod(value, .12) < .008 else 0.0
			var color = low.lerp(high, clampf(value + fine, 0.0, 1.0))
			var shade = clampf(Vector2(gx, gy).dot(light) * 0.25 + contour, -0.14, 0.14)
			color = color.lightened(shade) if shade > 0.0 else color.darkened(-shade)
			var point = Vector2(x, y) / float(tex_size - 1) * map_size
			var distance = INF
			for road in roads:
				var closest = Geometry2D.get_closest_point_to_segment(
					point, Vector2(road.x, road.y), Vector2(road.z, road.w)
				)
				distance = minf(distance, point.distance_to(closest))
			var edge = distance + noise.get_noise_2d(x * 3.0, y * 3.0) * .45
			var track = 1.0 - smoothstep(road_width * .36, road_width * .62, edge)
			color = color.lerp(high.lerp(low, .12 + value * .16), track * .85)
			image.set_pixel(x, y, color)
	_terrain = ImageTexture.create_from_image(image)


func _draw():
	var available = size - Vector2(48, 48)
	var scale_factor = minf(available.x / map_size.x, available.y / map_size.y)
	var extent = map_size * scale_factor
	var origin = (size - extent) / 2
	var accent = ArtTheme.accent()
	var display_font = ArtTheme.display_font()
	var num_font = ArtTheme.numeral_font()

	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	if _terrain == null:
		return

	# Subtle tactical map drop shadow + crisp framed terrain canvas.
	draw_rect(Rect2(origin + Vector2(3, 4), extent), Color(0, 0, 0, 0.45))
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

	# Cartographic grid overlay + perimeter tick marks.
	for index in range(1, 8):
		var offset = extent * index / 8.0
		var line_col = Color(1, 1, 1, 0.055 if index % 2 == 0 else 0.028)
		draw_line(origin + Vector2(offset.x, 0), origin + Vector2(offset.x, extent.y), line_col, 1, true)
		draw_line(origin + Vector2(0, offset.y), origin + Vector2(extent.x, offset.y), line_col, 1, true)
		draw_line(origin + Vector2(offset.x, -3), origin + Vector2(offset.x, 0), Color(accent, 0.45), 1, true)
		draw_line(origin + Vector2(-3, offset.y), origin + Vector2(0, offset.y), Color(accent, 0.45), 1, true)

	draw_rect(Rect2(origin, extent), Color(accent, 0.35), false, 1.2)

	for pool in water:
		draw_circle(
			origin + pool * scale_factor, water_radius * scale_factor, water_color, true, -1, true
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
		draw_circle(point, 9, Color("0b141bd8"), true, -1, true)
		draw_arc(point, 9, 0, TAU, 20, Color("7cc6d488"), 1.2, true)
		draw_colored_polygon(
			PackedVector2Array(
				[
					point + Vector2(0, -5),
					point + Vector2(5, 0),
					point + Vector2(0, 5),
					point + Vector2(-5, 0)
				]
			),
			Color("e8efe6")
		)
	for site in points_of_interest:
		var point = origin + site.position * scale_factor
		draw_circle(point + Vector2(0, 1), 9, Color(0, 0, 0, 0.5), true, -1, true)
		draw_circle(point, 8.5, Color("0d161ee6"), true, -1, true)
		draw_arc(point, 8.5, 0, TAU, 20, Color(accent, 0.72), 1.2, true)
		var symbol = (
			{
				"refinery": tr("R", "map_refinery"),
				"mercenary": tr("M", "map_mercenary"),
				"repair": tr("S", "map_repair"),
				"data_relay": tr("D", "map_data_relay")
			}
			. get(site.kind, "·")
		)
		var glyph_size = display_font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(
			display_font,
			point + Vector2(-glyph_size.x * 0.5, 4.5),
			symbol,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color("f1eee4")
		)
	for deposit in deposits:
		var point = origin + deposit * scale_factor
		draw_circle(point, 7.5, Color("0c1518c8"), true, -1, true)
		draw_arc(point, 7.5, 0, TAU, 16, Color("9fc88a88"), 1.0, true)
		for offset in [Vector2(-2.6, 1.2), Vector2(1.8, -2.5), Vector2(3.2, 2.5)]:
			draw_circle(point + offset, 2.2, Color("cbe39e"), true, -1, true)
	for index in starts.size():
		var point = origin + Vector2(starts[index].x, starts[index].z) * scale_factor
		var color = [Color("e2c180"), Color("dd8d81"), Color("88bad4"), Color("b5a1d4")][index % 4]
		var caption = ""
		for assignment in _slot_assignments:
			if assignment.get("location") == index:
				color = assignment.get("color", color)
				caption = assignment.get("name", "")
				break
		var is_hovered = index == _hovered_start
		var halo_radius = 27.0 if is_hovered else 22.0
		var halo_alpha = 0.30 if is_hovered else 0.14
		draw_circle(point, halo_radius, Color(color, halo_alpha), true, -1, true)
		if is_hovered:
			draw_arc(point, 20.0, 0, TAU, 32, Color(color, 0.85), 1.5, true)
		draw_circle(point + Vector2(0, 2), 15.0, Color(0, 0, 0, 0.65), true, -1, true)
		draw_circle(point, 13.5, color, true, -1, true)
		draw_arc(point, 13.5, 0, TAU, 28, Color("fff8e8bb"), 1.4, true)
		var num_text = str(index + 1)
		var num_w = num_font.get_string_size(num_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(
			num_font,
			point + Vector2(-num_w * 0.5, 5.5),
			num_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15,
			Color("101b25")
		)
		var caption_width = display_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		if not caption.is_empty():
			var pill = Rect2(point + Vector2(-caption_width / 2 - 7, 17), Vector2(caption_width + 14, 20))
			draw_rect(pill, Color("091118ea"))
			draw_rect(pill, Color(color, 0.55), false, 1.0)
			draw_rect(Rect2(pill.position, Vector2(3, pill.size.y)), color)
		draw_string(
			display_font,
			point + Vector2(-caption_width / 2, 31.5),
			caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color("f1eee4")
		)
	draw_string(
		display_font,
		origin + Vector2(0, -8),
		tr("N ↑"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("b0b9ba")
	)
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))
	var ruler = origin + Vector2(extent.x - 20 * scale_factor, extent.y + 12)
	draw_line(ruler, ruler + Vector2(20 * scale_factor, 0), Color("b0b9ba"), 2, true)
	draw_line(ruler + Vector2(0, -3), ruler + Vector2(0, 3), Color("b0b9ba"), 1.5, true)
	draw_line(
		ruler + Vector2(20 * scale_factor, -3),
		ruler + Vector2(20 * scale_factor, 3),
		Color("b0b9ba"),
		1.5,
		true
	)
	draw_string(
		num_font,
		ruler - Vector2(36, -4),
		tr("%d m") % 20,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color("b0b9ba")
	)


func _background():
	var box = StyleBoxFlat.new()
	box.bg_color = Color("070e13")
	box.set_corner_radius_all(0)
	box.set_border_width_all(1)
	box.border_color = Color("1e2f3bc0")
	return box
