extends RefCounted

var last_target = 0
var repair_target = 0
var responses = 0


func step(game):
	var human = game._get_human_player()
	for entry in game.convoy:
		if not game._alive(entry):
			continue
		var point = game.map.POINTS[entry.leg]
		if entry.unit.position.distance_to(point) > 7:
			continue
		var enemies = game.battlefield.nearby_units(point, 10).filter(
			func(unit):
				return (
					unit.player == game._enemy
					and unit.hp > 0
					and unit.movement_domain == 1
					and not unit.is_queued_for_deletion()
					and game.battlefield.is_observed(human, unit)
				)
		)
		if enemies.is_empty():
			continue
		var target = enemies[0]
		if target.get_instance_id() != last_target:
			last_target = target.get_instance_id()
			responses += 1
			for unit in game.escorts():
				if unit.hp > 0 and unit.attack_range != null:
					unit.issue_manual_order(
						load("res://source/match/units/actions/AttackMoving.gd").new(
							target.position
						)
					)
			print("CONVOY RESPONSE time=", game.simulation_time, " at=", target.position)
		break
	var damaged = game.trucks().filter(func(unit): return unit.hp < unit.hp_max)
	var repairs = game.escorts().filter(
		func(unit): return unit.type == "RepairRobot" and unit.hp > 0
	)
	if not damaged.is_empty() and not repairs.is_empty():
		damaged.sort_custom(func(a, b): return a.hp / a.hp_max < b.hp / b.hp_max)
		var truck = damaged[0]
		if truck.get_instance_id() != repair_target:
			repair_target = truck.get_instance_id()
			repairs[0].manual_orders.submit(
				load("res://source/match/orders/ManualOrders.gd").target_order("repair", truck)
			)
