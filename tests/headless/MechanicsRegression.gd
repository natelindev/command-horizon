extends "res://tests/headless/MatchFixture.gd"

var orders = null
var waiting = null
var attack_move = null
var harvest = null
var auto_attack = null


func _run():
	orders = load("res://source/match/orders/ManualOrders.gd")
	waiting = load("res://source/match/units/actions/WaitingForTargets.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	auto_attack = load("res://source/match/units/actions/AutoAttacking.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		await _group_destinations()
		await _clear()
		await _automatic_counters()
		await _clear()
		await _incoming_fire()
		await _clear()
		await _garrison_range()
		await _clear()
		await _repair_ownership()
		await _clear()
		await _drop_off_ownership()
		await _clear()
		await _mixed_support_orders()
		await _clear()
		await _service_routes()
		await _clear()
		await _defense_budget()
		await _clear()
		paused = false
		_game.queue_free()
		await _frames(5)
		print("MECHANICS faction=", faction, " cumulative_failures=", _errors.size())
	for message in _errors:
		push_error(message)
	print("Mechanics regression: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _open(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	for side in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = side + 1
		player.faction = faction
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(p): return p != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)


func _group_destinations():
	var movement_utils = load("res://source/match/utils/UnitMovementUtils.gd")
	var members = []
	for index in 8:
		var unit = _spawn("Tank", _human, Vector3(25 + index * 2, 0, 25))
		members.append(unit)
	await _frames(30)
	var point = Vector3(0.1, 0, 0.1)
	var pairs = movement_utils.crowd_moved_to_new_pivot(members, point)
	_check(pairs.size() == members.size(), "Formation lost selected members")
	var endpoints = []
	for pair in pairs:
		var movement = pair[0].get_node("Movement")
		var nav = movement.get_navigation_map()
		var projected = NavigationServer3D.map_get_closest_point(nav, pair[1])
		_check(
			pair[1].distance_to(projected * Vector3(1, 0, 1)) < 0.15,
			"Group destination falls outside navigable ground"
		)
		for previous in endpoints:
			_check(
				projected.distance_to(previous[1]) >= pair[0].radius + previous[0].radius,
				"Group destinations collapse into overlapping boundary slots"
			)
		endpoints.append([pair[0], projected])
	# Selection can include units already touching at a choke or work face.
	for unit in members:
		unit.position = Vector3(30, 0, 30)
	pairs = movement_utils.crowd_moved_to_new_pivot(members, Vector3(40, 0, 40))
	for index in pairs.size():
		for previous in range(index):
			_check(
				(
					pairs[index][1].distance_to(pairs[previous][1])
					>= pairs[index][0].radius + pairs[previous][0].radius
				),
				"Coincident origins produce coincident destinations"
			)
	_check(
		movement_utils.crowd_moved_to_new_pivot([members[0]], point)[0][1] == point,
		"Single-unit order changed its explicit destination"
	)


func _automatic_counters():
	var shooter = _spawn("RocketInfantry", _human, Vector3(35, 0, 35))
	var infantry = _spawn("Infantry", _enemy, Vector3(37, 0, 35))
	var armor = _spawn("Tank", _enemy, Vector3(39, 0, 35))
	await _frames(5)
	_game.battlefield.invalidate()
	_check(_game.battlefield.can_fire(shooter, armor), "Counter fixture cannot fire at armor")
	shooter.action = waiting.new()
	shooter.action._on_timer_timeout()
	_check(
		shooter.action._sub_action._target_unit == armor,
		"Anti-armor infantry wastes automatic fire on the nearer rifleman"
	)
	shooter.action = attack_move.new(Vector3(45, 0, 35))
	shooter.action._physics_process(0.2)
	_check(
		is_instance_valid(shooter.action._shot) and shooter.action._shot._target_unit == armor,
		"Attack-move ignores the weapon's effective counter"
	)
	# Explicit targets retain authority over automatic preferences.
	shooter.action = auto_attack.new(infantry)
	_check(shooter.action._target_unit == infantry, "Automatic preference replaced explicit attack")
	var far = Vector3(120, 0, 100)
	armor.position = far
	_game.battlefield.invalidate()
	shooter.action = waiting.new()
	shooter.action._on_timer_timeout()
	_check(
		shooter.action._sub_action._target_unit == infantry,
		"Automatic preference selected hidden armor"
	)


func _garrison_range():
	var source = _spawn("Infantry", _human, Vector3(45, 0, 40))
	var host = _spawn("Barracks", _human, source.position)
	var target = _spawn(
		"Infantry", _enemy, source.position + Vector3(source.attack_range + 1, 0, 0)
	)
	source.set_meta("garrison_host", host)
	source.set_meta("next_attack_availability_time", 1000000)
	await _frames(5)
	_game.battlefield.invalidate()
	_check(
		_game.battlefield.can_fire(source, target), "Garrison fixture has no legal extended shot"
	)
	source.action = attack_move.new(source.position)
	source.action._physics_process(0.2)
	_check(
		is_instance_valid(source.action._shot), "Attack-move discarded a legal garrison-range shot"
	)
	source.remove_meta("garrison_host")


func _incoming_fire():
	var first = _spawn("RocketInfantry", _human, Vector3(35, 0, 35))
	var second = _spawn("RocketInfantry", _human, Vector3(35, 0, 37))
	var doomed = _spawn("Tank", _enemy, Vector3(38, 0, 35))
	var fresh = _spawn("Tank", _enemy, Vector3(40, 0, 37))
	await _frames(5)
	_game.battlefield.invalidate()
	var rules = load("res://source/match/combat/CombatRules.gd")
	doomed.hp = rules.damage(first, doomed) * 0.5
	first.process_mode = Node.PROCESS_MODE_INHERIT
	first.action = load("res://source/match/units/actions/AttackingWhileInRange.gd").new(doomed)
	_check(
		first.get_children().any(
			func(child): return "target_unit" in child and child.target_unit == doomed
		),
		"Incoming-fire fixture did not launch a projectile"
	)
	second.action = waiting.new()
	second.action._on_timer_timeout()
	_check(
		second.action._sub_action._target_unit == fresh,
		"Automatic fire wastes a second rocket on an already lethal incoming shot"
	)
	await _frames(50)
	_check(not is_instance_valid(doomed), "Committed projectile did not deliver the predicted kill")
	second.action = waiting.new()
	second.action._on_timer_timeout()
	_check(
		second.action._sub_action._target_unit == fresh,
		"Resolved projectile retained a stale claim"
	)


func _repair_ownership():
	var robot = _spawn("RepairRobot", _human, Vector3(40, 0, 50))
	var target = _spawn("Tank", _human, Vector3(42, 0, 50))
	target.hp *= 0.5
	robot.process_mode = Node.PROCESS_MODE_INHERIT
	robot.manual_orders.submit(orders.target_order("repair", target))
	robot.manual_orders.submit(orders.point_order("move", Vector3(40, 0, 54)), true)
	await _frames(5)
	_check(robot.manual_orders.current.get("kind") == "repair", "Repair fixture did not start")
	target.reparent(_enemy, true)
	await _frames(45)
	_check(
		robot.manual_orders.current.get("kind") == "move",
		"Repair of a captured ally strands the queued retreat"
	)


func _drop_off_ownership():
	var worker = _spawn("Worker", _human, Vector3(40, 0, 55))
	var hq = _spawn("CommandCenter", _human, Vector3(44, 0, 55))
	worker.resource_a = 3
	var action = harvest.new(hq)
	hq.reparent(_enemy, true)
	worker.action = action
	_check(action._cc_unit != hq, "Engineer still uses a captured HQ as its drop-off")
	_check(worker.resource_a == 3, "Lost drop-off discarded cargo")


func _defense_budget():
	var price = load("res://source/match/FactionCatalog.gd").cost(_enemy, "Infantry")
	var workers = _enemy.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Worker"
	)
	while workers.size() < 6:
		workers.append(_spawn("Worker", _enemy, Vector3(95, 0, 65 + workers.size())))
	var barracks = _enemy.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Barracks"
	)
	var producer = barracks[0]
	var threat = _spawn("Tank", _human, workers[0].position + Vector3(2, 0, 0))
	await _frames(5)
	_game.battlefield.invalidate()
	_check(_game.battlefield.is_observed(_enemy, threat), "Defense budget threat is hidden")
	_enemy.resource_a = price.resource_a
	_enemy.resource_b = 0
	_enemy._train(_enemy._units(), "CommandLab")
	_check(
		producer.production_queue.size() == 1,
		"Optional lab savings block affordable emergency infantry"
	)
	_check(_enemy.resource_a == 0, "Emergency reinforcement did not pay its normal cost")
	producer.production_queue.cancel_all()
	threat.position = Vector3(50, 0, 2)
	_game.battlefield.invalidate()
	_enemy.resource_a = price.resource_a
	_enemy._train(_enemy._units(), "CommandLab")
	_check(
		producer.production_queue.size() == 0, "Peaceful production abandoned technology savings"
	)


