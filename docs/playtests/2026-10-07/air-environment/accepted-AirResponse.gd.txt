extends RefCounted

var targets = {}
var next_order = 0.0
var orders = 0


func step(game):
	if game.simulation_time < next_order or not game.sites.all(func(site): return site.cleared):
		return
	next_order = game.simulation_time + 1.0
	var human = game._get_human_player()
	var enemies = game.battlefield.nearby_units(game.map.SCREEN, 24).filter(
		func(unit):
			return (
				unit.player == game._enemy
				and game._alive(unit)
				and game.battlefield.is_observed(human, unit)
			)
	)
	var rules = load("res://source/match/combat/CombatRules.gd")
	var commands = load("res://source/match/orders/ManualOrders.gd")
	var ground = human.get_children().filter(
		func(unit):
			return (
				unit.is_in_group("units")
				and game._alive(unit)
				and unit.movement_speed > 0
				and unit.movement_domain == 1
				and unit.type != "Worker"
			)
	)
	for unit in ground:
		var choices = enemies.filter(func(enemy): return rules.can_target(unit, enemy))
		var kind = "attack"
		if unit.type == "RepairRobot":
			kind = "repair"
			choices = ground.filter(
				func(friend): return friend != unit and friend.hp < friend.hp_max
			)
		if choices.is_empty():
			continue
		choices.sort_custom(
			func(a, b):
				if unit.type == "CombatRobot" and a.movement_domain != b.movement_domain:
					return a.movement_domain == 0
				return (
					unit.position.distance_squared_to(a.position)
					< unit.position.distance_squared_to(b.position)
				)
		)
		var target = choices[0]
		var id = unit.get_instance_id()
		if targets.get(id, 0) == target.get_instance_id():
			continue
		targets[id] = target.get_instance_id()
		unit.manual_orders.submit(commands.target_order(kind, target))
		orders += 1
		print(
			"AIR RESPONSE ",
			kind,
			" role=",
			unit.type,
			" target=",
			target.type,
			" at=",
			game.simulation_time
		)
