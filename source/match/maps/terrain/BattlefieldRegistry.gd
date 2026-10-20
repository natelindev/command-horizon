extends RefCounted

# Authored battlefields pair a thin scene (`<Id>.tscn`, AuthoredBattlefield.gd)
# with a definition script (`<Id>.gd`, const DEFINITION) in one directory.
# Everything that needs a map's layout without loading its scene (facilities,
# previews, saves, metrics) asks this registry.

const ROOT = "res://source/match/maps/battlefields/"
const Layout = preload("res://source/match/maps/terrain/BattlefieldLayout.gd")
static var _layouts = {}


static func is_authored(map_path: String) -> bool:
	return map_path.begins_with(ROOT) and ResourceLoader.exists(_definition_path(map_path))


static func definition(map_path: String) -> Dictionary:
	if not is_authored(map_path):
		return {}
	return load(_definition_path(map_path)).DEFINITION


static func layout(map_path: String) -> Dictionary:
	if not is_authored(map_path):
		return {}
	if not _layouts.has(map_path):
		_layouts[map_path] = Layout.expand(definition(map_path))
	return _layouts[map_path]


static func revision(map_path: String) -> int:
	return definition(map_path).get("revision", 1)


static func _definition_path(map_path: String) -> String:
	return map_path.get_basename() + ".gd"
