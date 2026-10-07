extends RefCounted

const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")


static func inspect(producer, role, construction):
	var player = producer.player
	var cost = Factions.cost(player, role, construction)
	var fitted = not construction and role == "Tank" and producer.production_queue.fit_chips
	if fitted:
		cost.resource_b += Factions.chip_cost(player.faction)
	var lines = PackedStringArray(
		[
			Factions.title(player.faction, role),
			Factions.description(player.faction, role),
			"%d M / %d E" % [cost.resource_a, cost.resource_b],
		]
	)
	if construction:
		var seconds = (
			Factions.BUILD_TIMES[role]
			if player.get_meta("skirmish", false)
			else 1.0 / Constants.Match.Units.STRUCTURE_CONSTRUCTING_SPEED
		)
		lines.append("%d s construction with one engineer; travel extra." % ceili(seconds))
	else:
		var seconds = (
			(
				Factions.duration(player, role)
				+ (Factions.chip_seconds(player.faction) if fitted else 0.0)
			)
			/ player.production_factor()
		)
		lines.append(
			(
				"%d s production%s; queue wait extra."
				% [ceili(seconds), " at low power" if player.production_factor() < 1.0 else ""]
			)
		)
		if fitted:
			lines.append(
				(
					"Includes basic chip (+%d E / +%d s base time)."
					% [Factions.chip_cost(player.faction), Factions.chip_seconds(player.faction)]
				)
			)
	if player.technology != null:
		var upgrades = player.technology.summary(role)
		if upgrades != "":
			lines.append(upgrades)
	var reasons = PackedStringArray()
	var required = "CommandLab" if fitted else Factions.requirement(player, role, construction)
	if required != "" and not player.has_completed_structure(required):
		reasons.append("Requires " + Factions.title(player.faction, required) + ".")
	if (
		not construction
		and role == "AdvancedTank"
		and player.get_meta("skirmish", false)
		and not player.coordination_unlocked
	):
		reasons.append("Research Coordination at your lab.\n20 M / 20 E · 30 s at full power.")
	var missing = Vector2i(
		maxi(0, cost.resource_a - player.resource_a), maxi(0, cost.resource_b - player.resource_b)
	)
	if missing != Vector2i.ZERO:
		reasons.append("Short: %d M / %d E" % [missing.x, missing.y])
	if construction:
		if (
			player.get_meta("skirmish", false)
			and player.structure_count() >= Catalog.STRUCTURE_LIMIT
		):
			reasons.append("Structure limit reached (%d)." % Catalog.STRUCTURE_LIMIT)
	else:
		if player.population(true) >= Catalog.POPULATION_LIMIT:
			reasons.append(
				"Unit limit reached (%d, including paid queues)." % Catalog.POPULATION_LIMIT
			)
		if producer.production_queue.size() >= Constants.Match.Units.PRODUCTION_QUEUE_LIMIT:
			reasons.append("Queue full (%d jobs)." % Constants.Match.Units.PRODUCTION_QUEUE_LIMIT)
	lines.append_array(reasons)
	return {
		"cost": cost,
		"allowed": Factions.available(player, role, construction) and reasons.is_empty(),
		"text": "\n".join(lines)
	}
