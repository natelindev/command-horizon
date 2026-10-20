extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var keys = load("res://source/input/KeyBindings.gd")
	_migration(keys)
	for action in ["move_order", "attack_target"]:
		_check(keys.definitions().has(action), "Missing direct command shortcut: " + action)
	for faction in ["bastion", "helix"]:
		await _direct_orders(faction)
	for message in errors:
		push_error(message)
	print("Direct orders: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _direct_orders(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud._toggle_pause()
	var commands = game.hud.get_node_or_null("DirectOrders")
	_check(commands != null, faction + ": missing explicit Move/Attack target command flow")
	if commands != null:
		await _exercise_commands(commands)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _exercise_commands(commands):
	var player = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	for unit in get_nodes_in_group("units"):
		unit.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var tank = _units(player, "Tank")[0]
	var worker = _units(player, "Worker")[0]
	var target = _units(enemy, "Tank")[0]
	tank.position = Vector3(30, 0, 30)
	target.position = Vector3(33, 0, 30)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(player, target), "Command target fixture is hidden")
	await _select_units([tank, worker])
	var menus = game.find_child("UnitMenus")
	_check(menus._command_buttons.size() == 3, "Distinct command buttons are missing")
	var clock = game.simulation_time
	var destination = Vector3(30, 0, 38)
	commands.arm("move")
	_check(tank.manual_orders.pending.is_empty(), "Arming issued an order")
	commands.prompt()
	var prompt = game.hud._assignment_hint.text
	game.hud.show_notice("Pending test notice")
	_check(game.hud._assignment_hint.text == prompt, "Feedback displaced command instructions")
	_check(commands.commit(destination, target, false), "Explicit Move rejected a valid point")
	_check(tank.manual_orders.pending[0].kind == "move", "Move became contextual attack")
	_check(worker.manual_orders.pending[0].kind == "move", "Unarmed unit cannot use Move")
	var worker_queue = worker.manual_orders.pending.duplicate(true)
	commands.arm("attack")
	var before = tank.manual_orders.pending.duplicate(true)
	_check(not commands.commit(destination, worker, false), "Attack accepted a friendly unit")
	_check(
		commands.kind == "attack" and tank.manual_orders.pending == before,
		"Invalid target replaced orders"
	)
	target.position = Vector3(110, 0, 90)
	game.battlefield.invalidate()
	_check(not commands.commit(destination, target, false), "Attack accepted an unseen enemy")
	target.position = Vector3(33, 0, 30)
	game.battlefield.invalidate()
	_check(commands.commit(null, target, true), "Visible enemy could not be queued")
	_check(
		tank.manual_orders.pending.map(func(order): return order.kind) == ["move", "attack"],
		"Queued attack replaced Move"
	)
	_check(worker.manual_orders.pending == worker_queue, "Attack redirected an unarmed worker")
	var aircraft = _spawn_role(enemy, "Drone", Vector3(32, 1.5, 31))
	aircraft.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	aircraft.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	commands.arm("attack")
	_check(not commands.commit(null, aircraft, false), "Ground-only armor attacked aircraft")
	_check(
		game.hud._assignment_hint.text.contains("cannot attack"),
		"Wrong-domain target has no feedback"
	)
	commands.cancel()
	commands.arm("move")
	_check(
		not commands.commit(Vector3(-2, 0, 20), null, false), "Move accepted an out-of-map point"
	)
	_check(commands.kind == "move", "Invalid destination silently disarmed command")
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_check(not commands.handle_input(wheel) and commands.kind == "move", "Zoom cancelled Move")
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game.hud._unhandled_input(escape)
	_check(
		commands.kind.is_empty() and game.hud._overlay == null,
		"Escape opened menu instead of cancelling"
	)
	commands.arm("attack_move")
	for down in [true, false]:
		var right = InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = down
		_check(commands.handle_input(right), "Cancellation click escaped to contextual orders")
	_check(commands.kind.is_empty(), "Right-click did not cancel targeting")
	await _select_units([worker])
	menus = game.find_child("UnitMenus")
	menus._refresh_buttons()
	_check(
		menus._command_buttons.attack.disabled and menus._command_buttons.attack_move.disabled,
		"Worker has enabled combat commands"
	)
	await _select_units([tank])
	var placement = player.get_node("StructurePlacementHandler")
	var generator = load("res://source/match/units/PowerPlant.tscn")
	root.get_node("MatchSignals").place_structure.emit(generator)
	commands.arm("move")
	_check(not placement._structure_placement_started(), "Move left a live building blueprint")
	game.hud.arm_signature_sector([tank])
	_check(commands.kind.is_empty(), "Signature sector left direct targeting active")
	commands.arm("attack")
	_check(game.hud._assignment_kind.is_empty(), "Direct targeting left a signature sector active")
	root.get_node("MatchSignals").place_structure.emit(generator)
	_check(commands.kind.is_empty(), "Building placement left direct targeting active")
	placement._cancel_structure_placement()
	commands.arm("move")
	game.hud._open_menu()
	before = tank.manual_orders.pending.duplicate(true)
	_check(not commands.commit(destination, null, false), "Menu leaked an armed map order")
	_check(tank.manual_orders.pending == before, "Menu changed queued commands")
	game.hud._close_menu()
	commands.cancel()
	var dialog = root.get_node("Globals").open_settings()
	commands.arm("move")
	_check(commands.kind.is_empty(), "Settings leaked command shortcut")
	dialog._finish(false)
	await _frames(3)
	commands.arm("attack_move")
	_check(commands.commit(destination, null, false), "Attack-move was rejected")
	_check(tank.manual_orders.pending[0].kind == "attack_move", "Fighting advance became Move")
	for index in 15:
		tank.manual_orders.submit({"kind": "move", "point": destination}, true)
	commands.arm("move")
	_check(not commands.commit(destination, null, true), "Full queue accepted a new order")
	_check(
		(
			tank.manual_orders.pending.size() == 16
			and game.hud._assignment_hint.text.contains("queues full")
		),
		"Full queue was changed or gave no reason"
	)
	_check(paused and game.simulation_time == clock, "Command interaction advanced pause")
	await _review_controls(player, tank, target)
	await _archive_commands(tank, target)
	await _live_semantics()


