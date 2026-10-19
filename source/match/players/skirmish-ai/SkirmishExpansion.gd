extends RefCounted

# Authored battlefields list each start's expansion sites; the commander
# claims them in the map's preferred order with a new headquarters (the
# drop-off that makes a distant field worth mining), on a schedule set by its
# difficulty. Maps without authored expansions keep the single-base economy.

const FIRST = [330.0, 210.0, 150.0]
const INTERVAL = [240.0, 170.0, 140.0]
const MAXIMUM = [1, 3, 4]
const WORKERS_PER_BASE = 5
const CLEARANCE = 9.0
const DANGER_RADIUS = 22.0


static func headquarters(units) -> Array:
	return units.filter(func(unit): return unit.type == "CommandCenter")


static func worker_bonus(units) -> int:
	var built = headquarters(units).filter(func(unit): return unit.is_constructed())
	return maxi(0, built.size() - 1) * WORKERS_PER_BASE


# Ground point for the next headquarters, or null when it is not yet time.
static func next_site(game, player, units, observed):
	var layout = game.map.get("layout")
	if layout == null or layout.is_empty() or not layout.has("ai"):
		return null
	var level = clampi(player.difficulty, 0, FIRST.size() - 1)
	var bases = headquarters(units)
	var extra = bases.size() - 1
	if bases.is_empty() or extra >= MAXIMUM[level]:
		return null
	if bases.any(func(unit): return not unit.is_constructed()):
		return null
	if game.simulation_time < FIRST[level] + INTERVAL[level] * extra:
		return null
	var start = player.get_index()
	for name in layout.ai.get("expand_order", []):
		for expansion in layout.expansions:
			if expansion.name != name or expansion.get("player", -1) != start:
				continue
			var site = game.map.ground_point(expansion.site)
			if _claimed(game, site) or _dangerous(site, observed):
				continue
			return site
	return null


static func _claimed(game, site: Vector3) -> bool:
	for unit in game.get_tree().get_nodes_in_group("units"):
		if (
			unit.has_method("is_constructed")
			and unit.global_position_yless.distance_to(site * Vector3(1, 0, 1)) < CLEARANCE
		):
			return true
	return false


static func _dangerous(site: Vector3, observed) -> bool:
	var flat = site * Vector3(1, 0, 1)
	return observed.any(
		func(enemy):
			return (
				enemy.attack_range != null
				and enemy.global_position_yless.distance_to(flat) < DANGER_RADIUS
			)
	)
