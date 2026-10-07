extends "res://tests/headless/SaveRestoreEdges.gd"

var shooting
var moving
var rules
var lua_action_type


func _run():
	shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	rules = load("res://source/match/combat/CombatRules.gd")
	lua_action_type = load("res://source/match/programs/LuaAction.gd")
	await _setup("bastion")
	_check(await _bastion() == true, "Bastion suite did not finish")
	await _clean_match()
	await _setup("helix")
	_check(await _helix() == true, "Helix suite did not finish")
	await _clean_match()
	await _setup("bastion")
	_check(await _enemy_modes() == true, "AI suite did not finish")
	await _clean_match()
	print("Weapon modes: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _setup(faction):
	await _skirmish(faction)
	for side in get_nodes_in_group("players"):
		if side != game._get_human_player():
			side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)


func _clean_match():
	paused = false
	game.queue_free()
	await _frames(5)


func _spawn_weapon(role, side, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, true)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _sides():
	var human = game._get_human_player()
	return [human, get_nodes_in_group("players").filter(func(side): return side != human)[0]]


func _bastion():
	var sides = _sides()
	var walker = _spawn_weapon("CombatRobot", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(45, 0, 10))
	var air = _spawn_weapon("Drone", sides[1], Vector3(45, 0, 10))
	await _frames(40)
	_check(not walker.request_weapon_mode("interception"), "Bastion accepted Helix stance")
	_check(game.battlefield.can_fire(walker, target), "Walker ground range was shortened")
	_check(not game.battlefield.can_fire(walker, air), "Walker AA exceeds 4.5 m")
	air.global_position.x = 44
	game.battlefield.invalidate()
	_check(game.battlefield.can_fire(walker, air), "Walker cannot intercept nearby aircraft")
	walker.process_mode = Node.PROCESS_MODE_PAUSABLE
	walker.issue_manual_order(shooting.new(target, 1))
	await _frames(16)
	_check(is_equal_approx(target.hp_max - target.hp, 2.25), "Walker autocannon armor profile")
	var hp = air.hp
	walker.issue_manual_order(shooting.new(air, 1))
	await _frames(10)
	_check(air.hp == hp, "Changing target domain reset the shared reload")
	await _frames(30)
	_check(is_equal_approx(hp - air.hp, 5.0), "Walker AA profile did not fire after shared reload")
	# Lua contact legality must agree with actual short-range AA.
	air.global_position.x = 45
	var lua_action = lua_action_type.new(walker.program)
	lua_action._unit = walker
	_check(not lua_action._record(air, 1).can_attack, "Lua advertises out-of-range walker AA")
	lua_action.free()
	print("PASS: Bastion ground/AA range, armor and shared reload")
	return true


