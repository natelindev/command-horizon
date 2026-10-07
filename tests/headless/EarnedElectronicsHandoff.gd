extends "res://tests/headless/SaveRestoreEdges.gd"

const ARCHIVE = (
	"res://docs/playtests/2026-10-07/electronics-handoff/"
	+ "final-balanced-case6-10-electronics_handoff.json"
)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var records = []
	var output = "res://docs/playtests/2026-10-07/electronics-handoff/earned-continuation.json"
	if FileAccess.file_exists(output):
		push_error("Earned continuation output already exists")
		quit(2)
		return
	for retain in [false, true]:
		var data = FileStore.new().read_file(ARCHIVE)
		var loaded = await Restore.new().restore(self, data)
		_check(loaded.ok, "Earned handoff checkpoint failed to load")
		game = loaded.game
		var owner = game._get_human_player()
		var choices = _units(owner, "Worker").filter(
			func(unit):
				return (
					labor.queued_target(unit) != null and "resource_b" in labor.queued_target(unit)
				)
		)
		_check(
			choices.size() == 1,
			"Earned snapshot no longer has exactly one queued electronics handoff"
		)
		var worker = choices[0]
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		var position = worker.position
		await _frames(10)
		_check(
			(
				paused
				and game.simulation_time == data.simulation_time
				and worker.position == position
				and Vector2i(owner.resource_a, owner.resource_b) == funds
			),
			"Paused earned checkpoint changed"
		)
		_check(
			get_nodes_in_group("players").any(
				func(side): return side != owner and side.is_processing()
			),
			"Earned continuation disabled opponent decisions"
		)
		if not retain:
			worker.manual_orders.clear_waiting()
		var delivered = Vector2i.ZERO
		var start = game.simulation_time
		game.hud._toggle_pause()
		for frame in 3600:
			var cargo = Vector2i(worker.resource_a, worker.resource_b)
			var returning = (
				is_instance_of(worker.action, harvest)
				and worker.action._state == harvest.State.MOVING_TO_CC
			)
			await _frames(1)
			if not is_instance_valid(worker) or worker.is_queued_for_deletion():
				break
			if returning and cargo != Vector2i.ZERO and worker.resource_a + worker.resource_b == 0:
				delivered += cargo
			if retain and delivered.y >= 4:
				break
		game.hud.pause_after_load()
		_check(delivered.x >= 4, "Earned handoff lost carried materials")
		_check(
			delivered.y >= 4 if retain else delivered.y == 0,
			"Earned electronics delivery did not match retained order"
		)
		var row = {
			"retain_handoff": retain,
			"delivered": [delivered.x, delivered.y],
			"elapsed": game.simulation_time - start,
			"worker_alive": is_instance_valid(worker),
			"enemy_ai_active": true
		}
		records.append(row)
		print("EARNED HANDOFF ", JSON.stringify(row))
		paused = false
		game.queue_free()
		await _frames(5)
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	for error in errors:
		push_error(error)
	print("Earned electronics handoff: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
