# gdlint: disable=max-returns
extends RefCounted

## Portable, inert map data. Documents never contain resource paths or scripts.
const VERSION = 1
const MAP = "res://source/match/maps/ScenarioMap.tscn"
const DIRECTORY = "user://scenarios/"
const MAX_BYTES = 524288
const MAX_ITEMS = 256
const KITS = {
	"sandstone":
	{
		"name": "Sandstone shelf",
		"model": "desert/SandstoneShelfA",
		"scale": .45,
		"radius": 3.0,
		"height": 2.2
	},
	"basalt":
	{
		"name": "Basalt columns",
		"model": "volcanic/BasaltColumn",
		"scale": .65,
		"radius": 2.0,
		"height": 3.5
	},
	"granite":
	{
		"name": "Granite boulder",
		"model": "temperate/GraniteBoulderA",
		"scale": .8,
		"radius": 2.0,
		"height": 2.0
	},
	"container":
	{
		"name": "Freight container",
		"model": "quarry/QuarryContainerA",
		"scale": .7,
		"radius": 1.7,
		"height": 2.0
	},
	"freight":
	{
		"name": "Freight shelter",
		"model": "desert/AbandonedFreightBay",
		"scale": .8,
		"radius": 2.9,
		"height": 3.5
	},
	"relay_mast":
	{"name": "Relay mast", "model": "RelaySubstation", "scale": .5, "radius": 2.3, "height": 5.0},
	"tree":
	{
		"name": "Desert acacia",
		"model": "desert/DesertAcacia",
		"scale": .7,
		"radius": 1.0,
		"height": 3.0
	},
}
const TOOLS = ["select", "spawn", "materials", "electronics", "refinery", "data_relay"]
var error := ""


static func blank() -> Dictionary:
	return canonical(
		{
			"version": VERSION,
			"title": "New battlefield",
			"size": [96, 96],
			"biome": "desert",
			"spawns": [{"x": 14, "z": 14, "yaw": 180}, {"x": 82, "z": 82, "yaw": 0}],
			"items":
			[
				{"kind": "materials", "x": 14, "z": 24, "yaw": 0, "amount": 1600},
				{"kind": "electronics", "x": 24, "z": 14, "yaw": 0, "amount": 800},
				{"kind": "materials", "x": 82, "z": 72, "yaw": 180, "amount": 1600},
				{"kind": "electronics", "x": 72, "z": 82, "yaw": 180, "amount": 800},
			]
		}
	)


