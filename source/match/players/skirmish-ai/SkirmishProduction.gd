extends RefCounted

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Composition = preload("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
const Defense = preload("res://source/match/players/skirmish-ai/SkirmishDefense.gd")
const OPTIONAL_BUILDINGS = ["CommandLab", "AircraftFactory", "RepairDepot", "AntiGroundTurret"]


static func under_raid(game, player, units):
	var contacts = game.get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player != player
				and not unit.is_queued_for_deletion()
				and unit.hp > 0
				and game.battlefield.is_observed(player, unit)
			)
	)
	return not Defense.plan(game, player, units, contacts).threats.is_empty()


static func emergency_budget(game, player, units, desired):
	if desired not in OPTIONAL_BUILDINGS or not under_raid(game, player, units):
		return Vector2i.ZERO
	var budget = Vector2i.ZERO
	for job in requests(game, player, units):
		if job.priority <= 2:
			budget += Vector2i(job.cost.resource_a, job.cost.resource_b)
	return budget


static func requests(game, player, units, include_busy = false):
	var counts = Composition.inventory(units)
	var threats = Composition.observed(game, player)
	var sequence = player._production_index
	var result = []
	if player.population(true) >= Catalog.POPULATION_LIMIT:
		return result
	for producer in units:
		if (
			not producer.has_method("is_constructed")
			or not producer.is_constructed()
			or producer.production_queue == null
			or (not include_busy and producer.production_queue.size() > 0)
		):
			continue
		var choice = _choice(player, producer, counts, threats, sequence)
		if choice.is_empty() or not Factions.available(player, choice.role):
			continue
		var price = Factions.cost(player, choice.role).duplicate()
		var fit_chips = producer.production_queue.fit_chips
		if player.faction == "frontier" and producer.type == "VehicleFactory":
			# Frontier invests its cheaper fitting in new armor once the lab is ready.
			# Forecast without mutating the queue; a lost lab falls back to plain armor.
			fit_chips = (
				player.has_completed_structure("CommandLab") and player.basic_programs_unlocked()
			)
		if choice.role == "Tank" and fit_chips:
			if (
				not player.has_completed_structure("CommandLab")
				or not player.basic_programs_unlocked()
			):
				continue
			price.resource_b += Factions.chip_cost(player.faction)
		result.append(
			{
				"producer": producer,
				"role": choice.role,
				"priority": choice.priority,
				"cost": price,
				"fit_chips": fit_chips
			}
		)
		counts[choice.role] = counts.get(choice.role, 0) + 1
		if producer.type == "VehicleFactory":
			sequence += 1
	result.sort_custom(
		func(a, b):
			if a.priority != b.priority:
				return a.priority < b.priority
			return a.producer.get_index() < b.producer.get_index()
	)
	return result


static func reserve(player, units, desired):
	if desired == "":
		return Vector2i.ZERO
	# A foundation is already paid; do not reserve its price a second time.
	if units.any(
		func(unit):
			return (
				unit.type == desired
				and unit.has_method("is_constructed")
				and not unit.is_constructed()
			)
	):
		return Vector2i.ZERO
	var cost = Factions.cost(player, desired, true)
	return Vector2i(cost.resource_a, cost.resource_b)


static func demand(game, player, units):
	var result = reserve(player, units, player._next_building(units))
	for job in requests(game, player, units, true):
		result += Vector2i(job.cost.resource_a, job.cost.resource_b)
	var research = player._research_candidate(units)
	if not research.is_empty():
		result += research.cost
	return result


static func _choice(player, producer, counts, threats, sequence):
	match producer.type:
		"CommandCenter":
			if counts.get("Worker", 0) < 6:
				return {"role": "Worker", "priority": 0}
		"Barracks":
			if counts.get("Infantry", 0) < 4:
				return {"role": "Infantry", "priority": 2}
			if counts.get("Hero", 0) == 0 and Factions.available(player, "Hero"):
				return {"role": "Hero", "priority": 4}
			var preferred = (
				"RocketInfantry" if threats.armor > threats.infantry else "SniperInfantry"
			)
			var roles = [preferred, "AssaultInfantry", "RocketInfantry", "SniperInfantry"]
			for role in roles:
				if counts.get(role, 0) < (2 if role == preferred else 1):
					return {"role": role, "priority": 2}
			if counts.get("Infantry", 0) < Composition.infantry_target(player, threats):
				return {"role": "Infantry", "priority": 2}
		"VehicleFactory":
			return Composition.vehicle_choice(player, counts, threats, sequence)
		"AircraftFactory":
			if counts.get("Drone", 0) == 0:
				return {"role": "Drone", "priority": 4}
			var machinery = (
				counts.get("Tank", 0) + counts.get("CombatRobot", 0) + counts.get("AdvancedTank", 0)
			)
			var wings = maxi(1, ceili(machinery / 4.0))
			if machinery >= 2 and counts.get("Helicopter", 0) < wings:
				return {"role": "Helicopter", "priority": 5}
	return {}
