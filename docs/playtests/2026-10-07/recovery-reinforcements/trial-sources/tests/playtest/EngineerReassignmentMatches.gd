extends "res://tests/playtest/EngineerSafetyMatches.gd"


func _run():
	safety_policy_path = "res://tests/playtest/reference/EngineerReassignmentPolicy.gd"
	safety_policy_id = "spaced_retreat_safe_alternative"
	await super()


func _economy():
	super()
	if (
		archive_prefix != ""
		and engineer_safety.episodes.any(func(episode): return episode.get("alternative", false))
	):
		_archive_progress("worker_alternative")
