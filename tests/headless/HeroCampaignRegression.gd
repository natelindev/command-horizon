extends "res://tests/headless/CampaignRegression.gd"

const Campaigns = preload("res://source/match/campaign/CampaignCatalog.gd")
var _id = ""


func _make_operation(id):
	_id = id
	var operation = Campaigns.OPERATIONS[id]
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = id
	settings.map_path = operation.map
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if index == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = operation.faction if index == 0 else operation.enemy
		side.difficulty = 1
		settings.players.append(side)
	game = load(operation.scene).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(8)
	game.set_physics_process(false)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	path = "user://hero-campaign-%d.json" % OS.get_process_id()
	for faction in Campaigns.ORDER:
		for id in Campaigns.ORDER[faction]:
			paused = false
			await _make_operation(id)
			_check(game.campaign_hero.alive(), "Hero absent: " + id)
			_check(game.campaign_hero.unit.player.faction == faction, "Wrong hero faction: " + id)
			_check(
				game.campaign_hero.tier == mini(3, 1 + int((Campaigns.OPERATIONS[id].act - 1) / 2)),
				"Hero tier wrong: " + id
			)
			await _save_restore()
			if Campaigns.is_story(id):
				_objectives()
			else:
				game.campaign_hero.unit.hp = 0
				game.campaign_hero.step(0)
				_check(game.result == "Defeat", "Hero death not enforced: " + id)
			paused = false
			game.queue_free()
			await _frames(4)
	for id in Campaigns.STORIES:
		_check(Progress.new().record_operation(id, path), "Campaign progress write failed: " + id)
	var progress = Progress.new()
	_check(progress.read_progress(path), "Expanded progress could not reload")
	_check(progress.operations.size() == 11, "Expanded progress omitted a mission")
	_check(progress.foundry_support(), "Cinder Ford rescue support was lost")
	_check(progress.campaign_finished("helix"), "Helix completion omitted a mission")
	_check(progress.campaign_finished("frontier"), "Frontier completion omitted a mission")
	progress.supply_complete = true
	progress.complete = true
	progress.split_complete = true
	progress.foundry_complete = true
	progress.horizon_complete = true
	_check(
		not progress.air_complete and progress.campaign_finished(),
		"Cinder Ford did not replace Air Corridor in completion"
	)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".sav")
	for message in errors:
		push_error(message)
	print("Hero campaigns: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _save_restore():
	paused = true
	game.campaign_hero.cooldown = 12.5
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var state = capture.capture(game)
	_check(state != null, "Capture failed " + _id + ": " + capture.error)
	if state == null:
		return
	var file = load("res://source/match/saves/SaveFile.gd").new()
	_check(file.write_file(path + ".sav", state), "Disk write failed: " + file.error)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var invalid = state.duplicate(true)
	invalid.mission.hero.tier = 4
	_check(not restore.prepare(invalid), "Invalid hero tier accepted: " + _id)
	invalid = state.duplicate(true)
	invalid.mission.hero.cooldown = 31.0
	_check(not restore.prepare(invalid), "Invalid hero cooldown accepted: " + _id)
	if Campaigns.is_story(_id):
		invalid = state.duplicate(true)
		invalid.mission.stage = Campaigns.STORIES[_id].objectives.size()
		_check(not restore.prepare(invalid), "Out-of-range objective accepted: " + _id)
		invalid = state.duplicate(true)
		invalid.mission.wave_left = 41.0
		_check(not restore.prepare(invalid), "Invalid wave timer accepted: " + _id)
		if game.current_objective().kind == "escort":
			invalid = state.duplicate(true)
			invalid.mission.escort = ""
			_check(not restore.prepare(invalid), "Missing active convoy accepted: " + _id)
	var result = await restore.restore(self, file.read_file(path + ".sav"))
	_check(result.ok, "Restore failed " + _id + ": " + restore.error)
	if result.ok:
		game = result.game
		game.progress_path = path
		game.set_physics_process(false)
		game.get_node("IsometricCamera3D").set_physics_process(false)
		_check(game.campaign_hero.alive(), "Restore lost hero: " + _id)
		_check(game.campaign_hero.cooldown == 12.5, "Restore reset ability cooldown: " + _id)
		var heroes = game._get_human_player().get_children().filter(
			func(u): return u.is_in_group("units") and u.type == "Hero"
		)
		_check(heroes.size() == 1, "Restore duplicated hero: " + _id)


func _objectives():
	var objectives = Campaigns.STORIES[_id].objectives
	for index in objectives.size():
		var objective = objectives[index]
		_check(game.stage == index and not game.finished, "Objective skipped: " + _id)
		var guide = load("res://source/match/campaign/CampaignObjectives.gd")
		var expected = objective.destination if objective.kind == "escort" else objective.point
		_check(
			guide.point(game) == Vector3(expected[0], 0, expected[1]),
			"Locator points to wrong stage: " + _id
		)
		for language in ["en", "zh_CN"]:
			root.get_node("Globals").options.language = language
			root.get_node("Globals").options.apply()
			game.hud._process(0)
			_check(
				"24" in game.hud._objective_hint.text, "Hero distance requirement hidden: " + _id
			)
			_check(
				not game.hud._objective_hint.text.is_empty(), "Stage instructions missing: " + _id
			)
		var action = game.campaign_hero.unit.action
		game.hud._view_objective.pressed.emit()
		_check(
			game.campaign_hero.unit.action == action,
			"Objective locator changed hero orders: " + _id
		)
		match objective.kind:
			"capture", "hold":
				game.map.relays[index].captured_by = game._get_human_player()
				game.map.relays[index].contested = false
			"destroy":
				game.targets[index].hp = 0
			"escort":
				_check(is_instance_valid(game.escort), "Escort missing: " + _id)
				game.advance_escort()
				game.escort.position = Vector3(
					objective.destination[0], 0, objective.destination[1]
				)
		game.campaign_hero.unit.position = Vector3(18, 0, 100)
		game._check_outcome(float(objective.seconds))
		_check(game.stage == index, "Objective completed without hero: " + _id)
		var point = objective.destination if objective.kind == "escort" else objective.point
		game.campaign_hero.unit.position = Vector3(point[0], 0, point[1])
		game._check_outcome(0)
	_check(game.finished and game.result == "Victory", "Objectives did not win: " + _id)
