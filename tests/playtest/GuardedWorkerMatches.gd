extends "res://tests/playtest/CautiousRelayMatches.gd"


func _play_case(index):
	safety_policy_path = "res://tests/playtest/reference/GuardedReassignmentPolicy.gd"
	safety_policy_id = "spaced_retreat_guarded_alternative"
	await super(index)
