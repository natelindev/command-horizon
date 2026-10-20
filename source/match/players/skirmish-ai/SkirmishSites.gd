extends RefCounted

const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const Infantry = preload("res://source/match/BastionCatalog.gd")
const Production = preload("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
const Composition = preload("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
# Camps only accept their exclusive roster; the commander hires the anti-armor Lancer.
const CAMP_ROLE = "MercenaryLancer"


static func command(game, player, units, available, observed):
	var sites = Sites.sites(game)
	if sites.is_empty() or Production.under_raid(game, player, units):
		return []
	var soldiers = available.filter(
		func(unit): return Infantry.is_infantry(unit.type) and unit.hp >= unit.hp_max * .65
	)
	# Keep an opening screen at home; assign one infantry detachment rather
	# than sending the whole force away from engineers to a public landmark.
	if soldiers.size() < 4:
		return []
	for unit in soldiers:
		var reference = unit.get_meta("site_capture") if unit.has_meta("site_capture") else null
		var target = reference.get_ref() if reference is WeakRef else null
		if is_instance_valid(target) and target.player != player and _safe(target, observed):
			_order(unit, target)
			return [unit]
	var choices = sites.filter(func(site): return site.player != player and _safe(site, observed))
	var best = null
	var chosen = null
	var score = INF
	for site in choices:
		for unit in soldiers:
			var route = Utils.Match.Unit.Movement.path_distance_to(unit, site.position, 5.0)
			var value = route + {"refinery": 0.0, "mercenary": 8.0, "repair": 16.0}[site.kind]
			if value < score:
				best = site
				chosen = unit
				score = value
	if chosen == null:
		return []
	chosen.set_meta("site_capture", weakref(best))
	_order(chosen, best)
	return [chosen]


static func _safe(site, observed):
	return not observed.any(
		func(enemy):
			return enemy.movement_domain == 1 and enemy.position.distance_to(site.position) < 12
	)


static func _order(unit, site):
	if unit.action is AttackMove and unit.action.destination.distance_to(site.position) < 1:
		return
	unit.issue_manual_order(AttackMove.new(site.position))


static func recruit(game, player, units, desired):
	if Production.under_raid(game, player, units):
		return
	var reserve = Production.reserve(player, units, desired)
	for request in Production.requests(game, player, units):
		if request.priority <= 2:
			reserve += Vector2i(request.cost.resource_a, request.cost.resource_b)
	for site in Sites.sites(game):
		if (
			site.kind != "mercenary"
			or site.player != player
			or not site.operational()
			or not site.jobs.is_empty()
		):
			continue
		if units.filter(func(unit): return Infantry.is_infantry(unit.type)).size() >= 8:
			return
		var cap = Difficulty.army_cap(player.difficulty, game.simulation_time)
		if (
			cap > 0
			and Production.army_size(Composition.inventory(units)) + Sites.reserved(player) >= cap
		):
			return
		var cost = Sites.price(player.faction, CAMP_ROLE)
		if (
			player.resource_a >= reserve.x + cost.resource_a
			and player.resource_b >= reserve.y + cost.resource_b
		):
			site.hire(player, CAMP_ROLE)
			return
