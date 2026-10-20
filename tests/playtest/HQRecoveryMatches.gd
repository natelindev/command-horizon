extends "res://tests/playtest/CautiousRelayMatches.gd"

var hq_state_key = []
var hq_policy
var hq_recovery_enabled = false
var placing_hq = false
var lost_hq = false


func _run():
	hq_policy = load("res://tests/playtest/reference/HQRecoveryPolicy.gd").new()
	hq_recovery_enabled = "--hq-recovery" in OS.get_cmdline_user_args()
	await super()


func _play_case(index):
	hq_state_key.clear()
	lost_hq = false
	await super(index)


func _measure():
	super()
	var units = plan_rules.owned_units(human)
	var hqs = units.filter(func(unit): return unit.type == "CommandCenter")
	var complete = hqs.filter(func(unit): return unit.is_constructed())
	var health = complete.map(func(unit): return floori(unit.hp / unit.hp_max * 4))
	var funded = human.has_resources(factions.cost(human, "CommandCenter", true))
	var reserving = _hq_reserving()
	var key = [health, hqs.size(), funded, reserving]
	if key == hq_state_key:
		return
	hq_state_key = key.duplicate(true)
	if not metrics.has("hq_recovery_events"):
		metrics.hq_recovery_events = []
	var event = {
		"seconds": game.simulation_time,
		"health": complete.map(func(unit): return unit.hp / unit.hp_max),
		"foundations": hqs.size() - complete.size(),
		"funds": [human.resource_a, human.resource_b],
		"remaining": game._defeat_timers[human],
		"reserve_needed": reserving,
		"policy_enabled": hq_recovery_enabled
	}
	metrics.hq_recovery_events.append(event)
	print("HQ RECOVERY ", JSON.stringify(event))
	if archive_prefix != "":
		if complete.is_empty():
			lost_hq = true
			_archive_progress("hq_lost")
		elif lost_hq:
			_archive_progress("hq_rebuilt")
		elif health.any(func(value): return value < 3):
			_archive_progress("hq_damaged")


func _economy():
	if not hq_recovery_enabled or human.has_completed_structure("CommandCenter"):
		super()
		return
	var units = plan_rules.owned_units(human)
	engineer_safety.update(game, human, units)
	var protected = units.filter(
		func(unit): return unit.type == "Worker" and engineer_safety.protected(unit)
	)
	var builders = hq_policy.builders(game, human, units, protected)
	var cost = factions.cost(human, "CommandCenter", true)
	var pending = units.filter(
		func(unit): return unit.type == "CommandCenter" and not unit.is_constructed()
	)
	metrics.hq_recovery_policy = "observed_reserve_and_rebuild"
	if not pending.is_empty():
		if not builders.is_empty():
			hq_policy.continue_foundation(game, human, pending[0], builders)
	elif human.has_resources(cost):
		if not builders.is_empty():
			_place("CommandCenter", builders[0])
	elif _can_fund_with_refunds(units, cost):
		_recover_hq_funds(units, cost)


func _hq_gap(cost):
	return Vector2i(
		maxi(0, cost.resource_a - human.resource_a), maxi(0, cost.resource_b - human.resource_b)
	)


func _can_fund_with_refunds(units, cost):
	var funds = Vector2i(human.resource_a, human.resource_b)
	for unit in units:
		if unit.has_method("construction_refund"):
			var refund = unit.construction_refund()
			funds += Vector2i(refund.resource_a, refund.resource_b)
		if not "production_queue" in unit or unit.production_queue == null:
			continue
		for job in unit.production_queue.get_elements():
			funds += Vector2i(job.paid_cost.resource_a, job.paid_cost.resource_b)
	if human.technology != null and human.technology.active != "":
		funds += Vector2i(human.technology.paid.resource_a, human.technology.paid.resource_b)
	elif human.coordination_left > 0 and human.has_completed_structure("CommandLab"):
		funds += Vector2i(human.COORDINATION_COST.resource_a, human.COORDINATION_COST.resource_b)
	return funds.x >= cost.resource_a and funds.y >= cost.resource_b


# Reclaims one paid commitment per tick toward the HQ budget: queued jobs first,
# then research or coordination, then an unfinished foundation.
func _recover_hq_funds(units, cost):
	var gap = _hq_gap(cost)
	for unit in units:
		if not "production_queue" in unit or unit.production_queue == null:
			continue
		for job in unit.production_queue.get_elements():
			if (
				(gap.x > 0 and job.paid_cost.resource_a > 0)
				or (gap.y > 0 and job.paid_cost.resource_b > 0)
			):
				_spent -= Vector2(job.paid_cost.resource_a, job.paid_cost.resource_b)
				unit.production_queue.cancel(job)
				return
	if human.technology != null and human.technology.active != "":
		var paid = human.technology.paid.duplicate()
		human.technology.cancel()
		_spent -= Vector2(paid.resource_a, paid.resource_b)
		return
	if human.has_completed_structure("CommandLab") and human.cancel_coordination():
		_spent -= Vector2(human.COORDINATION_COST.resource_a, human.COORDINATION_COST.resource_b)
		return
	for unit in units:
		if not unit.has_method("construction_refund"):
			continue
		var refund = unit.construction_refund()
		if (gap.x > 0 and refund.resource_a > 0) or (gap.y > 0 and refund.resource_b > 0):
			unit.cancel_construction()
			_spent -= Vector2(refund.resource_a, refund.resource_b)
			return

func _place(role, builder):
	if (
		hq_recovery_enabled
		and role != "CommandCenter"
		and _hq_reserving()
		and not hq_policy.can_spend(human, factions.cost(human, role, true))
	):
		return
	placing_hq = hq_recovery_enabled and role == "CommandCenter"
	var before = plan_rules.owned_units(human)
	super(role, builder)
	if placing_hq:
		var added = plan_rules.owned_units(human).filter(func(unit): return unit not in before)
		if not added.is_empty():
			metrics.hq_paid_placements = metrics.get("hq_paid_placements", [])
			metrics.hq_paid_placements.append(
				{
					"seconds": game.simulation_time,
					"point": [added[0].position.x, added[0].position.z],
					"funds": [human.resource_a, human.resource_b]
				}
			)
			if archive_prefix != "":
				_archive_progress("hq_foundation")
	placing_hq = false


func _placement_candidate_allowed(point, builder):
	return (
		super(point, builder)
		and (
			not placing_hq
			or hq_policy.site_allowed(game, human, builder, point, game._defeat_timers[human])
		)
	)


func _hq_reserving():
	return hq_policy.reserve_needed(game, human, plan_rules.owned_units(human))


func _produce():
	if not hq_recovery_enabled or not _hq_reserving():
		super()
		return
	# Ordinary purchases above the protected HQ budget still use the same queue API.
	for request in _reference_requests():
		if not hq_policy.can_spend(human, request.cost):
			continue
		var job = request.producer.production_queue.produce(load(Catalog.scene_path(request.role)))
		if job != null:
			_spent += Vector2(job.paid_cost.resource_a, job.paid_cost.resource_b)
			if request.producer.type == "VehicleFactory":
				vehicle_sequence += 1
