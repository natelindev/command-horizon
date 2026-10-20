extends RefCounted

const CATALOG_PATH = "res://assets/audio/voices/catalog.json"
# Roles without a recorded cast speak with the closest recorded role's voice.
const VOICE_ALIASES = {
	"MercenaryWarden": "AssaultInfantry",
	"MercenaryRanger": "SniperInfantry",
	"MercenaryLancer": "RocketInfantry",
	"Fighter": "Helicopter",
	"Bomber": "Helicopter",
	"AntiAirVehicle": "Tank",
}
var _catalog = {}
var _variants = {}


func _init():
	_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)).factions


func announcer(faction, event_name):
	return _catalog.get(faction, _catalog.bastion).announcer.get(event_name, {}).duplicate()


func unit_line(unit, kind):
	var faction = unit.player.faction
	var roster = _catalog.get(faction, _catalog.bastion).units
	var role = voice_role(unit.type)
	if not roster.has(role):
		return {}
	var lines = roster[role]
	if not lines.has(kind):
		kind = "move"
	var key = "%s:%s:%s" % [faction, unit.type, kind]
	var variants = lines[kind]
	var index = _variants.get(key, 0) % variants.size()
	var result = variants[index].duplicate()
	result.speaker = load("res://source/match/FactionCatalog.gd").title(faction, unit.type)
	result.variant_key = key
	result.variant_index = index
	return result


static func voice_role(unit_type):
	return VOICE_ALIASES.get(unit_type, unit_type)


func accepted(line):
	# Only advance the variant when heard, not once per member of a box selection.
	if line.has("variant_key"):
		_variants[line.variant_key] = line.variant_index + 1
