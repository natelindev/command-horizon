extends RefCounted

const Players = preload("res://source/match/Players.gd")

const MIN_MATCH_TIME = 150.0
const PERSISTENCE = 18.0
const HOME_BASE_RADIUS = 35.0


static func evaluates_as_hopeless(game, player, units: Array) -> bool:
	if game == null or game.simulation_time < MIN_MATCH_TIME:
		return false
	if units.is_empty():
		return true

	# If active allies are still in fighting condition, stay to support them.
	var players = game.get_tree().get_nodes_in_group("players")
	var allies = players.filter(
		func(other):
			return (
				other != player
				and player.is_allied_with(other)
				and game._defeat_timers.get(other, 60.0) > 0.0
			)
	)
	for ally in allies:
		var ally_combat = (
			ally
			. live_units()
			. filter(func(u): return u.attack_range != null and not u.is_queued_for_deletion())
			. size()
		)
		if ally_combat >= 4:
			return false

	var combat_units = units.filter(
		func(u): return u.attack_range != null and not u.is_queued_for_deletion()
	)
	var combat_count = combat_units.size()
	var has_hq = (
		player.has_completed_structure("CommandCenter")
		or units.any(func(u): return u.type == "CommandCenter" and not u.is_queued_for_deletion())
	)
	var workers = units.filter(
		func(u): return u.type == "Worker" and not u.is_queued_for_deletion()
	)

	# Case 1: Paralyzed Command & Economy
	# No HQ, no workers (or insufficient resources to rebuild), and no combat army.
	if not has_hq:
		var can_afford_hq = player.resource_a >= 80 and player.resource_b >= 20
		if (workers.is_empty() or not can_afford_hq) and combat_count <= 1:
			return true

	# Count adversary combat strength
	var enemies = players.filter(
		func(other):
			return not player.is_allied_with(other) and game._defeat_timers.get(other, 60.0) > 0.0
	)
	var enemy_combat_count = 0
	for enemy in enemies:
		enemy_combat_count += (
			enemy
			. live_units()
			. filter(func(u): return u.attack_range != null and not u.is_queued_for_deletion())
			. size()
		)

	# If enemies have no significant military either, do not surrender.
	if enemy_combat_count < 6:
		return false

	# Check whether original starting base is still intact
	var home_intact = _is_home_base_intact(game, player, units)

	# Case 2: Stranded Remnant / Secret Outpost Without Hope
	# Original base destroyed, AI has at most 1 combat unit, no active production
	# facilities or bankrupt, against an overwhelming enemy army.
	if not home_intact and combat_count <= 1:
		var has_active_factory = (
			player.has_completed_structure("Barracks")
			or player.has_completed_structure("VehicleFactory")
			or player.has_completed_structure("AircraftFactory")
		)
		var has_factory_income = player.resource_a >= 40
		if (not has_active_factory or not has_factory_income) and enemy_combat_count >= 8:
			return true

	# Case 3: Total Wipeout
	# 0 combat units, tiny population (<= 3), home base fallen, against a large force (>= 10).
	if not home_intact and combat_count == 0 and units.size() <= 3 and enemy_combat_count >= 10:
		return true

	return false


static func _is_home_base_intact(game, player, units: Array) -> bool:
	if not "map" in game or game.map == null:
		return true
	var starts = game.map.find_child("SpawnPoints")
	if starts == null or starts.get_child_count() <= player.start_index():
		return true
	var home_pos = starts.get_child(player.start_index()).position
	for unit in units:
		if (
			unit.has_method("is_constructed")
			and not unit.is_queued_for_deletion()
			and unit.global_position.distance_to(home_pos) <= HOME_BASE_RADIUS
		):
			return true
	return false
