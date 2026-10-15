extends "res://tests/headless/Skirmish.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var game = await _start(_settings("bastion", "helix", false))
	_check(
		get_nodes_in_group("resource_units").size() == 28,
		"Fields lack five materials / two electronics"
	)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	paused = true
	var tracked = []
	for kind in ["A", "B"]:
		var property = "resource_a" if kind == "A" else "resource_b"
		var deposit = (
			load("res://source/match/units/non-player/Resource%s.tscn" % kind).instantiate()
		)
		_check(deposit.get(property) == 600, "Starting stock was not doubled: " + kind)
		deposit.position = Vector3(30, 0, 25 if kind == "A" else 30)
		game.map.get_node("Resources").add_child(deposit)
		for pair in [[600, 3], [301, 3], [300, 2], [151, 2], [150, 1], [61, 1], [60, 0], [1, 0]]:
			deposit.set(property, pair[0])
			_check_bounds(deposit)
			_check(_model_stage(deposit) == pair[1], "Wrong pile stage: %s / %d" % [kind, pair[0]])
			_check(
				is_equal_approx(deposit.radius, 0.6),
				"Depletion changed the harvest/navigation footprint"
			)
		deposit.set(property, 600)
		_check(_model_stage(deposit) == 3, "Refilled stock did not restore its full cluster")
		_check_bounds(deposit)
		deposit.set(property, 150 if kind == "A" else 60)
		tracked.append(deposit)
	var snapshotter = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = snapshotter.capture(game)
	_check(snapshot != null, "Pile snapshot capture failed: " + snapshotter.error)
	if snapshot != null:
		var ids = tracked.map(func(deposit): return snapshotter._reference(deposit))
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var restored = await restore.restore(self, snapshot)
		_check(restored.ok, "Partially depleted piles failed to restore")
		if restored.ok:
			game = restored.game
			for index in ids.size():
				var deposit = restore.entities[ids[index]]
				var property = "resource_a" if index == 0 else "resource_b"
				_check(
					deposit.get(property) == (150 if index == 0 else 60), "Reload refilled stock"
				)
				_check(
					_model_stage(deposit) == (1 if index == 0 else 0), "Reload grew depleted piles"
				)
				deposit.set(property, -1)
				_check(
					deposit.get(property) == 0 and deposit.is_queued_for_deletion(),
					"Empty pile survived"
				)
	paused = false
	await _frames(4)
	await _harvest_thresholds(game)
	game.queue_free()
	await _frames(4)
	for message in _errors:
		push_error(message)
	print("Resource piles: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _harvest_thresholds(game):
	var collecting = load("res://source/match/units/actions/CollectingResourcesWhileInRange.gd")
	for kind in ["A", "B"]:
		var property = "resource_a" if kind == "A" else "resource_b"
		var deposit = (
			load("res://source/match/units/non-player/Resource%s.tscn" % kind).instantiate()
		)
		deposit.position = Vector3(30, 0, 25)
		game.map.get_node("Resources").add_child(deposit)
		var worker = load(Catalog.scene_path("Worker")).instantiate()
		game._setup_and_spawn_unit(
			worker, Transform3D(Basis(), Vector3(32, 0, 25)), game._get_human_player(), false
		)
		await _frames(90)
		for pair in [[301, 2], [151, 1], [61, 0]]:
			deposit.set(property, pair[0])
			worker.set(property, 0)
			worker.position = deposit.position + Vector3(1.5, 0, 0)
			worker.issue_manual_order(collecting.new(deposit))
			for frame in 240:
				await physics_frame
				if worker.get(property) > 0:
					break
			worker.issue_manual_order(null)
			_check(worker.get(property) == 1, "Worker did not collect exactly one resource")
			_check(deposit.get(property) == pair[0] - 1, "Model swap changed the resource balance")
			_check(
				_model_stage(deposit) == pair[1],
				"Harvest did not change the model at its threshold"
			)
		worker.queue_free()
		deposit.queue_free()
		await _frames(5)


func _model_stage(deposit):
	var models = deposit.get_node("Geometry").get_children()
	if models.size() == 5:
		return 3
	if models.size() != 1:
		return -1
	for stage in 3:
		if models[0].scene_file_path.ends_with("_depleted_%d.glb" % stage):
			_check(
				models[0].scale == Vector3.ONE, "Depletion shrank a model instead of replacing it"
			)
			return stage
	return -1


func _check_bounds(deposit):
	for mesh in deposit.find_children("*", "MeshInstance3D", true, false):
		if not deposit.get_node("Geometry").is_ancestor_of(mesh):
			continue
		var local = deposit.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point = local * vertex
				_check(
					Vector2(point.x, point.z).length() <= deposit.radius, "Salvage exceeds obstacle"
				)
