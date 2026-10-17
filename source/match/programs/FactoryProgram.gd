extends RefCounted

const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
const ROLES = ["Tank", "CombatRobot", "RepairRobot", "AdvancedTank", "Drone", "Helicopter"]


static func hold(reason = ""):
	return {"title": "Hold · built-in", "config": Library.defaults(), "notice": reason}


static func snapshot(pin, role, path = Library.PATH):
	if not role in ROLES:
		return {}
	if pin.is_empty():
		return hold()
	if not pin.get("name") is String or not pin.get("version") is int:
		return hold("Invalid factory program. New unit received Hold.")
	var library = Library.new()
	if not library.read_library(path):
		return hold("Program library unavailable. New unit received Hold.")
	var entry = library.find_version(pin.name, pin.version)
	if entry == null or not Record.validate(entry):
		return hold(
			"Saved program %s · v%d unavailable. New unit received Hold." % [pin.name, pin.version]
		)
	if (
		(pin.has("id") and pin.id != entry.id)
		or (pin.has("content_hash") and pin.content_hash != entry.content_hash)
	):
		return hold("Saved version has changed. New unit received Hold.")
	if not Record.compatible(entry, role):
		return hold("Saved program is incompatible with this unit role. New unit received Hold.")
	if Record.is_script(entry):
		return hold("Legacy scripted factory orders were replaced by built-in behavior.")
	return {
		"record": entry.duplicate(true),
		"title": "%s · v%d" % [entry.name, entry.version],
		"config": entry.config.duplicate(true),
		"notice": ""
	}


static func apply_to(unit, _snapshot_value):
	# Production delivers ordinary units. No VM, decision loop or library lookup
	# is attached; rally points and the five built-in behaviors own their orders.
	if unit.program != null:
		unit.program.manual_override()
