extends RefCounted

# Living detail for authored battlefields, all batched per model: forests of
# the biome's species, scattered shrubs, rocks and lone trees on open ground,
# talus along cliff feet, and authored landmarks. Gameplay ground stays clear:
# bases, resource lanes, roads, ramps, facilities and water get no clutter.

const MeshBatch = preload("res://source/match/maps/terrain/MeshBatch.gd")
const BiomeDressing = preload("res://source/match/maps/terrain/BiomeDressing.gd")
const CliffMesh = preload("res://source/match/maps/terrain/CliffMesh.gd")
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const OBSTACLE = preload("res://source/match/units/traits/MovementObstacle.tscn")
const START_CLEARANCE = 16.0
const FIELD_CLEARANCE = 12.0
const SITE_CLEARANCE = 8.0
const ROAD_CLEARANCE = 1.5
const TALUS_SPACING = 3.5
const RAIL = ["works/RailTrack", 0.52]
# Static bodies settle onto the navigation surface, which rides above the
# authored ground; this offset sets them back on the ground.
const GROUND_OFFSET = 0.6
const RAIL_PANEL = 6.0


static func populate(map):
	var layout: Dictionary = map.layout
	var model = map.terrain
	var kit = BiomeDressing.kit(layout.get("ground", layout.biome))
	var rng = RandomNumberGenerator.new()
	rng.seed = ("%s-dressing" % layout.id).hash()
	var batches = {}
	var clear = _clearances(map, layout)
	for forest in layout.forests:
		_forest(map, forest, kit, rng, batches)
	var low = kit.get("low_ground_density", 1.0)
	_scatter(map, model, kit.shrubs, kit.shrub_density, rng, batches, clear, false, low)
	_scatter(map, model, kit.rocks, kit.rock_density, rng, batches, clear, true, low)
	_scatter(map, model, kit.lone_trees, kit.tree_density, rng, batches, clear, true, low)
	_talus(map, layout, model, kit, rng, batches)
	_shores(map, layout, kit, rng, batches)
	for rail in layout.get("rails", []):
		_rail(map, rail.line, batches)
	_grass(map, batches, clear)
	var parent = Node3D.new()
	parent.name = "Dressing"
	map.add_child(parent)
	for key in batches:
		var batch = batches[key]
		MeshBatch.add(
			parent,
			MeshBatch.merged_mesh(batch.asset, batch.height),
			batch.transforms,
			batch.asset.get_file(),
			true
		)
	for landmark in layout.get("landmarks", []):
		_landmark(map, layout, landmark)


# Cosmetic grass uses its own seed, so adding it never changes existing trees,
# rocks, sight blockers or resource lanes. One shared MultiMesh, no colliders.
static func _grass(map, batches, clear):
	if map.layout.get("ground", map.layout.biome) not in ["forest", "farmland", "village"]:
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = ("%s-meadow-grass" % map.layout.id).hash()
	var placed = 0
	for x in range(2, int(map.size.x) - 2, 3):
		for z in range(2, int(map.size.y) - 2, 3):
			var point = Vector2(x, z) + Vector2(rng.randf(), rng.randf())
			var flags = map.terrain.flag_at(point)
			if (
				flags
				& (
					TerrainModel.WATER
					| TerrainModel.SOLID
					| TerrainModel.RAMP
					| TerrainModel.FORD
					| TerrainModel.BRIDGE
				)
			):
				continue
			if not _open(point, clear):
				continue
			var verge = false
			for segment in clear.roads:
				var closest = Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1])
				if point.distance_to(closest) < segment[2] + 4.5:
					verge = true
					break
			if not verge and not flags & TerrainModel.FOREST:
				continue
			if rng.randf() > 0.7:
				continue
			_add(batches, ["temperate/MeadowGrass", 0.38], _placement(map, point, rng))
			placed += 1
			if placed >= 1800:
				return


static func _add(batches, entry: Array, transform: Transform3D):
	var key = "%s@%.2f" % entry
	if not batches.has(key):
		batches[key] = {"asset": entry[0], "height": entry[1], "transforms": []}
	batches[key].transforms.append(transform)


static func _placement(map, point: Vector2, rng, scale_range := Vector2(0.8, 1.2)) -> Transform3D:
	var scale = rng.randf_range(scale_range.x, scale_range.y)
	return Transform3D(
		Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), map.ground_point(point)
	)


