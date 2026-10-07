extends RefCounted

const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Construct = preload("res://source/match/units/actions/Constructing.gd")


func reserve_needed(game, player, units):
	var hqs = units.filter(
		func(unit): return unit.type == "CommandCenter" and unit.is_constructed() and unit.hp > 0
	)
	if hqs.is_empty():
		return not units.any(func(unit): return unit.type == "CommandCenter" and unit.hp > 0)
	var observed = Economy.contacts(game, player)
	return hqs.all(
		func(hq):
			return hq.hp < hq.hp_max * .6 or Economy.danger(hq.global_position_yless, hq, observed)
	)


func can_spend(player, cost):
	var reserve = Factions.cost(player, "CommandCenter", true)
	return (
		player.resource_a >= cost.resource_a + reserve.resource_a
		and player.resource_b >= cost.resource_b + reserve.resource_b
	)


func builders(game, player, units, protected):
	var observed = Economy.contacts(game, player)
	return units.filter(
		func(unit):
			return (
				unit.type == "Worker"
				and unit.hp > 0
				and unit not in protected
				and not Economy.danger(unit.global_position_yless, unit, observed)
			)
	)


func site_allowed(game, player, builder, point, remaining):
	var observed = Economy.contacts(game, player)
	if (
		Economy.danger(point, builder, observed)
		or not Economy._clear_approach(builder.global_position_yless, point, builder, observed)
	):
		return false
	var nav = game.navigation.get_navigation_map_rid_by_domain(builder.movement_domain)
	var path = NavigationServer3D.map_get_path(nav, builder.global_position_yless, point, true)
	if path.is_empty() or (path[-1] * Vector3(1, 0, 1)).distance_to(point) > .3:
		return false
	var distance = 0.0
	for index in range(1, path.size()):
		distance += path[index - 1].distance_to(path[index])
	return distance / builder.movement_speed + Factions.BUILD_TIMES.CommandCenter + 2.0 < remaining


func continue_foundation(game, player, foundation, workers):
	if workers.any(
		func(worker): return worker.action is Construct and worker.action._target_unit == foundation
	):
		return false
	var observed = Economy.contacts(game, player)
	var choices = workers.filter(
		func(worker):
			return (
				not Economy.danger(foundation.global_position_yless, worker, observed)
				and Economy._clear_approach(
					worker.global_position_yless, foundation.global_position_yless, worker, observed
				)
			)
	)
	choices.sort_custom(
		func(a, b):
			return (
				a.position.distance_squared_to(foundation.position)
				< b.position.distance_squared_to(foundation.position)
			)
	)
	if choices.is_empty():
		return false
	choices[0].issue_manual_order(Construct.new(foundation))
	return true
