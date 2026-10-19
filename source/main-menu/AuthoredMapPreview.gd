extends RefCounted

# Menu preview image of an authored battlefield, drawn from its gameplay
# terrain: ground palette, lighter higher tiers, hill-shaded cliffs, water,
# fords, forest, sand and roads. Starts, fields and facilities are drawn on top
# by the preview control.

const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const TerrainMesh = preload("res://source/match/maps/terrain/TerrainMesh.gd")
const Palettes = preload("res://source/match/maps/terrain/BiomePalettes.gd")
const PIXELS = 384
const LIGHT = Vector2(-0.6, -0.8)


static func image(map_path: String) -> Image:
	var layout = Registry.layout(map_path)
	var model = TerrainModel.new(layout)
	var control = TerrainMesh.build_control(model, layout)
	var palette = Palettes.PALETTES.get(
		layout.get("ground", layout.biome), Palettes.PALETTES.desert
	)
	var noise = FastNoiseLite.new()
	noise.seed = layout.id.hash()
	noise.frequency = 0.06
	var size: Vector2 = layout.size
	var scale = maxf(size.x, size.y) / PIXELS
	var width = int(size.x / scale)
	var depth = int(size.y / scale)
	var result = Image.create(width, depth, false, Image.FORMAT_RGB8)
	for y in depth:
		for x in width:
			var point = (Vector2(x, y) + Vector2(0.5, 0.5)) * scale
			var height = model.height_at(point)
			var texel = control.get_pixel(
				mini(int(point.x / TerrainModel.RESOLUTION), model.columns - 1),
				mini(int(point.y / TerrainModel.RESOLUTION), model.rows - 1)
			)
			var macro = noise.get_noise_2dv(point) * 0.5 + 0.5
			var color: Color = palette.ground_low.lerp(palette.ground_high, macro)
			color = color.lerp(palette.get("sand", palette.ground_high), texel.a * 0.85)
			color = color.lerp(palette.forest_floor, texel.b * 0.7)
			color = color.lerp(palette.road, texel.r * 0.8)
			color = color.lerp(palette.bed, texel.g)
			color = color.lightened(clampf(height / (model.tier_step * 3.5), -0.25, 0.3))
			# Hill shading from the gameplay slope picks out cliffs and ramps.
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
			var shade = clampf(gradient.dot(LIGHT) / (scale * 2.0) * 0.6, -0.55, 0.4)
			color = color.lightened(shade) if shade > 0.0 else color.darkened(-shade)
			if model.flag_at(point) & TerrainModel.SOLID:
				color = palette.rock.lightened(0.1 + macro * 0.1)
			result.set_pixel(x, y, color)
	return result
