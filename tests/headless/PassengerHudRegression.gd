extends "res://tests/headless/MechanicsRegression.gd"


class SelectionSession:
	extends RefCounted
	var authority = false
	var applying = false
	var submitted = []

	func id_for(unit):
		return str(unit.get_instance_id())

	func submit_group_member(intent):
		submitted.append(intent)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _open("frontier")
	var rig = _spawn("AdvancedTank", _human, Vector3(42, 0, 42))
	var infantry = []
	for index in 4:
		infantry.append(_spawn("Infantry", _human, Vector3(42, 0, 43)))
	await _frames(20)
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(
			(
				rig._native_state != null
				and infantry.all(func(unit): return unit._native_state != null)
			),
			"Native passenger selection silently used scripted unit state"
		)
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		_check(
			rig.get_node("Movement")._native_runtime != null,
			"Native passenger selection silently used scripted movement"
		)
	var groups = _game.find_child("UnitGroupSelectionHandler")
	_game.hud.select_units(infantry)
	groups.set_group(1)
	await _replica_selection(rig, infantry)
	for index in infantry.size():
		infantry[index].action = load("res://source/match/units/actions/Garrisoning.gd").new(rig)
		_check(rig.enter(infantry[index], index), "Could not fill a firing port")
	await _mounted_selection(rig, infantry, groups)
	_game.hud.select_units([rig])
	await _frames(6)
	var menus = _game.find_child("UnitMenus")
	menus.open_page("Passengers")
	await _frames(3)
	var panel = menus._pages.get_node("Passengers").get_child(0)
	_check(panel.cards.size() == 4, "Passenger console lacks four direct cards")
	_check(
		infantry.all(func(unit): return not unit.is_visible_in_tree()),
		"Passenger card made mounted infantry visible in world"
	)
	var complete = true
	for card in panel.cards:
		complete = (
			complete
			and not card.title.text.is_empty()
			and card.portrait.texture != null
			and not card.price.text.is_empty()
		)
	_check(complete, "Passenger card omitted portrait/name/cost")

	panel.cards[0].unload.pressed.emit()
	await _frames(6)
	panel.refresh()
	_check(rig.occupants.size() == 3, "Direct unload did not release exactly one passenger")
	_check(infantry[0].is_visible_in_tree(), "Released passenger stayed hidden")
	_check(
		get_nodes_in_group("selected_units") == [rig],
		"Unload replaced selected carrier with passenger"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	groups.access_group(1)
	_check(
		_selected_is([rig, infantry[0]]),
		"Mixed unloaded/mounted group did not select the visible infantry and its carrier"
	)
	_game.hud.select_units([rig])
	await _frames(3)
	menus.open_page("Passengers")
	panel = menus._pages.get_node("Passengers").get_child(0)
	panel.unload_all.pressed.emit()
	await _frames(6)
	panel.refresh()
	_check(rig.occupants.is_empty(), "Unload all left passengers in carrier")
	_check(panel.unload_all.disabled, "Empty carrier still offers Unload all")
	_check(get_nodes_in_group("selected_units") == [rig], "Unload all discarded carrier selection")
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Passenger HUD: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _mounted_selection(rig, infantry, groups):
	paused = true
	var clock = _game.simulation_time
	var action = infantry[0].action
	var pending = infantry[0].manual_orders.pending.duplicate(true)
	groups.access_group(1)
	_check(_selected_is([rig]), "Mounted control-group recall selected hidden passengers")
	_check(
		infantry.all(func(unit): return not unit.is_visible_in_tree()),
		"Control-group recall revealed a mounted world body"
	)
	_check(
		infantry.all(func(unit): return unit.is_in_group("unit_group_1")),
		"Recalling cargo rewrote its stored control group"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	infantry[0].get_node("Selection").select()
	_check(_selected_is([rig]), "Direct passenger selection did not resolve to its carrier")
	_game.hud.select_units([rig] + infantry)
	_check(_selected_is([rig]), "Shared cargo produced duplicate or passenger selections")
	_select_all_combat(rig, infantry, groups)
	var enemy_rig = _spawn("AdvancedTank", _enemy, Vector3(65, 0, 65))
	await _frames(3)
	_check(enemy_rig.garrison_mount != null, "Ownership fixture has no carrier mounts")
	root.get_node("MatchSignals").deselect_all_units.emit()
	infantry[0].set_meta("garrison_host", enemy_rig)
	infantry[0].get_node("Selection").select()
	_check(_selected_is([]), "Passenger selection crossed carrier ownership")
	infantry[0].set_meta("garrison_host", rig)
	enemy_rig.queue_free()
	_check(
		infantry[0].action == action and infantry[0].manual_orders.pending == pending,
		"Carrier selection changed a passenger's orders"
	)
	_check(paused and _game.simulation_time == clock, "Mounted recall advanced tactical pause")
	paused = false


func _select_all_combat(rig, infantry, groups):
	var controlled = get_nodes_in_group("controlled_units")
	var worker = controlled.filter(func(unit): return unit.type == "Worker")[0]
	var structure = controlled.filter(func(unit): return unit.type == "CommandCenter")[0]
	for unit in controlled:
		if unit != worker and unit != structure:
			unit.remove_from_group("controlled_units")
	_game.hud.select_units([worker])
	groups.select_all_combat_units()
	_check(_selected_is([worker]), "Empty combat cohort changed the existing selection")
	var tank = _spawn("Tank", _human, Vector3(52, 0, 52))
	groups.select_all_combat_units()
	_check(_selected_is([tank]), "Select All rejected combat units or included workers/structures")
	for unit in [rig] + infantry:
		unit.add_to_group("controlled_units")
	groups.select_all_combat_units()
	_check(_selected_is([tank, rig]), "Select All did not deduplicate mounted cargo to its carrier")
	_check(
		infantry.all(func(unit): return not unit.is_visible_in_tree()),
		"Select All revealed mounted passenger bodies"
	)
	for unit in controlled:
		unit.add_to_group("controlled_units")
	tank.queue_free()
	_game.hud.select_units([rig])


func _replica_selection(rig, infantry):
	paused = true
	var other = _spawn("Infantry", _human, Vector3(50, 0, 50))
	var enemy_rig = _spawn("AdvancedTank", _enemy, Vector3(65, 0, 65))
	await _frames(3)
	var replica = load("res://source/match/network/AuthoritativeReplica.gd").new()
	replica.game = _game
	for index in infantry.size():
		replica.entities[str(index)] = infantry[index]
	var mounted = {"occupants": ["0", "1", "2", "3"], "slots": [0, 1, 2, 3], "evacuating": []}
	var empty = {"occupants": [], "slots": [], "evacuating": []}
	_game.hud.select_units([other, infantry[0], infantry[1]])
	var selected_events = []
	var on_selected = func(unit): selected_events.append(unit)
	root.get_node("MatchSignals").unit_selected.connect(on_selected)
	var session = SelectionSession.new()
	_game.set_meta("network_session", session)
	# Exercise the actual replica patch used for an already selected guest body.
	replica._mount(rig.garrison_mount, mounted)
	_check(
		_selected_is([other, rig]), "Replica mounting retained an independently selected passenger"
	)
	_check(selected_events == [rig], "Replica shared cargo did not deduplicate its host selection")
	_check(
		infantry.all(func(unit): return not unit.is_visible_in_tree()),
		"Replica selection normalization revealed a mounted world body"
	)
	selected_events.clear()
	replica._mount(rig.garrison_mount, mounted)
	_check(
		_selected_is([other, rig]) and selected_events.is_empty(),
		"Repeated replica mount changed the selection or selected an unrequested host"
	)
	replica._mount(rig.garrison_mount, empty)
	_game.hud.select_units([other, infantry[0]])
	selected_events.clear()
	replica._mount(enemy_rig.garrison_mount, {"occupants": ["0"], "slots": [0], "evacuating": []})
	_check(
		_selected_is([other]) and selected_events.is_empty(),
		"Replica selection normalization crossed ownership or discarded unrelated selection"
	)
	replica._mount(enemy_rig.garrison_mount, empty)
	_check(session.submitted.is_empty(), "Authoritative mount selection emitted a remote command")
	_game.remove_meta("network_session")
	root.get_node("MatchSignals").unit_selected.disconnect(on_selected)
	other.queue_free()
	enemy_rig.queue_free()
	paused = false


func _selected_is(expected):
	var selected = get_nodes_in_group("selected_units")
	return selected.size() == expected.size() and expected.all(func(unit): return unit in selected)