func _helix():
	var sides = _sides()
	var walker = _spawn_weapon("CombatRobot", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(45, 0, 10))
	var air = _spawn_weapon("Drone", sides[1], Vector3(44, 0, 12))
	await _frames(40)
	_check(walker.weapon_mode == "precision", "Lancer did not start in Precision")
	_check(is_equal_approx(rules.damage(walker, target), 30.0), "Precision lacks armor advantage")
	_check(rules.damage(walker, air) == 0, "Precision can damage air")
	var infantry = _spawn_weapon("Infantry", sides[1], Vector3(46, 0, 15))
	var support = _spawn_weapon("RepairRobot", sides[1], Vector3(46, 0, 18))
	_check(is_equal_approx(rules.damage(walker, infantry), 4.5), "Lance lost its infantry weakness")
	_check(
		is_equal_approx(rules.damage(walker, support), 12.0), "Lance light-machine damage changed"
	)
	target.global_position.x = 47.8
	game.battlefield.invalidate()
	_check(game.battlefield.can_fire(walker, target), "Lancer cannot use its new standoff reach")
	_check(
		game.battlefield.fireable_targets(walker).has(target),
		"Candidate search truncated Helix Precision range"
	)
	target.global_position.x = 48.2
	_spawn_weapon("Drone", sides[0], Vector3(46, 0, 10))
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(sides[0], target), "Range probe target is hidden")
	_check(not game.battlefield.can_fire(walker, target), "Lance exceeds eight-metre range")
	_check(
		not game.battlefield.fireable_targets(walker).has(target),
		"Candidate search exceeded current weapon range"
	)
	target.global_position.x = 45
	game.battlefield.invalidate()
	walker.process_mode = Node.PROCESS_MODE_PAUSABLE
	var order = moving.new(Vector3(42, 0, 8))
	walker.issue_manual_order(order)
	var start = walker.global_position
	_check(walker.request_weapon_mode("interception"), "Interception switch rejected")
	_check(walker.action == order, "Mode switch replaced a movement order")
	_check(not walker.request_weapon_mode("precision"), "Switch can be cancelled to evade lock")
	await _frames(60)
	_check(walker.global_position.distance_to(start) > 0.5, "Switch freezes movement")
	var left = walker.weapon_switch_left
	paused = true
	await _frames(40)
	_check(walker.weapon_switch_left == left, "Switch advances while paused")
	paused = false
	await _frames(70)
	_check(walker.weapon_mode == "interception", "Switch did not finish")
	_check(rules.damage(walker, target) == 0, "Interception still damages ground")
	_check(is_equal_approx(rules.damage(walker, air), 5), "Interception damage profile")
	walker.global_position = Vector3(40, 0.6, 10)
	walker.get_node("Movement").stop()
	game.battlefield.invalidate()
	walker.issue_manual_order(shooting.new(air, 1))
	await _frames(15)
	_check(is_equal_approx(air.hp_max - air.hp, 5), "Lancer did not actually intercept aircraft")
	# Preserve a longer existing cooldown across a switch and a real archive reload.
	_check(walker.request_weapon_mode("precision"), "Return to Precision rejected")
	var contact_reader = lua_action_type.new(walker.program)
	contact_reader._unit = walker
	_check(not contact_reader._record(air, 1).can_attack, "Lua ignores the switching lock")
	contact_reader.free()
	walker.issue_manual_order(shooting.new(air))
	var hp = air.hp
	await _frames(60)
	_check(air.hp == hp, "Lancer fired during a mode switch")
	walker.set_meta("next_attack_availability_time", int(game.simulation_time * 1000) + 4000)
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Weapon snapshot failed: " + builder.error)
	if snapshot == null:
		return false
	var saved = snapshot.units.filter(func(entry): return entry.role == "CombatRobot")[0]
	var broken = snapshot.duplicate(true)
	broken.units.filter(func(entry): return entry.id == saved.id)[0].weapon_mode.weapon_switch_left = 3
	_check(not Restore.new().prepare(broken), "Oversized mode duration accepted")
	broken = snapshot.duplicate(true)
	var broken_mode = broken.units.filter(func(entry): return entry.id == saved.id)[0].weapon_mode
	broken_mode.pending_weapon_mode = "interception"
	_check(not Restore.new().prepare(broken), "Same-mode transition accepted")
	var legacy = _legacy_snapshot(snapshot, 1)
	var legacy_reader = Restore.new()
	_check(legacy_reader.prepare(legacy), "Version-one archive rejected")
	_check(not legacy_reader.warnings.is_empty(), "Legacy Lancer mode migration is not disclosed")
	var archive = "user://weapon-mode-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(archive, snapshot), "Weapon archive write failed")
	var restored = await Restore.new().restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(restored.ok, "Weapon restore failed: " + restored.get("error", ""))
	if not restored.ok:
		return false
	game = restored.game
	walker = _units(game._get_human_player(), "CombatRobot")[0]
	_check(walker.weapon_mode == "interception", "Restore committed a pending mode too early")
	_check(walker.weapon_switch_left == saved.weapon_mode.weapon_switch_left, "Switch time lost")
	var remaining = walker.weapon_switch_left
	await _frames(20)
	_check(walker.weapon_switch_left == remaining, "Loaded paused mode advanced")
	var enemy = _sides()[1]
	enemy.set_process(false)
	for unit in enemy.get_children():
		if "hp" in unit:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var ground = _units(enemy, "Tank").filter(func(unit): return unit.position.z < 15)[0]
	var ground_hp = ground.hp
	game.hud._toggle_pause()
	await _frames(100)
	_check(walker.weapon_mode == "precision", "Loaded switch did not finish")
	_check(
		walker.get_meta("next_attack_availability_time") > int(game.simulation_time * 1000),
		"Mode change reset an existing weapon cooldown"
	)
	_check(ground.hp == ground_hp, "Restored switch bypassed cooldown and fired early")
	# The new Precision shot prepares for 0.75 s after the preserved reload.
	await _frames(220)
	_check(ground.hp < ground_hp, "Precision never resumed firing after the restored cooldown")
	paused = true
	var old = await Restore.new().restore(self, legacy)
	_check(old.ok, "Version-one archive cannot reconstruct")
	if not old.ok:
		return false
	game = old.game
	walker = _units(game._get_human_player(), "CombatRobot")[0]
	_check(
		walker.weapon_mode == "precision" and walker.weapon_switch_left == 0, "Legacy mode default"
	)
	print("PASS: Helix domains, switch firing lock, movement/pause, cooldown and v1/v2 archives")
	return true


