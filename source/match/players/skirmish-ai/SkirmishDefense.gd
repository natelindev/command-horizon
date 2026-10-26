extends RefCounted

const Rules = preload("res://source/match/combat/CombatRules.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")


static func under_raid(game, player, units, contacts) -> bool:
	return not _find_threats(game, player, units, contacts, true).is_empty()


static func _find_threats(game, player, units, contacts, first_only = false) -> Array:
	var assets = units.filter(
		func(unit): return unit.type == "Worker" or unit.has_method("is_constructed")
	)
	var threats = []
	for contact in contacts:
		if contact.attack_range == null:
			continue
		if not game.battlefield.is_observed(player, contact):
			continue
		var danger = INF
		# Runtime load avoids Economy -> Labor -> Production -> Defense cycles.
		var reach = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd").threat_reach(
			contact, 6.0
		)
		var origin = contact.global_position_yless
		for asset in assets:
			if origin.distance_squared_to(asset.global_position_yless) > reach * reach:
				continue
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
			if first_only:
				return threats
	threats.sort_custom(func(a, b): return a.danger < b.danger)
	return threats


static func plan(game, player, units, contacts):
	var threats = _find_threats(game, player, units, contacts)
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
	# Difficulty changes how many simultaneous raids the commander coordinates
	# and how many defenders answer each one.
	# Reconstruct plans from current observation; existing actions preserve their
	# last observed destination across fog and saves without retaining hidden units.
	var profile = Difficulty.of(player.difficulty)
	var coordinated = 0
	for group in groups:
		if coordinated >= profile.task_groups:
			break
		var target = group.target
		var candidates = available.filter(func(unit): return _can_respond(unit, target))
		if candidates.is_empty():
			continue
		coordinated += 1
		# Compute expensive combat and speed modifiers once per candidate, not
		# twice per comparison throughout the sort.
		var scores = {}
		for candidate in candidates:
			scores[candidate] = _score(candidate, target)
		candidates.sort_custom(func(a, b): return scores[a] < scores[b])
		var members = candidates.slice(0, mini(profile.defense_responders, group.count * 2))
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
