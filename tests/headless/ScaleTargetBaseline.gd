extends "res://source/match/combat/Battlefield.gd"


# Test-only reference: preserve the original full legality scan for comparisons.
func fireable_targets(source):
	return get_tree().get_nodes_in_group("units").filter(
		func(candidate): return can_fire(source, candidate)
	)
