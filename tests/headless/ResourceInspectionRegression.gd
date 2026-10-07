extends "res://tests/headless/SaveRestoreEdges.gd"

var human
var overlay
var material
var electronics
var aircraft
var camera
var wreck


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _inspection_fixture(faction)
		for target in [material, electronics, aircraft]:
			await _point_at(target)
			_check(
				overlay._hovered_unit(camera) == target,
				faction + ": world hover ray missed " + target.name
			)
		await _details(faction)
		await _visibility(faction)
		await _lifetime(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	await _archive()
	await _harvesting()
	for error in errors:
		push_error(error)
	print("Resource inspection: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _inspection_fixture(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.set_physics_process(false)
	game.hud._toggle_pause()
	root.get_node("MatchSignals").deselect_all_units.emit()
	overlay = game.get_node("OwnershipLayer/OwnershipOverlay")
	camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(24)
	camera.set_position_safely(Vector3(32, 0, 28))
	material = _stock("ResourceA", Vector3(32, 0, 28))
	electronics = _stock("ResourceB", Vector3(32, 0, 33))
	aircraft = load("res://source/match/units/Drone.tscn").instantiate()
	game._setup_and_spawn_unit(aircraft, Transform3D(Basis(), Vector3(37, 3, 28)), human, true)
	aircraft.set_physics_process(false)
	wreck = _stock("Wreck", Vector3(34, 0, 31))
	wreck.resource_a = 4
	wreck.salvage_left = 178.0
	wreck._refresh()
	await _frames(5)


func _stock(kind, point):
	var resource = load("res://source/match/units/non-player/" + kind + ".tscn").instantiate()
	resource.position = point
	game.map.get_node("Resources").add_child(resource)
	return resource


func _point_at(target):
	camera.set_position_safely(target.global_position)
	var event = InputEventMouseMotion.new()
	event.position = camera.unproject_position(target.global_position + Vector3.UP * .3)
	event.global_position = event.position
	root.push_input(event, true)
	await _frames(5)


func _card_text():
	return "\n".join(overlay.hover_card().get("lines", []))


func _authority():
	var state = [paused, game.simulation_time, human.resource_a, human.resource_b]
	for unit in human.get_children():
		if unit.is_in_group("units") and not unit.is_queued_for_deletion():
			state.append([unit, unit.position, unit.hp, unit.action])
			if unit.manual_orders != null:
				state.append(unit.manual_orders.pending.duplicate(true))
	state.append(get_nodes_in_group("selected_units"))
	return state


func _details(faction):
	var before = _authority()
	await _point_at(material)
	_check("Materials · 300 M" in _card_text(), faction + ": material stock missing")
	_check("2 work slots" in _card_text(), faction + ": work slots missing")
	material.resource_a = 127
	_check("Materials · 127 M" in _card_text(), faction + ": material stock stale")
	await _point_at(electronics)
	_check("Electronics · 300 E" in _card_text(), faction + ": electronics stock missing")
	await _point_at(aircraft)
	_check("Your forces" in _card_text(), faction + ": aircraft ownership missing")
	await _point_at(wreck)
	_check("Wreck ·" in _card_text(), faction + ": wreck identity missing")
	_check("4 M · expires in 2:58" in _card_text(), faction + ": wreck stock/expiry missing")
	_check(
		("recover materials" in _card_text()) == (faction == "frontier"),
		faction + ": wrong salvage eligibility hint"
	)
	_check(wreck.find_children("*", "Label3D", true, false).is_empty(), "Persistent wreck label")
	_check(
		overlay.markers().all(func(row): return not row.unit.is_in_group("resource_units")),
		"Neutral resource received military marker"
	)
	var options = root.get_node("Globals").options
	var symbols = options.ownership_symbols
	options.ownership_symbols = false
	_check(not overlay.hover_card().is_empty(), "Ownership setting hid resource inspection")
	await _point_at(aircraft)
	_check(overlay.hover_card().is_empty(), "Ownership setting did not hide aircraft caption")
	options.ownership_symbols = symbols
	_check(_authority() == before, faction + ": paused hover changed gameplay")
	_check(wreck.salvage_left == 178.0, faction + ": paused hover advanced expiry")
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hover card captures commands")
	var event = InputEventMouseMotion.new()
	event.position = game.hud._pause_button.get_global_rect().get_center()
	root.push_input(event, true)
	await _frames(3)
	_check(overlay.hover_card().is_empty(), "Resource hover leaked through HUD")


func _visibility(faction):
	var positions = {}
	for unit in get_nodes_in_group("units"):
		if unit.player == human:
			positions[unit] = unit.position
			unit.position = Vector3(3, 0, 3)
	game.battlefield.invalidate()
	for resource in [material, electronics, wreck]:
		# A stale visible flag must never disclose current stock through fog.
		resource.visible = true
		await _point_at(resource)
		_check(not game.battlefield.is_observed(human, resource), "Fog fixture is observed")
		_check(overlay.hover_card().is_empty(), faction + ": hidden resource detail leaked")
		var visibility = game.settings.visibility
		game.settings.visibility = game.settings.Visibility.FULL
		_check(not overlay.hover_card().is_empty(), "Full spectator resource inspection missing")
		game.settings.visibility = visibility
		aircraft.position = resource.position + Vector3(2, 3, 0)
		game.battlefield.invalidate()
		_check(not overlay.hover_card().is_empty(), "New observation did not reveal resource")
		# Revoke the successful observer in the same frame; cached hints must revalidate.
		aircraft.position = Vector3(3, 3, 3)
		_check(overlay.hover_card().is_empty(), "Cached observer leaked withdrawn resource")
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var scout = _units(enemy, "Worker")[0]
	var origin = scout.position
	scout.position = material.position + Vector3(2, 0, 0)
	game.battlefield.invalidate()
	await _point_at(material)
	_check(overlay.hover_card().is_empty(), "Enemy vision leaked into local inspection")
	game.settings.visibility = game.settings.Visibility.ALL_PLAYERS
	_check(not overlay.hover_card().is_empty(), "All-player observer resource details missing")
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	scout.position = origin
	for unit in positions:
		unit.position = positions[unit]
	game.battlefield.invalidate()
	wreck._refresh()


func _lifetime(faction):
	await _point_at(material)
	material.resource_a = 0
	_check(overlay.hover_card().is_empty(), faction + ": depleted material card persists")
	await _frames(3)
	await _point_at(electronics)
	electronics.resource_b = 0
	_check(overlay.hover_card().is_empty(), faction + ": depleted electronics card persists")
	await _frames(3)
	await _point_at(wreck)
	wreck.salvage_left = .05
	paused = false
	await _frames(10)
	paused = true
	_check(not is_instance_valid(wreck), faction + ": expired wreck persists")
	_check(overlay.hover_card().is_empty(), faction + ": expired wreck card persists")


func _archive():
	await _inspection_fixture("frontier")
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Inspection archive capture failed")
	if data == null:
		return
	var ids = [builder._reference(material), builder._reference(wreck)]
	var archive = "user://resource-inspection-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(archive, data), "Inspection archive write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, file.read_file(archive))
	_check(result.ok, "Inspection archive reload failed: " + result.get("error", ""))
	if result.ok:
		game = result.game
		human = game._get_human_player()
		camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		overlay = game.get_node("OwnershipLayer/OwnershipOverlay")
		material = restore.entities[ids[0]]
		wreck = restore.entities[ids[1]]
		_check(paused, "Resource inspection archive resumed")
		await _point_at(material)
		_check("300 M" in _card_text(), "Restored material stock missing")
		await _point_at(wreck)
		_check("4 M · expires in 2:58" in _card_text(), "Restored wreck details changed")
		_check(wreck.find_children("*", "Label3D", true, false).is_empty(), "Restored wreck label")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive))
	paused = false
	game.queue_free()
	await _frames(5)


