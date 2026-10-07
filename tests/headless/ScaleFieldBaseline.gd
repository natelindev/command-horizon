# Test-only reference query from before observer hints, for comparable workload runs.
extends "res://source/match/combat/Battlefield.gd"


func is_observed(player, target):
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target.player == player:
		return true
	_refresh()
	var cell = _cell(target.global_position)
	var extent = ceili(_max_sight / CELL_SIZE) + 1
	var cells = _observers.get(player, {})
	for x in range(cell.x - extent, cell.x + extent + 1):
		for y in range(cell.y - extent, cell.y + extent + 1):
			for ally in cells.get(Vector2i(x, y), []):
				if can_observe(ally, target):
					return true
	return false
