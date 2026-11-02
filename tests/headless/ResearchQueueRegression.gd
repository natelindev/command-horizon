extends "res://tests/headless/SaveRestoreEdges.gd"

var human
var lab
var research
var catalog
var schema_script


func _run():
	TranslationServer.set_locale("en")
	root.get_node("SaveManager").autosaves_enabled = false
	catalog = load("res://source/match/research/TechnologyCatalog.gd")
	schema_script = load("res://source/match/saves/SnapshotSchema.gd")
	await _skirmish("helix", "res://source/match/maps/DesertFrontier.tscn")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	_bind()
	human.resource_a = 2000
	human.resource_b = 2000
	await _purchases_and_refunds()
	await _ordered_completion_and_restore()
	_invalid_queues()
	game.queue_free()
	paused = false
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Research queue: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _bind():
	human = game._get_human_player()
	lab = _units(human, "CommandLab")[0]
	research = human.technology


func _funds():
	return Vector2i(human.resource_a, human.resource_b)


func _ids():
	return research.queued.map(func(entry): return entry.id)


func _purchases_and_refunds():
	var funds = _funds()
	_check(not research.enqueue("phase_overload", lab), "Unplanned Coordination was accepted")
	_check(not research.enqueue("weapons_1", lab), "Retired mirrored technology was accepted")
	for id in [
		"coordination",
		"plasma_shields",
		"beam_amplification",
		"flux_capacitors",
		"phase_thrusters",
		"phase_overload"
	]:
		_check(research.enqueue(id, lab), "Paid queue rejected " + id)
	_check(
		research.active == "" and human.coordination_left > 0 and research.queued.size() == 5,
		"Research ran concurrently with Coordination"
	)
	_check(_funds() == funds - Vector2i(250, 185), "Queue did not reserve exact faction prices")
	for id in ["coordination", "plasma_shields", "phase_overload", "continuous_coherence"]:
		_check(not research.enqueue(id, lab), "Duplicate or excluded project was charged: " + id)
	_check(_funds() == funds - Vector2i(250, 185), "Rejected project changed resources")
	var state = research.capture()
	await _frames(8)
	_check(research.capture() == state, "Pause advanced or reordered queued research")
	_check(research.cancel_queued(2), "Queued Flux Capacitors could not be cancelled")
	_check(
		_ids() == ["plasma_shields", "beam_amplification", "phase_thrusters", "phase_overload"],
		"Independent cancellation changed FIFO order"
	)
	_check(_funds() == funds - Vector2i(205, 150), "Queued price was not refunded exactly")
	_check(not research.cancel_queued(8), "Invalid queue index was accepted")
	_check(human.cancel_coordination(), "Active Coordination cancellation refused")
	_check(
		research.queued.is_empty() and _funds() == funds,
		"Coordination cancellation lost dependent funds"
	)
	_check(not human.cancel_coordination(), "Coordination cancellation refunded twice")
	human.coordination_unlocked = true
	_check(research.enqueue("plasma_shields", lab), "Resonator retry refused")
	_check(research.enqueue("flux_capacitors", lab), "Independent follow-up refused")
	_check(
		research.cancel() and research.active == "flux_capacitors",
		"Cancellation did not advance independent work"
	)
	_check(research.cancel() and not research.cancel(), "Active cancellation refunded twice")
	_check(_funds() == funds, "Independent cancellations did not conserve resources")
	human.coordination_unlocked = false
	human.resource_a = 0
	_check(not research.enqueue("coordination", lab), "Queue accepted an unpaid project")
	human.resource_a = funds.x
	print("PASS faction queue exact payments, exclusions, pause and cascading refunds")


