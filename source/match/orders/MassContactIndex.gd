extends RefCounted

## Only light bodies participate in heavy/light contacts. Index them once per
## physics frame instead of reading every neighboring tank's derived stats.
const CELL = 3.0


static func nearby(game, point: Vector3, reach: float) -> Array:
	var frame = Engine.get_physics_frames()
	var cache = game.get_meta("mass_contact_index", {"frame": -1, "cells": {}})
	var cells = cache.cells
	if cache.frame != frame:
		cache.frame = frame
		cells.clear()
		game.set_meta("mass_contact_index", cache)
		for unit in game.get_tree().get_nodes_in_group("light_crowd_units"):
			if (
				not is_instance_valid(unit)
				or unit.is_queued_for_deletion()
				or unit.hp <= 0
				or unit.has_meta("garrison_host")
			):
				continue
			var position = unit.global_position
			var key = Vector2i(floori(position.x / CELL), floori(position.z / CELL))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(unit)
	# Pure vehicle cohorts still ask for contacts on every moving heavy body.
	# An empty published index cannot contribute a contact in any query cell.
	if cells.is_empty():
		return []
	var result = []
	var left = floori((point.x - reach) / CELL)
	var right = floori((point.x + reach) / CELL)
	var top = floori((point.z - reach) / CELL)
	var bottom = floori((point.z + reach) / CELL)
	for x in range(left, right + 1):
		for z in range(top, bottom + 1):
			result.append_array(cells.get(Vector2i(x, z), []))
	return result
