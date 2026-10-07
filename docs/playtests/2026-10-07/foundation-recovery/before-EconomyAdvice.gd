# gdlint: disable=max-returns
extends RefCounted

const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")


static func recovery(player, units):
	var workers = role(units, "Worker")
	if not player.has_completed_structure("CommandCenter"):
		if workers.is_empty():
			return _last_stand(
				units,
				"HQ cannot be rebuilt",
				(
					"No engineers or completed HQ remain. Win with your surviving army before "
					+ "the recovery countdown expires, or restart from Menu."
				)
			)
		return building(player, units, "CommandCenter", "Recover your headquarters")
	if workers.is_empty():
		return _replace_workers(player, units)
	return {}


static func assignments(units):
	var workers = role(units, "Worker")
	var stranded = _waiting(workers, [Harvest.Wait.HQ])
	if not stranded.is_empty():
		return step(
			"drop_off",
			"Recover stranded cargo",
			(
				"Select these engineers, then right-click a completed friendly HQ to "
				+ "deliver their cargo. Choose a resource field after delivery."
			),
			"Select stranded engineers",
			stranded
		)
	var depleted = _waiting(workers, [Harvest.Wait.DEPLETED])
	if not depleted.is_empty():
		return step(
			"expand",
			"Move to a new resource field",
			(
				"Use Army to scout and protect the next field. Select these engineers, "
				+ "then right-click the materials or electronics you want them to gather."
			),
			"Select displaced engineers",
			depleted
		)
	var delivered = _waiting(workers, [Harvest.Wait.DELIVERED])
	if not delivered.is_empty():
		return step(
			"reassign",
			"Return engineers to work",
			(
				"Cargo is delivered. Right-click materials or electronics with these "
				+ "engineers to assign their next field."
			),
			"Select engineers",
			delivered
		)
	var waiting = _waiting(workers, [Harvest.Wait.SLOT])
	if waiting.size() >= 2:
		return step(
			"distribute",
			"Spread out your gatherers",
			(
				"Two or more engineers are waiting for work slots. Each deposit supports "
				+ "two workers. Right-click another resource field, or use a waiting "
				+ "engineer to build."
			),
			"Select waiting engineers",
			waiting
		)
	return {}


static func building(player, units, building_role, title):
	var workers = role(units, "Worker")
	var pending = role(units, building_role).filter(func(unit): return not unit.is_constructed())
	var cost = Factions.cost(player, building_role, true)
	var name = Factions.title(player.faction, building_role)
	var selected = builders(workers, pending)
	var description = "Build %s (%d M / %d E)." % [name, cost.resource_a, cost.resource_b]
	if not pending.is_empty():
		description = (
			(
				"Your %s is already paid for. Right-click its foundation with an engineer "
				+ "to continue construction."
			)
			% name
		)
	elif not player.has_resources(cost):
		return _fund_build(player, units, building_role, name, cost, selected)
	if building_role == "CommandCenter":
		# The objective panel always owns the live HQ deadline. A paid
		# foundation can be partly built, so do not present a full new build
		# duration as its remaining construction time.
		if pending.is_empty():
			description += " Construction takes %d s." % Factions.BUILD_TIMES.CommandCenter
	elif building_role == "CommandLab":
		description += " A completed factory and lab unlock chip programs."
	elif building_role == "PowerPlant":
		description += " Low power slows production and service buildings."
	return step(building_role, title, description, "Select engineer", selected)


static func builders(workers, pending = []):
	if not pending.is_empty():
		for worker in workers:
			var action = worker.action
			if action != null and "_target_unit" in action and action._target_unit in pending:
				return [worker]
	var idle = workers.filter(
		func(worker):
			return (
				worker.action == null
				or (
					worker.action.has_method("needs_assignment")
					and worker.action.needs_assignment()
				)
			)
	)
	return (idle if not idle.is_empty() else workers).slice(0, 1)


static func _replace_workers(player, units):
	var hqs = role(units, "CommandCenter").filter(func(hq): return hq.is_constructed())
	for hq in hqs:
		for entry in hq.production_queue.get_elements():
			if Catalog.type_from_path(entry.unit_prototype.resource_path) == "Worker":
				return step(
					"workers_pending",
					"Engineer replacement queued",
					(
						"An engineer is already paid for. Keep HQ safe while its queue completes, "
						+ "then assign the new engineer to salvage."
					),
					"Select HQ",
					[hq]
				)
	var cost = Factions.cost(player, "Worker")
	if not player.has_resources(cost):
		var refundable = _refundable(units, _gap(player, cost))
		if not refundable.is_empty():
			return _refund_step(
				"workers_refund", "Recover funds for an engineer", player, cost, refundable
			)
		var research = _research_refund(player, units, "workers_research")
		if not research.is_empty():
			return research
		return _last_stand(
			units,
			"Economy stalled",
			(
				(
					"An engineer costs %d M / %d E. No engineers or useful paid queues "
					+ "remain. Fight with your surviving army or restart from Menu."
				)
				% [cost.resource_a, cost.resource_b]
			)
		)
	if player.population(true) >= Catalog.POPULATION_LIMIT:
		var queued = _refundable(units, Vector2i.ONE)
		return step(
			"workers_capacity",
			"Make room for an engineer",
			(
				"The unit limit includes queued troops. Cancel a waiting troop to free a "
				+ "slot, or train an engineer after a combat loss."
			),
			"Review paid queue" if not queued.is_empty() else "Select army",
			queued.slice(0, 1) if not queued.is_empty() else _army(units)
		)
	return step(
		"workers",
		"Restart your economy",
		(
			(
				"Train an engineer at HQ (%d M / %d E), then right-click salvage. Protect "
				+ "the replacement on its first trip."
			)
			% [cost.resource_a, cost.resource_b]
		),
		"Select HQ",
		hqs.slice(0, 1)
	)