static func canonical(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.version = int(result.version)
	result.size = [int(result.size[0]), int(result.size[1])]
	for entry in result.spawns + result.items:
		entry.x = float(entry.x)
		entry.z = float(entry.z)
		entry.yaw = float(entry.yaw)
		if entry.has("amount"):
			entry.amount = int(entry.amount)
	return result


func validate(value) -> bool:
	error = ""
	if not _fields(value, ["version", "title", "size", "biome", "spawns", "items"]):
		return _fail("Invalid battlefield document.")
	if (
		value.version != VERSION
		or not value.title is String
		or value.title.strip_edges().is_empty()
	):
		return _fail("Unsupported battlefield version or missing title.")
	if value.title.length() > 80 or value.biome not in ["desert", "temperate", "volcanic"]:
		return _fail("Invalid battlefield title or terrain.")
	if not value.size is Array or value.size.size() != 2:
		return _fail("Invalid battlefield dimensions.")
	for axis in value.size:
		if not _integer(axis, 48, 192) or int(axis) % 8 != 0:
			return _fail("Battlefield dimensions must be multiples of 8 between 48 and 192.")
	if not value.spawns is Array or value.spawns.size() not in [2, 4]:
		return _fail("A battlefield needs 2 or 4 starting positions.")
	if not value.items is Array or value.items.size() > MAX_ITEMS:
		return _fail("A battlefield supports up to 256 pieces.")
	var occupied := []
	for spawn in value.spawns:
		if not _fields(spawn, ["x", "z", "yaw"]) or not _position(spawn, value.size, 7.0):
			return _fail("Starting positions need 7 m of clearance from the map edge.")
		for point in occupied:
			if Vector2(spawn.x, spawn.z).distance_to(point) < 16.0:
				return _fail("Starting positions must be at least 16 m apart.")
		occupied.append(Vector2(spawn.x, spawn.z))
	for item in value.items:
		if not _fields(item, ["kind", "x", "z", "yaw", "amount"]):
			return _fail("Invalid battlefield piece.")
		if (
			item.kind not in KITS
			and item.kind not in ["materials", "electronics", "refinery", "data_relay"]
		):
			return _fail("Unknown battlefield piece.")
		var radius: float = KITS.get(item.kind, {}).get("radius", 1.5)
		if not _position(item, value.size, radius + 1.0):
			return _fail("A piece extends beyond the map edge.")
		if not _integer(item.amount, 0, 10000):
			return _fail("Deposit amounts must be whole numbers up to 10000.")
		if item.kind in ["materials", "electronics"] and item.amount < 1:
			return _fail("A deposit needs at least 1 resource.")
		if item.kind not in ["materials", "electronics"] and item.amount != 0:
			return _fail("Only deposits can contain resources.")
		for spawn in occupied:
			if Vector2(item.x, item.z).distance_to(spawn) < radius + 6.0:
				return _fail("Keep pieces clear of starting headquarters.")
	return true


static func site_definitions(document: Dictionary) -> Array:
	var result := []
	for item in document.get("items", []):
		if item.kind in ["refinery", "data_relay"]:
			result.append(
				{
					"kind": item.kind,
					"position": Vector2(item.x, item.z),
					"name": "Tech Refinery" if item.kind == "refinery" else "Data Relay"
				}
			)
	return result


func write_document(filename: String, document: Dictionary) -> bool:
	if not validate(document) or not _safe_name(filename):
		return false
	var text := JSON.stringify(document, "\t", true) + "\n"
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _fail("Battlefield file is too large.")
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		return _fail("Could not create the battlefield folder.")
	var path := DIRECTORY + filename + ".rtsmap"
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _fail("Could not write the battlefield file.")
	file.store_string(text)
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if not written or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return _fail("Could not save the battlefield file.")
	return true


func read_document(filename: String) -> Dictionary:
	error = ""
	if not _safe_name(filename):
		return {}
	var file := FileAccess.open(DIRECTORY + filename + ".rtsmap", FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		_fail("Could not read the battlefield file.")
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not validate(json.data):
		if error.is_empty():
			_fail("Invalid battlefield file.")
		return {}
	return canonical(json.data)


static func files() -> Array:
	var result := []
	if not DirAccess.dir_exists_absolute(DIRECTORY):
		return result
	for filename in DirAccess.get_files_at(DIRECTORY):
		if filename.ends_with(".rtsmap"):
			result.append(filename.trim_suffix(".rtsmap"))
	result.sort()
	return result


func _safe_name(filename: String) -> bool:
	if filename.is_empty() or filename.length() > 48:
		return _fail("Choose a filename of 1–48 letters, numbers, spaces, hyphens or underscores.")
	for character in filename:
		if (
			not character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789 _-"
			and character.unicode_at(0) < 128
		):
			return _fail("Use letters, numbers, spaces, hyphens or underscores in filenames.")
	return filename == filename.strip_edges() or _fail("Remove spaces around the filename.")


func _position(value: Dictionary, bounds: Array, margin: float) -> bool:
	return (
		_number(value.x)
		and _number(value.z)
		and _number(value.yaw)
		and value.x >= margin
		and value.x <= bounds[0] - margin
		and value.z >= margin
		and value.z <= bounds[1] - margin
		and absf(value.yaw) <= 360.0
	)


static func _fields(value, fields: Array) -> bool:
	return (
		value is Dictionary
		and value.size() == fields.size()
		and fields.all(func(field): return value.has(field))
	)


static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(value)


static func _integer(value, low: int, high: int) -> bool:
	return _number(value) and value == int(value) and value >= low and value <= high


func _fail(message: String) -> bool:
	error = message
	return false
