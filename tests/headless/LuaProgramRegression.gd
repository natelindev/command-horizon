extends "res://tests/headless/SpecialistRegression.gd"

const LUA_HOLD = """return function(s,m)
    m.ticks=(m.ticks or 0)+1
    return {intent={kind='hold'}, state=m}
end"""
const LUA_MOVE = """return function(s,m)
    return {intent={kind='move', assignment='anchor'},state=m}
end"""
const LUA_ATTACK = """return function(s,m)
    for _,e in ipairs(s.enemies) do
        if e.can_attack then return {intent={kind='attack',target=e.id},state=m} end
    end
    return {intent={kind='hold'},state=m}
end"""
const LUA_REPAIR = """return function(s,m)
    for _,e in ipairs(s.allies) do
        if e.hp<e.hp_max then return {intent={kind='repair',target=e.id},state=m} end
    end
    return {intent={kind='hold'},state=m}
end"""


func _run():
	_moving = load("res://source/match/units/actions/Moving.gd")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(40)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for player in [_human, _enemy]:
		var gated = _spawn("CombatRobot", player, Vector3(20, 0, 19))
		_check(gated.program.configure_lua(LUA_HOLD).ok, "Gate fixture rejected source")
		_check(not gated.program.run(), "Lua bypassed the technology gate")
		_spawn("VehicleFactory", player, Vector3(12, 0, 12))
		_spawn("CommandLab", player, Vector3(18, 0, 12))
		_check(player.basic_programs_unlocked(), "Lua fixture locked")
		var conventional = _spawn("Tank", player, Vector3(21, 0, 19))
		conventional.program.configure_lua(LUA_HOLD)
		_check(not conventional.program.run(), "Lua bypassed the hardware gate")
		var tank = _spawn("Tank", player, Vector3(22, 0, 22), true)
		_check(tank.program.configure_lua(LUA_HOLD).ok, "Lua configuration failed")
		await _lua_authority(tank)
		await _lua_fault(tank)
		await _lua_contacts(tank, player)
		await _lua_repair(player)
		await _lua_escort(player)
		await _clear()
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print("PASS: both-faction Lua actions, perception, pause/manual, faults and clean Resume")
	quit(0 if _errors.is_empty() else 1)


func _lua_authority(tank):
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	var program = tank.program
	_check(program.run(), "Valid Lua did not start")
	await _frames(35)
	_check(
		program.mode == "Running" and program.lua_runtime.state_snapshot().ticks > 0,
		"Lua was not evaluated by simulation"
	)
	_game.hud._toggle_pause()
	var ticks = program.lua_runtime.state_snapshot().ticks
	await _frames(30)
	_check(program.lua_runtime.state_snapshot().ticks == ticks, "Lua advanced while paused")
	_game.hud._toggle_pause()
	tank.issue_manual_order(_moving.new(Vector3(26, 0, 22)))
	var action = tank.action
	_check(program.mode == "Manual", "Manual order did not suspend Lua")
	_check(not program.configure_lua("return function(").ok, "Broken Lua accepted")
	_check(tank.action == action, "Rejected Lua replaced manual order")
	await _frames(180)
	_check(
		(
			tank.global_position_yless.distance_to(
				(
					NavigationServer3D.map_get_closest_point(
						tank.get_node("Movement").get_navigation_map(), Vector3(26, 0, 22)
					)
					* Vector3(1, 0, 1)
				)
			)
			< 0.5
		),
		"Lua prevented manual movement"
	)
	_check(
		program.lua_runtime.state_snapshot().ticks == ticks, "Lua kept evaluating after override"
	)
	_check(program.configure_lua(LUA_MOVE).ok, "Move script rejected")
	program.anchor = null
	_check(program.run(), "Lua missing-assignment run rejected")
	await _frames(35)
	_check(program.mode == "Waiting", "Missing Lua assignment did not wait")
	program.anchor = Vector3(29, 0, 22)
	await _frames(150)
	_check(tank.global_position_yless.distance_to(program.anchor) < 1.5, "Assigned Lua move failed")
	program.configure_lua(LUA_HOLD)
	program.run()
	await _frames(20)
	program.configure(Library.defaults("guard"))
	_check(
		program.lua_source.is_empty() and program.lua_runtime == null, "Preset retained custom Lua"
	)


func _lua_fault(tank):
	var program = tank.program
	(
		program
		. configure_lua(
			"""return function(s,m)
    m.tick=(m.tick or 0)+1
    if m.tick==1 then
        return {intent={kind='move',assignment='anchor'},state=m}
    end
    while true do end
end""",
			"Fault test v1"
		)
	)
	program.anchor = Vector3(35, 0, 30)
	program.run()
	await _frames(60)
	_check(program.mode == "Error" and "budget" in program.reason, "Budget did not suspend unit")
	_check(
		program.lua_runtime.state_snapshot().get("tick") == 1,
		"Fault fixture never issued its first move or committed invalid state"
	)
	_check(not tank.get_node("Movement")._has_destination, "Fault retained movement")
	_check(is_instance_valid(tank.action._defense), "Fault did not retain idle defense")
	var runtime = program.lua_runtime
	var metrics = runtime.metrics.duplicate(true)
	var trace = program.trace.size()
	await _frames(90)
	_check(
		program.trace.size() == trace and runtime.metrics == metrics, "Fault repeatedly restarted"
	)
	tank.issue_manual_order(_moving.new(Vector3(26, 0, 23)))
	_check(program.mode == "Manual", "Fault prevented a manual override")
	await _frames(120)
	program.configure_lua(LUA_HOLD)
	program.run()
	await _frames(40)
	_check(program.lua_runtime.state_snapshot().ticks > 0, "Replacement failed to recover")
	program.run()
	_check(program.lua_runtime.state_snapshot().is_empty(), "Resume did not clear Lua state")
	await _frames(20)


