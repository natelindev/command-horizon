extends "res://tests/headless/FrontierGameplayRegression.gd"

const ROLES = {"Worker": 6, "Tank": 6, "RepairRobot": 4, "CombatRobot": 4, "AdvancedTank": 8}
const EVIDENCE = "res://docs/playtests/2026-10-07/frontier-wheels/"
var wheel_move
var subjects = []
var measured = []


func _run():
	wheel_move = load("res://source/match/units/actions/Moving.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)
	var index = 0
	for role in ROLES:
		var unit = _spawn_frontier(role, human, Vector3(16 + index * 3, 0, 32))
		unit.issue_manual_order(null)
		subjects.append(unit)
		index += 1
	await _frames(10)

	await _actual_travel()
	if not "--baseline" in OS.get_cmdline_user_args():
		for unit in subjects:
			_controlled(unit)
		await _pause_and_archive()
	(
		FileAccess
		. open(
			(
				EVIDENCE
				+ (
					"baseline.json"
					if "--baseline" in OS.get_cmdline_user_args()
					else "verified.json"
				)
			),
			FileAccess.WRITE
		)
		. store_string(JSON.stringify(measured, "\t"))
	)
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Frontier wheels: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _wheels(unit):
	return (
		unit.find_children("*WheelPivot*", "Node3D", true, false)
		+ unit.find_children("*", "VehicleWheel3D", true, false)
	)


func _actual_travel():
	var before = {}
	for unit in subjects:
		var wheels = _wheels(unit)
		_check(wheels.size() == ROLES[unit.type], unit.type + ": missing authored wheels")
		before[unit] = [unit.position, wheels.map(func(wheel): return wheel.basis)]
		unit.issue_manual_order(wheel_move.new(unit.position + Vector3(0, 0, -8)))
	await _frames(90)
	for unit in subjects:
		var distance = unit.position.distance_to(before[unit][0])
		var changed = 0
		var wheels = _wheels(unit)
		for index in wheels.size():
			if not wheels[index].basis.is_equal_approx(before[unit][1][index]):
				changed += 1
		_check(distance > 1.0, unit.type + ": real movement fixture did not travel")
		_check(
			changed == ROLES[unit.type], unit.type + ": wheels remain static during actual travel"
		)
		measured.append({"role": unit.type, "distance": distance, "animated_wheels": changed})
		print("WHEEL TRAVEL ", unit.type, " distance=", distance, " changed=", changed)
		unit.issue_manual_order(null)
	await _frames(30)


func _controlled(unit):
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	var visual = unit.get_node("BastionVisuals")
	var drive = visual._wheel_motion
	_check(
		drive != null and drive.wheels.size() == ROLES[unit.type],
		unit.type + ": wheel setup missing"
	)
	_check(
		unit.find_children("*", "VehicleWheel3D", true, false).is_empty(),
		"Import created vehicle physics wheels"
	)
	if drive == null or drive.wheels.is_empty():
		return
	var original = unit.transform
	var hp = unit.hp
	var interval = unit.attack_interval
	var action = unit.action
	var before = _poses(unit)
	var radius = drive.wheels[0].radius
	for wheel in drive.wheels:
		_check(
			absf(wheel.radius - wheel.offset.y) < .025,
			unit.type + ": scaled rolling radius differs from ground contact"
		)
	var forward = -unit.basis.z.normalized()
	unit.position += forward * radius * PI / 2
	visual._physics_process(.1)
	for index in drive.wheels.size():
		_check(
			_basis_close(_wheels(unit)[index].basis, before[index] * Basis(Vector3.RIGHT, -PI / 2)),
			unit.type + ": quarter-circumference roll is wrong"
		)
	unit.position -= forward * radius * PI / 2
	visual._physics_process(.1)
	_check(_same_poses(before, _poses(unit)), unit.type + ": reversing does not unwind roll")
	unit.position += unit.basis.x * .1
	visual._physics_process(.1)
	_check(_same_poses(before, _poses(unit)), unit.type + ": sideways crowd push spins wheels")
	unit.position -= unit.basis.x * .1
	visual._physics_process(.1)
	var angles = drive.wheels.map(func(wheel): return wheel.angle)
	unit.rotate_y(.2)
	visual._physics_process(.1)
	for index in drive.wheels.size():
		var wheel = drive.wheels[index]
		var roll = angle_difference(angles[index], wheel.angle)
		_check(
			roll * wheel.offset.x < 0,
			unit.type + ": turn fails to roll opposite sides independently"
		)
	unit.rotate_y(-.2)
	visual._physics_process(.1)
	_check(
		_same_poses(before, _poses(unit)), unit.type + ": reciprocal turn accumulates roll drift"
	)
	for cycle in 1000:
		unit.position += forward * .025
		visual._physics_process(1.0 / 60)
		unit.position -= forward * .025
		visual._physics_process(1.0 / 60)
	_check(_same_poses(before, _poses(unit)), unit.type + ": repeated reverse cycles drift")
	var start_angles = drive.wheels.map(func(wheel): return wheel.angle)
	unit.rotate_y(PI)
	visual._physics_process(.1)
	for index in drive.wheels.size():
		var wheel = drive.wheels[index]
		var positive = (
			wheel.rest
			* Basis(Vector3.RIGHT, start_angles[index] - PI * wheel.offset.x / wheel.radius)
		)
		var negative = (
			wheel.rest
			* Basis(Vector3.RIGHT, start_angles[index] + PI * wheel.offset.x / wheel.radius)
		)
		_check(
			_basis_close(wheel.pivot.basis, positive) or _basis_close(wheel.pivot.basis, negative),
			unit.type + ": half-turn lost signed wheel travel"
		)
	unit.transform = original
	drive._previous = original
	# Restore only the cosmetic phase after the isolated half-turn fixture.
	for index in drive.wheels.size():
		drive.wheels[index].angle = start_angles[index]
		drive.wheels[index].pivot.basis = before[index]
	unit.position += Vector3(12, 0, 0)
	visual._physics_process(1.0 / 60)
	_check(_same_poses(before, _poses(unit)), unit.type + ": relocation creates wheel travel")
	unit.transform = original
	visual._physics_process(1.0 / 60)
	visual._movement._has_destination = true
	for frame in 120:
		visual._physics_process(1.0 / 60)
	_check(_same_poses(before, _poses(unit)), unit.type + ": blocked order spins wheels")
	visual._movement._has_destination = false
	visual.fire_recoil()
	for frame in 600:
		visual._physics_process(1.0 / 60)
	_check(_same_poses(before, _poses(unit)), unit.type + ": recoil/idle body motion spins wheels")
	_check(
		(
			unit.transform.is_equal_approx(original)
			and unit.hp == hp
			and unit.attack_interval == interval
			and unit.action == action
		),
		unit.type + ": wheel motion changed gameplay authority"
	)
	print("WHEEL CONTROL ", unit.type, " radius=", radius, " wheels=", drive.wheels.size())
	unit.process_mode = Node.PROCESS_MODE_INHERIT


func _basis_close(a, b):
	return (
		a.x.distance_to(b.x) < .0005
		and a.y.distance_to(b.y) < .0005
		and a.z.distance_to(b.z) < .0005
	)


func _poses(unit):
	return _wheels(unit).map(func(wheel): return wheel.basis)


func _same_poses(a, b):
	for index in a.size():
		if not _basis_close(a[index], b[index]):
			return false
	return true


func _pause_and_archive():
	for unit in subjects:
		unit.issue_manual_order(wheel_move.new(unit.position + Vector3(0, 0, -4)))
	await _frames(15)
	game.hud._toggle_pause()
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = subjects.map(func(unit): return builder._reference(unit))
	var poses = subjects.map(_poses)
	await _frames(20)
	for index in subjects.size():
		_check(poses[index] == _poses(subjects[index]), "Tactical pause advances wheels")
	var store = FileStore.new()
	_check(
		store.write_file(EVIDENCE + "moving-archive.json", data),
		"Wheel motion archive write failed"
	)
	var restore = Restore.new()
	var result = await restore.restore(self, store.read_file(EVIDENCE + "moving-archive.json"))
	_check(result.ok, "Wheel motion archive restore failed")
	if not result.ok:
		return
	game = result.game
	human = game._get_human_player()
	subjects = ids.map(func(id): return restore.entities[id])
	await _frames(10)
	var again = builder.capture(game)
	_check(
		paused and again.simulation_time == data.simulation_time and again.players == data.players,
		"Wheel motion changed saved time/economy"
	)
	for saved in data.units:
		var loaded = again.units.filter(func(unit): return unit.id == saved.id)[0]
		for field in ["position", "hp", "action", "orders", "production"]:
			if saved.has(field):
				_check(loaded[field] == saved[field], "Wheel motion changed saved " + field)
	for unit in subjects:
		_check(
			unit.get_node("BastionVisuals")._wheel_motion.wheels.all(
				func(wheel): return is_zero_approx(wheel.angle)
			),
			"Reload wheel phase did not initialize locally"
		)
	poses = subjects.map(_poses)
	game.hud._toggle_pause()
	await _frames(60)
	for index in subjects.size():
		_check(
			not _same_poses(poses[index], _poses(subjects[index])),
			"Restored moving wheels remain static"
		)
	print("WHEEL ARCHIVE exact paused state and resumed articulation")
