extends "res://tests/headless/HeroCampaignRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://hub-salvage-%d.json" % OS.get_process_id()
	await _make_operation("frontier_drainage")
	var human = game._get_human_player()
	var worker = _units(human, "Worker")[0]
	worker.action = null
	var wreck = load("res://source/match/units/non-player/Wreck.tscn").instantiate()
	wreck.position = worker.global_position + Vector3(0, 0, .7)
	game.map.get_node("Resources").add_child(wreck)
	await _frames(4)
	game.fog_of_war._physics_process(0)
	_check(wreck.dismantle(worker), "Frontier campaign worker could not recover nearby wreck")
	var state = load("res://source/match/campaign/CampaignHubState.gd").new()
	_check(state.read_state(path + ".hub") and state.recoveries == ["frontier_drainage"], "Actual wreck recovery did not deliver a persistent trophy")
	_check(not wreck.dismantle(worker), "Already consumed wreck was salvaged twice")
	_check(state.forge_insignia("Cinder Wings", path + ".hub"), "Recovered wreck trophy could not forge cosmetic insignia")
	_check(not state.forge_insignia("Meridian Star", path + ".hub"), "One recovered wreck trophy paid for two insignia")
	_check(state.read_state(path + ".hub") and state.insignia == ["Cinder Wings"], "Forged insignia did not persist")
	game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".hub")
	for message in errors:
		push_error(message)
	print("Campaign hub wreck trophies: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
