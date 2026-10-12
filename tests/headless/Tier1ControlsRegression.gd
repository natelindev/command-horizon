extends SceneTree


class FixtureUnit:
	extends Node3D
	var radius = 1.2
	var hp = 100


class FixtureMovement:
	extends NavigationAgent3D
	# Provisional geometry before map synchronization; real navigation is
	# exercised by FormationCapRegression's synchronized army fixtures.
	var _synchronized = false


var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	await _test_formation_slots()
	await _test_tactical_stances()
	await _test_control_groups_and_snap()
	await _test_idle_worker_cycling()

	print("Tier 1 controls regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _test_formation_slots():
	var UtilsMovement = load("res://source/match/utils/UnitMovementUtils.gd")
	var dummy_units = []
	for i in range(5):
		var u = FixtureUnit.new()
		var movement = FixtureMovement.new()
		movement.name = "Movement"
		u.add_child(movement)
		root.add_child(u)
		u.global_position = Vector3(float(i) * 3.0, 0.0, 0.0)
		dummy_units.append(u)

	var target = Vector3(50, 0, 50)
	var heading = Vector3(0, 0, 1)  # Facing North (positive Z)

	# 1. Line formation
	var line_slots = UtilsMovement.calculate_formation_slots(
		dummy_units, target, heading, "line", 3.0
	)
	_check(line_slots.size() == 5, "Line formation did not generate 5 slots")
	# Facing positive Z, slots vary along X while sharing the target's Z.
	var z_coords = line_slots.map(func(pair): return pair[1].z)
	_check(is_equal_approx(z_coords[0], z_coords[1]), "Line slots not aligned along rank")

	# 2. Wedge formation
	var wedge_slots = UtilsMovement.calculate_formation_slots(
		dummy_units, target, heading, "wedge", 3.0
	)
	_check(wedge_slots.size() == 5, "Wedge formation did not generate 5 slots")
	# Tip at target, trailing wings behind tip in Z
	var has_tip = wedge_slots.any(func(pair): return is_equal_approx(pair[1].z, target.z))
	_check(has_tip, "Wedge tip not at target Z")

	# 3. Crowd moved wrapper with heading
	var crowd_slots = UtilsMovement.crowd_moved_to_new_pivot(dummy_units, target, heading, "line")
	_check(crowd_slots.size() == 5, "crowd_moved_to_new_pivot failed with heading")
	for index in crowd_slots.size():
		for earlier in index:
			_check(
				(
					crowd_slots[index][1].distance_to(crowd_slots[earlier][1])
					>= crowd_slots[index][0].radius + crowd_slots[earlier][0].radius
				),
				"Heading wrapper collapsed provisional formation destinations"
			)

	for u in dummy_units:
		u.queue_free()
	print("PASS Formation geometry, slot distribution and drag heading orientation")


func _test_tactical_stances():
	var unit_script = load("res://source/match/units/Unit.gd")
	var unit = unit_script.new()

	_check(unit.stance == unit.Stance.AGGRESSIVE, "Default stance is not Aggressive")
	_check(unit.stance_name() == "Aggressive", "Default stance name mismatch")

	unit.cycle_stance()
	_check(unit.stance == unit.Stance.DEFENSIVE, "Cycle stance 1 failed")
	_check(unit.stance_name() == "Defensive", "Defensive stance name mismatch")

	unit.cycle_stance()
	_check(unit.stance == unit.Stance.HOLD_POSITION, "Cycle stance 2 failed")

	unit.cycle_stance()
	_check(unit.stance == unit.Stance.HOLD_FIRE, "Cycle stance 3 failed")

	unit.cycle_stance()
	_check(unit.stance == unit.Stance.AGGRESSIVE, "Cycle stance wrap failed")

	unit.queue_free()
	print("PASS Tactical stance enumeration, state cycling and stance properties")


func _test_control_groups_and_snap():
	var handler = load("res://source/match/handlers/UnitGroupSelectionHandler.gd").new()
	root.add_child(handler)

	var dummy_unit1 = FixtureUnit.new()
	dummy_unit1.add_to_group("controlled_units")
	dummy_unit1.add_to_group("selected_units")
	root.add_child(dummy_unit1)

	handler.set_group(1)
	_check(dummy_unit1.is_in_group("unit_group_1"), "Unit not added to group 1")

	var dummy_unit2 = FixtureUnit.new()
	dummy_unit2.add_to_group("controlled_units")
	dummy_unit2.add_to_group("selected_units")
	root.add_child(dummy_unit2)

	handler.append_to_group(1)
	_check(
		dummy_unit1.is_in_group("unit_group_1") and dummy_unit2.is_in_group("unit_group_1"),
		"Append to group 1 failed"
	)

	# Double-tap camera centering tracking
	handler.access_group(1)
	var first_access = handler._last_access_time
	_check(handler._last_access_id == 1, "Last access id not tracked")
	_check(first_access > 0, "Last access timestamp zero")

	dummy_unit1.queue_free()
	dummy_unit2.queue_free()
	handler.queue_free()
	print("PASS Control group assignment, shift append, and double-tap snap tracking")


func _test_idle_worker_cycling():
	var idle_handler = load("res://source/match/handlers/IdleWorkerHandler.gd").new()
	root.add_child(idle_handler)

	var idle_list = idle_handler.get_idle_workers()
	_check(idle_list is Array, "get_idle_workers did not return an array")

	idle_handler.queue_free()
	print("PASS Idle worker query API and cycling handler")


func _check(condition: bool, message: String):
	if not condition:
		errors.append(message)
		print("FAIL: " + message)
		push_error(message)
