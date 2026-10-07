extends RefCounted

const Economy = preload("res://source/match/EconomyAdvice.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")


static func armor(player, units):
	if units.any(func(unit): return unit.type in ["Tank", "CombatRobot", "AdvancedTank"]):
		return {}
	var factories = _factories(units)
	for factory in factories:
		if factory.production_queue.get_elements().any(
			func(entry): return Catalog.type_from_path(entry.unit_prototype.resource_path) == "Tank"
		):
			return Economy.step(
				"armor_pending",
				"Frontline armor queued",
				(
					"Your first tank is already paid for. Protect its factory while it "
					+ "completes, then use it with your infantry to defend the economy."
				),
				"Select factory",
				[factory]
			)
	var cost = Factions.cost(player, "Tank")
	var title = Factions.title(player.faction, "Tank")
	if not player.has_resources(cost):
		var gap = Vector2i(
			maxi(0, cost.resource_a - player.resource_a),
			maxi(0, cost.resource_b - player.resource_b)
		)
		return Economy.step(
			"fund_armor",
			"Gather for frontline armor",
			(
				(
					"Need %d M / %d E more for a %s. Keep gathering and defend the "
					+ "engineers while you prepare armor."
				)
				% [gap.x, gap.y, title]
			),
			"Select engineer",
			Economy.builders(Economy.role(units, "Worker"))
		)
	return Economy.step(
		"armor",
		"Field conventional armor",
		(
			(
				"Produce a %s (%d M / %d E) before investing in the lab. Use "
				+ "direct orders to support your infantry; this vehicle can fit a "
				+ "chip after unlock."
			)
			% [title, cost.resource_a, cost.resource_b]
		),
		"Select factory",
		factories.slice(0, 1)
	)


static func chips(player, units):
	var installing = units.filter(
		func(unit): return unit.program != null and unit.program.install_left > 0
	)
	if not installing.is_empty():
		return Economy.step(
			"chips_installing",
			"Chip installation in progress",
			(
				"The chip is already paid for. Let the vehicle reach its service "
				+ "point and finish installation. A new direct order cancels "
				+ "installation and refunds the fee."
			),
			"Select installing vehicle",
			installing.slice(0, 1)
		)
	var factories = _factories(units)
	for factory in factories:
		if factory.production_queue.get_elements().any(func(entry): return entry.fitted_chip):
			return Economy.step(
				"chips_pending",
				"Programmable armor queued",
				(
					"A tank with a fitted chip is already paid for. Protect its "
					+ "factory while production completes, then choose a program."
				),
				"Select factory",
				[factory]
			)
	var conventional = units.filter(
		func(unit): return unit.program != null and not unit.program.installed
	)
	if not conventional.is_empty():
		if player.resource_b < Factions.chip_cost(player.faction):
			return Economy.step(
				"fund_chip",
				"Gather for a chip",
				(
					(
						"Need %d E more to fit a chip to your existing vehicle. Keep it "
						+ "defending the economy while an engineer gathers electronics."
					)
					% (Factions.chip_cost(player.faction) - player.resource_b)
				),
				"Select engineer",
				Economy.builders(Economy.role(units, "Worker"))
			)
		return Economy.step(
			"retrofit",
			"Upgrade your existing armor",
			(
				(
					"Choose Fit chip · %d E, then click a friendly HQ or repair depot. "
					% Factions.chip_cost(player.faction)
				)
				+ (
					"The vehicle travels there for installation: %d seconds at full "
					% Factions.chip_seconds(player.faction)
				)
				+ "power. Keep other units defending."
			),
			"Select conventional vehicle",
			conventional.slice(0, 1)
		)
	return Economy.step(
		"chips",
		"Produce your first programmable unit",
		(
			(
				"At the factory, enable Fit chips before queuing a tank (+%d E / "
				+ "+%d s). Repair robots include a chip."
			)
			% [Factions.chip_cost(player.faction), Factions.chip_seconds(player.faction)]
		),
		"Select factory",
		factories.slice(0, 1)
	)


static func _factories(units):
	return units.filter(func(unit): return unit.type == "VehicleFactory" and unit.is_constructed())
