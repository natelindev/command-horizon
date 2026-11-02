extends RefCounted

const CATALOG_PATH = "res://assets/audio/voices/catalog.json"
const Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")
const ORDER_KINDS = ["select", "move", "attack", "gather", "construct", "repair", "stop"]
var _catalog = {}
# Camp mercenaries are neutral hires: one cast voice each, whichever army pays them.
var _mercenaries = {}
var _variants = {}


func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_catalog = data.factions
	_mercenaries = data.get("mercenaries", {})


func announcer(faction, event_name):
	return _catalog.get(faction, _catalog.bastion).announcer.get(event_name, {}).duplicate()


func role_lines(faction, role):
	if role in Mercenaries.ROLES:
		return _mercenaries.get(role, {})
	return _catalog.get(faction, _catalog.bastion).units.get(role, {})


func order_streams(faction):
	var paths = []
	var roles = _catalog.get(faction, _catalog.bastion).units.values() + _mercenaries.values()
	for lines in roles:
		for kind in ORDER_KINDS:
			for line in lines.get(kind, []):
				paths.append(line.stream)
	return paths


func unit_line(unit, kind):
	var faction = unit.player.faction
	var lines = role_lines(faction, unit.type)
	if lines.is_empty():
		return {}
	if not lines.has(kind):
		return {}
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
