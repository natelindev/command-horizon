# gdlint: disable=max-returns
extends RefCounted

const Parameters = preload("res://source/match/programs/LuaParameters.gd")
const Rules = preload("res://source/match/programs/VisualRules.gd")
const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const ROLES = ["Tank", "AdvancedTank", "CombatRobot", "RepairRobot", "Drone", "Helicopter"]
const ARMED = ["Tank", "AdvancedTank", "CombatRobot", "Helicopter"]
const REQUIREMENTS = ["movement", "attack", "repair"]
const API_VERSION = 1
const SOURCE_BYTES = 32768


static func preset(title, revision, config):
	return seal(
		{
			"id": identifier(title),
			"name": title,
			"version": revision,
			"mode": "preset",
			"api_version": API_VERSION,
			"config": config.duplicate(true),
			"source": "",
			"roles": ROLES.filter(func(role): return Library.compatible(config.preset, role)),
			"requirements": ["movement"],
			"parameter_schema": {},
			"test_notes": "Built-in preset."
		}
	)


static func lua(title, revision, source, roles, requirements, notes = ""):
	return seal(
		{
			"id": identifier(title),
			"name": title,
			"version": revision,
			"mode": "lua",
			"api_version": API_VERSION,
			"config": _script_config(),
			"source": source,
			"roles": roles.duplicate(),
			"requirements": requirements.duplicate(),
			"parameter_schema": {},
			"test_notes": notes
		}
	)


static func visual(title, revision, document, roles):
	var compiled = Rules.compile(document)
	var requirements = Rules.requirements(document)
	var result = lua(title, revision, compiled.get("source", ""), roles, requirements)
	result.mode = "visual"
	result.rules = document.duplicate(true)
	result.parameter_schema = Rules.PARAMETER_SCHEMA.duplicate(true)
	return seal(result)


static func is_script(value):
	return value.get("mode") in ["lua", "visual"]


static func _script_config():
	# Script behavior comes from its exact source. Keep the canonical envelope
	# independent of fresh preset defaults so existing pins and archives stay valid.
	return {"preset": "hold", "radius": 6.0, "retreat": 30, "return": 80, "priority": "nearest"}


static func identifier(title):
	return "program-" + title.sha256_text()


static func seal(value):
	value.source_hash = value.source.sha256_text()
	value.content_hash = digest(value)
	return value


static func digest(value):
	var content = value.duplicate(true)
	content.erase("content_hash")
	return JSON.stringify(_canonical(content)).sha256_text()


static func _canonical(value):
	if value is float and is_finite(value) and value == int(value):
		return int(value)
	if value is Array:
		return value.map(_canonical)
	if value is Dictionary:
		var result = {}
		for key in value:
			result[key] = _canonical(value[key])
		return result
	return value


static func valid_identity(value):
	return (
		value is Dictionary
		and value.get("name") is String
		and value.name == value.name.strip_edges()
		and not value.name.is_empty()
		and value.name.length() <= 40
		and not value.name.to_utf8_buffer().has(0)
		and (value.get("version") is int or value.get("version") is float)
		and is_finite(float(value.version))
		and value.version >= 1
		and value.version <= 1000000
		and value.version == int(value.version)
	)


static func validate(value):
	if not valid_identity(value):
		return false
	if value.size() != (14 if value.get("mode") == "visual" else 13):
		return false
	if value.get("id") != identifier(value.name) or value.get("api_version") != API_VERSION:
		return false
	if (
		not value.get("mode") in ["preset", "lua", "visual"]
		or not Library.validate(value.get("config"))
	):
		return false
	if not value.get("source") is String or not value.get("test_notes") is String:
		return false
	if value.test_notes.length() > 1000:
		return false
	if value.mode == "visual":
		if not Rules.validate(value.get("rules")).is_empty():
			return false
		if _canonical(value.get("parameter_schema")) != _canonical(Rules.PARAMETER_SCHEMA):
			return false
		if value.source != Rules.compile(value.rules).source:
			return false
		if value.get("requirements") != Rules.requirements(value.rules):
			return false
	elif value.mode == "lua":
		if not Parameters.valid(value.get("parameter_schema"), value.source):
			return false
	elif value.get("parameter_schema") != {}:
		return false
	if not _valid_list(value.get("roles"), ROLES):
		return false
	if not _valid_list(value.get("requirements"), REQUIREMENTS):
		return false
	if not "movement" in value.requirements:
		return false
	if is_script(value):
		var expected = _script_config()
		# Accept the new-default envelope too, without rewriting its sealed hash.
		if value.config.priority not in ["nearest", "effective"]:
			return false
		expected.priority = value.config.priority
		if _canonical(value.config) != _canonical(expected):
			return false
		var size = value.source.to_utf8_buffer().size()
		if size < 1 or size > SOURCE_BYTES or value.source.to_utf8_buffer().has(0):
			return false
		if not value.roles.all(func(role): return meets_requirements(value.requirements, role)):
			return false
	elif (
		value.source != ""
		or not value.roles.all(func(role): return Library.compatible(value.config.preset, role))
	):
		return false
	return (
		value.get("source_hash") == value.source.sha256_text()
		and value.get("content_hash") == digest(value)
	)


static func _valid_list(value, allowed):
	if not value is Array or value.is_empty() or value.size() > allowed.size():
		return false
	var seen = []
	for item in value:
		if not item in allowed or item in seen:
			return false
		seen.append(item)
	return true


static func meets_requirements(requirements, role):
	return (
		role in ROLES
		and (not "attack" in requirements or role in ARMED)
		and (not "repair" in requirements or role == "RepairRobot")
	)


static func compatible(value, role):
	return (
		role in value.roles
		and meets_requirements(value.requirements, role)
		and (is_script(value) or Library.compatible(value.config.preset, role))
	)


static func pin(value):
	return {
		"name": value.name,
		"version": int(value.version),
		"id": value.id,
		"content_hash": value.content_hash
	}
