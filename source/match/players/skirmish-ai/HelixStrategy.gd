extends RefCounted

const Moving = preload("res://source/match/units/actions/Moving.gd")


static func profile(base: Dictionary) -> Dictionary:
	var result = base.duplicate(true)
	result.first_wave *= 0.8
	result.wave_interval *= 0.75
	result.research = [
		"plasma_shields",
		"flux_capacitors",
		"continuous_coherence",
		"beam_amplification",
		"phase_thrusters"
	]
	return result


static func command(game, _player, units: Array, observed: Array) -> Array:
	var claimed = []
	for unit in units:
		if unit.movement_speed <= 0.0 or unit.shields_max <= 0.0 or unit.attack_range == null:
			continue
		var withdrawing = unit.get_meta("shield_withdrawing", false)
		if withdrawing and unit.shields >= unit.shields_max * 0.9:
			unit.remove_meta("shield_withdrawing")
			continue
		if not withdrawing and unit.shields > unit.shields_max * 0.25:
			continue
		unit.set_meta("shield_withdrawing", true)
		claimed.append(unit)
		var threats = observed.filter(
			func(enemy):
				return (
					enemy.attack_range != null
					and unit.global_position.distance_to(enemy.global_position) < 22.0
				)
		)
		if threats.is_empty():
			continue
		threats.sort_custom(
			func(a, b):
				return (
					a.global_position.distance_squared_to(unit.global_position)
					< b.global_position.distance_squared_to(unit.global_position)
				)
		)
		var away = (unit.global_position - threats[0].global_position) * Vector3(1, 0, 1)
		if away.length_squared() < 0.01:
			away = Vector3.RIGHT
		var point = unit.global_position + away.normalized() * 12.0
		point = game.map.ground_point(
			Vector2(
				clampf(point.x, 2.0, game.map.size.x - 2.0),
				clampf(point.z, 2.0, game.map.size.y - 2.0)
			)
		)
		if unit.abilities != null and unit.type == "CombatRobot":
			unit.abilities.trigger("phase_shift", point)
		if not unit.action is Moving or unit.action._target_position.distance_to(point) > 5.0:
			unit.issue_manual_order(Moving.new(point))
	return claimed