static func _forest(map, forest: Dictionary, kit: Dictionary, rng, batches):
	var species = kit.get(forest.get("flora", "trees"), kit.trees)
	var spacing = 3.4 / sqrt(clampf(forest.get("density", 0.5), 0.1, 1.0))
	var polygon: PackedVector2Array = forest.polygon
	var bounds = Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	for x in range(int(bounds.size.x / spacing) + 1):
		for z in range(int(bounds.size.y / spacing) + 1):
			var point = (
				bounds.position
				+ Vector2(x, z) * spacing
				+ Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * spacing * 0.8
			)
			if not Geometry2D.is_point_in_polygon(point, polygon):
				continue
			_add(batches, species[rng.randi() % species.size()], _placement(map, point, rng))
			# An understorey of shrubs fills between trunks.
			if rng.randf() < 0.6:
				var under = point + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * spacing
				if Geometry2D.is_point_in_polygon(under, polygon):
					_add(
						batches,
						kit.shrubs[rng.randi() % kit.shrubs.size()],
						_placement(map, under, rng)
					)


# `low_share` thins scatter on ground at or below 1 m (salt pans, mud flats).
static func _scatter(
	map, model, entries: Array, density: float, rng, batches, clear, avoid_slopes, low_share := 1.0
):
	if entries.is_empty() or density <= 0.0:
		return
	var spacing = 1.0 / sqrt(density)
	for x in range(int(map.size.x / spacing) + 1):
		for z in range(int(map.size.y / spacing) + 1):
			var point = (Vector2(x, z) + Vector2(rng.randf(), rng.randf())) * spacing
			if point.x < 1 or point.y < 1 or point.x > map.size.x - 1 or point.y > map.size.y - 1:
				continue
			var cell = model.flag_at(point)
			if (
				cell
				& (
					TerrainModel.WATER
					| TerrainModel.SOLID
					| TerrainModel.FOREST
					| TerrainModel.FORD
					| TerrainModel.BRIDGE
				)
			):
				continue
			if avoid_slopes and cell & TerrainModel.RAMP:
				continue
			if not _open(point, clear):
				continue
			var i = clampi(int(point.x / TerrainModel.RESOLUTION), 0, model.columns - 1)
			var j = clampi(int(point.y / TerrainModel.RESOLUTION), 0, model.rows - 1)
			# Scenery also dresses inaccessible tops, never cliffs or water.
			if not model.is_walkable_cell(i, j) and not cell & TerrainModel.BARRIER:
				continue
			if low_share < 1.0 and model.height_at(point) < 1.0 and rng.randf() > low_share:
				continue
			_add(batches, entries[rng.randi() % entries.size()], _placement(map, point, rng))


static func _talus(map, layout: Dictionary, model, kit: Dictionary, rng, batches):
	var outlines = []
	for tier in layout.tiers:
		if not tier.has("falloff"):
			outlines.append(tier.polygon)
	for blocker in layout.blockers:
		outlines.append(blocker.polygon)
	for polygon in outlines:
		var outward = -1.0 if Geometry2D.is_polygon_clockwise(polygon) else 1.0
		var points = CliffMesh.densified(polygon, TALUS_SPACING)
		for index in points.size():
			var point: Vector2 = points[index]
			var normal = CliffMesh.vertex_normal(points, index, outward)
			var top = model.height_at(point - normal)
			var foot = point + normal * rng.randf_range(1.2, 2.2)
			if top - model.height_at(foot) < 1.5 or rng.randf() > 0.65:
				continue
			if model.flag_at(foot) & (TerrainModel.WATER | TerrainModel.RAMP):
				continue
			_add(
				batches,
				kit.talus[rng.randi() % kit.talus.size()],
				_placement(map, foot, rng, Vector2(0.7, 1.15))
			)


# Rocks ring natural pools so their banks read as worn stone, not a cut edge.
static func _shores(map, layout: Dictionary, kit: Dictionary, rng, batches):
	for water in layout.water:
		if water.get("ford", false):
			continue
		var polygon: PackedVector2Array = water.polygon
		var outward = -1.0 if Geometry2D.is_polygon_clockwise(polygon) else 1.0
		var points = CliffMesh.densified(polygon, 1.6)
		for index in points.size():
			if rng.randf() > 0.7:
				continue
			var normal = CliffMesh.vertex_normal(points, index, outward)
			var bank = points[index] + normal * rng.randf_range(0.2, 0.9)
			if map.terrain.flag_at(bank) & TerrainModel.BRIDGE:
				continue
			_add(
				batches,
				kit.talus[rng.randi() % kit.talus.size()],
				_placement(map, bank, rng, Vector2(0.45, 0.8))
			)


