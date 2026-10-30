extends "res://tests/headless/SaveRestoreEdges.gd"

var factions


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		await _production()
		await _selection_ranges()
		await _visuals(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Battle polish: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _production():
	var player = game._get_human_player()
	player.resource_a = 5000
	player.resource_b = 5000
	var first = _units(player, "VehicleFactory")[0]
	var second = load("res://source/match/units/VehicleFactory.tscn").instantiate()
	factions.prepare_model(second, player.faction)
	game._setup_and_spawn_unit(
		second, Transform3D(Basis.IDENTITY, first.position + Vector3(8, 0, 0)), player, false
	)
	await _frames(3)
	paused = true
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in [first, second]:
		unit.get_node("Selection").select()
	await _frames(3)
	var menu = game.find_child("UnitMenus")
	var button = menu.find_child("ProduceTank", true, false)
	_check(button != null and not button.disabled, "Multi-factory production unavailable")
	if button == null:
		return
	for index in 4:
		button.pressed.emit()
	_check(
		first.production_queue.size() == 2 and second.production_queue.size() == 2,
		"Clicks were not balanced across two factories"
	)
	first.production_queue.get_elements()[0].time_left = .1
	button.pressed.emit()
	_check(first.production_queue.size() == 3, "Remaining production time was ignored")
	var hud_queue = game.get_node("HUD").find_child("QueueElements", true, false)
	_check(hud_queue != null and hud_queue.get_child_count() == 5, "Combined paid jobs missing")
	if hud_queue == null:
		return
	var refund_before = player.resource_a
	var job = hud_queue.get_child(0)
	var owner = job.queue
	var size_before = owner.size()
	job.pressed.emit()
	_check(
		owner.size() == size_before - 1 and player.resource_a > refund_before,
		"Combined queue cancellation did not refund the correct producer"
	)
	# A full first queue must not disable an available second producer.
	for index in root.get_node("Constants").Match.Units.PRODUCTION_QUEUE_LIMIT:
		first.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	_check(menu._production_target("Tank") == second, "Full queue blocks another producer")
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in [_units(player, "Worker")[0], first, second, _units(player, "Barracks")[0]]:
		unit.get_node("Selection").select()
	await _frames(3)
	_check(menu.find_child("ProduceInfantry", true, false) != null, "Mixed producer roster missing")
	menu._activate("Infantry", false)
	_check(
		_units(player, "Barracks")[0].production_queue.size() == 1,
		"Mixed selection sent infantry to an incompatible producer"
	)
	paused = false


func _visuals(faction):
	var player = game._get_human_player()
	var handler = player.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/AntiGroundTurret.tscn"))
	_check(is_instance_valid(handler._placement_range), "Placement has no tactical range")
	if is_instance_valid(handler._placement_range):
		_check(
			handler._placement_range.material_override.albedo_color.a < .35,
			"Range preview is too opaque"
		)
		_check(
			handler._placement_range.material_override.render_priority > 2,
			"Range preview occluded by fog of war overlay"
		)
	var blueprint_meshes = handler._active_blueprint_node.find_children(
		"*", "MeshInstance3D", true, false
	)
	_check(not blueprint_meshes.is_empty(), "Blueprint has no mesh children")
	if not blueprint_meshes.is_empty():
		var blueprint_mat = blueprint_meshes[0].material_override
		_check(
			blueprint_mat != null and blueprint_mat.render_priority > 2,
			"Blueprint indicator occluded by fog of war overlay"
		)
	var eng_preview = load("res://source/match/hud/EngineeringPreview.gd").new()
	add_child(eng_preview)
	_check(
		eng_preview._material.render_priority > 2,
		"Engineering preview occluded by fog of war overlay"
	)
	eng_preview.queue_free()
	var terrain_feedback = load("res://source/match/effects/TerrainFeedback.gd").new()
	_check(
		terrain_feedback.material_override.render_priority > 2,
		"Terrain feedback occluded by fog of war overlay"
	)
	terrain_feedback.free()
	var controlled_air_mat = load(
		"res://source/match/resources/materials/controlled_unit_air_to_terrain_marker.material.tres"
	)
	_check(
		controlled_air_mat.render_priority > 2,
		"Controlled air marker occluded by fog of war overlay"
	)
	var adversary_air_mat = load(
		"res://source/match/resources/materials/adversary_unit_air_to_terrain_marker.material.tres"
	)
	_check(
		adversary_air_mat.render_priority > 2,
		"Adversary air marker occluded by fog of war overlay"
	)
	handler._cancel_structure_placement()
	_check(handler._placement_range == null, "Canceled placement retained range")
	var tank = _units(player, "Tank")[0]
	tank.get_node("Selection").select()
	_check(
		tank.get_node("Selection")._circle.color == player.color,
		"Selection outline does not use the owning player's color"
	)
	var turret = tank.find_child("*TurretPivot*", true, false)
	if turret != null:
		var scale_before = turret.global_basis.get_scale()
		game.combat_effects._wreck(tank, false)
		await _frames(5)
		var body = game.combat_effects._cook_offs[-1].node
		_check(body.scale.is_equal_approx(Vector3.ONE), "Detached turret physics body is scaled")
		_check(
			body.get_child(0).global_basis.get_scale().is_equal_approx(scale_before),
			faction + ": detached turret grew after a physics step"
		)
	var live_bounds = factions._bounds(tank.get_node("Geometry"), Transform3D.IDENTITY)
	var wreck = load("res://source/match/units/non-player/Wreck.tscn").instantiate()
	wreck.wreck_faction = faction
	game.map.get_node("Resources").add_child(wreck)
	var wreck_bounds = factions._bounds(
		wreck.get_node("Geometry").get_child(0), Transform3D.IDENTITY
	)
	_check(
		wreck_bounds.size.x <= live_bounds.size.x and wreck_bounds.size.z <= live_bounds.size.z,
		"Salvage wreck exceeds live tank size"
	)
	var life = game.map.get_node("AmbientLife")
	for actor in life.actors:
		var bounds = factions._bounds(actor._model, Transform3D.IDENTITY)
		if actor.entry.kind == "fox":
			_check(bounds.size.y < .5 and bounds.size.z < 1, "Fox exceeds believable size")
		if actor.entry.kind == "car":
			_check(bounds.size.z < live_bounds.size.z, "Civilian car is larger than tank")
		var scale_before = actor._model.scale
		actor.death_age = 1.0
		actor.apply_death_pose()
		_check(actor._model.scale.x == scale_before.x, "Neutral death reset model scale")
		actor.death_age = 0
	_check(game.get_node("NeutralWorld").buildings.size() == 2, "Central settlements missing")


func _selection_ranges():
	root.get_node("MatchSignals").deselect_all_units.emit()
	var player = game._get_human_player()
	var tank = _units(player, "Tank")[0].get_node("Selection")
	var infantry = _units(player, "Infantry")[0].get_node("Selection")
	var worker = _units(player, "Worker")[0].get_node("Selection")
	tank.select()
	_check(tank._range_ring != null and tank._range_ring.visible, "Single selection lost range")
	infantry.select()
	_check(not tank._range_ring.visible, "Group retained overlapping tank range")
	_check(
		infantry._range_ring == null or not infantry._range_ring.visible,
		"Group created infantry range"
	)
	_check(
		tank._circle.visible and infantry._circle.visible, "Group lost player selection outlines"
	)
	tank.deselect()
	_check(
		infantry._range_ring != null and infantry._range_ring.visible,
		"Shrinking selection lost range"
	)
	worker.select()
	_check(not infantry._range_ring.visible, "Unarmed mixed selection retained range")
	worker.deselect()
	_check(infantry._range_ring.visible, "Removing unarmed selection did not restore range")
	var extra = load("res://source/match/units/Infantry.tscn").instantiate()
	game._setup_and_spawn_unit(extra, Transform3D(Basis(), Vector3(40, 0, 40)), player, false)
	extra.get_node("Selection").select()
	extra.queue_free()
	await _frames(3)
	_check(infantry._range_ring.visible, "Selected unit deletion did not restore survivor range")
	infantry.deselect()
	_check(not infantry._range_ring.visible, "Deselection retained range")
