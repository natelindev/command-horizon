extends RefCounted

const Economy = preload("res://source/match/EconomyAdvice.gd")
const Service = preload("res://source/match/combat/RepairService.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")


static func endangered_workers(player, units):
	var game = player.get_parent().get_parent()
	var contacts = _contacts(player)
	return units.filter(
		func(unit):
			return (
				unit.player == player
				and unit.type == "Worker"
				and unit.hp > 0
				and not unit.is_queued_for_deletion()
				and (
					game.simulation_time - unit.last_enemy_damage_time <= 6.0
					or contacts.any(func(enemy): return _in_defense_reach(enemy, unit))
				)
			)
	)


static func defense(player, units, combatants):
	var game = player.get_parent().get_parent()
	var assets = units.filter(
		func(unit): return unit.type == "Worker" or unit.has_method("is_constructed")
	)
	var under_fire = assets.any(
		func(unit): return game.simulation_time - unit.last_enemy_damage_time <= 6.0
	)
	var threats = _contacts(player).filter(
		func(enemy): return assets.any(func(unit): return _in_defense_reach(enemy, unit))
	)
	if not under_fire and threats.is_empty():
		return {}
	var air = threats.filter(
		func(enemy): return enemy.movement_domain == Constants.Match.Navigation.Domain.AIR
	)
	if not air.is_empty():
		return _air_defense(player, units, combatants, threats, air)
	var selected = combatants
	if not threats.is_empty():
		selected = combatants.filter(
			func(unit): return threats.any(func(enemy): return _can_respond(unit, enemy))
		)
		if selected.is_empty():
			var stance = _stance_advice(player, combatants, "precision")
			if not stance.is_empty():
				return stance
	var action = "Select defenders"
	if selected.is_empty():
		selected = _producer(units, ["Barracks", "VehicleFactory"])
		action = "Select production"
		if selected.is_empty():
			var build = Economy.building(player, units, "Barracks", "Rebuild your ground defense")
			build.id = "defend_economy"
			return build
	return Economy.step(
		"defend_economy",
		"Protect your economy",
		(
			(
				"Enemy fire is hitting your engineers or buildings. "
				+ "Defend the approach and keep a reserve near your economy."
			)
			if under_fire
			else (
				"Enemy forces are near your engineers or buildings. "
				+ "Defend the approach and keep a reserve near your economy."
			)
		),
		action,
		selected
	)


static func _air_defense(player, units, combatants, threats, air):
	var ready = combatants.filter(
		func(unit): return air.any(func(enemy): return _can_respond(unit, enemy))
	)
	if not ready.is_empty():
		var mixed = threats.size() > air.size()
		if mixed:
			ready = combatants.filter(
				func(unit): return threats.any(func(enemy): return _can_respond(unit, enemy))
			)
		return Economy.step(
			"defend_economy",
			"Defend air and ground approaches" if mixed else "Respond to the air raid",
			(
				(
					"Keep anti-air units covering your engineers and buildings. "
					+ "Use ground units against the ground raiders."
				)
				if mixed
				else (
					"These units can attack aircraft. Keep them near the threatened engineers "
					+ "and buildings; ground-only weapons cannot stop this raid."
				)
			),
			"Select defenders" if mixed else "Select air defense",
			ready
		)
	var batteries = units.filter(
		func(unit):
			return (
				unit.type == "AntiAirTurret"
				and air.any(func(enemy): return _in_defense_reach(unit, enemy))
			)
	)
	if not batteries.is_empty():
		return Economy.step(
			"defend_economy",
			"Use your anti-air cover",
			(
				"Keep engineers within your anti-air battery's firing range. Ground-only weapons "
				+ "cannot attack the aircraft; protect the battery from ground raiders."
			),
			"Select anti-air cover",
			batteries
		)
	var stance = _stance_advice(player, combatants, "interception")
	if not stance.is_empty():
		return stance
	var role = "AntiAirTurret"
	var required = Factions.requirement(player, role, true)
	while required != "" and not player.has_completed_structure(required):
		role = required
		required = Factions.requirement(player, role, true)
	var step = Economy.building(player, units, role, "Prepare anti-air protection")
	step.id = "defend_economy"
	step.title = "Prepare anti-air protection"
	step.description = "Aircraft threaten your economy. " + step.description
	return step


