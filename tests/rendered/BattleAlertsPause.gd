extends "res://tests/rendered/BattleAlertsPreview.gd"


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	await _setup("bastion")
	alerts = game.alerts
	panel = game.hud.alert_panel
	await _prepare_alerts()
	var hq = _units(game._get_human_player(), "CommandCenter")[0]
	hq.process_mode = Node.PROCESS_MODE_PAUSABLE
	var queue = hq.get_node("ProductionQueue")
	var job = queue.produce(load("res://source/match/units/Worker.tscn"))
	_check(job != null, "Normal-clock pause fixture could not pay for worker")
	await _frames(5)
	var old_alert = _kind("attack")[0]
	var target = alerts.live_units(old_alert)[0]
	target.receive_weapon_hit(_units(_sides()[1], "Infantry")[0])
	alerts.scan()
	var incoming = _kind("attack", true).back()
	game.hud._toggle_pause()
	var clock = game.simulation_time
	var remaining = job.time_left
	var started = Time.get_ticks_msec()
	await create_timer(30.0).timeout
	_check(Time.get_ticks_msec() - started >= 29500, "Pause check did not exercise 30 real seconds")
	_check(paused and game.simulation_time == clock, "Normal-clock pause advanced simulation")
	_check(
		job.time_left == remaining and incoming.active, "Pause advanced paid queue or expired alert"
	)
	game.hud._toggle_pause()
	await create_timer(9.0).timeout
	_check(
		job.time_left < remaining and not incoming.active,
		"Resume failed to advance queue/resolve stopped fire"
	)
	await _clean_match()
	manager.autosaves_enabled = autosaves
	preferences.restore(original)
	print("Thirty-second normal-clock alert/production pause: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
