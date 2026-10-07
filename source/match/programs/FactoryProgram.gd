extends RefCounted

const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
const Runtime = preload("res://source/match/programs/LuaRuntime.gd")
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
	if Record.is_script(entry) and not Runtime.available():
		return hold("Lua is unavailable on this installation. New unit received Hold.")
	return {
		"record": entry.duplicate(true),
		"title": "%s · v%d" % [entry.name, entry.version],
		"config": entry.config.duplicate(true),
		"notice": ""
	}


static func apply_to(unit, snapshot_value):
	if unit.program == null or snapshot_value.is_empty():
		return
	var value = snapshot_value
	if (
		not Library.validate(value.get("config"))
		or not Library.compatible(value.config.preset, unit.type)
	):
		value = hold("Invalid or incompatible queued program. New unit received Hold.")
	var applied = false
	if value.has("record"):
		var entry = value.record
		if Record.validate(entry) and Record.compatible(entry, unit.type):
			var result = load("res://source/match/programs/ProgramApplication.gd").apply(
				entry, [unit], unit.player
			)
			applied = result.ok
		if not applied:
			value = hold("Queued program could not start. New unit received Hold.")
	if not applied:
		unit.program.configure(value.config, value.title)
		unit.program.run()
	if value.notice != "":
		unit.set_meta("program_fallback_reason", value.notice)
		unit.program.set_status(unit.program.mode, value.notice)
		var game = unit._match
		if "hud" in game and game.hud != null and unit.is_in_group("controlled_units"):
			game.hud.show_notice(value.notice)
