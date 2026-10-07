extends RefCounted

const Record = preload("res://source/match/programs/ProgramRecord.gd")
const Runtime = preload("res://source/match/programs/LuaRuntime.gd")


static func preview(entry, selection, player):
	var result = {"eligible": [], "incompatible": 0, "unready": 0, "unavailable": 0}
	var seen = []
	for unit in selection:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			result.unavailable += 1
		elif unit not in seen:
			seen.append(unit)
			if (
				unit.player != player
				or unit.program == null
				or not Record.compatible(entry, unit.type)
			):
				result.incompatible += 1
			elif not unit.program.ready_to_run():
				result.unready += 1
			else:
				result.eligible.append(unit)
	return result


static func apply(entry, selection, player):
	if not Record.validate(entry):
		return {"ok": false, "error": "Invalid program record. Current orders were preserved."}
	var targets = preview(entry, selection, player)
	if targets.eligible.is_empty():
		return {"ok": false, "error": "No compatible selected unit has an active chip."}
	# Prepare every VM before changing any order. No yields between prepare and commit.
	var prepared = []
	for unit in targets.eligible:
		var runtime = null
		if Record.is_script(entry):
			runtime = Runtime.new()
			var result = runtime.compile_source(entry.source)
			if not result.ok:
				return {"ok": false, "error": result.error}
		prepared.append(runtime)
	for index in range(targets.eligible.size()):
		targets.eligible[index].program.apply_prepared(entry, prepared[index])
	return {"ok": true, "applied": prepared.size(), "skipped": selection.size() - prepared.size()}
