extends RefCounted

var targets = {}
var next_order = 0.0
var orders = 0


func step(game):
	if game.simulation_time < next_order or game.waves_sent < 6 or game.controlled_relays() >= 2:
		return
	next_order = game.simulation_time + 1
	var human = game._get_human_player()
	var commands = load("res://source/match/orders/ManualOrders.gd")
	var units = human.get_children().filter(
		func(unit):
			return unit.is_in_group("units") and unit.hp > 0 and unit.type in ["Tank", "Infantry"]
	)
	for unit in units:
		var enemies = []
		for index in [0, 2]:
			var relay = game.map.relays[index]
			if not relay.contested:
				continue
			for enemy in game.battlefield.nearby_units(relay.position, 3):
				if (
					enemy.player == game._enemy
					and enemy.hp > 0
					and game.battlefield.is_observed(human, enemy)
				):
					enemies.append(enemy)
		if enemies.is_empty():
			continue
		enemies.sort_custom(
			func(a, b):
				return (
					unit.position.distance_squared_to(a.position)
					< unit.position.distance_squared_to(b.position)
				)
		)
		var target = enemies[0]
		var id = unit.get_instance_id()
		if targets.get(id, 0) == target.get_instance_id():
			continue
		targets[id] = target.get_instance_id()
		unit.manual_orders.submit(commands.target_order("attack", target))
		# A targeted attack replaces the previous advance. Queue explicit follow-through
		# so target death does not strand infantry on the way to the capture circle.
		var relays = [game.map.relays[0], game.map.relays[2]]
		relays.sort_custom(
			func(a, b):
				return (
					a.position.distance_squared_to(target.position)
					< b.position.distance_squared_to(target.position)
				)
		)
		unit.manual_orders.submit(
			commands.point_order("attack_move", relays[0].position - Vector3(1.5, 0, 0)), true
		)
		orders += 1
		print("SPLIT CLEARANCE ", unit.type, " -> ", target.type, " at=", game.simulation_time)