func _mixed_support_orders():
	var armor = _spawn("Tank", _human, Vector3(35, 0, 45))
	var support = _spawn("RepairRobot", _human, Vector3(35, 0, 47))
	await _frames(5)
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in [armor, support]:
		unit.get_node("Selection").select()
	var commands = _game.hud.direct_orders
	commands.arm("attack_move")
	_check(commands.commit(Vector3(40, 0, 45), null, false), "Mixed army rejected attack-move")
	_check(
		armor.manual_orders.pending[0].kind == "attack_move",
		"Armed advance lost engagement behavior"
	)
	_check(
		(
			not support.manual_orders.pending.is_empty()
			and support.manual_orders.pending[0].kind == "move"
		),
		"Attack-move leaves selected repair support behind"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(3)


func _service_routes():
	var unit = _spawn("Infantry", _human, Vector3(7, 0, 4))
	var near = _spawn("Barracks", _human, Vector3(13, 0, 4))
	var reachable = _spawn("Barracks", _human, Vector3(0, 0, 4))
	var worker = _spawn("Worker", _human, Vector3(7, 0, 4))
	var near_hq = _spawn("CommandCenter", _human, Vector3(13, 0, 4))
	var reachable_hq = _spawn("CommandCenter", _human, Vector3(0, 0, 4))
	await _frames(30)
	var nav = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(nav, true)
	var regions = []
	var meshes = []
	for x in [0, 12]:
		var mesh = NavigationMesh.new()
		mesh.vertices = PackedVector3Array(
			[Vector3(x, 0, 0), Vector3(x, 0, 8), Vector3(x + 8, 0, 8), Vector3(x + 8, 0, 0)]
		)
		mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
		var region = NavigationServer3D.region_create()
		NavigationServer3D.region_set_navigation_mesh(region, mesh)
		NavigationServer3D.region_set_map(region, nav)
		regions.append(region)
		meshes.append(mesh)
	var movement = unit.get_node("Movement")
	var original_map = movement.get_navigation_map()
	movement.set_navigation_map(nav)
	worker.get_node("Movement").set_navigation_map(nav)
	for frame in 4:
		await physics_frame
	NavigationServer3D.map_force_update(nav)
	var broken = NavigationServer3D.map_get_path(nav, unit.position, near.position, true)
	print(
		"ISLANDS iteration=",
		NavigationServer3D.map_get_iteration_id(nav),
		" path=",
		broken,
		" source=",
		unit.position,
		" target=",
		near.position
	)
	_check(
		not broken.is_empty() and broken[-1].distance_to(near.position) > 4.5,
		"Route fixture is not disconnected"
	)
	unit.hp *= 0.5
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	var state = _game.hud.direct_orders.recovery_state()
	_check(
		state.orders.size() == 1 and state.orders[0][1].target.get_ref() == reachable,
		"Recovery selects a nearer facility on an unreachable island"
	)
	_check(
		harvest._find_cc_closest_to_unit(worker) == reachable_hq,
		"Cargo delivery selects an unreachable HQ"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	movement.set_navigation_map(original_map)
	worker.get_node("Movement").set_navigation_map(original_map)
	for region in regions:
		NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(nav)
	await _frames(3)
