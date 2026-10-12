extends RefCounted

const MAPS = [
	"res://source/match/maps/ExpandedDesertFrontier.tscn",
	"res://source/match/maps/ExpandedAlpineRelay.tscn",
	"res://source/match/maps/ExpandedCoastalFoundry.tscn"
]
const ROLES = ["Infantry", "RocketInfantry", "SniperInfantry"]
const Factions = preload("res://source/match/FactionRules.gd")


static func populate(map):
	for index in map.POI_SITES.size():
		var entry = map.POI_SITES[index]
		var site = load("res://source/match/world/PointOfInterest.gd").new()
		site.site_id = "poi-%d" % index
		site.kind = entry.kind
		site.label_title = entry.name
		site.position = Vector3(entry.position.x, 0, entry.position.y)
		map.add_child(site)
		map.points_of_interest.append(site)


static func sites(game):
	if game == null or game.map == null:
		return []
	return game.map.points_of_interest if "points_of_interest" in game.map else []


static func repair_sites(player):
	var game = player.find_parent("Match")
	return sites(game).filter(func(site): return site.kind == "repair" and site.player == player)


static func services(player):
	return (
		player.get_children().filter(func(unit): return unit.is_in_group("units"))
		+ repair_sites(player)
	)


static func price(faction, role):
	var normal = Factions.unit_costs(faction)[role]
	return {"resource_a": ceili(normal[0] * 1.25), "resource_b": ceili(normal[1] * 1.25)}


static func reserved(player):
	var game = player.find_parent("Match")
	if game == null or game.map == null:
		return 0
	var count = 0
	for site in sites(game):
		if site.player == player:
			count += site.jobs.size()
	return count
