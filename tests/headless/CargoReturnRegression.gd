extends "res://tests/headless/DirectOrdersRegression.gd"

var harvest_rules
var carrier
var owner
var commands


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _cargo_fixture(faction)
		await _cargo_controls(faction)
		await _cargo_keyboard()
		await _cargo_archive_and_delivery(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Cargo return: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _cargo_fixture(faction):
	harvest_rules = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	owner = game._get_human_player()
	carrier = _units(owner, "Worker")[0]
	commands = game.hud.direct_orders
	_freeze_other_actors()
	game.hud._toggle_pause()
	var hq = _units(owner, "CommandCenter")[0]
	carrier.issue_manual_order(null)
	carrier.position = hq.position + Vector3(-8, 0, 0)
	carrier.resource_a = 3
	carrier.resource_b = 1
	_check(
		(
			carrier._cargo.visible
			and carrier._cargo._materials.visible
			and carrier._cargo._electronics.visible
		),
		faction + ": mixed cargo is not visible on the worker"
	)
	await _select_units([carrier])


func _freeze_other_actors():
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != carrier:
			unit.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			unit.process_mode = Node.PROCESS_MODE_DISABLED


func _cargo_controls(faction):
	var menus = game.find_child("UnitMenus")
	var button = menus.find_child("ReturnCargo", true, false)
	_check(
		button != null and not button.disabled, faction + ": loaded engineer cannot return cargo"
	)
	if button == null:
		return
	_check(
		menus._command_buttons.attack.visible == (carrier.attack_damage != null),
		"Worker attack button does not match its faction weapon"
	)
	_check(
		button.accessibility_description == button.tr(commands.cargo_return_state().description),
		"Missing accessible destination explanation"
	)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var clock = game.simulation_time
	var hq = _units(owner, "CommandCenter")[0]
	carrier.manual_orders.submit({"kind": "move", "point": carrier.position + Vector3(0, 0, 2)})
	var before = carrier.manual_orders.pending.duplicate(true)
	for index in 3:
		menus._refresh_buttons()
	_check(carrier.manual_orders.pending == before, "Refreshing cargo button changed orders")
	_check(commands.return_cargo(true), "Shift delivery rejected")
	_check(
		carrier.manual_orders.pending.map(func(order): return order.kind) == ["move", "gather"],
		"Shift delivery replaced retreat"
	)
	_check(carrier.manual_orders.pending[-1].target.get_ref() == hq, "Wrong HQ selected")
	commands.arm("move")
	button.pressed.emit()
	_check(
		commands.kind == "" and not game.hud.map_assignment_active(),
		"Delivery left Move targeting armed"
	)
	_check(
		(
			carrier.manual_orders.pending.size() == 1
			and carrier.manual_orders.pending[0].kind == "gather"
		),
		"Immediate delivery did not replace old queue"
	)
	_check(paused and game.simulation_time == clock, "Delivery unpaused or advanced simulation")
	_check(
		(
			Vector2i(owner.resource_a, owner.resource_b) == funds
			and carrier.resource_a == 3
			and carrier.resource_b == 1
		),
		"Cargo was credited before arrival"
	)
	# A full queue must preserve existing work and show failure without cancelling targeting.
	carrier.manual_orders.cancel()
	for index in 16:
		carrier.manual_orders.submit({"kind": "move", "point": carrier.position}, true)
	before = carrier.manual_orders.pending.duplicate(true)
	commands.arm("move")
	_check(not commands.return_cargo(true), "Full queue accepted delivery")
	_check(
		carrier.manual_orders.pending == before and commands.kind == "move",
		"Full queue changed control authority"
	)
	commands.cancel()
	carrier.issue_manual_order(null)
	# Other roles and empty engineers retain orders in a mixed selection.
	var empty = _units(owner, "Worker")[1]
	var tank = _units(owner, "Tank")[0]
	empty.resource_a = 0
	empty.resource_b = 0
	for unit in [empty, tank]:
		unit.manual_orders.submit({"kind": "move", "point": unit.position + Vector3(0, 0, 2)})
	var preserved = [
		empty.manual_orders.pending.duplicate(true), tank.manual_orders.pending.duplicate(true)
	]
	await _select_units([tank, empty, carrier])
	_check(commands.return_cargo(), "Mixed selection delivery rejected")
	_check(
		preserved == [empty.manual_orders.pending, tank.manual_orders.pending],
		"Cargo command redirected another role or empty engineer"
	)
	# Revalidation at click time: cargo emptied or HQ lost after the last refresh.
	await _select_units([carrier])
	carrier.resource_a = 0
	carrier.resource_b = 0
	before = carrier.manual_orders.pending.duplicate(true)
	_check(not commands.return_cargo(), "Stale loaded button accepted empty worker")
	menus._refresh_buttons()
	_check(
		menus._return_cargo.disabled and "no cargo" in menus._return_cargo.tooltip_text,
		"Empty-cargo state lacks reason"
	)
	_check(carrier.manual_orders.pending == before, "Empty-cargo rejection replaced orders")
	carrier.resource_a = 3
	carrier.resource_b = 1
	var progress = hq._construction_progress
	hq._construction_progress = .5
	menus._refresh_buttons()
	_check(
		(
			menus._return_cargo.disabled
			and "completed friendly HQ is required" in menus._return_cargo.tooltip_text
		),
		"Foundation or enemy HQ accepted as drop-off"
	)
	_check(
		not commands.return_cargo() and carrier.manual_orders.pending == before,
		"Missing-HQ rejection changed orders"
	)
	hq._construction_progress = progress
	# Finished matches reject the command through the same modal authority gate.
	game.finished = true
	_check(not commands.return_cargo(), "Cargo command accepted after match end")
	game.finished = false
	var near = load("res://source/match/units/CommandCenter.tscn").instantiate()
	game._setup_and_spawn_unit(
		near, Transform3D(Basis(), carrier.position + Vector3(0, 0, 5)), owner, false
	)
	_check(
		commands.cargo_return_state().orders[0][1].target.get_ref() == near,
		"Nearest completed own HQ not selected"
	)
	near.queue_free()
	_check(commands.return_cargo(), "Queued-for-deletion HQ blocked fallback")
	_check(
		carrier.manual_orders.pending[0].target.get_ref() == hq, "Dead HQ retained at click time"
	)
	await _frames(3)


func _cargo_keyboard():
	await _select_units([carrier])
	var menus = game.find_child("UnitMenus")
	var bindings = load("res://source/input/KeyBindings.gd")
	var original = InputMap.action_get_events("shift_selecting")
	for code in [KEY_SHIFT, KEY_CTRL]:
		InputMap.action_erase_events("shift_selecting")
		InputMap.action_add_event("shift_selecting", bindings.event_for(code))
		carrier.manual_orders.submit({"kind": "move", "point": carrier.position})
		var key = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = true
		key.shift_pressed = code == KEY_SHIFT
		key.ctrl_pressed = code == KEY_CTRL
		menus._cargo_input(key)
		_check(
			carrier.manual_orders.pending.map(func(order): return order.kind) == ["move", "gather"],
			"Modified Enter did not preserve and append orders"
		)
		key.echo = true
		menus._cargo_input(key)
		key.echo = false
		key.pressed = false
		menus._cargo_input(key)
		_check(carrier.manual_orders.pending.size() == 2, "Key repeat/release duplicated delivery")
	InputMap.action_erase_events("shift_selecting")
	for event in original:
		InputMap.action_add_event("shift_selecting", event)
	commands.return_cargo()


func _cargo_archive_and_delivery(faction):
	# Save while the ordinary delivery action is actually moving, not just queued.
	game.hud._toggle_pause()
	await _frames(30)
	game.hud._toggle_pause()
	_check(
		is_instance_of(carrier.action, harvest_rules) and carrier.resource_a == 3,
		"Active delivery fixture did not retain cargo"
	)
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Cargo delivery snapshot failed: " + snapshot.error)
	if data == null:
		return
	var id = snapshot._reference(carrier)
	var disk_path = "user://cargo-return-%s-%d.json" % [faction, OS.get_process_id()]
	var file = FileStore.new()
	_check(file.write_file(disk_path, data), "Cargo delivery disk write failed")
	var reader = Restore.new()
	var result = await reader.restore(self, file.read_file(disk_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(disk_path))
	_check(result.ok, "Cargo delivery reload failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	owner = game._get_human_player()
	carrier = reader.entities[id]
	commands = game.hud.direct_orders
	_freeze_other_actors()
	await _select_units([carrier])
	_check(
		paused and carrier.resource_a == 3 and carrier.resource_b == 1, "Paused reload lost cargo"
	)
	_check(carrier._cargo.visible, "Paused reload lost the visible resource load")
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	game.hud._toggle_pause()
	for frame in 1800:
		await _frames(1)
		if carrier.resource_a + carrier.resource_b == 0:
			break
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == funds + Vector2i(3, 1),
		"Actual HQ arrival failed exact cargo accounting"
	)
	_check(not carrier._cargo.visible, "Delivered resources remain visible on the worker")
	_check(
		(
			is_instance_of(carrier.action, harvest_rules)
			and carrier.action._waiting_reason == harvest_rules.Wait.DELIVERED
		),
		"Delivery did not wait for explicit field assignment"
	)
	await _frames(30)
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == funds + Vector2i(3, 1),
		"Delivered cargo was credited twice"
	)
	# A queued follow-up leaves the terminal delivery state, then new work earns income.
	carrier.manual_orders.submit(
		{"kind": "move", "point": carrier.position + Vector3(-2, 0, 0)}, true
	)
	for frame in 600:
		await _frames(1)
		if not carrier.manual_orders._engaged:
			break
	_check(not carrier.manual_orders._engaged, "Delivery waiting state blocked queued follow-up")
	var deposits = get_nodes_in_group("resource_units").filter(
		func(deposit): return "resource_a" in deposit and deposit.resource_a > 0
	)
	deposits.sort_custom(
		func(a, b):
			return (
				carrier.position.distance_to(a.position) < carrier.position.distance_to(b.position)
			)
	)
	var deposit = deposits[0]
	# Gather orders may choose a less crowded or shorter route within this field.
	var field = deposits.filter(
		func(candidate):
			return candidate.position.distance_to(deposit.position) <= harvest_rules.FIELD_RADIUS
	)
	var stock = field.reduce(func(total, candidate): return total + candidate.resource_a, 0)
	carrier.manual_orders.submit(commands.Orders.target_order("gather", deposit))
	var carried_pile_seen = false
	for frame in 3600:
		await _frames(1)
		if carrier.resource_a > 0:
			carried_pile_seen = (
				carried_pile_seen
				or (
					carrier._cargo.visible
					and carrier._cargo._materials.visible
					and not carrier._cargo._electronics.visible
				)
			)
		if owner.resource_a > funds.x + 3:
			break
	_check(carried_pile_seen, "Mining did not show a material pile before delivery")
	var remaining = field.reduce(
		func(total, candidate):
			return total + (candidate.resource_a if is_instance_valid(candidate) else 0),
		0
	)
	_check(
		owner.resource_a > funds.x + 3 and remaining < stock,
		"Explicit reassignment did not deliver newly collected materials"
	)
	_check(
		stock - remaining == owner.resource_a - (funds.x + 3) + carrier.resource_a,
		"Field reassignment lost or duplicated materials"
	)
