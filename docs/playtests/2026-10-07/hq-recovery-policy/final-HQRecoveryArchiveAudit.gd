extends "res://tests/headless/SaveRestoreEdges.gd"

var records = []


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var policy = load("res://tests/playtest/reference/HQRecoveryPolicy.gd").new()
	var plan = load("res://source/match/SkirmishPlan.gd")
	var prefix = "res://docs/playtests/2026-10-07/hq-recovery-policy/"
	var output = prefix + "archive-audit.json"
	if FileAccess.file_exists(output):
		push_error("Use a fresh audit output")
		quit(2)
		return
	for branch in ["control", "recovery"]:
		var file = prefix + branch + "-case6-10-hq_lost.json"
		var data = FileStore.new().read_file(file)
		var loaded = await Restore.new().restore(self, data)
		_check(loaded.ok, "HQ-loss checkpoint failed to restore")
		game = loaded.game
		var owner = game._get_human_player()
		var units = plan.owned_units(owner)
		var initial_funds = Vector2i(owner.resource_a, owner.resource_b)
		var workers = units.filter(func(unit): return unit.type == "Worker")
		var positions = workers.map(func(unit): return unit.position)
		var actions = workers.map(func(unit): return unit.action)
		var available = policy.builders(game, owner, units, [])
		var handler = owner.get_node("StructurePlacementHandler")
		handler._start_structure_placement(load("res://source/match/units/CommandCenter.tscn"))
		var sites = []
		for worker in available:
			for radius in [7.0, 11.0, 15.0, 19.0]:
				for index in 16:
					var angle = index * TAU / 16
					var point = worker.position + Vector3(cos(angle), 0, sin(angle)) * radius
					handler._active_blueprint_node.position = point
					var placement = root.get_node("Utils").Match.Unit.Placement
					if (
						handler._active_bluprint_out_of_map()
						or (
							placement.validate_agent_placement_position(
								point,
								handler._pending_structure_radius,
								get_nodes_in_group("units") + get_nodes_in_group("resource_units"),
								handler._pending_structure_navmap_rid
							)
							!= placement.VALID
						)
					):
						continue
					if policy.site_allowed(game, owner, worker, point, game._defeat_timers[owner]):
						sites.append(
							{
								"worker": [worker.position.x, worker.position.z],
								"site": [point.x, point.z]
							}
						)
		handler._cancel_structure_placement()
		var production = Vector2i.ZERO
		var construction = Vector2i.ZERO
		for unit in units:
			if unit.has_method("construction_refund"):
				var refund = unit.construction_refund()
				construction += Vector2i(refund.resource_a, refund.resource_b)
			if "production_queue" in unit and unit.production_queue != null:
				for job in unit.production_queue.get_elements():
					production += Vector2i(job.paid_cost.resource_a, job.paid_cost.resource_b)
		records.append(
			{
				"branch": branch,
				"seconds": game.simulation_time,
				"remaining": game._defeat_timers[owner],
				"funds": [initial_funds.x, initial_funds.y],
				"production_refunds": [production.x, production.y],
				"construction_refunds": [construction.x, construction.y],
				"research_active": owner.coordination_left > 0 or owner.technology.active != "",
				"guidance": plan.next_step(owner).id,
				"workers": workers.size(),
				"safe_workers": available.size(),
				"timely_clear_sites": sites
			}
		)
		await _frames(5)
		_check(
			paused and game.simulation_time == data.simulation_time, "Paused audit advanced time"
		)
		_check(
			(
				Vector2i(owner.resource_a, owner.resource_b) == initial_funds
				and workers.map(func(unit): return unit.position) == positions
				and workers.map(func(unit): return unit.action) == actions
			),
			"Geometry audit changed funds or orders"
		)
		paused = false
		game.queue_free()
		await _frames(5)
	var result = FileAccess.open(output, FileAccess.WRITE)
	result.store_string(JSON.stringify(records, "\t"))
	result.close()
	for error in errors:
		push_error(error)
	print("HQ archive audit: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
