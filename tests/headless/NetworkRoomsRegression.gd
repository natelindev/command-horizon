extends "res://tests/headless/NetworkSessionRegression.gd"

var role = ""
var port = 0


func _run():
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	port = _port(29250)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-role="):
			role = arg.trim_prefix("--network-role=")
	_deadline = Time.get_ticks_msec() + 130000
	if role == "server":
		await _directory_case()
	else:
		await _player_case()
	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	for message in failures:
		push_error(message)
	print("Network rooms %s: %d failures" % [role, failures.size()])
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _until(condition: Callable, description: String) -> bool:
	while not condition.call() and Time.get_ticks_msec() < _deadline:
		await process_frame
	var ok = condition.call()
	_check(ok, description)
	return ok


func _directory_case():
	var server = load("res://source/match/network/RoomServer.gd").new()
	server.port = port
	root.add_child(server)
	var browser_script = load("res://source/main-menu/RoomBrowser.gd")
	var browser = browser_script.new()
	var successor = browser_script.new()
	if not await _prepare_second_room(browser, successor):
		return
	var second_room = browser.mine
	print("NETWORK_READY port=", port)
	if not await _until(
		func(): return browser.listing.any(func(r): return r.state == "In battle"),
		"Duel did not launch"
	):
		return
	_check(browser.mine == second_room and browser.is_room_owner, "Independent room changed owner")
	_check(not browser.handed_off and browser.start_button.disabled, "Unrelated room was launched")
	browser.leave_button.pressed.emit()
	if not await _until(func(): return browser.mine == 0, "Could not leave second room"):
		return
	if not await _until(func(): return successor.is_room_owner, "Room ownership did not transfer"):
		return
	successor.queue_free()
	if not await _until(
		func(): return browser.listing.is_empty(), "Empty and finished rooms were not reaped"
	):
		return
	browser._create()
	await _until(
		func(): return browser.mine > second_room,
		"Directory did not accept a new room after the match"
	)
	browser.queue_free()
	server.queue_free()
	await process_frame


func _prepare_second_room(browser, successor) -> bool:
	root.add_child(browser)
	browser.browse("127.0.0.1", port)
	if not await _until(func(): return browser.online, "Could not browse directory"):
		return false
	browser.title_input.text = "Second room"
	browser.format.select(1)
	browser._create()
	if not await _until(func(): return browser.mine > 0, "Could not create second room"):
		return false
	var second_room = browser.mine
	root.add_child(successor)
	successor.browse("127.0.0.1", port)
	if not await _until(func(): return successor.online, "Second browser did not connect"):
		return false
	successor.link.send(1, {"type": "join", "id": second_room})
	if not await _until(
		func(): return successor.mine == second_room, "Could not join waiting room"
	):
		return false
	successor.link.send(1, {"type": "start"})
	if not await _until(
		func():
			return (
				successor.status.text == successor.tr("Only the room owner can start a full room.")
			),
		"Server allowed an unauthorized start"
	):
		return false
	return true


func _player_case():
	var menu = load("res://source/main-menu/Multiplayer.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.listen_port.value = port
	menu._browse_rooms()
	var browser = menu.room_browser
	if not await _until(func(): return browser.online, "Could not open multiplayer room browser"):
		return
	if role == "owner":
		browser.title_input.text = "Duel"
		browser._create()
		if not await _until(
			func(): return not browser.start_button.disabled, "Owner could not start full room"
		):
			return
		browser.start_button.pressed.emit()
	else:
		if not await _until(
			func(): return browser.listing.any(func(r): return r.name == "Duel"),
			"Duel missing from listing"
		):
			return
		for i in browser.listing.size():
			if browser.listing[i].name == "Duel":
				browser.rooms.select(i)
				browser._buttons()
		_check(not browser.join_button.disabled, "Listed duel could not be joined")
		browser.join_button.pressed.emit()
	if not await _until(
		func(): return menu.session != null, "Browser did not hand off to a battle"
	):
		return
	session = menu.session
	if not await _until(
		func(): return session.received_tick >= 60, "Battle did not replicate 60 ticks"
	):
		return
	_check(
		session.local_slot == (0 if role == "owner" else 1),
		"Room membership assigned the wrong slot"
	)
	print("Room battle tick=", session.received_tick, " slot=", session.local_slot)
	if role == "guest":
		_check(session.submit({"kind": "surrender"}), "Guest could not surrender")
	if not await _until(
		func(): return session.terminal_confirmed, "Worker did not deliver the battle result"
	):
		return
	_check(
		session.game.result == ("Victory" if role == "owner" else "Defeat"),
		"Wrong room match result"
	)
	session.shutdown()
	session.game.queue_free()
	await process_frame
