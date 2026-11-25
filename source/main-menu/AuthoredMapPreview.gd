extends RefCounted

# Menu preview image of an authored battlefield, drawn from its gameplay
# terrain: ground palette, bilinearly filtered control masks, water depth/foam,
# bridge spans, topographic contours, hill-shaded cliffs, forest and roads.

const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const TerrainMesh = preload("res://source/match/maps/terrain/TerrainMesh.gd")
const Palettes = preload("res://source/match/maps/terrain/BiomePalettes.gd")
const PIXELS = 768
const LIGHT = Vector2(-0.6, -0.8)
const LAVA_CRUST = Color("3a1a10")
const LAVA_GLOW = Color("e8641a")


static func _sample_control(control: Image, point: Vector2, cols: int, rows: int) -> Color:
	var fx = clampf(point.x / TerrainModel.RESOLUTION - 0.5, 0.0, float(cols - 1))
	var fy = clampf(point.y / TerrainModel.RESOLUTION - 0.5, 0.0, float(rows - 1))
	var x0 = int(floorf(fx))
	var y0 = int(floorf(fy))
	var x1 = mini(x0 + 1, cols - 1)
	var y1 = mini(y0 + 1, rows - 1)
	var tx = fx - float(x0)
	var ty = fy - float(y0)
	var c00 = control.get_pixel(x0, y0)
	var c10 = control.get_pixel(x1, y0)
	var c01 = control.get_pixel(x0, y1)
	var c11 = control.get_pixel(x1, y1)
	return c00.lerp(c10, tx).lerp(c01.lerp(c11, tx), ty)


