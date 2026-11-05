extends RefCounted

const Labor = preload("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")


static func profile(base: Dictionary) -> Dictionary:
	var result = base.duplicate(true)
	result.first_wave *= 0.6
	result.wave_interval *= 0.65
	result.task_groups += 1
	result.extra_factories = maxi(1, result.extra_factories)
	result.research = [
		"high_octane", "scrap_cannibalization", "guerrilla_insurgency", "concealed_claymores"
	]
	return result


static func command(game, player, units: Array, observed: Array) -> Array:
	var claimed = []
	_air_contract(player, observed)
	_ambush_corridors(game, player, units, observed, claimed)
	# Four firing ports become a mixed mobile squad instead of empty transports.
	for rig in units:
		if rig.garrison_mount == null:
			continue
		var infantry = units.filter(
			func(unit):
				return (
					unit.type in ["RocketInfantry", "SniperInfantry", "Infantry"]
					and not unit.has_meta("garrison_host")
					and unit.global_position.distance_to(rig.global_position) < 12.0
				)
		)
		infantry.sort_custom(
			func(a, b):
				return (
					a.global_position.distance_squared_to(rig.global_position)
					< b.global_position.distance_squared_to(rig.global_position)
				)
		)
		for soldier in infantry:
			if not rig.garrison_mount.can_garrison(soldier):
				break
			if (
				soldier.manual_orders != null
				and soldier.manual_orders.submit(Orders.target_order("garrison", rig))
			):
				claimed.append(soldier)
	return claimed


static func _air_contract(player, observed: Array):
	if (
		not player.has_completed_structure("CommandLab")
		or player.resource_a < 120
		or player.resource_b < 65
	):
		return
	var contracts = load("res://source/match/economy/FrontierAirContracts.gd").get_for(player)
	if contracts.cooldown_left > 0.0:
		return
	var role = (
		"Bomber"
		if observed.any(func(unit): return unit.has_method("is_constructed"))
		else "Helicopter"
	)
	if observed.any(
		func(unit): return unit.movement_domain == Constants.Match.Navigation.Domain.AIR
	):
		role = "Fighter"
	contracts.hire(role)


static func _ambush_corridors(game, player, units: Array, observed: Array, claimed: Array):
	if (
		game.engineering == null
		or not player.has_completed_structure("CommandLab")
		or player.resource_a < 70
	):
		return
	if (
		game.engineering.count_for(player, "mine")
		>= (10 if "guerrilla_insurgency" in player.technology.completed else 5)
	):
		return
	var workers = units.filter(
		func(unit):
			return unit.type == "Worker" and (unit.action == null or Labor.handoff_ready(unit))
	)
	var centers = units.filter(func(unit): return unit.type == "CommandCenter")
	if workers.is_empty() or centers.is_empty():
		return
	var home: Vector3 = centers[0].global_position
	var middle = Vector3(game.map.size.x * 0.5, 0, game.map.size.y * 0.5)
	var deposits = game.get_tree().get_nodes_in_group("resource_units").filter(
		func(resource): return resource.global_position.distance_to(home) > 18.0
	)
	deposits.sort_custom(
		func(a, b):
			return (
				a.global_position.distance_squared_to(middle)
				< b.global_position.distance_squared_to(middle)
			)
	)
	var worker = workers[0]
	for deposit in deposits:
		var approach = (deposit.global_position - home).normalized()
		var point = deposit.global_position - approach * (deposit.radius + 3.0)
		point = game.map.ground_point(Vector2(point.x, point.z))
		if observed.any(
			func(enemy):
				return (
					enemy.attack_range != null
					and enemy.global_position.distance_to(point) < enemy.attack_range + 4.0
				)
		):
			continue
		if game.engineering.placement_error(worker, "mine", point, 0.0) != "":
			continue
		if game.engineering.request(worker, "mine", point, 0.0, Labor.handoff_ready(worker)):
			claimed.append(worker)
			return
