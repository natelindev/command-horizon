extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		var catalog = load("res://source/match/FactionCatalog.gd")
		var roles = ["AdvancedTank", "RocketInfantry"]
		if faction == "helix":
			roles.append("CombatRobot")
		for role in roles:
			var unit = load(catalog.scene_path(faction, role)).instantiate()
			_game._setup_and_spawn_unit(
				unit, Transform3D(Basis(), Vector3(30, 0, 20)), _players[0], false
			)
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			var display = unit.get_node_or_null("WeaponPreparationVisual")
			_check(display != null, faction + " " + role + " has no preparation display")
			if display == null:
				continue
			if not display._lock:
				var style = 0 if faction == "bastion" else (1 if role == "AdvancedTank" else 2)
				_check(
					display._focus_material.get_shader_parameter("focus_style") == style,
					"Capacitor, prism and precision focus silhouettes are not routed distinctly"
				)
			if faction == "helix" and role == "AdvancedTank":
				_check(
					(
						(
							display
							. get_children()
							. filter(func(child): return child is MeshInstance3D)
							. size()
						)
						== 1
					),
					"Hovering Prism retained obsolete steel deployment feet"
				)
			var health = unit.hp
			var position_before = unit.position
			for stage in [[.05, .05], [.5, .26], [.98, .48]]:
				unit.weapon_charge_progress = stage[0]
				display._phase = stage[1]
				display.refresh()
				if not display._lock:
					_spark_continuity(display, stage[0])
			options.reduced_flashes = true
			paused = true
			options.changed.emit()
			_check(display._orb.visible, "Reduced flashes removed the charge cue")
			_check(
				display._sparks == null or not display._sparks.visible,
				"Reduced flashes kept sparks"
			)
			options.reduced_flashes = false
			options.changed.emit()
			paused = false
			unit.weapon_charge_progress = -1.0
			display.refresh()
			_check(not display._orb.visible, "Cancelled preparation retained its charge cue")
			_check(
				unit.hp == health and unit.position == position_before,
				"Charge drawing altered gameplay"
			)
		await _close()
	options.reduced_flashes = reduced
	for message in _errors:
		push_error(message)
	print("Charge motion continuity: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _spark_continuity(display, progress: float):
	_check(
		display._spark_directions.size() == display.SPARK_COUNT,
		"Spark directions were not prepared"
	)
	for direction in display._spark_directions:
		_check(is_equal_approx(direction.length(), 1.0), "Spark direction is not normalized")
	# A progress refresh used to move every particle immediately because elapsed
	# time was multiplied by the new speed (and its orbit radius grew as well).
	var phase = display._spark_phase
	var before = display._sparks.multimesh.get_instance_transform(0)
	display._unit.weapon_charge_progress = minf(1.0, progress + .02)
	display.refresh()
	_check(display._spark_phase == phase, "Progress refresh jumped the particle clock")
	if DisplayServer.get_name() != "headless":
		var after = display._sparks.multimesh.get_instance_transform(0)
		_check(after.origin.is_equal_approx(before.origin), "Progress refresh teleported a spark")
	# Equal real time and charge ramps must converge at 30 and 144 render fps.
	var phases = []
	for fps in [30, 144]:
		display._unit.weapon_charge_progress = -1.0
		display.refresh()
		for frame in fps:
			display._unit.weapon_charge_progress = float(frame + 1) / fps
			display._process(1.0 / fps)
		phases.append(display._spark_phase)
	_check(is_equal_approx(phases[0], phases[1]), "Charge motion depends on render frame rate")
	paused = true
	phase = display._spark_phase
	display._process(.2)
	_check(display._spark_phase == phase, "Pause advanced charge particles")
	paused = false
	if DisplayServer.get_name() == "headless":
		return
	# The first spark wraps at phase 1. Both sides must disappear rather than pop.
	for edge in [.99999, 1.00001]:
		display._spark_phase = edge
		display.refresh()
		var pose = display._sparks.multimesh.get_instance_transform(0)
		_check(pose.basis.x.length() < .0001, "Spark reset is visible")
