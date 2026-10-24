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
	_check(not research.enqueue("weapons_2", lab), "Unplanned prerequisites were accepted")
	_check(not research.enqueue("doctrine", lab), "Unplanned Coordination was accepted")
	for id in [
		"weapons_1",
		"coordination",
		"weapons_2",
		"armor_1",
		"armor_2",
		"service",
		"doctrine",
		"dual_purpose_aa"
	]:
		_check(research.enqueue(id, lab), "Paid queue rejected " + id)
	_check(
		research.active == "weapons_1" and research.queued.size() == 7, "Research ran concurrently"
	)
	_check(_funds() == funds - Vector2i(320, 215), "Queue did not reserve every exact price")
	_check(not research.enqueue("coordination", lab), "Duplicate queued Coordination was charged")
	_check(not research.enqueue("weapons_1", lab), "Duplicate active research was charged")
	_check(not research.enqueue("service", lab), "Duplicate queued technology was charged")
	_check(_funds() == funds - Vector2i(320, 215), "Rejected duplicate changed resources")
	var state = research.capture()
	await _frames(8)
	_check(research.capture() == state, "Tactical pause advanced or reordered queued research")
	_check(research.cancel_queued(0), "Queued Coordination could not be cancelled")
	_check(
		_ids() == ["armor_1", "service", "dual_purpose_aa"], "Dependent queue cancellation differs"
	)
	_check(_funds() == funds - Vector2i(135, 90), "Dependent queued prices were not refunded")
	_check(not research.cancel_queued(8), "Invalid queue index was accepted")
	while not research.queued.is_empty():
		research.cancel_queued(0)
	_check(research.cancel() and not research.cancel(), "Active cancellation refunded twice")
	_check(_funds() == funds, "Queue cancellation did not conserve resources")
	_check(research.enqueue("weapons_1", lab), "Weapon retry refused")
	_check(research.enqueue("dual_purpose_aa", lab), "Active prerequisite did not support queue")
	research.cancel()
	_check(
		research.queued.is_empty() and _funds() == funds,
		"Active prerequisite cancellation lost funds"
	)
	_check(research.enqueue("coordination", lab), "Direct Coordination queue purchase refused")
	_check(research.enqueue("doctrine", lab), "Doctrine could not follow Coordination")
	_check(human.cancel_coordination(), "Active Coordination cancellation refused")
	_check(
		research.queued.is_empty() and _funds() == funds,
		"Coordination cancellation lost dependent funds"
	)
	human.resource_a = 0
	_check(not research.enqueue("weapons_1", lab), "Queue accepted an unpaid project")
	human.resource_a = funds.x
	print("PASS research queue exact payments, unique projects, pause and cascading refunds")


func _ordered_completion_and_restore():
	var funds = _funds()
	for id in ["weapons_1", "coordination", "weapons_2", "armor_1"]:
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
	research.left = .01
	paused = false
	for frame in 8:
		await physics_frame
		if human.coordination_left > 0:
			break
	paused = true
	_check("weapons_1" in research.completed, "First queued research did not complete")
	_check(
		research.active == "" and human.coordination_left > 0, "Coordination did not take the slot"
	)
	_check(_ids() == ["weapons_2", "armor_1"], "Coordination handoff changed queue order")
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
	human.coordination_left = .01
	paused = false
	for frame in 8:
		await physics_frame
		if research.active == "weapons_2":
			break
	paused = true
	_check(human.coordination_unlocked, "Restored Coordination did not complete")
	_check(
		research.active == "weapons_2" and _ids() == ["armor_1"], "Dependent FIFO handoff failed"
	)
	_check(_funds() == paid_funds, "Starting a dependent queued upgrade charged twice")
	research.cancel()
	_check(
		research.active == "armor_1" and research.queued.is_empty(),
		"Cancellation did not advance independent work"
	)
	research.cancel()
	_check(
		_funds() == funds - Vector2i(50, 40),
		"Completed work or cancelled work was refunded incorrectly"
	)
	print("PASS ordered research completion, lab loss/rebuild and paid disk restore")


func _invalid_queues():
	var snapshot = Snapshot.new().capture(game)
	var schema = schema_script.new()
	_check(schema.validate(snapshot), "Post-queue snapshot invalid: " + schema.error)
	for kind in ["unknown", "duplicate", "underpaid", "dependency", "active", "coordination"]:
		var bad = snapshot.duplicate(true)
		var state = bad.players[0].technology
		state.queued = [{"id": "armor_1", "paid": {"resource_a": 30, "resource_b": 15}}]
		match kind:
			"unknown":
				state.queued[0].id = "free_damage"
			"duplicate":
				state.queued.append(state.queued[0].duplicate(true))
			"underpaid":
				state.queued[0].paid.resource_a = 0
			"dependency":
				state.queued = [{"id": "armor_2", "paid": {"resource_a": 60, "resource_b": 30}}]
			"active":
				state.active = "armor_1"
				state.left = 10.0
				state.paid = state.queued[0].paid.duplicate()
			"coordination":
				state.queued = [
					{"id": "coordination", "paid": {"resource_a": 20, "resource_b": 20}}
				]
		_check(not schema.validate(bad), "Malformed research queue accepted: " + kind)
	print("PASS research queue schema rejects invalid order, duplicates and unpaid projects")