static func image(map_path: String) -> Image:
	var layout = Registry.layout(map_path)
	var model = TerrainModel.new(layout)
	var control = TerrainMesh.build_control(model, layout)
	var palette = Palettes.PALETTES.get(
		layout.get("ground", layout.biome), Palettes.PALETTES.desert
	)
	var noise = FastNoiseLite.new()
	noise.seed = layout.id.hash()
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	var detail_noise = FastNoiseLite.new()
	detail_noise.seed = layout.id.hash() ^ 0x9e3779b9
	detail_noise.frequency = 0.22
	var size: Vector2 = layout.size
	var lava = layout.water.filter(func(water): return water.get("lava", false))
	var scale = maxf(size.x, size.y) / PIXELS
	var width = int(size.x / scale)
	var depth = int(size.y / scale)
	var result = Image.create(width, depth, false, Image.FORMAT_RGB8)
	var water_deep: Color = palette.get("water_deep", Color("1b3d4a"))
	var water_shallow: Color = palette.get("water_shallow", Color("3f7b84"))
	var water_foam: Color = palette.get("water_foam", Color("c9dce0"))
	var snowfield: bool = palette.get("snow_amount", 0.0) > 0.5
	var contour_step: float = maxf(model.tier_step * 0.5, 1.0)
	var cols: int = model.columns
	var rows: int = model.rows
	for y in depth:
		for x in width:
			var point = (Vector2(x, y) + Vector2(0.5, 0.5)) * scale
			var height = model.height_at(point)
			var texel = _sample_control(control, point, cols, rows)
			var macro = noise.get_noise_2dv(point) * 0.5 + 0.5
			var grain = detail_noise.get_noise_2dv(point) * 0.5 + 0.5
			var color: Color = palette.ground_low.lerp(palette.ground_high, macro * 0.78 + grain * 0.22)
			if palette.has("accent"):
				color = color.lerp(palette.accent, palette.get("accent_amount", 0.2) * grain)
			if palette.has("snow"):
				var cover = lerpf(
					palette.snow_amount, palette.snow_high, smoothstep(-0.5, 6.0, height)
				)
				var drift = noise.get_noise_2dv(point * 0.75 + Vector2(83, 41)) * 0.5 + 0.5
				color = color.lerp(palette.snow, smoothstep(0.88 - cover, 1.12 - cover, drift))
			color = color.lerp(palette.get("sand", palette.ground_high), smoothstep(0.15, 0.85, texel.a) * 0.85)
			var canopy = palette.get("canopy", palette.forest_floor)
			var forest_mask = smoothstep(0.15, 0.85, texel.b)
			if forest_mask > 0.01:
				var tree_dapple = canopy.lerp(canopy.darkened(0.28), grain * 0.65)
				color = color.lerp(tree_dapple, forest_mask * 0.82)
			# Elevation gradient + subtle cartographic contour lines.
			var rise = height / (model.tier_step * 3.5) - (0.15 if snowfield else 0.0)
			color = color.lightened(clampf(rise, -0.22, 0.28))
			var contour_phase = fposmod(height + 100.0, contour_step) / contour_step
			if contour_phase < 0.06 and texel.g < 0.25:
				color = color.darkened(0.12)
			# Hill shading from gameplay slope picks out cliffs, ridges and ramps.
			var gradient = Vector2(
				(
					model.height_at(point + Vector2(scale, 0))
					- model.height_at(point - Vector2(scale, 0))
				),
				(
					model.height_at(point + Vector2(0, scale))
					- model.height_at(point - Vector2(0, scale))
				)
			)
			var relief = 0.95 if snowfield else 0.68
			var slope_mag = gradient.length() / (scale * 2.0)
			var shade = clampf(gradient.dot(LIGHT) / (scale * 2.0) * relief, -0.52, 0.42)
			color = color.lightened(shade) if shade > 0.0 else color.darkened(-shade)
			if slope_mag > 0.42 and texel.g < 0.3:
				color = color.lerp(palette.rock, clampf((slope_mag - 0.42) * 0.8, 0.0, 0.65))
			# Roads sit smoothly over terrain with crisp shoulder contrast.
			var road_mask = smoothstep(0.22, 0.78, texel.r)
			if road_mask > 0.01:
				var road_col = palette.road.lerp(palette.road.darkened(0.14), grain * 0.35)
				color = color.lerp(road_col, road_mask * 0.88)
			# Water & shallow fords with shoreline foam and depth shading.
			var water_mask = texel.g
			if water_mask > 0.18:
				var is_lava = false
				for flow in lava:
					if Geometry2D.is_point_in_polygon(point, flow.polygon):
						is_lava = true
						var crust = LAVA_CRUST.lerp(LAVA_GLOW, smoothstep(-0.15, 0.65, macro * 2.0 - 1.0))
						color = color.lerp(crust, smoothstep(0.2, 0.75, water_mask))
						break
				if not is_lava:
					if water_mask < 0.62:
						# Shallow bank / ford crossing.
						var ford_col = palette.bed.lerp(water_shallow, 0.48 + grain * 0.14)
						var bank_t = smoothstep(0.18, 0.56, water_mask)
						color = color.lerp(ford_col, bank_t * 0.9)
						var foam = smoothstep(0.22, 0.42, water_mask) * (1.0 - smoothstep(0.45, 0.62, water_mask))
						color = color.lerp(water_foam, foam * 0.38)
					else:
						var depth_t = smoothstep(0.62, 0.98, water_mask)
						var w_col = water_shallow.lerp(water_deep, depth_t * 0.85 + macro * 0.15)
						color = color.lerp(w_col, smoothstep(0.55, 0.78, water_mask))
			# Bridge spans and solid rock outcrops.
			var flags = model.flag_at(point)
			if flags & TerrainModel.BRIDGE:
				var deck_col = palette.road.lightened(0.24).lerp(Color("9aa3aa"), 0.38)
				color = deck_col.lerp(deck_col.darkened(0.12), grain * 0.25)
			elif flags & TerrainModel.SOLID:
				var rock_shade = clampf(gradient.dot(LIGHT) / (scale * 2.0) * 0.4, -0.25, 0.28)
				var rock_col = palette.rock.lightened(0.08 + macro * 0.12)
				color = rock_col.lightened(rock_shade) if rock_shade > 0.0 else rock_col.darkened(-rock_shade)
			# Subtle perimeter framing vignette keeps map borders crisp against dark UI.
			var edge_x = minf(point.x, size.x - point.x) / (size.x * 0.06)
			var edge_y = minf(point.y, size.y - point.y) / (size.y * 0.06)
			var edge_fade = clampf(minf(edge_x, edge_y), 0.0, 1.0)
			color = color.darkened((1.0 - edge_fade) * 0.22)
			result.set_pixel(x, y, color)
	return result
