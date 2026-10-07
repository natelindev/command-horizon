extends "res://tests/playtest/EngineerReassignmentMatches.gd"


func _run():
	conventional_recovery_enabled = true
	await super()


func _command():
	super()
	metrics.conventional_recovery = conventional_recovery.episodes
	for unit in conventional_protected:
		_check(
			is_instance_of(unit.action, conventional_recovery.Recover),
			"Commander replaced conventional treatment"
		)
		metrics.conventional_control_checks = metrics.get("conventional_control_checks", 0) + 1
	if archive_prefix != "":
		if not conventional_protected.is_empty():
			_archive_progress("infantry_recovery")
		if conventional_recovery.episodes.any(func(episode): return episode.result == "ready"):
			_archive_progress("infantry_ready")
