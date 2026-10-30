extends "res://source/match/units/Structure.gd"

# One vehicle occupies the open service bay. The surrounding tools remain
# scenery; the platform itself must be navigable to board and leave it.
const SERVICE_REACH = 0.55


func service_point(_unit):
	return to_global(Vector3(0, 0, 0.25))


func service_reach():
	return SERVICE_REACH


func service_slots():
	return (
		2
		if (
			player != null
			and player.technology != null
			and "siege_logistics" in player.technology.completed
		)
		else 1
	)


func services(unit):
	return (
		unit.global_position_yless.distance_to(service_point(unit) * Vector3(1, 0, 1))
		<= SERVICE_REACH
	)


func bay_busy(unit):
	for other in _match.battlefield.nearby_units(global_position, 1.6):
		if (
			other != unit
			and other.movement_speed > 0
			and other.movement_domain == unit.movement_domain
		):
			var own_distance = unit.global_position_yless.distance_to(global_position_yless)
			var other_distance = other.global_position_yless.distance_to(global_position_yless)
			if (
				other_distance < own_distance - 0.01
				or (
					absf(other_distance - own_distance) <= 0.01
					and other.get_instance_id() < unit.get_instance_id()
				)
			):
				return true
	return false


func deck_height(point):
	var local = to_local(point)
	# Blend the entry onto the deck instead of popping the chassis upward.
	var edge = maxf(absf(local.x) / 1.15, absf(local.z) / 1.25)
	var height = {"bastion": 0.28, "helix": 0.20, "frontier": 0.14}.get(player.faction, 0.28)
	return height * clampf((1.0 - edge) / 0.35, 0.0, 1.0)
