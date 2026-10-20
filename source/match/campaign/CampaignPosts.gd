extends RefCounted

# Authored enemy posts. Guards hold a point without pursuit; posted repair
# robots service damaged allies nearby. Stance and actions persist in saves.
const Behavior = preload("res://source/match/orders/UnitBehavior.gd")
const Repairing = preload("res://source/match/units/actions/Repairing.gd")
const SERVICE_RADIUS = 8.0


static func guard(unit, point):
	Behavior.guard(unit, point)


static func service(player):
	for robot in player.get_children():
		if (
			not robot is Repairing.RepairRobot
			or robot.is_queued_for_deletion()
			or robot.stance != robot.Stance.HOLD_POSITION
			or robot.action is Repairing
			or robot.manual_orders._engaged
		):
			continue
		var best = null
		var best_distance = SERVICE_RADIUS
		for ally in player.get_children():
			if not Repairing.is_applicable(robot, ally) or ally.hp >= ally.hp_max:
				continue
			var distance = robot.global_position_yless.distance_to(ally.global_position_yless)
			if distance <= best_distance:
				best = ally
				best_distance = distance
		if best != null:
			robot.action = Repairing.new(best, true)
