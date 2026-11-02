extends "res://tests/headless/CampaignRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://campaign-hub-loop-%d.json" % OS.get_process_id()
	var state = load("res://source/match/campaign/CampaignHubState.gd").new()
	_check(state.choose_doctrine("bastion", "fortress_doctrine", path + ".hub"), "Could not choose campaign doctrine")
	await _make_match()
	var player = game._get_human_player()
	_check("fortress_doctrine" in player.technology.completed, "Hub doctrine did not reach the actual operation")
	var story = game.campaign_story
	story._clear()
	story.start_briefing(true)
	_check(story.cinematic and paused, "Hub operation did not enter illustrated briefing")
	_check(story._illustration.backdrop.texture != null and story._illustration.foreground.texture != null, "Operation briefing lost painted layers")
	_check(story._scene_length >= 45 and story._scene_length <= 60, "Briefing duration outside45–60s")
	story.skip_briefing()
	_check(not story.cinematic and not paused, "Briefing skip did not return simulation control")
	var hero = game.campaign_hero.unit
	hero.hp = hero.hp_max * .5
	game.finished = true
	game.result = "Victory"
	_check(state.record_debrief(game), "Half-hull hero did not earn commendation")
	_check(state.read_state(path + ".hub") and game.settings.mission_id in state.commendations, "Commendation was not persisted")
	game.hud.show_result("Victory")
	await _frames(5)
	var details = game.hud._overlay.find_child("StoryDebrief", true, false)
	_check(details != null and details.text.contains("Preservation commendation earned"), "Debrief does not show the earned secondary objective")
	game.hud._back_to_setup()
	await _frames(8)
	var hub = current_scene
	_check(hub.name == "CampaignHub" and hub.faction == "bastion", "Debrief did not return to matching3D command hub")
	_check(hub.progress_path == path and hub.hub_state_path == path + ".hub", "Hub return lost the active campaign progress file")
	hub._open_station(2)
	hub._start_preview("first_orders")
	await _frames(4)
	_check(hub._preview != null and hub._audio.playing, "Archive cannot replay actual illustrated narration")
	var cancel = InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	hub._unhandled_key_input(cancel)
	await _frames(3)
	_check(hub._preview == null and hub._station_buttons[2].has_focus(), "Archive skip did not restore station keyboard focus")
	hub.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".hub")
	for message in errors:
		push_error(message)
	print("Campaign hub operation loop: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