# Track in 6 m panels laid end to end along each segment of the line; panels
# stretch slightly so every segment is filled exactly.
static func _rail(map, line: PackedVector2Array, batches):
	for index in line.size() - 1:
		var a = line[index]
		var b = line[index + 1]
		var length = a.distance_to(b)
		var count = maxi(1, ceili(length / RAIL_PANEL))
		var step = length / count
		var basis = (
			Basis(Vector3.UP, -(b - a).angle()) * Basis.from_scale(Vector3(step / RAIL_PANEL, 1, 1))
		)
		for panel in count:
			var centre = a.lerp(b, (panel + 0.5) / count)
			_add(batches, RAIL, Transform3D(basis, map.ground_point(centre)))


# Heading is the direction of the model's +X in the ground plane, in degrees;
# rotated and reflected copies face the transformed direction.
static func heading(layout: Dictionary, entry: Dictionary) -> float:
	var value = entry.get("heading", 0.0)
	var reflected = entry.get("player", 0) % 2 == 1
	match layout.get("symmetry", "rotate"):
		"mirror_x":
			return 180.0 - value if reflected else value
		"mirror_y":
			return -value if reflected else value
	return value + entry.get("player", 0) * 360.0 / layout.players


static func _landmark(map, layout: Dictionary, landmark: Dictionary):
	var body = Node3D.new()
	body.name = landmark.get("name", landmark.asset.get_file()).to_pascal_case()
	body.position = map.ground_point(landmark.position)
	# Afloat: ships and boats ride at an absolute height (the water surface).
	if landmark.has("level"):
		body.position.y = landmark.level
	body.rotation.y = -deg_to_rad(heading(layout, landmark))
	body.set_meta("landmark", landmark.asset)
	map.get_node("Decorations").add_child(body)
	var model = load("res://assets/models/environment/%s.glb" % landmark.asset).instantiate()
	model.scale = Vector3.ONE * landmark.get("scale", 1.0)
	body.add_child(model)
	if landmark.has("solid"):
		_obstacle(body, landmark.solid, landmark.get("sight_height", 3.0))
	# Walls with openings: local outlines that turn with the landmark.
	for outline in landmark.get("footprints", []):
		_obstacle(body, 0.5, landmark.get("sight_height", 3.0), PackedVector2Array(outline))


static func _obstacle(
	body: Node3D, radius: float, sight_height: float, footprint := PackedVector2Array()
):
	var obstacle = OBSTACLE.instantiate()
	obstacle.name = "MovementObstacle"
	obstacle.radius = radius
	obstacle.footprint = footprint
	obstacle.sight_height = sight_height
	obstacle.path_height_offset = GROUND_OFFSET
	obstacle.affect_navigation_mesh = true
	body.add_child(obstacle)


# Circles kept free of clutter: starts, resource fields and lanes, facilities,
# ramps and landmarks; roads are checked separately by distance.
static func _clearances(map, layout: Dictionary) -> Dictionary:
	var circles = []
	for base in layout.bases:
		circles.append([base.start, START_CLEARANCE])
		circles.append([base.field, FIELD_CLEARANCE * 0.6])
	for expansion in layout.expansions:
		circles.append([expansion.site, FIELD_CLEARANCE])
		circles.append([expansion.field, FIELD_CLEARANCE * 0.6])
	for site in layout.sites:
		circles.append([site.position, SITE_CLEARANCE])
	for landmark in layout.get("landmarks", []):
		circles.append([landmark.position, landmark.get("solid", 2.0) + 2.0])
	for ramp in layout.ramps:
		for step in 5:
			circles.append([ramp.from.lerp(ramp.to, step / 4.0), ramp.width / 2.0 + 1.0])
	var segments = []
	for road in layout.roads:
		for index in road.line.size() - 1:
			segments.append([road.line[index], road.line[index + 1], road.width / 2.0])
	for rail in layout.get("rails", []):
		for index in rail.line.size() - 1:
			segments.append([rail.line[index], rail.line[index + 1], 2.0])
	return {"circles": circles, "roads": segments, "size": map.size}


static func _open(point: Vector2, clear: Dictionary) -> bool:
	for circle in clear.circles:
		if point.distance_squared_to(circle[0]) < circle[1] * circle[1]:
			return false
	for segment in clear.roads:
		var closest = Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1])
		if point.distance_to(closest) < segment[2] + ROAD_CLEARANCE:
			return false
	return true
