extends RefCounted

const Rules = preload("res://source/match/combat/CombatRules.gd")


static func plan(game, player, units, contacts):
	var assets = units.filter(
		func(unit): return unit.type == "Worker" or unit.has_method("is_constructed")
	)
	var threats = []
	for contact in contacts:
		if not game.battlefield.is_observed(player, contact):
			continue
		var danger = INF
		for asset in assets:
			if not Rules.can_target(contact, asset):
				continue
			var distance = contact.global_position_yless.distance_to(asset.global_position_yless)
			var margin = distance - Rules.range_for(contact, asset)
			if margin > 6.0:
				continue
			var recent_fire = game.simulation_time - asset.last_enemy_damage_time <= 6.0
			danger = minf(danger, margin - (6.0 if recent_fire else 0.0))
		if is_finite(danger):
			threats.append({"target": contact, "danger": danger})
	threats.sort_custom(func(a, b): return a.danger < b.danger)
	var groups = []
	for threat in threats:
		var target = threat.target
		var group = null
		for candidate in groups:
			if (
				candidate.target.movement_domain == target.movement_domain
				and candidate.point.distance_to(target.global_position_yless) <= 8.0
			):
				group = candidate
				break
		if group == null:
			group = {"target": target, "point": target.global_position_yless, "count": 0}
			groups.append(group)
		group.count += 1
	var available = units.filter(
		func(unit): return unit.movement_speed > 0 and unit.attack_range != null
	)
	var assignments = []
	var assigned_groups = []
	# Difficulty changes how many simultaneous raids the commander coordinates.
	# Reconstruct plans from current observation; existing actions preserve their
	# last observed destination across fog and saves without retaining hidden units.
	var coordinated = 0
	for group in groups:
		if coordinated >= player.difficulty + 1:
			break
		var target = group.target
		var candidates = available.filter(func(unit): return _can_respond(unit, target))
		if candidates.is_empty():
			continue
		coordinated += 1
		candidates.sort_custom(func(a, b): return _score(a, target) < _score(b, target))
		var members = candidates.slice(0, mini(6, group.count * 2))
		assigned_groups.append({"point": group.point, "members": members})
		for unit in members:
			assignments.append({"unit": unit, "point": group.point, "target": target})
			available.erase(unit)
	return {
		"assignments": assignments,
		"threats": threats.map(func(threat): return threat.target),
		"groups": assigned_groups
	}


static func _can_respond(unit, target):
	if Rules.can_target(unit, target):
		return true
	# A Lancer can prepare its other weapon mode while moving to a known raid.
	return (
		unit.hp > 0
		and not unit.is_queued_for_deletion()
		and unit.type == "CombatRobot"
		and unit.player.faction == "helix"
	)


static func _score(unit, target):
	var travel = unit.global_position_yless.distance_to(target.global_position_yless)
	travel /= unit.movement_speed
	var damage_per_second = Rules.damage(unit, target) / unit.attack_interval
	var engagement = minf(10.0, target.hp / maxf(0.1, damage_per_second))
	return travel + engagement * 0.25
