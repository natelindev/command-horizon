extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://art/frontier/roster.json"))
	var catalog = load("res://source/match/FactionCatalog.gd")
	_check(roster is Dictionary and roster.size() == 17, "Incomplete Frontier roster")
	for role in roster:
		var model = load("res://assets/models/frontier/v1/%s.glb" % roster[role]).instantiate()
		root.add_child(model)
		var bounds = catalog._bounds(model, Transform3D.IDENTITY)
		_check(bounds.size.is_finite() and bounds.size.min_axis_index() >= 0, role + ": bad bounds")
		_check(
			bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.z > 0, role + ": empty model"
		)
		var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
		var factor = unit.radius * 1.85 / max(bounds.size.x, bounds.size.z)
		if role == "Infantry":
			factor = 1.15 / bounds.size.y
		elif role in ["Drone", "Helicopter"]:
			factor *= 1.35
		model.scale = Vector3.ONE * factor
		model.position = (
			-Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
		)
		var final_bounds = catalog._bounds(model, Transform3D.IDENTITY)
		_check(absf(final_bounds.position.y) < .001, role + ": model floats below/above ground")
		var muzzle = model.find_child("*Muzzle", true, false)
		if (
			role
			in [
				"Infantry",
				"Tank",
				"AdvancedTank",
				"CombatRobot",
				"Helicopter",
				"AntiGroundTurret",
				"AntiAirTurret"
			]
		):
			_check(muzzle != null and muzzle.global_position.z < 0, role + ": muzzle orientation")
		var wheels = model.find_children("*WheelPivot*", "Node3D", true, false)
		_check(
			(
				wheels.size()
				== (
					{"Worker": 6, "Tank": 6, "RepairRobot": 4, "CombatRobot": 4, "AdvancedTank": 8}
					. get(role, 0)
				)
			),
			role + ": motion wheel discovery"
		)
		_check(
			model.find_children("*", "VehicleWheel3D", true, false).is_empty(),
			role + ": wheel suffix enabled vehicle physics"
		)
		for wheel in wheels:
			var child = wheel.get_child(0)
			var before = child.global_transform
			wheel.rotate_x(.7)
			_check(
				not child.global_transform.is_equal_approx(before),
				role + ": wheel cannot articulate"
			)
		var rotors = model.find_children("*Rotor?", "Node3D", true, false)
		_check(
			rotors.size() == {"Drone": 4, "Helicopter": 1}.get(role, 0),
			role + ": motion rotor discovery"
		)
		for rotor in rotors:
			var child = rotor.get_child(0)
			var before = child.global_transform
			rotor.rotate_y(.7)
			_check(
				not child.global_transform.is_equal_approx(before),
				role + ": rotor cannot articulate"
			)
		var icon = load("res://assets/ui/frontier/%s.png" % roster[role])
		_check(icon != null and icon.get_size() == Vector2(256, 256), role + ": icon import")
		unit.free()
		model.free()
	for error in errors:
		push_error(error)
	print("Frontier asset import: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		errors.append(message)
