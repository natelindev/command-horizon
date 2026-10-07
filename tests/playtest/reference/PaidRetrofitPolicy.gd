extends RefCounted

const Install = preload("res://source/match/programs/ChipInstalling.gd")
const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
var episodes = []
var spent_e = 0
var active = {}
var retry_at = {}
var skipped = {}


func settle(now):
	if active.is_empty():
		return
	var unit = active.unit.get_ref()
	if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
		_finish("lost", now, false)
	elif unit.program.installed:
		_finish("installed", now, false)
	elif not is_instance_of(unit.action, Install):
		# Shipping installation refunds live cancellation, including service loss
		# and stalled travel. Destroyed units lose the reserved fee.
		_finish("cancelled", now, true)


func update(game, owner, units, allow_start = true):
	settle(game.simulation_time)
	var observed = game.get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player != owner
				and unit.hp > 0
				and not unit.is_queued_for_deletion()
				and game.battlefield.is_observed(owner, unit)
			)
	)
	if not active.is_empty():
		var unit = active.unit.get_ref()
		if not unit.program.valid_service(unit.action.service):
			unit.issue_manual_order(null)
			_finish("service_cancelled", game.simulation_time, true)
			return
		if (
			Economy.danger(unit.global_position_yless, unit, observed)
			or Economy.danger(unit.action.service.global_position_yless, unit, observed)
		):
			unit.issue_manual_order(null)
			_finish("threat_cancelled", game.simulation_time, true)
		return
	if not allow_start or not owner.basic_programs_unlocked():
		return
	for unit in units:
		if (
			unit.type != "Tank"
			or unit.program == null
			or unit.program.installed
			or unit.program.install_left > 0
			or unit.program.mode != "Manual"
		):
			continue
		if unit.hp < unit.hp_max * .6 or game.simulation_time - unit.last_enemy_damage_time < 5:
			_skip("wounded_or_recently_hit")
			continue
		if (
			not unit.manual_orders.pending.is_empty()
			or game.simulation_time < retry_at.get(unit.get_instance_id(), 0.0)
		):
			continue
		if (
			Economy.danger(unit.global_position_yless, unit, observed)
			or not game.battlefield.fireable_targets(unit).is_empty()
		):
			_skip("engaged")
			continue
		var services = units.filter(
			func(service):
				return (
					unit.program.valid_service(service)
					and not Economy.danger(service.global_position_yless, unit, observed)
				)
		)
		services.sort_custom(
			func(a, b):
				return (
					unit.global_position_yless.distance_squared_to(a.global_position_yless)
					< unit.global_position_yless.distance_squared_to(b.global_position_yless)
				)
		)
		for service in services:
			if not _reachable(game, unit, service):
				continue
			var fee = Factions.chip_cost(owner.faction)
			if not unit.program.install_at(service):
				_skip("unaffordable")
				return
			spent_e += fee
			episodes.append(
				{
					"start": game.simulation_time,
					"fee": fee,
					"health": unit.hp / unit.hp_max,
					"service": service.type,
					"result": "installing"
				}
			)
			active = {
				"unit": weakref(unit),
				"id": unit.get_instance_id(),
				"episode": episodes.size() - 1,
				"fee": fee
			}
			return


func protects(unit):
	return (
		not active.is_empty()
		and active.unit.get_ref() == unit
		and is_instance_of(unit.action, Install)
	)


func _finish(result, now, refunded):
	var episode = episodes[active.episode]
	episode.result = result
	episode.end = now
	episode.refunded = refunded
	if refunded:
		spent_e -= active.fee
	retry_at[active.id] = now + 10.0
	active = {}


func _skip(reason):
	skipped[reason] = skipped.get(reason, 0) + 1


func _reachable(game, unit, service):
	var map = game.navigation.get_navigation_map_rid_by_domain(unit.movement_domain)
	var path = NavigationServer3D.map_get_path(
		map, unit.global_position, service.global_position, true
	)
	return (
		not path.is_empty()
		and (
			(path[-1] * Vector3(1, 0, 1)).distance_to(service.global_position_yless)
			<= service.radius + unit.radius + .75
		)
	)
