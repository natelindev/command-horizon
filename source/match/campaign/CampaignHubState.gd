# gdlint: disable=max-returns,duplicated-load
# Independent guard clauses keep validation and eligibility paths explicit.
# Runtime loading avoids autoload-dependent preload cycles.
extends RefCounted

## Campaign hub choices are separate from both operation completion and battle
## snapshots. Existing campaign progress is never rewritten by a hub interaction.
const PATH = "user://campaign-hub.json"
const DOCTRINES = {
	"bastion": ["fortress_doctrine", "iron_blitz"],
	"helix": ["phase_overload", "continuous_coherence"],
	"frontier": ["guerrilla_insurgency", "salvage_war_machine"]
}
const INSIGNIA = ["Cinder Wings", "Meridian Star", "Dustfall Shield"]

const UPGRADE_COSTS = {
	"weapons_1": 100,
	"weapons_2": 150,
	"weapons_3": 200,
	"armor_1": 100,
	"armor_2": 150,
	"armor_3": 200,
	"service": 100,
	"dual_purpose_aa": 150,
	"tank_stabilizers": 150,
	"tandem_rockets": 150,
	"reactive_armor": 150,
	"siege_logistics": 150,
	"bunker_reinforcements": 100,
	"plasma_shields": 150,
	"beam_amplification": 150,
	"flux_capacitors": 150,
	"phase_thrusters": 150,
	"scrap_cannibalization": 150,
	"high_octane": 150,
	"concealed_claymores": 150,
}

const UPGRADE_REQUIREMENTS = {
	"weapons_2": "weapons_1",
	"weapons_3": "weapons_2",
	"armor_2": "armor_1",
	"armor_3": "armor_2",
}

const FACTION_UPGRADES = {
	"bastion":
	[
		"weapons_1",
		"weapons_2",
		"weapons_3",
		"armor_1",
		"armor_2",
		"armor_3",
		"tank_stabilizers",
		"tandem_rockets",
		"reactive_armor",
		"siege_logistics",
		"bunker_reinforcements",
		"service",
		"dual_purpose_aa"
	],
	"helix":
	[
		"weapons_1",
		"weapons_2",
		"weapons_3",
		"armor_1",
		"armor_2",
		"armor_3",
		"plasma_shields",
		"beam_amplification",
		"flux_capacitors",
		"phase_thrusters",
		"service",
		"dual_purpose_aa"
	],
	"frontier":
	[
		"weapons_1",
		"weapons_2",
		"weapons_3",
		"armor_1",
		"armor_2",
		"armor_3",
		"scrap_cannibalization",
		"high_octane",
		"concealed_claymores",
		"bunker_reinforcements",
		"service",
		"dual_purpose_aa"
	]
}

var faction = "bastion"
var doctrines = {}
var insignia = []
var commendations = []
var recoveries = []
var upgrades = {"bastion": [], "helix": [], "frontier": []}
var error = ""


func read_state(path = PATH) -> bool:
	faction = "bastion"
	doctrines.clear()
	insignia.clear()
	commendations.clear()
	recoveries.clear()
	upgrades = {"bastion": [], "helix": [], "frontier": []}
	error = ""
	if not FileAccess.file_exists(path):
		return true
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4096:
		return _fail("Campaign hub choices could not be read.")
	var value = JSON.parse_string(file.get_as_text())
	if not _valid(value):
		return _fail("Campaign hub choices are invalid. Existing file retained.")
	faction = value.faction
	doctrines = value.doctrines.duplicate()
	insignia = value.insignia.duplicate()
	commendations = value.get("commendations", []).duplicate()
	recoveries = value.get("recoveries", []).duplicate()
	if value.get("schema") >= 4 and value.get("upgrades") is Dictionary:
		upgrades = value.upgrades.duplicate(true)
	return true


func _valid(value) -> bool:
	if (
		not value is Dictionary
		or (
			(value.get("schema") == 1 and value.size() != 4)
			or (value.get("schema") == 2 and value.size() != 5)
			or (value.get("schema") == 3 and value.size() != 6)
			or (value.get("schema") == 4 and value.size() != 7)
			or (
				value.get("schema") != 1
				and value.get("schema") != 2
				and value.get("schema") != 3
				and value.get("schema") != 4
			)
		)
	):
		return false
	if (
		value.get("faction") not in DOCTRINES
		or not value.get("doctrines") is Dictionary
		or not value.get("insignia") is Array
	):
		return false
	for key in value.doctrines:
		if key not in DOCTRINES or value.doctrines[key] not in DOCTRINES[key]:
			return false
	var seen = []
	for item in value.insignia:
		if item not in INSIGNIA or item in seen:
			return false
		seen.append(item)
	if value.get("schema") >= 2:
		if not value.get("commendations") is Array:
			return false
		var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
		var recorded = []
		for id in value.commendations:
			if not id is String or id not in catalog.operations() or id in recorded:
				return false
			recorded.append(id)
	if value.get("schema") >= 3:
		if not value.get("recoveries") is Array:
			return false
		var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
		var recovered = []
		for id in value.recoveries:
			if not id is String or id not in catalog.ORDER.frontier or id in recovered:
				return false
			recovered.append(id)
	if value.get("schema") == 4:
		if not value.get("upgrades") is Dictionary:
			return false
		for fac in value.upgrades:
			if fac not in DOCTRINES or not value.upgrades[fac] is Array:
				return false
			for up_id in value.upgrades[fac]:
				if not up_id is String or not UPGRADE_COSTS.has(up_id):
					return false
	return true


