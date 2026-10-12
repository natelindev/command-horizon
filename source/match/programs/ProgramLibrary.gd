# gdlint: disable=max-returns
extends RefCounted

const PATH = "user://program-library.json"
const PRESETS = [
	"hold",
	"guard",
	"escort",
	"patrol",
	"standoff",
	"strike_return",
	"fire_support",
	"scout_patrol",
	"escort_repair",
	"hold_service"
]
const SPECIALISTS = ["standoff", "strike_return", "fire_support"]
const ROLES = {
	"standoff": ["Tank", "AdvancedTank"],
	"strike_return": ["Helicopter"],
	"fire_support": ["CombatRobot", "AdvancedTank"],
	"scout_patrol": ["Drone"],
	"escort_repair": ["RepairRobot"],
	"hold_service": ["RepairRobot"],
}
const TITLES = {
	"hold": "Hold position",
	"guard": "Guard area",
	"escort": "Escort ally",
	"patrol": "Patrol route",
	"standoff": "Standoff armor",
	"strike_return": "Strike & return",
	"fire_support": "Fire support",
	"scout_patrol": "Scout route",
	"escort_repair": "Escort & repair",
	"hold_service": "Service area",
}
const BEHAVIORS = {
	"standoff": "guard",
	"strike_return": "guard",
	"fire_support": "guard",
	"scout_patrol": "patrol",
	"escort_repair": "escort",
	"hold_service": "guard"
}
const DESCRIPTIONS = {
	"guard": "Guard the area; return fire at visible attackers without outside pursuit.",
	"standoff": "Preserve 55–80% weapon-range spacing inside your assigned area.",
	"strike_return":
	"One shot per pass, then regroup and wait for cooldown. Requires area and safe point.",
	"fire_support": "Occupy the assigned point; fire inside the sector without pursuit.",
	"scout_patrol": "Scout between two assigned waypoints; retreat uses your chosen safe point.",
	"escort_repair": "Follow a chosen ally and repair eligible units inside the escort area.",
	"hold_service": "Repair damaged allies inside the assigned service area.",
}
const PRIORITIES = ["nearest", "weakest", "armor", "effective"]
const MAX_VERSIONS = 128
const MAX_FILE_BYTES = 8 * 1024 * 1024
var versions = []
var error = ""


static func defaults(preset = "hold"):
	return {"preset": preset, "radius": 6.0, "retreat": 30, "return": 80, "priority": "effective"}


static func validate(config):
	if not config is Dictionary or config.size() != 5:
		return false
	if not config.get("preset") in PRESETS or not config.get("priority") in PRIORITIES:
		return false
	for key in ["radius", "retreat", "return"]:
		if not config.get(key) is float and not config.get(key) is int:
			return false
		if not is_finite(float(config[key])):
			return false
	return (
		config.radius >= 3
		and config.radius <= 12
		and config.retreat >= 10
		and config.retreat <= 60
		and config["return"] >= 40
		and config["return"] <= 95
		and config["return"] >= config.retreat + 10
		and int(config.retreat) % 5 == 0
		and int(config["return"]) % 5 == 0
		and config.retreat == int(config.retreat)
		and config["return"] == int(config["return"])
	)


func read_library(path = PATH):
	error = ""
	versions.clear()
	if not FileAccess.file_exists(path):
		return true
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		error = "Could not read the program library (maximum 8 MiB)."
		return false
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "Program library contains invalid JSON. Existing file was preserved."
		return false
	var data = parser.data
	if (
		not data is Dictionary
		or (
			data.get("schema") != 1
			and data.get("schema") != 2
			and data.get("schema") != 3
			and data.get("schema") != 4
		)
		or not data.get("versions") is Array
	):
		error = "Unsupported program library format."
		return false
	if data.versions.size() > MAX_VERSIONS:
		error = "Program library exceeds 128 saved versions."
		return false
	var record = _record_type()
	var identities = {}
	var loaded = []
	for raw in data.versions:
		if not record.valid_identity(raw):
			error = "A saved program name or version is invalid."
			return false
		var entry = raw.duplicate(true)
		if data.schema == 1 and not entry.has("mode") and validate(entry.get("config")):
			entry = record.preset(entry.name, int(entry.version), entry.config)
		# JSON stores whole numbers as floats. Normalize before hashing records.
		entry.version = int(entry.version)
		if not record.validate(entry):
			error = "A saved program is invalid or changed; the library was left unchanged."
			return false
		var identity = JSON.stringify([entry.id, entry.version])
		if identities.has(identity):
			error = "Duplicate program version. Existing file was preserved."
			return false
		identities[identity] = true
		loaded.append(entry)
	versions = loaded
	return true


func save_version(title, config, path = PATH):
	if not validate(config):
		error = "Use valid preset thresholds."
		return null
	var record = _record_type()
	return save_record(record.preset(title.strip_edges(), 1, config), path)


func save_record(draft, path = PATH):
	# Every writer re-reads: two open editors must not lose each other's versions.
	if not read_library(path):
		return null
	var record = _record_type()
	if not record.validate(draft):
		error = "Use a name of 1–40 characters, supported roles and a valid program record."
		return null
	if versions.size() >= MAX_VERSIONS:
		error = "Library full (128 versions)."
		return null
	var entry = draft.duplicate(true)
	entry.version = 1
	for previous in versions:
		if previous.id == entry.id:
			entry.version = maxi(entry.version, int(previous.version) + 1)
	if entry.version > 1000000:
		error = "Program version limit reached. Choose another name."
		return null
	record.seal(entry)
	var updated = versions.duplicate(true)
	updated.append(entry)
	var serialized = JSON.stringify({"schema": 4, "versions": updated}, "\t")
	if serialized.to_utf8_buffer().size() > MAX_FILE_BYTES:
		error = "Program library exceeds 8 MiB. Existing versions were preserved."
		return null
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "Could not save the program library."
		return null
	file.store_string(serialized)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, path) != OK:
		error = "Could not replace the program library; existing versions were preserved."
		return null
	versions = updated
	return entry.duplicate(true)


func find_version(title, revision):
	for entry in versions:
		if entry.name == title and int(entry.version) == revision:
			return entry.duplicate(true)
	return null


static func compatible(preset, role):
	return (
		preset in PRESETS
		and (
			role
			in ROLES.get(
				preset,
				["Tank", "AdvancedTank", "CombatRobot", "RepairRobot", "Drone", "Helicopter"]
			)
		)
	)


static func behavior(preset):
	return BEHAVIORS.get(preset, preset)


func _record_type():
	return load("res://source/match/programs/ProgramRecord.gd")
