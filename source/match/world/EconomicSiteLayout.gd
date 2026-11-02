extends RefCounted

## Additional sites append after the authored list: existing facility IDs are
## permanent save identities. One tested position is copied by map symmetry.
const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const Ground = preload("res://source/match/maps/terrain/TerrainModel.gd")
const Layout = preload("res://source/match/maps/terrain/BattlefieldLayout.gd")
const Cache = preload("res://source/utils/RuntimeCache.gd")
const LEGACY_RELAYS = {
	"AlpineRelay": [Vector2(48, 20), Vector2(80, 84)],
	"BastionDesert": [Vector2(20, 32), Vector2(44, 32)],
	"DesertFrontier": [Vector2(46, 48), Vector2(82, 48)],
	"IndustrialCrossroads": [Vector2(44, 52), Vector2(84, 52)],
	"CoastalFoundry": [Vector2(38, 40), Vector2(90, 40)],
	"PlainAndSimple": [Vector2(15, 25), Vector2(35, 25)],
	"BigArena": [Vector2(32, 50), Vector2(68, 50)],
}


static func additional(map_path: String) -> Array:
	var layouts = Cache.bucket("economic_site_layouts")
	if layouts.has(map_path):
		return layouts[map_path]
	var result = []
	if Registry.is_authored(map_path):
		var definition = Registry.definition(map_path)
		var layout = Registry.layout(map_path)
		var point = _authored_position(definition, layout)
		for side in definition.players:
			(
				result
				. append(
					{
						"kind": "data_relay",
						"position": Layout.transform_point(point, definition, side),
						"name": "Data satellite relay %d" % (side + 1),
					}
				)
			)
	else:
		var positions = LEGACY_RELAYS.get(map_path.get_file().get_basename(), [])
		for side in positions.size():
			result.append(
				{
					"kind": "data_relay",
					"position": positions[side],
					"name": "Data satellite relay %d" % (side + 1)
				}
			)
	layouts[map_path] = result
	return result


static func _authored_position(definition: Dictionary, layout: Dictionary) -> Vector2:
	var ground = Ground.new(layout)
	var expansion = definition.expansions[-1]
	var origin: Vector2 = expansion.site
	var heading: Vector2 = (origin - expansion.field).normalized()
	for distance in [7.0, 9.0, 12.0, 16.0, 21.0, 27.0]:
		for step in 32:
			var point = origin + heading.rotated(step * TAU / 32.0) * distance
			if _clear(point, ground, layout):
				return point
	push_error("No safe data relay site on " + str(definition.id))
	return origin


static func _clear(point: Vector2, ground, layout: Dictionary) -> bool:
	if point.x < 4 or point.y < 4 or point.x > ground.size.x - 4 or point.y > ground.size.y - 4:
		return false
	var height = ground.height_at(point)
	for x in [-2.5, 0.0, 2.5]:
		for y in [-2.5, 0.0, 2.5]:
			var sample = point + Vector2(x, y)
			if (
				ground.flag_at(sample)
				& (Ground.WATER | Ground.SOLID | Ground.FOREST | Ground.BARRIER)
			):
				return false
			if absf(ground.height_at(sample) - height) > .15:
				return false
	for base in layout.bases:
		if point.distance_to(base.start) < 9 or point.distance_to(base.field) < 10:
			return false
	for expansion in layout.expansions:
		if point.distance_to(expansion.site) < 6 or point.distance_to(expansion.field) < 10:
			return false
	for site in layout.sites + layout.relays:
		if point.distance_to(site.position) < 7:
			return false
	for garrison in layout.garrisons:
		if point.distance_to(garrison.position) < garrison.get("radius", 6.0) + 3:
			return false
	for landmark in layout.landmarks:
		if point.distance_to(landmark.position) < landmark.get("solid", 0.0) + 4:
			return false
	return true
