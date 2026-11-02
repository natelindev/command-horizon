extends RefCounted

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Composition = preload("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
const Defense = preload("res://source/match/players/skirmish-ai/SkirmishDefense.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
const Expansion = preload("res://source/match/players/skirmish-ai/SkirmishExpansion.gd")
const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const OPTIONAL_BUILDINGS = ["CommandLab", "AircraftFactory", "RepairDepot", "AntiGroundTurret"]


static func under_raid(game, player, units):
	var contacts = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd").contacts(
		game, player
	)
	# Budget checks need only a threat predicate; do not sort and assign an army.
	return Defense.under_raid(game, player, units, contacts)


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
	var cap = Difficulty.army_cap(player.difficulty, game.simulation_time)
	var pending_hires = Sites.reserved(player)
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
		if (
			cap > 0
			and producer.type != "CommandCenter"
			and army_size(counts) + pending_hires >= cap
		):
			continue
		var choice = _choice(player, producer, counts, threats, sequence)
		if choice.is_empty() or not Factions.available(player, choice.role):
			continue
		result.append(
			{
				"producer": producer,
				"role": choice.role,
				"priority": choice.priority,
				"cost": Factions.production_cost(player, choice.role)
			}
		)
		counts[choice.role] = counts.get(choice.role, 0) + Factions.batch_size(player.faction, choice.role)
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


static func army_size(counts):
	# Mobile units ordered from barracks, factories and airfields, queued or fielded.
	var total = 0
	for producer in Catalog.PRODUCES:
		if producer == "CommandCenter":
			continue
		for role in Catalog.PRODUCES[producer]:
			total += counts.get(role, 0)
	# Fielded camp recruits; pending contracts are counted by Sites.reserved().
	for role in Catalog.Mercenaries.ROLES:
		total += counts.get(role, 0)
	return total


static func _choice(player, producer, counts, threats, sequence):
	match producer.type:
		"CommandCenter":
			var bonus = Expansion.worker_bonus(
				player.get_children().filter(func(unit): return "type" in unit)
			)
			if counts.get("Worker", 0) < Difficulty.of(player.difficulty).workers + bonus:
				return {"role": "Worker", "priority": 0}
		"Barracks":
			if counts.get("Infantry", 0) < 4:
				return {"role": "Infantry", "priority": 2}
			if counts.get("Hero", 0) == 0 and Factions.available(player, "Hero"):
				return {"role": "Hero", "priority": 4}
			# Rocket infantry answer both armor and aircraft.
			var preferred = (
				"RocketInfantry"
				if threats.armor + threats.air > threats.infantry
				else "SniperInfantry"
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
			return Composition.air_choice(player, producer, counts, threats)
	return {}
