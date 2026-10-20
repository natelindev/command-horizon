extends "res://tests/headless/BattleDebriefRegression.gd"

var auto_attack_script
var waiting_script


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("frontier", "res://source/match/maps/DesertFrontier.tscn", true)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.hud.pause_after_load()
	await _defense()
	await _statistics()
	for error in errors:
		push_error(error)
	print("Allied defense and statistics: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _spawn_test(role, owner, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, false)
	return unit


func _defense():
	auto_attack_script = load("res://source/match/units/actions/AutoAttacking.gd")
	waiting_script = load("res://source/match/units/actions/WaitingForTargets.gd")
	var owner = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != owner)[0]
	var origin = Vector3(30, 0, 48)
	var victim = _spawn_test("PowerPlant", owner, origin)
	var responder = _spawn_test("Tank", owner, origin + Vector3(0, 0, 7))
	var busy = _spawn_test("Tank", owner, origin + Vector3(2, 0, 7))
	var distant = _spawn_test("Tank", owner, origin + Vector3(0, 0, 20))
	var worker = _spawn_test("Worker", owner, origin + Vector3(0, 0, 5))
	var attacker = _spawn_test("Tank", enemy, origin + Vector3(6, 0, 0))
	await _frames(2)
	busy.manual_orders.submit({"kind": "move", "point": origin + Vector3(0, 0, 30)})
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(owner, attacker), "Defense fixture attacker is hidden")
	victim.receive_weapon_hit(attacker)
	_check(
		is_instance_of(responder.action, auto_attack_script),
		"Idle ally did not defend attacked structure"
	)
	_check(responder.action._target_unit == attacker, "Defender chose wrong attacker")
	_check(
		not is_instance_of(busy.action, auto_attack_script),
		"Defense replaced explicit movement order"
	)
	_check(
		not is_instance_of(distant.action, auto_attack_script), "Distant unit joined local fight"
	)
	_check(not is_instance_of(worker.action, auto_attack_script), "Unarmed worker joined fight")
	var old_action = responder.action
	victim.receive_weapon_hit(attacker)
	_check(responder.action == old_action, "Repeated damage restarted defensive action")
	var starting_hp = attacker.hp
	game.hud._toggle_pause()
	for frame in 360:
		await physics_frame
		if attacker.hp < starting_hp:
			break
	game.hud.pause_after_load()
	_check(attacker.hp < starting_hp, "Defender did not move into range and fire")
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Defense snapshot failed: " + builder.error)
	var id = builder._reference(responder)
	var attacker_id = builder._reference(attacker)
	var restore = Restore.new()
	var loaded = await restore.restore(self, snapshot)
	_check(loaded.ok, "Defensive action did not restore: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	responder = restore.entities[id]
	attacker = restore.entities[attacker_id]
	_check(
		(
			is_instance_of(responder.action, auto_attack_script)
			and responder.action._defense_radius > 0
		),
		"Defense pursuit limit was lost on load"
	)
	attacker.position = origin + Vector3(30, 0, 0)
	game.battlefield.invalidate()
	responder.action._refresh()
	await _frames(3)
	_check(
		is_instance_of(responder.action, waiting_script), "Defender pursued beyond local engagement"
	)
	# Unit damage uses the same assistance path; player commands can override it immediately.
	owner = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(p): return p != owner)[0]
	var friend = _spawn_test("Worker", owner, origin)
	attacker.position = origin + Vector3(5, 0, 0)
	game.battlefield.invalidate()
	friend.receive_weapon_hit(attacker)
	_check(
		is_instance_of(responder.action, auto_attack_script),
		"Idle ally did not defend attacked worker"
	)
	responder.manual_orders.submit({"kind": "move", "point": origin + Vector3(0, 0, 25)})
	_check(
		not is_instance_of(responder.action, auto_attack_script),
		"Manual retreat could not override defense"
	)


func _statistics():
	var owner = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != owner)[0]
	var record = game.battle_record
	var attacker = _units(owner, "Tank")[0]
	var before_kills = record.data.statistics.units_destroyed
	var victim = _spawn_test("Tank", enemy, Vector3(35, 0, 45))
	victim.hp = 1
	victim.receive_weapon_hit(attacker)
	_check(
		record.data.statistics.units_destroyed == before_kills + 1, "Lethal weapon hit not credited"
	)
	victim.receive_weapon_hit(attacker)
	_check(
		record.data.statistics.units_destroyed == before_kills + 1, "Destroyed unit counted twice"
	)
	var building = _spawn_test("PowerPlant", enemy, Vector3(38, 0, 45))
	building.hp = 1
	building.receive_weapon_hit(attacker)
	_check(record.data.statistics.structures_destroyed == 1, "Destroyed building not credited")
	var foundation = _foundation(owner)
	foundation.construct(1.0)
	_check(record.data.statistics.structures_built == 1, "Completed building not recorded")
	var worker = _units(owner, "Worker")[0]
	var deposit = get_nodes_in_group("resource_units").filter(func(u): return "resource_a" in u)[0]
	worker.position = deposit.position + Vector3(worker.radius + deposit.radius, 0, 0)
	var harvest = load("res://source/match/units/actions/CollectingResourcesWhileInRange.gd").new(
		deposit
	)
	worker.action = harvest
	var before = record.data.statistics.materials
	harvest._transfer_single_resource_unit_from_resource_to_worker()
	_check(record.data.statistics.materials == before + 1, "Actual mining transfer not recorded")
	var original = record.capture()
	_check(record.valid(original), "Current battle record rejected")
	var incomplete = original.duplicate(true)
	incomplete.erase("statistics")
	_check(not record.valid(incomplete), "Battle record without statistics accepted")
	for value in [-1, 1.5, INF]:
		var corrupt = original.duplicate(true)
		corrupt.statistics.materials = value
		_check(not record.valid(corrupt), "Invalid statistic accepted")
	var snapshot = Snapshot.new().capture(game)
	var loaded = await Restore.new().restore(self, snapshot)
	_check(loaded.ok, "Statistics archive restore failed")
	if loaded.ok:
		game = loaded.game
		_check(game.battle_record.capture() == original, "Statistics changed on save/load")
	game.finished = true
	game.result = "Victory"
	game.hud.show_result(game.result)
	_check(
		game.hud._overlay.find_children("Statistics", "ScrollContainer", true, false).size() == 1,
		"Result screen missing statistics table"
	)
