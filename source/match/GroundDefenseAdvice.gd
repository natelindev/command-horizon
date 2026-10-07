extends RefCounted

const Economy = preload("res://source/match/EconomyAdvice.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const RosterInfo = preload("res://source/match/hud/RosterInfo.gd")
const WARNING = "Heavy armor threatens your economy. Rifles deal little damage to it. "


static func counters_armor(role, faction):
	var profile = Rules.PROFILES.get(role, "")
	if role == "CombatRobot" and faction == "helix":
		profile = "Anti-armor lance"
	return Rules.MULTIPLIERS.has(profile) and Rules.MULTIPLIERS[profile][2] >= 1.0


static func production(player, units):
	var producers = units.filter(
		func(unit):
			return (
				"production_queue" in unit
				and unit.production_queue != null
				and unit.is_constructed()
			)
	)
	for producer in producers:
		for job in producer.production_queue.get_elements():
			var role = Catalog.type_from_path(job.unit_prototype.resource_path)
			if not counters_armor(role, player.faction):
				continue
			var blocked = producer.production_queue.blocked_reason()
			return _step(
				"Anti-armor support queued",
				(
					"%s production is already paid for. " % Factions.title(player.faction, role)
					+ (
						"Protect its production building while the queue completes."
						if blocked.is_empty()
						else blocked
					)
				),
				[producer]
			)
	var factories = producers.filter(func(unit): return unit.type == "VehicleFactory")
	if factories.is_empty():
		var role = "VehicleFactory"
		var required = Factions.requirement(player, role, true)
		while required != "" and not player.has_completed_structure(required):
			role = required
			required = Factions.requirement(player, role, true)
		var build = Economy.building(player, units, role, "Prepare armored defense")
		build.id = "defend_economy"
		build.description = WARNING + build.description
		return build
	# Prefer a factory that can accept the recommendation with its current settings.
	var factory = factories[0]
	for candidate in factories:
		if RosterInfo.inspect(candidate, "Tank", false).allowed:
			factory = candidate
			break
	var info = RosterInfo.inspect(factory, "Tank", false)
	var title = Factions.title(player.faction, "Tank")
	var description = (
		"Produce %s (%d M / %d E). " % [title, info.cost.resource_a, info.cost.resource_b]
	)
	if not info.allowed:
		description = "%s: %s" % [title, info.reasons[0]]
		if not description.ends_with("."):
			description += "."
		if (
			factory.production_queue.fit_chips
			and ("Short:" in info.reasons[0] or "Requires" in info.reasons[0])
		):
			description += " Turn off Fit chips for conventional production."
	elif factory.production_queue.fit_chips:
		description += "Price includes a fitted chip."
	else:
		description += "Use it with infantry to defend the approach."
	return _step(
		"Field an armor counter" if info.allowed else "Prepare armored production",
		description,
		[factory]
	)


static func _step(title, description, units):
	return Economy.step("defend_economy", title, WARNING + description, "Select production", units)
