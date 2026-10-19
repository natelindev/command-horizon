extends RefCounted

# Expands an authored battlefield sector into the complete, fair layout. Each
# definition describes one player's share of the map; every feature is copied
# for each start by rotation about the centre (or by reflection), so all
# players receive identical terrain, routes and resources. Features listed
# under "shared" (a central lake, a crater) appear once.

const FEATURES = ["tiers", "ramps", "water", "blockers", "forests", "roads", "landmarks"]
const ORDERED = ["bases", "expansions", "sites"]


static func expand(definition: Dictionary) -> Dictionary:
	var layout = definition.duplicate(true)
	var players: int = definition.players
	for key in FEATURES + ORDERED:
		layout[key] = []
	# Per-player entries interleave by player so bases[i] belongs to player i
	# and site order (a permanent save identity) is stable.
	for key in FEATURES + ORDERED:
		for entry in definition.get(key, []):
			for player in players:
				layout[key].append(_transformed(entry, definition, player))
	for key in FEATURES:
		for entry in definition.get("shared", {}).get(key, []):
			layout[key].append(_normalized(entry.duplicate(true)))
	for key in ORDERED:
		for entry in definition.get("shared", {}).get(key, []):
			layout[key].append(_normalized(entry.duplicate(true)))
	return layout


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
