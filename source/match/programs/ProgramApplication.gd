extends RefCounted

const Record = preload("res://source/match/programs/ProgramRecord.gd")


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
	if entry.mode != "preset":
		return {"ok": false, "error": "Scripted unit orders have been replaced by fixed behaviors."}
	for unit in targets.eligible:
		unit.program.apply_prepared(entry, null)
	return {
		"ok": true,
		"applied": targets.eligible.size(),
		"skipped": selection.size() - targets.eligible.size()
	}
