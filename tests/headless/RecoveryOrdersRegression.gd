extends "res://tests/headless/DirectOrdersRegression.gd"

var recovery_action
var recovery_schema

var owner
var patient
var service
var commands


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _recovery_fixture(faction)
		var button = game.find_child("UnitMenus").find_child("RecoverHealth", true, false)
		_check(button != null and not button.disabled, faction + ": missing recovery command")
		if button != null:
			await _controls()
			await _archive_and_heal(faction)
			await _loss_and_block()
			await _service_domains()
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Recovery orders: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _recovery_fixture(faction):
	recovery_action = load("res://source/match/units/actions/RecoveringAtService.gd")
	recovery_schema = load("res://source/match/saves/SnapshotSchema.gd")
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud._toggle_pause()
	owner = game._get_human_player()
	patient = _units(owner, "Infantry")[0]
	service = _units(owner, "Barracks")[0]
	commands = game.hud.direct_orders
	patient.issue_manual_order(null)
	patient.position = service.position + Vector3(-8, 0, -5)
	patient.hp = patient.hp_max * .3
	await _select_units([patient])


func _controls():
	var menus = game.find_child("UnitMenus")
	var clock = game.simulation_time
	var hp = patient.hp
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	patient.manual_orders.submit(commands.Orders.point_order("move", patient.position))
	_check(commands.recover_health(true), "Queued recovery rejected")
	_check(
		patient.manual_orders.pending.map(func(order): return order.kind) == ["move", "recover"],
		"Recovery replaced queued move"
	)
	var armored = _units(owner, "Tank")[0]
	armored.hp = armored.hp_max * .3
	await _select_units([armored])
	menus = game.find_child("UnitMenus")
	commands.arm("move")
	menus._recover_health.pressed.emit()
	_check(
		armored.manual_orders.pending.map(func(order): return order.kind) == ["recover"],
		"Recovery button did not order the selected unit"
	)
	_check(commands.kind == "", "Recovery left map targeting armed")
	armored.issue_manual_order(null)
	await _select_units([patient])
	menus = game.find_child("UnitMenus")
	commands.recover_health()
	_check(
		(
			paused
			and clock == game.simulation_time
			and hp == patient.hp
			and funds == Vector2i(owner.resource_a, owner.resource_b)
		),
		"Paused recovery advanced simulation"
	)
	var before = patient.manual_orders.pending.duplicate(true)
	menus._refresh_buttons()
	_check(patient.manual_orders.pending == before, "Refresh changed orders")
	var bindings = load("res://source/input/KeyBindings.gd")
	var original = InputMap.action_get_events("shift_selecting")
	for code in [KEY_SHIFT, KEY_CTRL]:
		InputMap.action_erase_events("shift_selecting")
		InputMap.action_add_event("shift_selecting", bindings.event_for(code))
		patient.manual_orders.submit(commands.Orders.point_order("move", patient.position))
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		event.shift_pressed = code == KEY_SHIFT
		event.ctrl_pressed = code == KEY_CTRL
		menus._recovery_input(event)
		_check(
			(
				patient.manual_orders.pending.map(func(order): return order.kind)
				== ["move", "recover"]
			),
			"Modified recovery Enter failed"
		)
		event.echo = true
		menus._recovery_input(event)
		event.echo = false
		event.pressed = false
		menus._recovery_input(event)
		_check(
			patient.manual_orders.pending.size() == 2, "Recovery repeat/release duplicated order"
		)
	InputMap.action_erase_events("shift_selecting")
	for event in original:
		InputMap.action_add_event("shift_selecting", event)
	patient.manual_orders.cancel()
	for index in 16:
		patient.manual_orders.submit(commands.Orders.point_order("move", patient.position), true)
	before = patient.manual_orders.pending.duplicate(true)
	_check(
		not commands.recover_health(true) and patient.manual_orders.pending == before,
		"Full queue changed"
	)
	patient.hp = patient.hp_max
	menus._refresh_buttons()
	_check(
		menus._recover_health.disabled and not commands.recover_health(), "Healthy unit redirected"
	)
	patient.hp = hp
	var progress = service._construction_progress
	service._construction_progress = .5
	_check(
		not commands.recover_health() and patient.manual_orders.pending == before,
		"Foundation accepted"
	)
	service._construction_progress = progress
	game.finished = true
	_check(not commands.recover_health(), "Finished match accepted recovery")
	game.finished = false
	# Every domain uses its own service; a healthy mixed-selection member retains orders.
	var members = [patient]
	for role in ["Tank", "Worker", "Drone"]:
		var unit = (
			_units(owner, role)[0]
			if not _units(owner, role).is_empty()
			else _spawn_role(owner, role, Vector3(24, 0, 24))
		)
		unit.hp = unit.hp_max * .4
		members.append(unit)
	var flight = load("res://source/match/units/AircraftFactory.tscn").instantiate()
	game._setup_and_spawn_unit(flight, Transform3D(Basis(), Vector3(30, 0, 24)), owner, false)
	# Adding flight service exceeds the Advanced start's power supply. This
	# fixture verifies full-rate healing; low-power service is covered separately.
	_spawn_role(owner, "PowerPlant", Vector3(30, 0, 15))
	var healthy = _units(owner, "Infantry")[1]
	healthy.hp = healthy.hp_max
	healthy.manual_orders.submit(commands.Orders.point_order("move", healthy.position))
	before = healthy.manual_orders.pending.duplicate(true)
	await _select_units(members + [healthy])
	_check(commands.recover_health(), "Mixed recovery rejected")
	_check(healthy.manual_orders.pending == before, "Healthy mixed member redirected")
	for unit in members:
		_check(
			(
				unit.manual_orders.pending[0].target.get_ref().type
				== commands.Repairs.facility_for_role(unit.type)
			),
			"Wrong recovery domain"
		)
		if unit != patient:
			unit.issue_manual_order(null)
	# A nearer owned completed facility wins. A dying one is ignored on activation.
	var near = load("res://source/match/units/Barracks.tscn").instantiate()
	game._setup_and_spawn_unit(
		near, Transform3D(Basis(), patient.position + Vector3(-4, 0, 0)), owner, false
	)
	await _select_units([patient])
	_check(
		commands.recovery_state().orders[0][1].target.get_ref() == near, "Nearest service ignored"
	)
	near.queue_free()
	_check(
		commands.recovery_state().orders[0][1].target.get_ref() == service, "Dying service retained"
	)
	await _frames(3)
	commands.recover_health()