func _select_units(units):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	await _frames(3)


func _spawn_role(player, role, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _archive_commands(tank, target):
	var commands = game.hud.direct_orders
	commands.cancel()
	await _select_units([tank])
	commands.arm("move")
	commands.commit(Vector3(30, 0, 38), null, false)
	commands.arm("attack")
	commands.commit(null, target, true)
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Direct command snapshot failed: " + builder.error)
	if snapshot == null:
		return
	var id = builder._reference(tank)
	var saved_target = builder._reference(target)
	var archive = "user://direct-orders-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(archive, snapshot), "Direct command disk write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(result.ok, "Direct command archive restore failed")
	if not result.ok:
		return
	game = result.game
	tank = restore.entities[id]
	target = restore.entities[saved_target]
	_check(
		tank.manual_orders.pending.map(func(order): return order.kind) == ["move", "attack"],
		"Disk restoration changed explicit order types"
	)
	_check(
		tank.manual_orders.pending[1].target.get_ref() == target, "Restored attack lost its target"
	)
	_check(
		paused and game.hud.direct_orders.kind.is_empty(),
		"Archive resumed time or armed a UI command"
	)


func _live_semantics():
	var player = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	for side in [player, enemy]:
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var tank = _units(player, "Tank")[0]
	var target = _units(enemy, "Tank")[0]
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	await _select_units([tank])
	for kind in ["move", "attack_move"]:
		tank.issue_manual_order(null)
		tank.position = Vector3(30, 0, 30)
		target.position = Vector3(33, 0, 30)
		target.hp = target.hp_max
		game.battlefield.invalidate()
		var hp = target.hp
		game.hud.direct_orders.arm(kind)
		_check(
			game.hud.direct_orders.commit(Vector3(30, 0, 38), null, false), "Live command rejected"
		)
		game.hud._toggle_pause()
		await _frames(90)
		game.hud._toggle_pause()
		print(
			"DIRECT LIVE ",
			player.faction,
			" ",
			kind,
			" damage=",
			hp - target.hp,
			" travel=",
			tank.position.distance_to(Vector3(30, 0, 30))
		)
		if kind == "move":
			_check(target.hp == hp, "Move acquired and shot a passing enemy")
			_check(tank.position.distance_to(Vector3(30, 0, 30)) > 1, "Move never advanced")
		else:
			_check(target.hp < hp, "Attack-move passed an enemy without firing")
			_check(
				tank.position.distance_to(Vector3(30, 0, 30)) < 1.5,
				"Attack-move did not stop to engage"
			)
		tank.issue_manual_order(null)
	tank.position = Vector3(30, 0, 30)
	target.position = Vector3(35.5, 0, 30)
	game.battlefield.invalidate()
	game.hud.direct_orders.arm("attack")
	_check(game.hud.direct_orders.commit(null, target, false), "Explicit live attack rejected")
	game.hud._toggle_pause()
	await _frames(20)
	var last_seen = target.position
	target.position = Vector3(110, 0, 90)
	game.battlefield.invalidate()
	await _frames(20)
	game.hud._toggle_pause()
	var action = tank.manual_orders._active
	_check(is_instance_valid(action) and action._lost_contact, "Attack did not lose hidden contact")
	if is_instance_valid(action):
		_check(
			action._last_known_position == last_seen,
			"Attack tracked the hidden enemy's new position"
		)


func _review_controls(_player, _tank, _target):
	pass


func _migration(keys):
	var legacy = keys.defaults()
	legacy.version = 1
	for action in keys.ADDED_IN_V2:
		legacy.keys.erase(action)
	legacy.keys.toggle_match_menu = KEY_M
	legacy.keys.rotate_structure = KEY_T
	legacy.keys.pause_battle = KEY_M | KEY_MASK_SHIFT
	legacy.keys.quicksave_battle = KEY_M | KEY_MASK_ALT
	legacy.keys.quickload_battle = KEY_M | KEY_MASK_CTRL
	var untouched = legacy.duplicate(true)
	var upgraded = keys.normalize(legacy)
	_check(upgraded.version == 2 and upgraded.keys.size() == 33, "Legacy controls did not migrate")
	for action in legacy.keys:
		_check(
			upgraded.keys[action] == legacy.keys[action], "Migration reset custom key: " + action
		)
	for action in upgraded.keys:
		_check(
			keys.problem(action, upgraded.keys[action], upgraded.keys).is_empty(),
			"Migration introduced a key conflict: " + action
		)
	_check(legacy == untouched, "Migration mutated the source key profile")
	_check(keys.normalize(upgraded) == upgraded, "Migrated key profile is not stable")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	var stored = load("res://source/data-model/Options.gd").new()
	stored.screen = 1
	stored.key_bindings = legacy
	var archive = "user://direct-order-keys-%d.tres" % OS.get_process_id()
	_check(stored.persist(archive) == OK, "Legacy control fixture did not write")
	var loaded = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	preferences.restore(loaded.capture())
	_check(preferences.key_bindings == upgraded, "Loading legacy controls lost custom keys")
	_check(preferences.persist(archive) == OK, "Migrated controls did not save")
	loaded = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded.key_bindings == upgraded, "Migrated controls did not survive disk storage")
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
