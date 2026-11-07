extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion")
	for role in ["Tank", "AdvancedTank", "Worker", "RepairRobot"]:
		_test_tracks(role)
	_test_recoil_cycle()
	_test_selection_entrance()
	_test_dust_palette()
	_test_blast_collapse()
	_test_command_markers()
	_test_heat_budget()
	await _close()
	await _fixture("frontier")
	for role in ["Tank", "AdvancedTank", "Worker", "CombatRobot"]:
		var unit = _spawn(role, 0, Vector3(25, 0, 18))
		_check(
			not unit.get_node("BastionVisuals")._antennas.is_empty(),
			"Frontier " + role + ": antenna missing"
		)
		unit.queue_free()
	await _close()
	for message in _errors:
		push_error(message)
	print("Animation polish regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _test_tracks(role):
	var unit = _spawn(role, 0, Vector3(25, 0, 18))
	var visual = unit.get_node("BastionVisuals")
	var tracks = visual._track_motion
	_check(
		tracks != null and tracks.belts.size() == 2,
		role + ": missing two independently driven tracks"
	)
	if tracks == null:
		unit.queue_free()
		return
	for belt in tracks.belts:
		var arrays = belt.mesh.mesh.surface_get_arrays(0)
		var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][0]
		var uv2: Vector2 = arrays[Mesh.ARRAY_TEX_UV2][0]
		_check(
			1.0 - uv.y > .5 and uv2.x > .2 and 1.0 - uv2.y > .2,
			role + ": capsule metadata did not survive export"
		)
	var root_before = unit.global_transform
	tracks.advance(STEP)
	_check(unit.global_transform == root_before, "Track animation moved the gameplay root")
	_check(tracks.belts.all(func(belt): return belt.travel == 0.0), "Stationary treads creep")
	unit.position.z -= .05
	tracks.advance(STEP)
	var forward = tracks.belts.map(func(belt): return belt.travel)
	_check(forward.all(func(distance): return distance > 0.0), "Tracks do not roll forward")
	unit.position.z += .05
	tracks.advance(STEP)
	_check(
		tracks.belts.all(func(belt): return absf(belt.travel) < .0001),
		"Reverse motion does not unwind tread travel"
	)
	unit.rotate_y(.03)
	tracks.advance(STEP)
	var left = tracks.belts[0]
	var right = tracks.belts[1]
	var left_signed = wrapf(left.travel, -left.perimeter * .5, left.perimeter * .5)
	var right_signed = wrapf(right.travel, -right.perimeter * .5, right.perimeter * .5)
	_check(left_signed * right_signed < 0.0, "Pivot turn does not counter-rotate belts")
	var phases = tracks.belts.map(func(belt): return belt.travel)
	unit.position.x += 20.0
	tracks.advance(STEP)
	_check(phases == tracks.belts.map(func(belt): return belt.travel), "Teleport spun tracks")
	_check(not visual._antennas.is_empty(), role + ": exported antenna pivot missing")
	visual.chassis.accel = Vector2(-8, 2)
	visual._advance_antennas(.1)
	_check(visual._antenna_lean.length() > .01, "Antenna ignores braking inertia")
	visual.chassis.accel = Vector2.ZERO
	for frame in 240:
		visual._advance_antennas(STEP)
	_check(visual._antenna_lean.length() < .001, "Antenna does not settle")
	unit.queue_free()


func _test_recoil_cycle():
	var script = load("res://source/match/units/traits/BastionVisuals.gd")
	_check(script.recoil_envelope(0.0) == 0.0, "Recoil starts discontinuously")
	_check(
		script.recoil_envelope(.1) == 1.0 and script.recoil_envelope(.23) == 1.0,
		"Recoil lacks a brief mechanical hold"
	)
	_check(
		script.recoil_envelope(.5) > script.recoil_envelope(.8), "Hydraulic return runs backwards"
	)
	_check(
		script.recoil_envelope(1.0) == 0.0 and script.recoil_envelope(2.0) == 0.0,
		"Recoil sticks after a long frame"
	)
	var unit = _spawn("Tank", 0, Vector3(25, 0, 18))
	var visual = unit.get_node("BastionVisuals")
	visual._set_barrel_pitch(.4)
	visual._recoil = .85
	visual._apply_geometry(STEP, 0.0)
	var offset = visual._barrel.position - visual._barrel_rest
	_check(offset.y < 0.0 and offset.z > 0.0, "Elevated barrel recoils outside its bore axis")
	visual._recoil = 0.0
	visual._apply_geometry(STEP, 0.0)
	_check(
		visual._barrel.position.is_equal_approx(visual._barrel_rest),
		"Barrel failed to return to battery"
	)
	unit.queue_free()


