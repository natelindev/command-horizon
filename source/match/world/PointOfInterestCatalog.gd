extends RefCounted

const Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")
const ROLES = Mercenaries.ROLES
const EconomicLayout = preload("res://source/match/world/EconomicSiteLayout.gd")
const Authored = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
# Capturable facilities per skirmish map, in save order. Every list pairs its
# sites with the map's start symmetry so no start owns a uniquely close one.
# Append new sites after existing ones: saves identify sites by their index.
const SITES = {
	"BastionDesert":
	[
		{"kind": "refinery", "position": Vector2(21, 53), "name": "South Refinery"},
		{"kind": "refinery", "position": Vector2(43, 11), "name": "North Refinery"},
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
	var existing = (
		Authored.layout(map_path).sites
		if Authored.is_authored(map_path)
		else SITES.get(map_path.get_file().get_basename(), [])
	)
	return existing + EconomicLayout.additional(map_path)


static func accepts_population(map_path, count):
	return count == definitions(map_path).size()


static func populate(map):
	var entries = (
		load("res://source/scenario/ScenarioDocument.gd").site_definitions(map.scenario)
		if "scenario" in map
		else definitions(map.scene_file_path)
	)
	for index in entries.size():
		var entry = entries[index]
		var site
		if entry.kind in ["refinery", "data_relay"]:
			site = (
				load(
					(
						"res://source/match/world/%s.tscn"
						% ("TechRefinery" if entry.kind == "refinery" else "DataRelay")
					)
				)
				. instantiate()
			)
		else:
			site = load("res://source/match/world/PointOfInterest.gd").new()
		site.site_id = "poi-%d" % index
		site.kind = entry.kind
		site.label_title = entry.name
		site.position = map.ground_point(entry.position)
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