func _archive_and_heal(faction):
	game.hud._toggle_pause()
	await _frames(20)
	game.hud._toggle_pause()
	_check(
		patient.action != null and (patient.action.get_script() == recovery_action),
		"Recovery did not activate"
	)
	if patient.action == null or not "_full_recovery" in patient.action:
		return
	patient.manual_orders.submit(
		commands.Orders.point_order("move", service.position + Vector3(-7, 0, -6)), true
	)
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Recovery capture failed: " + snapshot.error)
	if data == null:
		return
	var id = snapshot._reference(patient)
	var row = data.units.filter(func(unit): return unit.id == id)[0]
	var index = data.units.find(row)
	var schema = recovery_schema.new()
	_check(schema.validate(data), "Recovery archive invalid: " + schema.error)
	var corrupt = data.duplicate(true)
	corrupt.units[index].action.state._full_recovery = 2
	_check(not schema.validate(corrupt), "Invalid recovery completion flag accepted")
	var disk = "user://recovery-orders-%s-%d.json" % [faction, OS.get_process_id()]
	var file = FileStore.new()
	_check(file.write_file(disk, data), "Recovery disk write failed")
	var reader = Restore.new()
	var loaded = await reader.restore(self, file.read_file(disk))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk))
	_check(loaded.ok, "Recovery restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	owner = game._get_human_player()
	patient = reader.entities[id]
	service = patient.action._target
	commands = game.hud.direct_orders
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != patient:
			unit.issue_manual_order(null)
	_check(
		paused and patient.action._full_recovery and patient.manual_orders.pending.size() == 1,
		"Reload lost recovery authority"
	)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var passed_eighty = false
	game.hud._toggle_pause()
	for frame in 3600:
		await _frames(1)
		if patient.hp >= patient.hp_max * .8 and patient.hp < patient.hp_max:
			passed_eighty = true
			_check(
				patient.manual_orders.current.get("kind") == "recover",
				"Recovery released before full health"
			)
		if not patient.manual_orders._engaged:
			break
	_check(
		passed_eighty and patient.hp == patient.hp_max, "Recovery failed to heal beyond 80 percent"
	)
	_check(not patient.manual_orders._engaged, "Full recovery did not finish queued move")
	_check(funds == Vector2i(owner.resource_a, owner.resource_b), "Recovery spent resources")
	game.hud._toggle_pause()
	await _select_units([patient])


func _loss_and_block():
	patient.hp = patient.hp_max * .3
	commands.recover_health()
	game.hud._toggle_pause()
	await _frames(3)
	game.hud._toggle_pause()
	patient.action.block()
	game.hud._toggle_pause()
	await _frames(3)
	game.hud._toggle_pause()
	_check("Skip" in patient.manual_orders.status, "Blocked recovery lacks actionable status")
	patient.manual_orders.skip()
	_check(not is_instance_of(patient.action, recovery_action), "Skip did not release recovery")
	commands.recover_health()
	patient.manual_orders.submit(commands.Orders.point_order("move", patient.position), true)
	game.hud._toggle_pause()
	await _frames(3)
	game.hud._toggle_pause()
	service.queue_free()
	await _frames(3)
	game.hud._toggle_pause()
	await _frames(60)
	_check(not patient.manual_orders._engaged, "Lost service blocked queued handoff")
	game.hud._toggle_pause()


func _service_domains():
	var members = []
	for role in ["Tank", "Worker", "Drone"]:
		var unit = _units(owner, role)[0]
		var facility = _units(owner, commands.Repairs.facility_for_role(role))[0]
		unit.issue_manual_order(null)
		unit.hp = unit.hp_max * .3
		unit.position = facility.position + Vector3(3.5 if role == "Worker" else -3.5, 0, 0)
		members.append(unit)
	await _select_units(members)
	commands.recover_health()
	# Save a pending recovery as well as the active recovery covered above.
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	var schema = recovery_schema.new()
	_check(data != null and schema.validate(data), "Pending recovery archive rejected")
	if data != null:
		var id = snapshot._reference(members[0])
		var row = data.units.filter(func(unit): return unit.id == id)[0]
		var index = data.units.find(row)
		var corrupted = data.duplicate(true)
		corrupted.units[index].orders.pending[0].target = snapshot._reference(
			_units(owner, "CommandCenter")[0]
		)
		_check(not schema.validate(corrupted), "Wrong-domain queued recovery accepted")
	var ids = members.map(func(unit): return snapshot._reference(unit))
	var reader = Restore.new()
	var loaded = await reader.restore(self, data)
	_check(loaded.ok, "Queued recovery restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	owner = game._get_human_player()
	commands = game.hud.direct_orders
	members = ids.map(func(id): return reader.entities[id])
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit not in members:
			unit.issue_manual_order(null)
	game.hud._toggle_pause()
	for frame in 2700:
		await _frames(1)
		if members.all(
			func(unit): return unit.hp == unit.hp_max and not unit.manual_orders._engaged
		):
			break
	for unit in members:
		_check(
			unit.hp == unit.hp_max and not unit.manual_orders._engaged,
			"Domain healing failed: " + unit.type
		)
	game.hud._toggle_pause()