static func _fund_build(player, units, building_role, name, cost, workers):
	var gap = _gap(player, cost)
	if building_role == "CommandCenter":
		var refundable = _refundable(units, gap)
		var affordable_after_refunds = _can_fund_with_refunds(player, units, cost)
		if affordable_after_refunds and not refundable.is_empty():
			return _refund_step("hq_refund", "Recover the HQ budget", player, cost, refundable)
		var research = _research_refund(player, units, "hq_research")
		if affordable_after_refunds and not research.is_empty():
			return research
		return step(
			"hq_funds",
			"HQ recovery lacks funds",
			(
				(
					"Need %d M / %d E more to rebuild. Cargo cannot be delivered without HQ. "
					+ "Use your remaining army before the countdown expires, or restart from "
					+ "Menu."
				)
				% [gap.x, gap.y]
			),
			"Select army",
			_army(units)
		)
	var need = "materials" if gap.x > 0 else "electronics"
	return step(
		"fund_" + building_role,
		"Gather for " + name,
		(
			(
				"Need %d M / %d E more. Assign an engineer to %s and keep its route to HQ "
				+ "protected; then build %s."
			)
			% [gap.x, gap.y, need, name]
		),
		"Select engineer",
		workers
	)


static func _refund_step(id, title, player, cost, producers):
	var gap = _gap(player, cost)
	return step(
		id,
		title,
		(
			(
				"Need %d M / %d E more. Select this producer and click paid queue icons "
				+ "to cancel for a full refund. You decide which jobs to give up."
			)
			% [gap.x, gap.y]
		),
		"Review paid queue",
		producers.slice(0, 1)
	)


static func _refundable(units, gap):
	var result = []
	for unit in units:
		if not "production_queue" in unit or unit.production_queue == null:
			continue
		for entry in unit.production_queue.get_elements():
			if (
				(gap.x > 0 and entry.paid_cost.resource_a > 0)
				or (gap.y > 0 and entry.paid_cost.resource_b > 0)
			):
				result.append(unit)
				break
	return result


static func _gap(player, cost):
	return Vector2i(
		maxi(0, cost.resource_a - player.resource_a), maxi(0, cost.resource_b - player.resource_b)
	)


static func _waiting(workers, reasons):
	return workers.filter(
		func(worker):
			return (
				worker.action is Harvest
				and worker.action.is_waiting()
				and worker.action._waiting_reason in reasons
			)
	)


static func _last_stand(units, title, description):
	return step("last_stand", title, description, "Select army", _army(units))


static func _army(units):
	return units.filter(func(unit): return unit.movement_speed > 0 and unit.attack_range != null)


static func role(units, value):
	return units.filter(func(unit): return unit.type == value)


static func step(id, title, description, action, units):
	return {"id": id, "title": title, "description": description, "action": action, "units": units}


static func _research_refund(player, units, id):
	if player.technology != null and player.technology.active != "":
		var paid = player.technology.paid
		var result = step(
			id,
			"Review paid research",
			(
				"Open Tech and choose Cancel & refund to reclaim %d M / %d E for recovery."
				% [paid.resource_a, paid.resource_b]
			),
			"Open technology",
			[]
		)
		result.open_technology = true
		return result
	var labs = role(units, "CommandLab").filter(func(lab): return lab.is_constructed())
	if player.coordination_left <= 0 or labs.is_empty():
		return {}
	return step(
		id,
		"Review paid research",
		(
			"Coordination is still in progress. Select the lab and use Cancel & refund "
			+ "to reclaim 20 M / 20 E if you want to fund recovery instead."
		),
		"Select research lab",
		labs.slice(0, 1)
	)


static func _can_fund_with_refunds(player, units, cost):
	var funds = Vector2i(player.resource_a, player.resource_b)
	for unit in units:
		if not "production_queue" in unit or unit.production_queue == null:
			continue
		for entry in unit.production_queue.get_elements():
			funds += Vector2i(entry.paid_cost.resource_a, entry.paid_cost.resource_b)
	if player.technology != null and player.technology.active != "":
		funds += Vector2i(player.technology.paid.resource_a, player.technology.paid.resource_b)
	elif not _research_refund(player, units, "").is_empty():
		funds += Vector2i(player.COORDINATION_COST.resource_a, player.COORDINATION_COST.resource_b)
	return funds.x >= cost.resource_a and funds.y >= cost.resource_b