func _lua_contacts(tank, player):
	var opponent = _opponent(player)
	tank.issue_manual_order(null)
	tank.global_position = Vector3(30, 0, 30)
	tank.program.configure_lua(LUA_ATTACK)
	tank.program.run()
	var target = _spawn("Tank", opponent, Vector3(33, 0, 30))
	target.hp_max = 10000
	target.hp = 10000
	await _frames(120)
	_check(target.hp < 10000, "Lua did not fire a real weapon")
	var action = tank.action
	var snapshot = action._snapshot()
	_check(snapshot.enemies.any(func(entry): return entry.can_attack), "No legal enemy in snapshot")
	var handle = snapshot.enemies[0].id
	target.global_position = Vector3(72, 0, 72)
	_game.battlefield.invalidate()
	snapshot = action._snapshot()
	_check(not snapshot.enemies.any(func(entry): return entry.id == handle), "Hidden target leaked")
	action._apply_intent({"kind": "attack", "target": handle})
	_check(
		tank.program.mode == "Waiting" and not is_instance_valid(action._shot),
		"Stale target handle authorized fire"
	)
	for index in range(40):
		_spawn("Drone", player, Vector3(30 + (index % 8) * 0.5, 0, 32 + (index / 8) * 0.5))
	_game.battlefield.invalidate()
	snapshot = action._snapshot()
	_check(
		snapshot.allies.size() + snapshot.enemies.size() == 32 and snapshot.contacts_truncated,
		"Lua contacts were not capped"
	)
	var again = action._snapshot()
	_check(
		again == snapshot and action._handles.size() == 32 and action._known.size() == 32,
		"Unstable contact ordering/handles or unbounded retention"
	)
	tank.program.disable()


func _lua_repair(player):
	var robot = _spawn("RepairRobot", player, Vector3(50, 0, 30), true)
	var friend = _spawn("Tank", player, Vector3(52, 0, 30))
	friend.hp = friend.hp_max * 0.5
	robot.process_mode = Node.PROCESS_MODE_INHERIT
	robot.program.configure_lua(LUA_REPAIR)
	robot.program.anchor = robot.global_position_yless
	robot.program.run()
	var before = friend.hp
	await _frames(150)
	_check(friend.hp > before, "Lua repair did not use the shared repair service")
	robot.program.disable()
	var tank = _spawn("Tank", player, Vector3(51, 0, 33), true)
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	tank.program.configure_lua(LUA_REPAIR)
	tank.program.anchor = tank.global_position_yless
	tank.program.run()
	await _frames(40)
	_check(
		tank.program.mode == "Waiting" and "cannot repair" in tank.program.reason,
		"Lua bypassed repair capability"
	)
	robot.queue_free()
	friend.queue_free()
	tank.queue_free()
	await _frames(3)


func _lua_escort(player):
	var drone = _spawn("Drone", player, Vector3(42, 0, 40))
	var ally = _spawn("Tank", player, Vector3(46, 0, 40))
	var foreign = _spawn("Tank", _opponent(player), Vector3(48, 0, 40))
	drone.process_mode = Node.PROCESS_MODE_INHERIT
	drone.program.configure_lua("return function(s,m) return {intent={kind='escort'},state=m} end")
	drone.program.run()
	await _frames(40)
	_check(drone.program.mode == "Waiting", "Missing escort did not wait")
	drone.program.escort = foreign
	await _frames(30)
	_check(drone.program.mode == "Waiting", "Foreign escort accepted")
	drone.program.escort = ally
	await _frames(150)
	_check(
		drone.global_position_yless.distance_to(ally.global_position_yless) < 3.3,
		"Lua escort did not follow its assigned ally"
	)
	ally.queue_free()
	await _frames(35)
	_check(drone.program.mode == "Waiting", "Destroyed escort did not wait")
	drone.program.configure_lua(
		"return function(s,m) return {intent={kind='move',assignment='safe'},state=m} end"
	)
	drone.program.safe_point = Vector3(40, 0, 40)
	drone.program.run()
	await _frames(150)
	_check(
		drone.global_position_yless.distance_to(drone.program.safe_point) < 1.2,
		"Lua safe-point move failed"
	)
	drone.program.route = [Vector3(40, 0, 41), Vector3(40, 0, 43)]
	_check(
		(
			drone.action._assigned_point("route_a") == drone.program.route[0]
			and drone.action._assigned_point("route_b") == drone.program.route[1]
		),
		"Route points swapped"
	)
	drone.queue_free()
	foreign.queue_free()
	await _frames(3)
