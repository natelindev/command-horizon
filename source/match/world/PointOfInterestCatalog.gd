extends RefCounted

const Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")
const ROLES = Mercenaries.ROLES
# Capturable facilities per skirmish map, in save order. Every list pairs its
# sites with the map's start symmetry so no start owns a uniquely close one.
# Append new sites after existing ones: saves identify sites by their index.
const SITES = {
	"BastionDesert":
	[
		{"kind": "refinery", "position": Vector2(21, 53), "name": "South Refinery"},
		{"kind": "refinery", "position": Vector2(43, 11), "name": "North Refinery"},
	],
	"ExpandedDesertFrontier":
	[
		{"kind": "refinery", "position": Vector2(66, 20), "name": "North Refinery"},
		{"kind": "refinery", "position": Vector2(126, 124), "name": "South Refinery"},
		{"kind": "mercenary", "position": Vector2(44, 82), "name": "West Mercenary Camp"},
		{"kind": "mercenary", "position": Vector2(148, 62), "name": "East Mercenary Camp"},
		{"kind": "repair", "position": Vector2(84, 68), "name": "West Repair Shop"},
		{"kind": "repair", "position": Vector2(108, 76), "name": "East Repair Shop"},
	],
	"ExpandedAlpineRelay":
	[
		{"kind": "refinery", "position": Vector2(50, 45), "name": "West Refinery"},
		{"kind": "refinery", "position": Vector2(142, 111), "name": "East Refinery"},
		{"kind": "mercenary", "position": Vector2(56, 114), "name": "South Mercenary Camp"},
		{"kind": "mercenary", "position": Vector2(136, 42), "name": "North Mercenary Camp"},
		{"kind": "repair", "position": Vector2(72, 78), "name": "West Repair Shop"},
		{"kind": "repair", "position": Vector2(120, 78), "name": "East Repair Shop"},
	],
	"ExpandedCoastalFoundry":
	[
		{"kind": "refinery", "position": Vector2(56, 78), "name": "West Refinery"},
		{"kind": "refinery", "position": Vector2(136, 78), "name": "East Refinery"},
		{"kind": "mercenary", "position": Vector2(78, 149), "name": "West Mercenary Camp"},
		{"kind": "mercenary", "position": Vector2(114, 149), "name": "East Mercenary Camp"},
		{"kind": "repair", "position": Vector2(62, 104), "name": "West Repair Shop"},
		{"kind": "repair", "position": Vector2(130, 104), "name": "East Repair Shop"},
	],
	"DesertFrontier":
	[
		{"kind": "refinery", "position": Vector2(30, 72), "name": "West Refinery"},
		{"kind": "refinery", "position": Vector2(98, 24), "name": "East Refinery"},
		{"kind": "repair", "position": Vector2(64, 82), "name": "South Repair Shop"},
		{"kind": "repair", "position": Vector2(64, 14), "name": "North Repair Shop"},
	],
	"IndustrialCrossroads":
	[
		{"kind": "repair", "position": Vector2(24, 8), "name": "West Repair Shop"},
		{"kind": "repair", "position": Vector2(104, 96), "name": "East Repair Shop"},
		{"kind": "refinery", "position": Vector2(46, 98), "name": "South Refinery"},
		{"kind": "refinery", "position": Vector2(82, 6), "name": "North Refinery"},
	],
	"CoastalFoundry":
	[
		{"kind": "refinery", "position": Vector2(38, 48), "name": "West Refinery"},
		{"kind": "refinery", "position": Vector2(90, 48), "name": "East Refinery"},
		{"kind": "repair", "position": Vector2(40, 88), "name": "West Repair Shop"},
		{"kind": "repair", "position": Vector2(88, 88), "name": "East Repair Shop"},
	],
	"PlainAndSimple":
	[
		{"kind": "refinery", "position": Vector2(25, 6), "name": "North Refinery"},
		{"kind": "refinery", "position": Vector2(25, 44), "name": "South Refinery"},
	],
	"BigArena":
	[
		{"kind": "refinery", "position": Vector2(25, 63), "name": "West Refinery"},
		{"kind": "refinery", "position": Vector2(75, 37), "name": "East Refinery"},
	],
}


static func definitions(map_path):
	var battlefield = preload("res://source/match/maps/BattlefieldCatalog.gd").profile(map_path)
	return (
		battlefield.sites
		if not battlefield.is_empty()
		else SITES.get(map_path.get_file().get_basename(), [])
	)


static func accepts_population(map_path, count):
	return count == definitions(map_path).size()


static func populate(map):
	var entries = definitions(map.scene_file_path)
	for index in entries.size():
		var entry = entries[index]
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


static func price(role):
	var cost = Mercenaries.UNITS[role].cost
	return {"resource_a": cost[0], "resource_b": cost[1]}


static func reserved(player):
	var game = player.find_parent("Match")
	if game == null or game.map == null:
		return 0
	var count = 0
	for site in sites(game):
		if site.player == player:
			count += site.jobs.size()
	return count