func _test_selection_entrance():
	var unit = _spawn("Tank", 0, Vector3(25, 0, 18))
	var selection = unit.get_node("Selection")
	var options = root.get_node("Globals").options
	var previous = options.reduced_flashes
	options.reduced_flashes = false
	selection.select()
	_check(selection._circle.scale.x > 1.0, "Selection entrance did not start")
	selection._process(.25)
	_check(
		selection._circle.scale.is_equal_approx(Vector3.ONE), "Selection entrance did not settle"
	)
	selection.deselect()
	options.reduced_flashes = true
	selection.select()
	_check(
		selection._circle.scale.is_equal_approx(Vector3.ONE),
		"Reduced flashes still animates selection entrance"
	)
	selection.deselect()
	options.reduced_flashes = previous
	unit.queue_free()


func _test_dust_palette():
	var effects = load("res://source/match/effects/CombatEffects.gd")
	_check(
		effects.dust_color("alpine").r > effects.dust_color("desert").r,
		"Snow powder keeps desert color"
	)
	_check(
		effects.dust_color("temperate").r < effects.dust_color("desert").r,
		"Dirt keeps desert color"
	)


func _test_blast_collapse():
	var unit = _spawn("Infantry", 0, Vector3(25, 0, 18))
	var visual = unit.get_node("BastionVisuals")
	visual.hit_reaction(unit.position + Vector3.FORWARD, true)
	var blast = visual.death_motion()
	_check(blast.get("lift", 0.0) > 0.0, "Explosive infantry death does not lift")
	visual.hit_reaction(unit.position + Vector3.FORWARD, false)
	var ordinary = visual.death_motion()
	_check(ordinary.get("lift", 0.0) == 0.0, "Ordinary hit throws infantry into the air")
	unit.queue_free()


func _test_command_markers():
	var feedback = _game.hud.command_feedback
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	feedback._add_marker(Vector3(25, 0, 18), "move", "Move", true)
	var marker = feedback.markers.back()
	var initial = marker.node.get_aabb().size
	marker.age = .35
	feedback._pose_marker(marker)
	_check(marker.node.get_aabb().size != initial, "Accepted order ring never animates")
	for index in 10:
		feedback._add_marker(Vector3(25, 0, 18), "attack", "Attack", true)
	_check(feedback.markers.size() == feedback.MAX_MARKERS, "Command marker pool is unbounded")
	options.reduced_flashes = true
	marker = feedback.markers.back()
	marker.age = 0.0
	feedback._pose_marker(marker)
	var steady = marker.node.get_aabb()
	marker.age = .2
	feedback._pose_marker(marker)
	_check(marker.node.get_aabb() == steady, "Reduced flashes animates the command marker")
	options.reduced_flashes = reduced


func _test_heat_budget():
	var heat = load("res://source/match/effects/WeaponHeat.gd").new()
	root.add_child(heat)
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	var units = []
	for index in 30:
		var unit = Node3D.new()
		var socket = Node3D.new()
		socket.name = "ProjectileOrigin"
		unit.add_child(socket)
		root.add_child(unit)
		units.append(unit)
		heat.shot(unit)
	_check(heat.entries.size() == heat.MAX_HOT_WEAPONS, "Hot weapon budget exceeded")
	for shot in 12:
		heat.shot(units[0])
	_check(heat.entries[0].heat == 1.0, "Repeated shots did not accumulate bounded heat")
	heat._process(.5)
	_check(
		absf(heat.entries[0].heat - exp(-heat.COOLING * .5)) < .00001,
		"Barrel cooling is not exponential"
	)
	units[0].free()
	heat._process(0.0)
	_check(heat.entries.size() == heat.MAX_HOT_WEAPONS - 1, "Dead unit retained a hot muzzle")
	options.reduced_flashes = true
	heat._process(0.0)
	_check(heat.entries.is_empty(), "Reduced flashes did not clear thermal effects")
	for index in range(1, units.size()):
		units[index].free()
	heat.free()
	options.reduced_flashes = reduced
