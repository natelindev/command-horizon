extends "res://tests/headless/StructureActivityRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture(faction)
		for role in ["PowerPlant", "RepairDepot", "AircraftFactory", "CommandCenter"]:
			await _resume(role)
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Construction resume: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _resume(role):
	var site = _spawn(role, Vector3(45, 0, 35), true)
	var first = _spawn("Worker", Vector3(45, 0, 40))
	var replacement = _spawn("Worker", Vector3(38, 0, 35))
	await _frames(30)
	for unit in [site, first, replacement]:
		unit.process_mode = Node.PROCESS_MODE_INHERIT
	var funds = Vector2i(human.resource_a, human.resource_b)
	var controller = human.get_node("UnitActionsController")
	_check(controller.context_kind(first, site) == "construct", role + ": wrong context order")
	controller._navigate_unit_towards_unit(first, site)
	await _frames(300)
	_check(site.construction_progress() > 0, role + ": first worker never started")
	first.issue_manual_order(null)
	await _frames(3)
	var progress = site.construction_progress()
	await _frames(30)
	if human.faction == "helix":
		_check(
			site.construction_progress() > progress, role + ": nanite beacon stopped with worker"
		)
		_check(not site.needs_constructor(), role + ": active beacon requests replacement engineer")
		for frame in 3000:
			if site.is_constructed():
				break
			await _frames(1)
		_check(site.is_constructed(), role + ": autonomous site never completed")
		_check(first.action == null, role + ": nanite site reassigned stopped engineer")
		for unit in [first, replacement, site]:
			unit.queue_free()
		await _frames(5)
		return
	_check(site.construction_progress() == progress, role + ": stopped site kept building")
	root.get_node("MatchSignals").deselect_all_units.emit()
	replacement.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(site.position)
	camera.set_size_safely(28 if role == "AircraftFactory" else 20)
	await _frames(5)
	# The near corners of the fabrication pad previously fell outside the
	# building cylinder. Use real physics picking and mouse dispatch here.
	var bounds = site.get_node("ConstructionVisual").rig.bounds
	var corner = Vector3(bounds.end.x, .15, bounds.end.z)
	var pointer = camera.unproject_position(site.to_global(corner))
	_check(game.hud._pick_unit(pointer) == site, role + ": visible site corner is not targetable")
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = pointer
	root.push_input(click, true)
	await _frames(3)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await _frames(3)
	_check(
		replacement.manual_orders.current.get("kind") == "construct", role + ": resume not assigned"
	)
	await _frames(420)
	_check(site.construction_progress() > progress, role + ": replacement cannot resume")
	for frame in 2400:
		if site.is_constructed():
			break
		await _frames(1)
	await _frames(3)
	_check(site.is_constructed(), role + ": replacement never completed site")
	_check(
		not site.has_node("ConstructionFootprintTarget"),
		role + ": completed site retains input pad"
	)
	_check(Vector2i(human.resource_a, human.resource_b) == funds, role + ": handoff charged again")
	_check(first.action == null, role + ": handoff reassigned stopped worker")
	print(
		"RESUME ",
		human.faction,
		" ",
		role,
		" progress=",
		progress,
		" completed=",
		site.is_constructed()
	)
	for unit in [first, replacement, site]:
		unit.queue_free()
	await _frames(5)