func _ordered_completion_and_restore():
	var funds = _funds()
	for id in ["coordination", "plasma_shields", "beam_amplification", "phase_overload"]:
		_check(research.enqueue(id, lab), "Ordered queue rejected " + id)
	var paid_funds = _funds()
	var prior = research.capture()
	var lab_position = lab.global_transform
	lab.queue_free()
	await _frames(4)
	paused = false
	await _frames(8)
	paused = true
	_check(research.capture() == prior, "Missing lab advanced paid queued research")
	var replacement = load("res://source/match/units/CommandLab.tscn").instantiate()
	game._setup_and_spawn_unit(replacement, lab_position, human, false)
	lab = replacement
	await _frames(12)
	human.coordination_left = .01
	paused = false
	for frame in 8:
		await physics_frame
		if research.active == "plasma_shields":
			break
	paused = true
	_check(human.coordination_unlocked, "Queued Coordination did not complete")
	_check(research.active == "plasma_shields", "First branch did not take the research slot")
	_check(
		_ids() == ["beam_amplification", "phase_overload"],
		"Coordination handoff changed queue order"
	)
	_check(_funds() == paid_funds, "Starting queued Coordination charged twice")
	var before = research.capture()
	var coordination_before = human.coordination_left
	var snapshot = Snapshot.new().capture(game)
	_check(snapshot != null, "Queued research snapshot failed")
	if snapshot == null:
		return
	var schema = schema_script.new()
	_check(schema.validate(snapshot), "Queued research snapshot invalid: " + schema.error)
	var path = "user://research-queue-%d.json" % OS.get_process_id()
	var file = load("res://source/match/saves/SaveFile.gd").new()
	_check(file.write_file(path, snapshot), "Queued research disk write failed: " + file.error)
	var saved = file.read_file(path)
	DirAccess.remove_absolute(path)
	_check(saved != null, "Queued research disk read failed: " + file.error)
	if saved == null:
		return
	var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, saved)
	_check(restored.ok, "Queued research restore failed: " + str(restored.get("error", "")))
	if not restored.ok:
		return
	game = restored.game
	_bind()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_check(paused and research.capture() == before, "Restore changed the queue or released pause")
	_check(human.coordination_left == coordination_before, "Restore changed active Coordination")
	_check(_funds() == paid_funds, "Restore lost prepaid queue resources")
	await _frames(6)
	_check(research.capture() == before, "Restored queue advanced while paused")
	research.left = .01
	paused = false
	for frame in 8:
		await physics_frame
		if research.active == "beam_amplification":
			break
	paused = true
	_check("plasma_shields" in research.completed, "Restored resonator research did not complete")
	_check(
		research.active == "beam_amplification" and _ids() == ["phase_overload"],
		"Dependent FIFO handoff failed"
	)
	_check(_funds() == paid_funds, "Starting a dependent queued upgrade charged twice")
	research.cancel()
	_check(
		research.active == "phase_overload" and research.queued.is_empty(),
		"Cancellation did not advance independent work"
	)
	research.cancel()
	_check(
		_funds() == funds - Vector2i(60, 45),
		"Completed work or cancelled work was refunded incorrectly"
	)
	print("PASS ordered research completion, lab loss/rebuild and paid disk restore")


func _invalid_queues():
	var snapshot = Snapshot.new().capture(game)
	var schema = schema_script.new()
	_check(schema.validate(snapshot), "Post-queue snapshot invalid: " + schema.error)
	for kind in [
		"unknown",
		"duplicate",
		"underpaid",
		"dependency",
		"active",
		"coordination",
		"doctrines",
		"foreign"
	]:
		var bad = snapshot.duplicate(true)
		var state = bad.players[0].technology
		state.queued = [{"id": "beam_amplification", "paid": {"resource_a": 50, "resource_b": 35}}]
		match kind:
			"unknown":
				state.queued[0].id = "free_damage"
			"duplicate":
				state.queued.append(state.queued[0].duplicate(true))
			"underpaid":
				state.queued[0].paid.resource_a = 0
			"dependency":
				bad.players[0].coordination_unlocked = false
			"active":
				state.active = "beam_amplification"
				state.left = 10.0
				state.paid = state.queued[0].paid.duplicate()
			"coordination":
				state.queued = [
					{"id": "coordination", "paid": {"resource_a": 20, "resource_b": 20}}
				]
			"doctrines":
				state.queued = [
					{"id": "phase_overload", "paid": {"resource_a": 55, "resource_b": 40}},
					{"id": "continuous_coherence", "paid": {"resource_a": 55, "resource_b": 40}}
				]
			"foreign":
				state.queued = [
					{"id": "reactive_armor", "paid": {"resource_a": 40, "resource_b": 20}}
				]
		_check(not schema.validate(bad), "Malformed research queue accepted: " + kind)
	print("PASS research queue schema rejects invalid order, duplicates and unpaid projects")