func _enemy_modes():
	var sides = _sides()
	var ai = sides[1]
	var walker = _spawn_weapon("CombatRobot", ai, Vector3(40, 0, 10))
	var air = _spawn_weapon("Drone", sides[0], Vector3(46, 0, 10))
	var blocker = _spawn_weapon("Barracks", ai, Vector3(43, 0, 10))
	blocker.construct(1.0)
	await _frames(40)
	# A nearby aircraft behind a building must not influence the AI's weapon choice.
	for unit in ai.get_children():
		if "sight_range" in unit:
			unit.sight_range = 0.1
	walker.sight_range = 8
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(ai, air), "Hidden-air fixture is visible")
	ai._choose_weapon_modes([walker])
	_check(walker.pending_weapon_mode == "", "AI reacted to hidden aircraft")
	blocker.queue_free()
	await _frames(40)
	game.battlefield.invalidate()
	ai._choose_weapon_modes([walker])
	_check(walker.pending_weapon_mode == "interception", "AI ignored observed aircraft")
	walker.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _frames(125)
	air.global_position = Vector3(60, 2, 10)
	game.battlefield.invalidate()
	ai._choose_weapon_modes([walker])
	_check(
		walker.weapon_mode == "interception" and walker.pending_weapon_mode == "",
		"AI churns modes without contacts"
	)
	_spawn_weapon("Tank", sides[0], Vector3(46, 0, 10))
	await _frames(5)
	game.battlefield.invalidate()
	ai._choose_weapon_modes([walker])
	_check(walker.pending_weapon_mode == "precision", "AI cannot return to observed ground combat")
	print("PASS: AI chooses modes from observed contacts and retains stance without contacts")
	return true


func _check(value, message):
	if not value:
		errors.append(message)
		push_error(message)


func _legacy_snapshot(snapshot, version):
	var result = snapshot.duplicate(true)
	result.snapshot_version = version
	result.erase("battle_record")
	for resource in result.resources:
		resource.erase("wreck")
	result.erase("ambient")
	for side in result.players:
		side.erase("technology")
		side.erase("signatures")
	for unit in result.units:
		unit.erase("signature")
		if version < 3:
			unit.erase("deployment")
		if version == 1:
			unit.erase("weapon_mode")
		_legacy_action(unit.action, version)
	return result


func _legacy_action(action, version):
	if action.is_empty():
		return
	if version < 3 and action.kind == "AttackingWhileInRange":
		for field in ["_charge_left", "_charge_total", "_charge_origin"]:
			action.state.erase(field)
	if version < 5 and action.kind == "CollectingResourcesSequentially":
		for field in ["_kind", "_field_origin", "_waiting_reason", "_retry_left"]:
			action.state.erase(field)
	for child in action.children.values():
		_legacy_action(child, version)
