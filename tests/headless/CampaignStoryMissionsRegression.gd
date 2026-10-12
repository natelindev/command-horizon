extends "res://tests/headless/CampaignStoryRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	for mission in Narration.MISSIONS:
		var operation = load("res://source/match/campaign/CampaignCatalog.gd").OPERATIONS[mission]
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.mission_id = mission
		settings.map_path = operation.map
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = (
				root.get_node("Constants").PlayerType.HUMAN
				if index == 0
				else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
			)
			side.faction = "bastion" if index == 0 else "helix"
			side.difficulty = 1
			settings.players.append(side)
		game = load(operation.scene).instantiate()
		game.settings = settings
		game.map = load(settings.map_path).instantiate()
		game.progress_path = "user://story-all-%d.json" % OS.get_process_id()
		root.add_child(game)
		current_scene = game
		game.get_node("IsometricCamera3D").set_physics_process(false)
		await _frames(5)
		_check(game.campaign_story.current.id == mission + ".intro", "Missing intro: " + mission)
		game.campaign_story.start_briefing(true)
		game.campaign_story._scene_time = game.campaign_story._scene_length / 2
		game.campaign_story._animate_camera()
		await _frames(2)
		game.campaign_story.skip_briefing()
		game.campaign_story._observe()
		if mission == "air_corridor":
			game.opposition.activate()
			game.campaign_story._observe()
			_check(
				"common.enemy_base" in game.campaign_story.seen,
				"Air Corridor base activation was not narrated"
			)
			_check(
				(
					"common.boss_arrives" not in game.campaign_story.seen
					and "common.boss_defeated" not in game.campaign_story.seen
				),
				"Air Corridor narrated a siege commander that does not exist"
			)
		elif mission == "command_horizon":
			game.opposition.boss.hp = 0
			game.opposition._step_boss(0)
			game.campaign_story._observe()
			_check(
				(
					not game.opposition.boss_started
					and "common.boss_defeated" in game.campaign_story.seen
				),
				"A commander killed before its first barrage was not narrated"
			)
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("All story missions: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
