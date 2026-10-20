extends "res://tests/headless/ConstructionContractRegression.gd"

var recovery_policy
var plan


func _run():
	recovery_policy = load("res://tests/playtest/reference/HQRecoveryPolicy.gd").new()
	plan = load("res://tests/UnitQueries.gd")
	await super()


func _paid_site():
	owner = game._get_human_player()
	var units = plan.owned_units(owner)
	var hq = _units(owner, "CommandCenter")[0]
	_check(
		not recovery_policy.reserve_needed(game, owner, units),
		"Healthy peaceful HQ reserves recovery funds"
	)
	hq.hp = hq.hp_max * .5
	_check(
		recovery_policy.reserve_needed(game, owner, units), "Damaged HQ does not reserve rebuild"
	)
	hq.hp = hq.hp_max
	owner.resource_a = 86
	owner.resource_b = 20
	_check(
		recovery_policy.can_spend(owner, {"resource_a": 6, "resource_b": 0}),
		"Exact excess funds unavailable"
	)
	owner.resource_a = 85
	_check(
		not recovery_policy.can_spend(owner, {"resource_a": 6, "resource_b": 0}),
		"Production invades HQ materials"
	)
	owner.resource_a = 100
	owner.resource_b = 19
	_check(
		not recovery_policy.can_spend(owner, {"resource_a": 6, "resource_b": 0}),
		"HQ electronics reserve ignored"
	)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var raider = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(
		raider, Transform3D(Basis(), hq.position + Vector3(6, 0, 0)), enemy, false
	)
	raider.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(owner, raider), "HQ threat fixture not observed")
	_check(
		recovery_policy.reserve_needed(game, owner, units),
		"Observed HQ threat did not reserve funds"
	)
	raider.position = Vector3(80, 0, 80)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(owner, raider), "Distant threat unexpectedly observed")
	_check(
		not recovery_policy.reserve_needed(game, owner, units),
		"Unseen distant threat reserved HQ funds"
	)
	raider.queue_free()
	await _frames(4)
	hq.hp = 0
	await _frames(4)
	_check(
		recovery_policy.reserve_needed(game, owner, plan.owned_units(owner)),
		"HQ loss released unpaid reserve"
	)
	# Restore only the parent fixture's prerequisite; parent then tests real paid replacement.
	var replacement = hq_scene.instantiate()
	game._setup_and_spawn_unit(replacement, Transform3D(Basis(), Vector3(14, 0, 50)), owner, false)
	await _frames(4)
	await super()
	_check(
		not recovery_policy.reserve_needed(game, owner, plan.owned_units(owner)),
		"Paid HQ foundation still reserves duplicate price"
	)
	var protected = [workers[0]]
	var eligible = recovery_policy.builders(game, owner, plan.owned_units(owner), protected)
	_check(
		workers[0] not in eligible and eligible.size() == 3, "Recovery steals protected engineer"
	)
	var point = foundation.position + Vector3(7, 0, 0)
	var build_time = faction_catalog.BUILD_TIMES.CommandCenter
	_check(
		recovery_policy.site_allowed(game, owner, workers[1], point, build_time + 25),
		"Reachable timely HQ site rejected"
	)
	_check(
		not recovery_policy.site_allowed(game, owner, workers[1], point, build_time),
		"Late HQ placement ignores build duration"
	)
	for worker in workers:
		worker.issue_manual_order(null)
	_check(
		recovery_policy.continue_foundation(game, owner, foundation, eligible),
		"Abandoned foundation was not resumed"
	)
	_check(workers[0].action == null, "Protected stopped worker was reassigned")
	_check(
		not recovery_policy.continue_foundation(game, owner, foundation, eligible),
		"Existing HQ constructor was replaced"
	)
	for worker in workers:
		worker.issue_manual_order(construction_action.new(foundation))
