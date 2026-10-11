extends "res://tests/headless/CommandHorizonRules.gd"

const Ambient = preload("res://source/match/ambient/AmbientCatalog.gd")


func _run():
	path = "user://ambient-regression-%d.json" % OS.get_process_id()
	for map_name in [
		"CommandHorizonMap",
		"BrokenFoundryMap",
		"AlpineRelay",
		"DesertFrontier",
		"IndustrialCrossroads",
		"CoastalFoundry"
	]:
		await _create(map_name)
		_check(await _behavior() == true, map_name + " behavior aborted")
		_check(await _archives() == true, map_name + " archive aborted")
		await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Ambient life: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _create(map_name):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/%s.tscn" % map_name
	var scene = "res://source/match/Skirmish.tscn"
	if map_name in ["CommandHorizonMap", "BrokenFoundryMap"]:
		settings.mission_id = (
			"command_horizon" if map_name == "CommandHorizonMap" else "broken_foundry"
		)
		scene = "res://source/match/campaign/%s.tscn" % map_name.trim_suffix("Map")
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load(scene).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	if "progress_path" in game:
		game.progress_path = path
	root.add_child(game)
	current_scene = game
	await _frames(45)
	_freeze_units()


func _freeze_units():
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.position = (
				Vector3(4, 0, 4)
				if unit.player == game._get_human_player()
				else Vector3(game.map.size.x - 4, 0, game.map.size.y - 4)
			)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.battlefield.invalidate()


func _behavior():
	var life = game.map.get_node("AmbientLife")
	var expected = Ambient.entries(game.settings.map_path)
	_check(life.actors.size() == expected.size(), "Missing authored population")
	var unit_count = get_nodes_in_group("units").size()
	for actor in life.actors:
		_check(actor.player == null and actor.hp > 0, "Neutral lacks health or has an owner")
		for group in [
			"units",
			"vision_sources",
			"resource_units",
			"selected_units",
			"sight_blockers",
			"terrain_navigation_input"
		]:
			_check(not actor.is_in_group(group), "Neutral entered gameplay group: " + group)
		_check(
			actor.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Neutral intercepts input or collides"
		)
		for distance in range(ceili(actor.entry.length)):
			var point = Ambient.point(actor.entry, float(distance))
			_check(
				(
					point.x > 1
					and point.z > 1
					and point.x < game.map.size.x - 1
					and point.z < game.map.size.y - 1
				),
				"Route escaped map"
			)
			if game.map.has_method("is_land"):
				_check(
					game.map.is_land(point) == (not actor.entry.kind in ["gull", "tug"]),
					"Coastal neutral left its land/water route"
				)
			for obstacle in get_nodes_in_group("sight_blockers"):
				if obstacle.get_parent().is_in_group("units"):
					continue
				_check(
					point.distance_to(obstacle.get_parent().position) > obstacle.radius + .5,
					"Authored route clips scenery: " + actor.entry.id
				)
		var source = _units(game._get_human_player(), "Tank")
		if not source.is_empty():
			_check(
				(
					load("res://source/match/combat/CombatRules.gd").can_target(source[0], actor)
					if actor.entry.kind != "gull"
					else not load("res://source/match/combat/CombatRules.gd").can_target(
						source[0], actor
					)
				),
				"Neutral weapon-domain targeting failed"
			)
		if actor.entry.kind in ["resident", "fox"]:
			_check(actor._limbs.size() == 4, "Missing animation pivots: " + actor.entry.kind)
		if actor.entry.kind == "gull":
			_check(actor._wings.size() == 2, "Gull missing wing pivots")
		var forward = Ambient.point(actor.entry, actor.travel + .25) - actor.position
		_check(actor.basis.z.dot(forward.normalized()) > .99, "Neutral faces backward")
		actor.stop_left = 0
	var before = life.capture()
	await _frames(180)
	for index in life.actors.size():
		_check(
			life.actors[index].travel != before[index].travel,
			"Neutral never moved: " + life.actors[index].entry.id
		)
	paused = true
	before = life.capture()
	for frame in 8:
		await process_frame
	_check(life.capture() == before, "Pause advanced neutral motion/animation")
	paused = false
	var actor = life.actors[0]
	var human = game._get_human_player()
	var unit = _units(human, "Worker")[0]
	var previous = unit.position
	actor.stop_left = 0
	unit.position = Ambient.point(
		actor.entry, actor.travel + (3.36 if actor.entry.kind == "car" else 1.44)
	)
	game.battlefield.invalidate()
	before = actor.travel
	await _frames(30)
	_check(actor.yielding and actor.travel == before, "Neutral did not yield to ground unit")
	unit.position = previous
	game.battlefield.invalidate()
	await _frames(30)
	_check(not actor.yielding and actor.travel != before, "Neutral did not resume after clearance")
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	life.refresh_visibility()
	_check(not actor.visible, "Unobserved neutral leaked through fog")
	unit.position = actor.position + Vector3(0, 0, 2)
	game.battlefield.invalidate()
	life.refresh_visibility()
	_check(actor.visible, "Observed neutral stayed invisible")
	unit.position = previous
	game.battlefield.invalidate()
	life.refresh_visibility()
	_check(not actor.visible, "Explored fog retained moving neutral")
	if game.settings.map_path.ends_with("CommandHorizonMap.tscn"):
		var saved_position = actor.position
		var old_sight = unit.sight_range
		unit.sight_range = 30
		actor.position = Vector3(59, 0, 44)
		unit.position = Vector3(45, 0, 44)
		game.battlefield.invalidate()
		life.refresh_visibility()
		_check(not actor.visible, "Neutral visible through opaque ruin")
		actor.position = saved_position
		unit.position = previous
		unit.sight_range = old_sight
		game.battlefield.invalidate()
	game.settings.visibility = game.settings.Visibility.FULL
	life.refresh_visibility()
	_check(life.actors.all(func(a): return a.visible), "Full visibility hides neutrals")
	_check(get_nodes_in_group("units").size() == unit_count, "Neutrals altered military population")
	print(
		"PASS neutral routes, motion, yield, pause, fog, target isolation: ", game.settings.map_path
	)
	return true


