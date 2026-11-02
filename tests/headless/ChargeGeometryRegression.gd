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
					_spark_parity(display, stage[0], stage[1])
			options.reduced_flashes = true
			display.refresh()
			_check(display._orb.visible, "Reduced flashes removed the charge cue")
			_check(
				display._sparks == null or not display._sparks.visible,
				"Reduced flashes kept sparks"
			)
			options.reduced_flashes = false
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
	print("Charge geometry exact parity: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _spark_parity(display, progress: float, phase: float):
	_check(
		display._spark_directions.size() == display.SPARK_COUNT,
		"Spark directions were not prepared"
	)
	for index in display._sparks.multimesh.visible_instance_count:
		var angle = index * 2.399963
		var y = 1.0 - 2.0 * (index + .5) / display.SPARK_COUNT
		var radial = sqrt(1.0 - y * y)
		var direction = Vector3(cos(angle) * radial, y, sin(angle) * radial)
		var travel = fposmod(phase * (1.4 + progress) + index * .618034, 1.0)
		var radius = .07 + (1.0 - travel) * (1.0 - travel) * (.85 + progress * .3)
		var size = sin(travel * PI) * (.65 + progress * .55)
		var expected = Transform3D(
			Basis.looking_at(-direction).scaled(Vector3.ONE * size), direction * radius
		)
		_check(
			display._spark_directions[index].is_equal_approx(direction), "Spark direction changed"
		)
		_check(
			display._spark_bases[index].is_equal_approx(Basis.looking_at(-direction)),
			"Spark orientation changed"
		)
		# DummyRenderingServer does not retain MultiMesh instance transforms.
		# The same suite with a real renderer also checks the published result.
		if DisplayServer.get_name() == "headless":
			continue
		var actual = display._sparks.multimesh.get_instance_transform(index)
		var difference = maxf(
			actual.origin.distance_to(expected.origin),
			maxf(
				(actual.basis.x - expected.basis.x).length(),
				maxf(
					(actual.basis.y - expected.basis.y).length(),
					(actual.basis.z - expected.basis.z).length()
				)
			)
		)
		_check(difference < .00001, "Prepared spark pose changed by %.9f" % difference)
