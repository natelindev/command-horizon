extends "res://tests/headless/BattleAlertsRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _feedback_case(faction)
	await _earned_raid()
	for message in errors:
		push_error(message)
	print("Attack feedback: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _feedback_case(faction):
	await _setup(faction)
	alerts = game.alerts
	panel = game.hud.alert_panel
	var human = game._get_human_player()
	var enemy = _sides()[1]
	var tank = _units(human, "Tank")[0]
	var raider = _units(enemy, "Tank")[0]
	var hq = _units(human, "CommandCenter")[0]
	alerts.entries.clear()
	panel._refresh()
	_check(panel.toggle.text == "Alerts", "Empty history did not show Alerts")
	raider.receive_weapon_hit(tank)
	tank.hp -= 1
	panel._refresh()
	_check(panel.toggle.text == "Alerts", "Enemy hit or generic HP loss announced own attack")
	var action = tank.action
	var funds = Vector2i(human.resource_a, human.resource_b)
	tank.receive_weapon_hit(raider)
	panel._refresh()
	_check(panel.toggle.text == "Units under attack", faction + ": closed panel hides unit attack")
	paused = true
	var clock = game.simulation_time
	alerts.mark_read()
	panel._refresh()
	_check(panel.toggle.text == "Units under attack", "Reading history hid active attack")
	_check("0 new" in panel.toggle.tooltip_text, "Attack label lost unread count context")
	await _review_attack(faction + "-units")
	hq.receive_weapon_hit(raider)
	tank.receive_weapon_hit(raider)
	panel._refresh()
	_check(panel.toggle.text == "Base under attack", faction + ": newer unit fire hid base attack")
	alerts.clear_history()
	panel._refresh()
	await _frames(45)
	_check(panel.toggle.text == "Base under attack", "Clear or pause removed active base feedback")
	_check(game.simulation_time == clock, "Feedback advanced paused simulation")
	_check(tank.action == action, "Feedback changed unit action")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Feedback changed funds")
	await _review_attack(faction + "-base")
	paused = false
	await _frames(300)
	tank.receive_weapon_hit(raider)
	await _frames(245)
	alerts.scan()
	panel._refresh()
	_check(panel.toggle.text == "Units under attack", "Expired base alert masked ongoing unit fire")
	await _frames(540)
	alerts.scan()
	panel._refresh()
	_check(panel.toggle.text.begins_with("Alerts"), "Stopped fire left a stale attack label")
	paused = true
	await _review_attack(faction + "-resolved")
	hq.receive_weapon_hit(raider)
	panel._refresh()
	_check(panel.toggle.text == "Base under attack", "Renewed base fire did not return warning")
	var dialog = root.get_node("Globals").open_settings()
	await _frames(5)
	_check(not panel._available(), "Attack feedback bypassed settings")
	var camera = game.get_node("IsometricCamera3D")
	var position = camera.position
	panel._toggle()
	panel.navigate(_kind("base_attack", true)[0].id)
	_check(
		not panel.panel.visible and camera.position == position,
		"Settings allowed attack inspection"
	)
	dialog._finish(false)
	await _frames(5)
	_check(panel.toggle.visible, "Attack feedback did not return after settings")
	game.finished = true
	await _frames(5)
	_check(not panel.toggle.visible, "Ended battle kept interactive attack feedback")
	print(
		"ATTACK FEEDBACK ", faction, " damage, priority, read, clear, pause, expiry and authority"
	)
	await _clean_match()


func _earned_raid():
	var file = "res://docs/playtests/2026-10-06/relay-contest/earned6-case6-10-worker_withdrawal.json"
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(file))
	_check(loaded.ok, "Earned Industrial raid failed to restore")
	if not loaded.ok:
		return
	game = loaded.game
	alerts = game.alerts
	panel = game.hud.alert_panel
	var began = game.simulation_time
	paused = false
	var found = false
	for frame in 5400:
		await _frames(1)
		if not _kind("base_attack", true).is_empty():
			found = true
			break
		if game.finished:
			break
	paused = true
	_check(found, "Earned raid did not produce live base damage within 90 seconds")
	if found:
		panel._refresh()
		_check(panel.toggle.text == "Base under attack", "Earned live base attack remained hidden")
		var entry = _kind("base_attack", true)[0]
		game.get_node("IsometricCamera3D").set_position_safely(entry.point)
		print("EARNED ATTACK after=", game.simulation_time - began, " title=", entry.title)
		await _review_attack("earned-industrial")
	await _clean_match()


func _review_attack(_label):
	pass