func _archives():
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, "Neutral capture failed: " + capture.error)
	if data == null:
		return false
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Neutral schema rejected capture: " + schema.error)
	for change in [
		{"id": "injected"},
		{"travel": -1.0},
		{"travel": 100000.0},
		{"phase": INF},
		{"stop_left": 3.0},
		{"path": "res://malicious.gd"}
	]:
		var bad = data.duplicate(true)
		bad.ambient[0].merge(change, true)
		_check(not schema.validate(bad), "Invalid neutral archive accepted: " + str(change))
	var duplicate = data.duplicate(true)
	duplicate.ambient[1] = duplicate.ambient[0].duplicate()
	_check(not schema.validate(duplicate), "Duplicate neutral IDs accepted")
	var missing = data.duplicate(true)
	missing.ambient.pop_back()
	_check(not schema.validate(missing), "Missing neutral accepted")
	var file = load("res://source/match/saves/SaveFile.gd").new()
	_check(file.write_file(path + ".archive", data), "Ambient disk write failed: " + file.error)
	data = file.read_file(path + ".archive")
	DirAccess.remove_absolute(path + ".archive")
	var loader = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await loader.restore(self, data)
	_check(result.ok, "Neutral restoration failed: " + result.get("error", ""))
	if not result.ok:
		return false
	game = result.game
	if "progress_path" in game:
		game.progress_path = path
	_check(
		capture.capture(game).ambient == data.ambient, "Archive changed neutral position/timer/pose"
	)
	_freeze_units()
	paused = false
	await _frames(30)
	_check(
		game.map.get_node("AmbientLife").capture() != data.ambient,
		"Restored neutrals failed to resume"
	)
	paused = true
	var legacy = data.duplicate(true)
	legacy.snapshot_version = 5
	legacy.erase("battle_record")
	for resource in legacy.resources:
		resource.erase("wreck")
	legacy.erase("ambient")
	legacy.erase("neutral_buildings")
	for side in legacy.players:
		side.erase("technology")
	_check(schema.validate(legacy), "Version 5 migration rejected: " + schema.error)
	result = await loader.restore(self, legacy)
	_check(result.ok, "Legacy restore failed")
	if not result.ok:
		return false
	game = result.game
	if "progress_path" in game:
		game.progress_path = path
	_check(
		game.map.get_node("AmbientLife").actors.size() == data.ambient.size(),
		"Legacy save lacks default neutrals"
	)
	print(
		"PASS exact neutral archive, hostile data rejection and v5 migration: ",
		game.settings.map_path
	)
	paused = false
	return true
