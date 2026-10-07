extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in ["AlpineRelay", "IndustrialCrossroads"]:
		for faction in ["bastion", "helix", "frontier"]:
			await _scenario(map_name, faction)
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn")
	_check(game.hud.find_child("OpenRelays", true, false) == null, "Non-relay map offers relays")
	game.queue_free()
	await _frames(5)
	for error in errors:
		push_error(error)
	print("Relay overview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _scenario(map_name, faction):
	await _skirmish(faction, "res://source/match/maps/%s.tscn" % map_name)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud.pause_after_load()
	var open = game.hud.find_child("OpenRelays", true, false)
	_check(open != null, map_name + "/" + faction + ": no relay overview access")
	if open != null:
		await _overview_checks(open, map_name + "-" + faction)
	paused = false
	game.queue_free()
	await _frames(5)


func _overview_checks(open, label):
	var owner = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var worker = _units(owner, "Worker")[0]
	worker.manual_orders.submit({"kind": "move", "point": Vector3(35, 0, 30)})
	worker.manual_orders.submit({"kind": "move", "point": Vector3(40, 0, 30)}, true)
	root.get_node("MatchSignals").deselect_all_units.emit()
	worker.get_node("Selection").select()
	var orders = worker.manual_orders.pending.duplicate(true)
	var action = worker.action
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var clock = game.simulation_time
	await _activate(open, label + "-open")
	var overview = game.hud.find_child("RelayOverview", true, false)
	_check(overview != null, "Relay dialog did not open")
	if overview == null:
		return
	_check(overview._rows.size() == 2, "Relay count mismatch")
	_check("North Relay" in overview._rows[0].status.text, "North relay lacks name")
	_check("South Relay" in overview._rows[1].status.text, "South relay lacks name")
	_check("Neutral" in overview._rows[0].status.text, "Neutral state missing")
	await _review(label + "-neutral")
	for index in 2:
		var relay = game.map.relays[index]
		await _activate(overview._rows[index].button, label + "-view")
		_check(game.hud._overlay == null, "View kept overlay open")
		_check(paused, "View resumed a previously paused match")
		var camera = game.get_node("IsometricCamera3D")
		var point = camera.get_ray_intersection_with_plane(
			root.get_visible_rect().size / 2, Plane(Vector3.UP, relay.global_position.y)
		)
		_check(
			point.distance_to(relay.global_position) < 0.1,
			"Camera missed relay: %s versus %s" % [point, relay.global_position]
		)
		_check(get_nodes_in_group("selected_units") == [worker], "View changed selection")
		_check(
			worker.action == action and worker.manual_orders.pending == orders,
			"View changed pending orders"
		)
		_check(Vector2i(owner.resource_a, owner.resource_b) == funds, "View spent funds")
		_check(game.simulation_time == clock, "Paused overview advanced simulation")
		var markers = game.hud.find_child("RelayMarkers", true, false)
		_check(markers != null, "Relay view has no public marker")
		if markers != null:
			_check(markers._markers[index].label.visible, "Located relay marker hidden")
			var ground = camera.get_ray_intersection(
				markers._markers[index].label.get_rect().get_center()
			)
			_check(
				(
					Vector2(ground.x, ground.z).distance_to(
						Vector2(relay.position.x, relay.position.z)
					)
					< relay.RADIUS
				),
				"Ground order at marker misses capture radius"
			)
			_check(markers.get_parent().layer < game.hud.layer, "Marker draws over HUD")
			_check(markers._markers[index].minimap.z_index > 0, "Minimap marker under fog")
		await _review(label + "-located-" + str(index))
		await _activate(open, label + "-reopen")
		overview = game.hud.find_child("RelayOverview", true, false)
	game.hud._close_menu()
	await _frames(3)
	# A real ten-second capture, interrupted by a real contest and a disk reload.
	var relay = game.map.relays[0]
	var infantry = _units(owner, "Infantry")[0]
	infantry.position = relay.position + Vector3(-2, 0, 0)
	game.battlefield.invalidate()
	paused = false
	await _frames(180)
	game.hud.pause_after_load()
	await _activate(open, label + "-progress")
	overview = game.hud.find_child("RelayOverview", true, false)
	_check(relay.candidate == owner and relay.progress > 2, "Real capture did not start")
	_check("Your capture" in overview._rows[0].status.text, "Capture progress missing")
	await _review(label + "-progress")
	game.hud._close_menu()
	var tank = _units(enemy, "Tank")[0]
	var tank_home = tank.position
	tank.position = relay.position + Vector3(2, 0, 0)
	game.battlefield.invalidate()
	paused = false
	await _frames(3)
	game.hud.pause_after_load()
	_check(relay.contested, "Enemy armor did not contest")
	var progress = relay.progress
	await _activate(open, label + "-contest")
	overview = game.hud.find_child("RelayOverview", true, false)
	_check("Contested" in overview._rows[0].status.text, "Contest status missing")
	await _review(label + "-contested")
	_check(relay.progress == progress, "Paused capture progressed")
	game.hud._close_menu()
	var file = "user://relay-overview-%d.json" % OS.get_process_id()
	var store = FileStore.new()
	_check(store.write_file(file, Snapshot.new().capture(game)), "Relay archive write failed")
	var loaded = await Restore.new().restore(self, store.read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Relay archive restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	owner = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	open = game.hud.find_child("OpenRelays", true, false)
	await _activate(open, label + "-restored")
	overview = game.hud.find_child("RelayOverview", true, false)
	relay = game.map.relays[0]
	_check(relay.progress == progress and relay.contested, "Reload changed relay state")
	_check(
		(
			"Your capture" in overview._rows[0].status.text
			and "Contested" in overview._rows[0].status.text
		),
		"Reload lost objective feedback"
	)
	game.hud._close_menu()
	_units(enemy, "Tank")[0].position = tank_home
	game.battlefield.invalidate()
	paused = false
	await _frames(450)
	game.hud.pause_after_load()
	await _activate(open, label + "-secured")
	overview = game.hud.find_child("RelayOverview", true, false)
	_check(relay.captured_by == owner, "Capture failed to complete after reload")
	_check("Yours" in overview._rows[0].status.text, "Completed capture state missing")
	await _review(label + "-secured")
	game.hud._close_menu()
	# An opponent captures the other public objective, outside friendly sight.
	var south = game.map.relays[1]
	var opponent = _units(enemy, "Infantry")[0]
	opponent.position = south.position + Vector3(2, 0, 0)
	game.battlefield.invalidate()
	paused = false
	await _frames(620)
	await _activate(open, label + "-enemy")
	overview = game.hud.find_child("RelayOverview", true, false)
	_check(paused, "Opening a running match did not pause")
	_check(south.captured_by == enemy, "Enemy capture did not complete")
	_check("Enemy owned" in overview._rows[1].status.text, "Public enemy state missing")
	var ownership = load("res://source/match/hud/Ownership.gd")
	_check(not ownership.known_now(opponent, game), "Objective view disclosed hidden infantry")
	await _review(label + "-enemy")
	await _activate(overview._rows[1].button, label + "-view-enemy")
	_check(not paused, "View did not restore a previously running match")
	_check(not ownership.known_now(opponent, game), "Camera revealed hidden infantry")
	# Existing modal ownership and results guard against nested locator panels.
	game.hud._open_menu()
	var overlay = game.hud._overlay
	open.pressed.emit()
	_check(game.hud._overlay == overlay, "Relay button replaced an existing modal")
	game.hud._close_menu()
	game.finished = true
	open.pressed.emit()
	_check(game.hud._overlay == null, "Finished match opened relay controls")
	game.finished = false


func _activate(button, _label):
	button.pressed.emit()
	await _frames(6)


func _review(_label):
	pass
