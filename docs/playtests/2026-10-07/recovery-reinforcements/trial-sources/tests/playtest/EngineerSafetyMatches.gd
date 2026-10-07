extends "res://tests/playtest/PaidProgressionMatches.gd"

var engineer_safety
var safety_policy_path = "res://tests/playtest/reference/EngineerSafetyPolicy.gd"
var safety_policy_id = "observed_retreat_deliver_resume"


func _play_case(index):
	engineer_safety = load(safety_policy_path).new()
	await super(index)


func _economy():
	engineer_safety.update(game, human, plan_rules.owned_units(human))
	metrics.worker_policy = safety_policy_id
	metrics.worker_episodes = engineer_safety.episodes
	metrics.worker_threatened_decisions = engineer_safety.threatened_decisions
	metrics.worker_no_safe_destination_decisions = engineer_safety.no_safe_destination_decisions
	if archive_prefix != "":
		if not engineer_safety.states.is_empty():
			_archive_progress("worker_withdrawal")
		if engineer_safety.episodes.any(func(episode): return episode.get("delivered", false)):
			_archive_progress("worker_cargo_delivered")
	var protected_orders = []
	for worker in plan_rules.owned_units(human):
		if worker.type == "Worker" and engineer_safety.protected(worker):
			protected_orders.append(
				[worker, worker.action, worker.manual_orders.pending.duplicate(true)]
			)
	super()
	for entry in protected_orders:
		_check(
			entry[0].action == entry[1] and entry[0].manual_orders.pending == entry[2],
			"Reference economy replaced a protected engineer's retreat/delivery order"
		)
		metrics.worker_authority_checks = metrics.get("worker_authority_checks", 0) + 1


func _economy_workers(units):
	return super(units).filter(func(worker): return not engineer_safety.protected(worker))
