extends RefCounted


static func select(candidate, ground_count, enabled):
	# Retain the existing Coordination exception and nine-ground-unit gate.
	if enabled and candidate.get("id", "coordination") != "coordination" and ground_count < 9:
		return {}
	return candidate
