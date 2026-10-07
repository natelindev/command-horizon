extends RefCounted


static func sample(driver):
	var army = driver._policy_army()
	var health = 0.0
	for unit in army:
		health += float(unit.hp) / unit.hp_max
	health /= max(1, army.size())
	var hq = driver._unit(driver.human, "CommandCenter")
	var threats = 0
	if hq != null:
		for unit in driver.get_nodes_in_group("units"):
			if (
				unit.player != driver.human
				and unit.attack_range != null
				and driver.game.battlefield.is_observed(driver.human, unit)
				and unit.position.distance_to(hq.position) < 30
			):
				threats += 1
	return {
		"phase": driver.phase,
		"army": army.size(),
		"health": health,
		"saw_attack": driver.saw_home_attack,
		"visible_home_threats": threats,
		"pressure_age": driver.game.simulation_time - driver.last_home_pressure,
		"assault_gates":
		{
			"army_at_least_9": army.size() >= 9,
			"health_at_least_80_percent": health >= .8,
			"quiet_20_seconds": driver.game.simulation_time - driver.last_home_pressure >= 20,
			"no_visible_home_threats": threats == 0,
			"saw_home_attack": driver.saw_home_attack
		}
	}