func total_points_earned(for_faction: String, progress = null) -> int:
	if progress == null:
		progress = load("res://source/match/campaign/CampaignProgress.gd").new()
		progress.read_progress()
	var points = 0
	var order = load("res://source/match/campaign/CampaignCatalog.gd").ORDER.get(for_faction, [])
	for id in order:
		if progress.completed(id):
			points += 100
		if id in commendations:
			points += 50
	return points


func points_spent(for_faction: String) -> int:
	var total = 0
	var list = upgrades.get(for_faction, [])
	for id in list:
		total += UPGRADE_COSTS.get(id, 100)
	return total


func points_available(for_faction: String, progress = null) -> int:
	return maxi(0, total_points_earned(for_faction, progress) - points_spent(for_faction))


func can_purchase_upgrade(for_faction: String, id: String, progress = null) -> bool:
	if for_faction not in FACTION_UPGRADES:
		return false
	if id not in FACTION_UPGRADES[for_faction]:
		return false
	var list = upgrades.get(for_faction, [])
	if id in list:
		return false
	if UPGRADE_REQUIREMENTS.has(id):
		var req = UPGRADE_REQUIREMENTS[id]
		if req not in list:
			return false
	var cost = UPGRADE_COSTS.get(id, 100)
	return points_available(for_faction, progress) >= cost


func purchase_upgrade(for_faction: String, id: String, path = PATH, progress = null) -> bool:
	if not read_state(path):
		return false
	if not can_purchase_upgrade(for_faction, id, progress):
		return false
	if not upgrades.has(for_faction):
		upgrades[for_faction] = []
	if id not in upgrades[for_faction]:
		upgrades[for_faction].append(id)
	faction = for_faction
	return save_state(path)


func reset_upgrades(for_faction: String, path = PATH) -> bool:
	if not read_state(path):
		return false
	if not upgrades.has(for_faction) or upgrades[for_faction].is_empty():
		return true
	upgrades[for_faction].clear()
	faction = for_faction
	return save_state(path)


func has_upgrade(for_faction: String, id: String) -> bool:
	return upgrades.get(for_faction, []).has(id)


func choose_doctrine(for_faction: String, id: String, path = PATH) -> bool:
	if not read_state(path) or for_faction not in DOCTRINES or id not in DOCTRINES[for_faction]:
		return false
	if doctrines.has(for_faction):
		return doctrines[for_faction] == id
	doctrines[for_faction] = id
	faction = for_faction
	return save_state(path)


func forge_insignia(id: String, path = PATH) -> bool:
	if (
		not read_state(path)
		or id not in INSIGNIA
		or id in insignia
		or recoveries.size() <= insignia.size()
	):
		return false
	insignia.append(id)
	return save_state(path)


func save_state(path = PATH) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _fail("Campaign hub choices could not be saved.")
	file.store_string(
		JSON.stringify(
			{
				"schema": 4,
				"faction": faction,
				"doctrines": doctrines,
				"insignia": insignia,
				"commendations": commendations,
				"recoveries": recoveries,
				"upgrades": upgrades
			}
		)
	)
	file.flush()
	var code = file.get_error()
	file.close()
	if code != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		DirAccess.remove_absolute(path + ".tmp")
		return _fail("Campaign hub choices could not be replaced.")
	return true


func _fail(message: String) -> bool:
	error = message
	return false


func apply_to_campaign(game):
	if game.restoring or not read_state(path_for(game)) or game.settings.mission_id.is_empty():
		return
	var player = game._get_human_player()
	if player == null or player.technology == null:
		return
	var catalog = load("res://source/match/research/TechnologyCatalog.gd")
	var doc_id = doctrines.get(player.faction, "")
	if not doc_id.is_empty() and doc_id not in player.technology.completed:
		if catalog.exclusion(doc_id, player.technology.completed).is_empty():
			player.technology.completed.append(doc_id)
	var list = upgrades.get(player.faction, [])
	for up_id in list:
		if up_id not in player.technology.completed:
			if catalog.exclusion(up_id, player.technology.completed).is_empty():
				player.technology.completed.append(up_id)
	for unit in player.get_children():
		if unit.is_in_group("units"):
			player.technology.apply_unit(unit)
	player.emit_changed()


static func path_for(game) -> String:
	var progress = load("res://source/match/campaign/CampaignProgress.gd")
	if "progress_path" in game and game.progress_path != progress.PATH:
		return game.progress_path + ".hub"
	return PATH


func record_debrief(game) -> bool:
	if game.result != "Victory" or game.campaign_hero == null or not game.campaign_hero.alive():
		return false
	var hero = game.campaign_hero.unit
	if hero.hp < hero.hp_max * .5 or not read_state(path_for(game)):
		return false
	var id = game.settings.mission_id
	if id not in load("res://source/match/campaign/CampaignCatalog.gd").operations():
		return false
	if id in commendations:
		return true
	commendations.append(id)
	faction = game._get_human_player().faction
	return save_state(path_for(game))


func record_recovered_wreck(unit) -> bool:
	var game = unit.find_parent("Match")
	if (
		game == null
		or game.restoring
		or game.settings.mission_id.is_empty()
		or unit.player != game._get_human_player()
		or unit.player.faction != "frontier"
	):
		return false
	if not read_state(path_for(game)):
		return false
	var id = game.settings.mission_id
	if id not in load("res://source/match/campaign/CampaignCatalog.gd").ORDER.frontier:
		return false
	if id in recoveries:
		return true
	recoveries.append(id)
	faction = "frontier"
	return save_state(path_for(game))