func _harvesting():
	await _skirmish("frontier", "res://source/match/maps/PlainAndSimple.tscn")
	human = game._get_human_player()
	camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(24)
	overlay = game.get_node("OwnershipLayer/OwnershipOverlay")
	var worker = _units(human, "Worker")[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != worker:
			unit.set_physics_process(false)
	for engineer in _units(human, "Worker"):
		engineer.issue_manual_order(null)
	for deposit in get_nodes_in_group("resource_units"):
		deposit.queue_free()
	await _frames(5)
	var hq = _units(human, "CommandCenter")[0]
	var target_point = hq.global_position_yless + Vector3(5, 0, 2)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for index in range(3):
		var victim = load("res://source/match/units/Tank.tscn").instantiate()
		game._setup_and_spawn_unit(
			victim, Transform3D(Basis(), target_point + Vector3(index * .85, 0, 0)), enemy, false
		)
		await _frames(3)
		victim.hp = 0
	await _frames(5)
	game.hud._toggle_pause()
	var wrecks = get_nodes_in_group("salvage_wrecks")
	_check(wrecks.size() == 3, "Cluster fixture did not create three actual death wrecks")
	_check(
		wrecks.all(func(node): return node.find_children("*", "Label3D", true, false).is_empty()),
		"Cluster retains persistent text labels"
	)
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	wreck = wrecks[0]
	await _point_at(wreck)
	_check(overlay.hover_card().get("unit") == wreck, "Cluster does not inspect pointed wreck")
	_check(overlay.hover_card().get("lines", []).size() == 3, "Cluster merges unrelated wrecks")
	for extra in wrecks.slice(1):
		extra.queue_free()
	await _frames(5)
	worker.position = wreck.position + Vector3(0, 0, .85)
	worker.resource_a = 0
	worker.resource_b = 0
	var funds = human.resource_a
	worker.issue_manual_order(harvest.new(wreck))
	paused = false
	await _frames(80)
	paused = true
	_check(is_instance_valid(wreck), "Partial salvage fixture already depleted")
	if is_instance_valid(wreck):
		# A gathering worker may physically cover its deposit; stock text still reads live state.
		camera.set_position_safely(wreck.position)
		await _point_at(wreck)
		_check(worker.resource_a > 0, "Salvage action did not extract actual cargo")
		_check(
			wreck.resource_a + worker.resource_a + human.resource_a - funds == 4,
			"Inspection changed actual salvage conservation"
		)
		_check(
			("%d M" % wreck.resource_a) in "\n".join(overlay._resource_lines(wreck)),
			"Live inspection differs from harvested stock"
		)
	paused = false
	await _frames(1000)
	paused = true
	_check(human.resource_a == funds + 4, "Inspected salvage did not deliver exactly four M")
	_check(not is_instance_valid(wreck), "Delivered salvage retained its wreck")
	_check(overlay.hover_card().get("unit") != wreck, "Delivered salvage retained its card")
	print("PASS: actual death cluster, partial salvage stock, four-material delivery")
	paused = false
	game.queue_free()
	await _frames(5)
