extends "res://tests/headless/UnitAnimationRegression.gd"


class GenericStructure:
	extends Node3D
	var type := "CommandLab"
	var complete := true

	func is_constructed():
		return complete


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		for player in _players:
			player.indexed_rosters = true
		var player = _players[0]
		var generic := GenericStructure.new()
		player.add_child(generic)
		var plant = _spawn("PowerPlant", 0, Vector3(25, 0, 25))
		var lab = _spawn("CommandLab", 0, Vector3(30, 0, 30))
		_spawn("Tank", 0, Vector3(35, 0, 35))
		_compare_all()
		var rebuilds: int = player.roster_rebuilds
		for iteration in 30:
			_compare_all()
		_check(player.roster_rebuilds == rebuilds, "Stable membership rebuilt its index")
		# Completion and mutable generic roles are live, without a tree change.
		lab._construction_progress = .4
		generic.complete = false
		_compare_all()
		lab._construction_progress = 1.0
		generic.complete = true
		generic.type = "Barracks"
		_compare_all()
		if faction == "helix":
			var ability = plant.abilities.get_ability("power_overdrive")
			ability.is_active = true
			_compare_all()
			ability.is_active = false
			_compare_all()
		# Capture, reordering, direct removal and queued deletion must be visible
		# immediately; an earlier iteration snapshot must remain unchanged.
		var snapshot: Array = player.live_units()
		plant.reparent(_players[1])
		_check(plant in snapshot, "Capture mutated a retained iteration snapshot")
		_compare_all()
		player.move_child(lab, 0)
		_compare_all()
		generic.free()
		_compare_all()
		plant.queue_free()
		lab.queue_free()
		_compare_all()
		await _frames(3)
		_compare_all()
		await _close()
	for message in _errors:
		push_error(message)
	print("Player roster regression: %d failures across 3 factions" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _compare_all():
	for player in _players:
		var live := []
		var structures := 0
		var supply := 0
		var demand := 0
		var completed := {}
		for child in player.get_children():
			if child.is_queued_for_deletion():
				continue
			if "type" in child:
				live.append(child)
			if not child.has_method("is_constructed"):
				continue
			structures += 1
			if child.is_constructed():
				completed[child.type] = true
				supply += Catalog.POWER_SUPPLY.get(child.type, 0)
				demand += Catalog.POWER_USAGE.get(child.type, 0)
				if player.faction == "helix" and child.type == "PowerPlant":
					var support = load("res://source/match/combat/HelixSupport.gd")
					if support.requested(child):
						demand += support.OVERDRIVE_DEMAND
		_check(player.live_units() == live, "Live roster differs from current child order")
		_check(player.structure_count() == structures, "Structure count differs")
		_check(player.power_totals() == Vector2i(supply, demand), "Live power state differs")
		for role in [
			"CommandCenter", "CommandLab", "PowerPlant", "Barracks", "Tank", "RepairDepot"
		]:
			_check(
				player.has_completed_structure(role) == completed.has(role),
				"Completed structure lookup differs: " + role
			)