static func _stance_advice(player, combatants, mode):
	if player.faction != "helix":
		return {}
	var lancers = combatants.filter(func(unit): return unit.type == "CombatRobot" and unit.hp > 0)
	var switchable = lancers.filter(
		func(unit): return unit.weapon_switch_left <= 0 and unit.weapon_mode != mode
	)
	var title = mode.capitalize()
	var targets = "aircraft" if mode == "interception" else "ground raiders"
	if not switchable.is_empty():
		return Economy.step(
			"defend_economy",
			"Switch Lancers to " + title,
			(
				(
					"Select these Lancers and choose %s to attack %s. Switching disables fire "
					+ "for two seconds. Keep them near your engineers."
				)
				% [title, targets]
			),
			"Select Lancers",
			switchable
		)
	var pending = lancers.filter(func(unit): return unit.weapon_switch_left > 0)
	if not pending.is_empty():
		return (
			Economy
			. step(
				"defend_economy",
				"Prepare " + ("anti-air fire" if mode == "interception" else "ground defense"),
				(
					(
						"These Lancers are switching stance and cannot fire yet. Let the switch finish, "
						+ "then use %s against the %s."
					)
					% [title, targets]
				),
				"Select Lancers",
				pending
			)
		)
	return {}


static func _can_respond(unit, target):
	# Normal reload/deployment does not change a weapon's target role. A stance
	# switch can change domains, so its advice must expose the pending choice.
	return (
		Rules.can_target(unit, target)
		and not (unit.type == "CombatRobot" and unit.weapon_switch_left > 0)
	)


static func _in_defense_reach(source, target):
	return (
		Rules.can_target(source, target)
		and source.position.distance_to(target.position) <= Rules.range_for(source, target) + 8.0
	)


static func next_step(player, units, combatants):
	var damaged = units.filter(
		func(unit):
			return (
				unit.movement_speed > 0
				and unit.type != "Worker"
				and float(unit.hp) / unit.hp_max < .5
			)
	)
	if not damaged.is_empty():
		var missing = _missing_service(damaged, units)
		if missing != "":
			var titles = {
				"RepairDepot": "Set up ground repair",
				"Barracks": "Restore infantry recovery",
				"AircraftFactory": "Restore aircraft service"
			}
			var role = missing
			var required = Factions.requirement(player, role, true)
			while required != "" and not player.has_completed_structure(required):
				role = required
				required = Factions.requirement(player, role, true)
			return Economy.building(player, units, role, titles[missing])
		return Economy.step(
			"repair_army",
			"Recover damaged forces",
			(
				"Move damaged machinery to a depot or repair robot. Infantry use barracks; "
				+ "aircraft use their flight facility. Hold still within service range to recover."
			),
			"Select damaged units",
			damaged
		)
	if combatants.size() < 4:
		return (
			Economy
			. step(
				"reinforce",
				"Rebuild your combat force",
				(
					"Keep defenders near your engineers and add units that cover your army's weaknesses. "
					+ "Repair support helps sustain operations."
				),
				"Select production",
				_producer(units, ["VehicleFactory", "Barracks"])
			)
		)
	var contacts = _contacts(player)
	if contacts.is_empty():
		var scouts = units.filter(func(unit): return unit.type == "Drone")
		if scouts.is_empty():
			scouts = combatants.duplicate()
			scouts.sort_custom(func(a, b): return a.movement_speed > b.movement_speed)
			scouts = scouts.slice(0, 1)
		return Economy.step(
			"scout",
			"Scout before committing",
			(
				"Reveal the route and defenses with a scout or a small detachment "
				+ "before committing your main force. Keep your economy protected."
			),
			"Select scout" if scouts.size() == 1 else "Select scouts",
			scouts
		)
	return Economy.step(
		"assault",
		"Assess the visible opposition",
		(
			"Inspect visible weapon and armor roles, then choose a raid or HQ assault. "
			+ "Keep a reserve and retreat damaged forces. Direct orders override programs."
		),
		"Select army",
		combatants
	)


static func _producer(units, roles):
	for role in roles:
		var choices = units.filter(func(unit): return unit.type == role and unit.is_constructed())
		if not choices.is_empty():
			return [choices[0]]
	return []


static func _contacts(player):
	var game = player.get_parent().get_parent()
	return player.get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player != player
				and not unit.is_queued_for_deletion()
				and unit.hp > 0
				and game.battlefield.is_observed(player, unit)
			)
	)


static func _missing_service(damaged, units):
	for target in damaged:
		var available = units.any(
			func(provider):
				return (
					Service.facility_eligible(provider, target)
					or (
						provider.type == "RepairRobot"
						and not provider.is_queued_for_deletion()
						and provider.hp > 0
						and Service.mobile_eligible(provider, target)
					)
				)
		)
		if not available:
			return Service.facility_for_role(target.type)
	return ""
