extends "res://tests/headless/SaveRestoreEdges.gd"

var human
var enemy
var panel
var plan
var worker
var raider


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan = load("res://source/match/SkirmishPlan.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _response_fixture(faction)
		panel.refresh()
		_check(not panel._idle.disabled, faction + ": busy endangered engineer shortcut disabled")
		_check("risk" in panel._idle.text, faction + ": engineer shortcut omits current danger")
		panel._idle.pressed.emit()
		_check(
			get_nodes_in_group("selected_units") == [worker],
			faction + ": threatened gatherer not selected"
		)
		await _selection_authority(faction)
		await _visibility_and_roles(faction)
		await _archive_and_retreat(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Engineer response: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _response_fixture(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.set_physics_process(false)
	game.hud._toggle_pause()
	panel = game.hud.battle_plan
	worker = _units(human, "Worker")[0]
	worker.position = Vector3(40, 0, 28)
	var deposit = get_nodes_in_group("resource_units")[0]
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for engineer in _units(human, "Worker"):
		engineer.issue_manual_order(harvest.new(deposit))
	raider = _spawn_response("Tank", enemy, Vector3(44, 0, 28))
	game.battlefield.invalidate()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(5)
	_check(game.battlefield.is_observed(human, raider), "Response fixture has no visible raider")
	_check(plan.idle_workers(human).is_empty(), "Response fixture has idle engineers")


func _spawn_response(role, owner, point):
	var unit = load("res://source/match/units/" + role + ".tscn").instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, true)
	unit.set_physics_process(false)
	return unit


func _authority():
	var result = [paused, game.simulation_time, human.resource_a, human.resource_b]
	for unit in plan.owned_units(human):
		result.append([unit, unit.position, unit.hp, unit.action])
		if unit.type == "Worker":
			result.append([unit.resource_a, unit.resource_b])
		if unit.manual_orders != null:
			result.append(unit.manual_orders.pending.duplicate(true))
	return result


func _selection_authority(faction):
	worker.resource_a = 3
	worker.resource_b = 1
	worker.manual_orders.submit({"kind": "move", "point": Vector3(30, 0, 28)}, true)
	var builder = _units(human, "Worker")[1]
	var original = builder.position
	builder.position = worker.position + Vector3(0, 0, 2)
	var foundation = _spawn_response("PowerPlant", human, Vector3(38, 0, 30))
	foundation._construction_progress = .2
	builder.issue_manual_order(
		load("res://source/match/units/actions/Constructing.gd").new(foundation)
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	var before = _authority()
	for index in 10:
		panel.refresh()
		panel._idle.pressed.emit()
		await _frames(1)
	var selected = get_nodes_in_group("selected_units")
	_check(
		selected.size() == 2 and worker in selected and builder in selected,
		faction + ": danger shortcut omits busy builder or gatherer"
	)
	_check(_authority() == before, faction + ": danger refresh/selection changed gameplay")
	_check(
		"Selection keeps their current orders" in panel._idle.accessibility_description,
		"Engineer shortcut lacks an accessible selection explanation"
	)
	# Existing primary advice must still select the appropriate combat response.
	_check(
		plan.next_step(human).id == "defend_economy", "Engineer shortcut displaced defense advice"
	)
	builder.position = original
	builder.issue_manual_order(null)
	foundation.queue_free()
	await _frames(3)
	# A stale visible shortcut rechecks eligibility when actually clicked.
	raider.position = Vector3(110, 0, 85)
	game.battlefield.invalidate()
	panel._idle.pressed.emit()
	_check(
		get_nodes_in_group("selected_units") == [builder],
		"Stale risk shortcut kept safe busy worker"
	)
	panel.refresh()
	_check(
		panel._idle.text == "Idle engineers · 1", "Safe shortcut did not return to idle engineers"
	)
	raider.position = Vector3(44, 0, 28)
	game.battlefield.invalidate()


func _visibility_and_roles(faction):
	var sights = {}
	for unit in plan.owned_units(human):
		sights[unit] = unit.sight_range
		unit.sight_range = 1.0
	game.battlefield.invalidate()
	raider.visible = true
	_check(not game.battlefield.is_observed(human, raider), "Hidden raider fixture is observed")
	_check(plan.endangered_workers(human).is_empty(), faction + ": hidden attacker leaked danger")
	worker.receive_weapon_hit(raider)
	_check(worker.hp > 0, "Recent-hit fixture killed engineer")
	_check(
		plan.endangered_workers(human) == [worker], "Unseen incoming damage lacks own-unit danger"
	)
	worker.last_enemy_damage_time = game.simulation_time - 6.01
	_check(plan.endangered_workers(human).is_empty(), "Expired hit kept danger shortcut")
	for unit in sights:
		unit.sight_range = sights[unit]
	game.battlefield.invalidate()
	raider.position = Vector3(110, 0, 85)
	var scout = _spawn_response("Drone", enemy, worker.position + Vector3(3, 3, 0))
	var aa = _spawn_response("AntiAirTurret", enemy, worker.position + Vector3(4, 0, 0))
	await _frames(3)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, scout), "Scout fixture not visible")
	_check(
		plan.endangered_workers(human).is_empty(),
		"Unarmed/AA-only contact endangered ground engineers"
	)
	var helicopter = _spawn_response("Helicopter", enemy, worker.position + Vector3(4, 3, 0))
	await _frames(3)
	game.battlefield.invalidate()
	_check(
		plan.endangered_workers(human) == [worker], "Visible strike aircraft did not flag engineer"
	)
	helicopter.queue_free()
	scout.queue_free()
	aa.queue_free()
	await _frames(3)
	raider.position = Vector3(44, 0, 28)
	game.battlefield.invalidate()


func _archive_and_retreat(faction):
	panel.refresh()
	panel._idle.pressed.emit()
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Engineer response capture failed: " + builder.error)
	if data == null:
		return
	var ids = [builder._reference(worker), builder._reference(raider)]
	var archive = "user://engineer-response-%s-%d.json" % [faction, OS.get_process_id()]
	var file = FileStore.new()
	_check(file.write_file(archive, data), "Engineer response disk write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive))
	_check(result.ok, "Engineer response reload failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	worker = restore.entities[ids[0]]
	raider = restore.entities[ids[1]]
	panel = game.hud.battle_plan
	game.get_node("IsometricCamera3D").set_physics_process(false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != worker:
			unit.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	panel.refresh()
	_check(paused and "risk" in panel._idle.text, "Paused archive lost visible danger context")
	var before = _authority()
	panel._idle.pressed.emit()
	_check(_authority() == before, "Restored shortcut changed orders/cargo")
	_check(worker.resource_a == 3 and worker.resource_b == 1, "Archive lost engineer cargo")
	var commands = game.hud.direct_orders
	commands.arm("move")
	_check(_authority() == before, "Arming evacuation issued a move")
	commands.cancel()
	_check(_authority() == before, "Cancelling evacuation changed engineer orders")
	commands.arm("move")
	var destination = worker.position + Vector3(-6, 0, 0)
	_check(commands.commit(destination, null, false), "Explicit engineer evacuation rejected")
	_check(
		worker.manual_orders.pending.size() == 1 and worker.manual_orders.pending[0].kind == "move",
		"Explicit evacuation did not replace the old queued move"
	)
	var origin = worker.position
	var funds = Vector2i(human.resource_a, human.resource_b)
	await _frames(5)
	_check(
		worker.position == origin and worker.resource_a == 3 and worker.resource_b == 1,
		"Paused evacuation moved worker or lost cargo"
	)
	paused = false
	await _frames(180)
	paused = true
	_check(worker.position.distance_to(origin) > 2, "Explicit evacuation did not move on resume")
	_check(
		worker.position.distance_to(destination) < origin.distance_to(destination),
		"Evacuation moved away from chosen destination"
	)
	_check(
		worker.resource_a == 3 and worker.resource_b == 1,
		"Ordinary Move discarded carried resources"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds,
		"Evacuation shortcut spent or granted funds"
	)
	print(
		"PASS: ",
		faction,
		" danger selection, fog, busy jobs, archive and explicit cargo-preserving retreat"
	)
