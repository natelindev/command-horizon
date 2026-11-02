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
var faction = "bastion"
var doctrines = {}
var insignia = []
var commendations = []
var recoveries = []
var error = ""


func read_state(path = PATH) -> bool:
	faction = "bastion"
	doctrines.clear()
	insignia.clear()
	commendations.clear()
	recoveries.clear()
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
	return true


func _valid(value) -> bool:
	if (
		not value is Dictionary
		or (
			(value.get("schema") == 1 and value.size() != 4)
			or (value.get("schema") == 2 and value.size() != 5)
			or (value.get("schema") == 3 and value.size() != 6)
			or (value.get("schema") != 1 and value.get("schema") != 2 and value.get("schema") != 3)
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
	if value.get("schema") == 3:
		if not value.get("recoveries") is Array:
			return false
		var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
		var recovered = []
		for id in value.recoveries:
			if not id is String or id not in catalog.ORDER.frontier or id in recovered:
				return false
			recovered.append(id)
	return true


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
				"schema": 3,
				"faction": faction,
				"doctrines": doctrines,
				"insignia": insignia,
				"commendations": commendations,
				"recoveries": recoveries
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
	var id = doctrines.get(player.faction, "")
	if id.is_empty() or id in player.technology.completed:
		return
	var catalog = load("res://source/match/research/TechnologyCatalog.gd")
	if not catalog.exclusion(id, player.technology.completed).is_empty():
		return
	player.technology.completed.append(id)
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
