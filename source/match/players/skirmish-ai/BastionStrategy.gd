extends RefCounted


## Bastion commits slowly, covers expansions and protects its deployed guns.
static func profile(base: Dictionary) -> Dictionary:
	var result = base.duplicate(true)
	result.first_wave *= 1.2
	result.wave_interval *= 1.15
	result.research = [
		"pressurized_furnaces",
		"reactive_armor",
		"siege_logistics",
		"slag_recirculation",
		"fortress_doctrine",
		"tandem_rockets",
		"bunker_reinforcements"
	]
	return result


static func outpost(units: Array) -> Dictionary:
	var centers = units.filter(
		func(unit):
			return unit.type in ["CommandCenter", "ForwardRefinery"] and unit.is_constructed()
	)
	for center in centers.slice(1):
		var guards = units.filter(
			func(unit):
				return (
					unit.type == "AntiGroundTurret"
					and unit.global_position.distance_to(center.global_position) < 18.0
				)
		)
		if guards.is_empty():
			return {"role": "AntiGroundTurret", "origin": center.global_position}
		var service = units.filter(
			func(unit):
				return (
					unit.type == "RepairDepot"
					and unit.global_position.distance_to(center.global_position) < 20.0
				)
		)
		if service.is_empty():
			return {"role": "RepairDepot", "origin": center.global_position}
	return {}


static func command(_game, player, units: Array, observed: Array) -> Array:
	var claimed = []
	for siege in units:
		if siege.type != "AdvancedTank":
			continue
		var contacts = observed.filter(
			func(enemy):
				return (
					enemy.combat_domain() == 1
					and siege.global_position.distance_to(enemy.global_position) <= 15.5
				)
		)
		if contacts.is_empty():
			continue
		# A live firing opportunity holds the siege line in place through deployment.
		if siege.get_node("Movement")._has_destination:
			siege.issue_manual_order(null)
			siege.get_node("Movement").stop()
		claimed.append(siege)
		if player.coordination_unlocked and player.profile().signatures:
			player.signatures.activate([siege], siege.global_position)
	return claimed
