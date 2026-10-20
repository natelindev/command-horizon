extends "res://tests/headless/SaveRestoreEdges.gd"

var Behavior
var Following


func _run():
	Behavior = load("res://source/match/orders/UnitBehavior.gd")
	Following = load("res://source/match/units/actions/Following.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/BigArena.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		await _behaviors()
		await _save_behaviors()
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Unit behaviors: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _behaviors():
	for unit in get_nodes_in_group("units"):
		if unit.attack_range != null:
			Behavior.set_stance(unit, "hold_fire")
	var player = game._get_human_player()
	var tank = _units(player, "Tank")[0]
	var ally = _units(player, "Tank")[1]
	tank.position = Vector3(38, 0, 40)
	ally.position = Vector3(44, 0, 36)
	var opponent = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	var target = _units(opponent, "Tank")[0]
	target.position = Vector3(42, 0, 43)
	var initial_health = target.hp
	Behavior.set_stance(target, "hold_fire")
	game.battlefield.invalidate()
	var temporary = load("res://source/match/units/Infantry.tscn").instantiate()
	game._setup_and_spawn_unit(
		temporary, Transform3D(Basis.IDENTITY, Vector3(39.04, 0, 40)), player, false
	)
	var query = Vector3(38.91, 0, 40)
	game.battlefield.nearby_units(query, .04)
	temporary.position.x = 38.92
	_check(
		game.battlefield.nearby_units(query, .04).has(temporary),
		"Spatial cache missed a body crossing its cell in the same tick"
	)
	temporary.free()
	var survivors = game.battlefield.nearby_units(Vector3(40, 0, 40), 2.0)
	_check(
		survivors != null and survivors.all(func(unit): return is_instance_valid(unit)),
		"Spatial cache retained a freed body"
	)

	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	await _frames(3)
	var menus = game.find_child("UnitMenus")
	_check(is_instance_valid(menus._behavior_panel), "Behavior controls missing")
	_check(
		menus._orders_panel.find_children("*", "CheckBox", true, false).is_empty(),
		"Retired auto-resume control remains"
	)
	_check(
		menus._behavior_panel.find_child("HoldFire", true, false) != null,
		"Hold Fire control missing"
	)
	Behavior.set_stance(tank, "attack")
	await _frames(120)
	_check(target.hp < initial_health, "Attack did not fire")
	Behavior.set_stance(tank, "hold_fire")
	await _frames(120)  # Allow shots already in flight to resolve.
	var health = target.hp
	await _frames(120)
	_check(
		target.hp == health and tank.aim_target == null, "Hold Fire continued automatic shooting"
	)
	Behavior.set_stance(tank, "defensive")
	_check(tank.stance == tank.Stance.DEFENSIVE, "Defensive stance was not applied")
	# Pause retains input while neither movement nor firing advances.
	paused = true
	var clock = game.simulation_time
	var before = tank.position
	game.hud.direct_orders.arm("guard")
	_check(game.hud.direct_orders.commit(Vector3(35, 0, 39), null, false), "Guard command rejected")
	await _frames(5)
	_check(
		game.simulation_time == clock and tank.position == before,
		"Paused guard advanced simulation"
	)
	paused = false
	await _frames(240)
	_check(
		tank.position.distance_to(Vector3(35, 0, 39)) < 1.5,
		"Guard did not reach its assigned point"
	)
	_check(tank.stance == tank.Stance.HOLD_POSITION, "Guard did not retain its stance")
	game.hud.direct_orders.arm("follow")
	_check(not game.hud.direct_orders.commit(null, target, false), "Follow accepted an enemy")
	_check(game.hud.direct_orders.commit(null, ally, false), "Follow rejected an ally")
	await _frames(180)
	_check(tank.action.get_script() == Following, "Follow did not retain the moving target")
	ally.position += Vector3(0, 0, -4)
	await _frames(240)
	_check(
		tank.position.distance_to(ally.position) < 3.5,
		"Follower did not follow a changed destination"
	)


func _save_behaviors():
	paused = true
	var tank = _units(game._get_human_player(), "Tank")[0]
	var capture = Snapshot.new()
	var saved = capture.capture(game)
	_check(saved != null, "Behavior save failed: " + capture.error)
	if saved == null:
		return
	var invalid = saved.duplicate(true)
	invalid.units[0].stance = -1
	_check(not Restore.new().prepare(invalid), "Archive accepted an invalid stance")
	var older = saved.duplicate(true)
	older.snapshot_version = Snapshot.VERSION - 1
	_check(not Restore.new().prepare(older), "Retired save format was accepted")
	var id = capture._reference(tank)
	var loader = Restore.new()
	var loaded = await loader.restore(self, saved)
	_check(loaded.ok, "Behavior load failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	tank = loader.entities[id]
	_check(
		tank.stance == tank.Stance.DEFENSIVE and tank.action.get_script() == Following,
		"Follow/stance failed to restore"
	)

