extends RefCounted

# Expands an authored battlefield sector into the complete, fair layout. Each
# definition describes one player's share of the map; every feature is copied
# for each start by rotation about the centre (or by reflection), so all
# players receive identical terrain, routes and resources. Features listed
# under "shared" (a central lake, a crater) appear once.

const FEATURES = [
	"tiers", "ramps", "water", "bridges", "blockers", "forests", "roads", "landmarks", "sands"
]
const ORDERED = ["bases", "expansions", "sites"]
const NATURAL_STEP = 2.5


static func expand(definition: Dictionary) -> Dictionary:
	var layout = definition.duplicate(true)
	var players: int = definition.players
	for key in FEATURES + ORDERED:
		layout[key] = []
	# Per-player entries interleave by player so bases[i] belongs to player i
	# and site order (a permanent save identity) is stable.
	for key in FEATURES + ORDERED:
		var index = 0
		for entry in definition.get(key, []):
			var shaped = _roughened(
				entry, "%s-%s-%d" % [definition.id, key, index], definition.size
			)
			index += 1
			for player in players:
				layout[key].append(_transformed(shaped, definition, player))
	for key in FEATURES:
		var index = 0
		for entry in definition.get("shared", {}).get(key, []):
			var shaped = _roughened(
				entry, "%s-shared-%s-%d" % [definition.id, key, index], definition.size
			)
			index += 1
			layout[key].append(_normalized(shaped.duplicate(true)))
	for key in ORDERED:
		for entry in definition.get("shared", {}).get(key, []):
			layout[key].append(_normalized(entry.duplicate(true)))
	layout["ai"] = _ai(definition)
	return layout


# Commander hints: the expansion order (by name, per start) and every attack
# lane crossing, copied for all starts and merged where copies coincide.
static func _ai(definition: Dictionary) -> Dictionary:
	var hints: Dictionary = definition.get("ai", {})
	var lanes = []
	for point in hints.get("lanes", []):
		for player in definition.players:
			var copy = transform_point(point, definition, player)
			if not lanes.any(func(lane): return lane.distance_to(copy) < 2.0):
				lanes.append(copy)
	return {"expand_order": hints.get("expand_order", []), "lanes": lanes}


static func transform_point(point: Vector2, definition: Dictionary, player: int) -> Vector2:
	var size: Vector2 = definition.size
	match definition.get("symmetry", "rotate"):
		"mirror_x":
			return Vector2(size.x - point.x, point.y) if player % 2 == 1 else point
		"mirror_y":
			return Vector2(point.x, size.y - point.y) if player % 2 == 1 else point
		_:
			var centre = size / 2.0
			return centre + (point - centre).rotated(player * TAU / definition.players)


static func _transformed(entry: Dictionary, definition: Dictionary, player: int) -> Dictionary:
	var copy = entry.duplicate(true)
	for key in copy.keys():
		var value = copy[key]
		if value is Vector2:
			copy[key] = transform_point(value, definition, player)
		elif value is Array or value is PackedVector2Array:
			if not value.is_empty() and value[0] is Vector2:
				var points = PackedVector2Array()
				for point in value:
					points.append(transform_point(point, definition, player))
				copy[key] = points
	copy["player"] = player
	if copy.has("names"):
		copy["name"] = copy.names[player]
	return _normalized(copy)


# Polylines with a width become polygons; polygons are packed arrays.
static func _normalized(entry: Dictionary) -> Dictionary:
	if entry.has("polygon"):
		entry.polygon = PackedVector2Array(entry.polygon)
	if entry.has("line") and not entry.has("polygon") and entry.has("width"):
		entry.line = PackedVector2Array(entry.line)
		var outlines = Geometry2D.offset_polyline(
			entry.line, entry.width / 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND
		)
		entry.polygon = outlines[0] if not outlines.is_empty() else PackedVector2Array()
	return entry


# Natural outlines: each authored edge is subdivided and its new points pushed
# along the edge normal by seeded noise, so cliffs, rock and shores do not read
# as straight polygons. Authored vertices stay exact (ramps and chokes keep
# their positions); the shape is computed once, then copied to every player.
static func _roughened(entry: Dictionary, seed_text: String, size: Vector2) -> Dictionary:
	if not entry.get("natural", false) or not entry.has("polygon"):
		return entry
	var amplitude: float = entry.get("roughness", 1.2)
	var noise = FastNoiseLite.new()
	noise.seed = seed_text.hash()
	noise.frequency = 0.18
	var polygon = PackedVector2Array(entry.polygon)
	var outline = PackedVector2Array()
	for index in polygon.size():
		var a = polygon[index]
		var b = polygon[(index + 1) % polygon.size()]
		outline.append(a)
		# Edges along the map boundary stay straight: the ground continues there.
		if _on_boundary(a, b, size):
			continue
		var length = a.distance_to(b)
		var pieces = int(length / NATURAL_STEP)
		var normal = (b - a).orthogonal().normalized()
		for piece in range(1, pieces):
			var t = float(piece) / pieces
			# Taper toward the authored corners so they stay where they were placed.
			var taper = minf(1.0, minf(t, 1.0 - t) * length / (NATURAL_STEP * 2.0))
			var point = a.lerp(b, t)
			outline.append(point + normal * noise.get_noise_2dv(point) * amplitude * taper)
	var shaped = entry.duplicate(true)
	shaped.polygon = outline
	return shaped


static func _on_boundary(a: Vector2, b: Vector2, size: Vector2) -> bool:
	for axis in 2:
		for limit in [0.0, size[axis]]:
			if absf(a[axis] - limit) < 0.01 and absf(b[axis] - limit) < 0.01:
				return true
	return false
