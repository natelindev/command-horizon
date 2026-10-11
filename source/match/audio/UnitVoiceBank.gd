extends RefCounted

const CATALOG_PATH = "res://assets/audio/voices/catalog.json"
var _catalog = {}
var _variants = {}


func _init():
	_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)).factions


func announcer(faction, event_name):
	return _catalog.get(faction, _catalog.bastion).announcer.get(event_name, {}).duplicate()


func unit_line(unit, kind):
	var faction = unit.player.faction
	var roster = _catalog.get(faction, _catalog.bastion).units
	if not roster.has(unit.type):
		return {}
	var lines = roster[unit.type]
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


func accepted(line):
	# Only advance the variant when heard, not once per member of a box selection.
	if line.has("variant_key"):
		_variants[line.variant_key] = line.variant_index + 1
