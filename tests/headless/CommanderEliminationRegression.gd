extends "res://tests/headless/SaveRestoreEdges.gd"

var _eliminations = []
var _completed = 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"language": "en", "reduced_motion": true, "reduced_flashes": true})
	await _four_player_case()
	await _eight_player_case()
	options.restore(original)
	_check(_completed == 2, "Elimination cases did not finish")
	for message in errors:
		push_error(message)
	print("Commander elimination regression: %d cases, %d failures" % [_completed, errors.size()])
	quit(0 if errors.is_empty() else 1)


func _battle(count):
	paused = false
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	var constants = root.get_node("Constants")
	for index in count:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = "frontier"
		side.color = constants.Player.COLORS[index]
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(10)
	paused = true
	game.set_physics_process(false)
	_eliminations.clear()
	game.player_eliminated.connect(func(player): _eliminations.append(player.get_index()))
	await _frames(3)


func _four_player_case():
	await _battle(4)
	var players = get_nodes_in_group("players")
	var rival = players[1]
	var roster = game.hud.commander_roster
	_check(roster.rows.size() == 4, "Four-player commander list is incomplete")
	_check(roster.rows[players[0]].identity.text.ends_with("You"), "Own commander lacks You marker")
	var names = []
	for player in players:
		names.append(roster.rows[player].identity.text)
		_check(roster.rows[player].status.text == "In battle", "Intact commander marked eliminated")
	_check(names.size() == 4 and names[1] != names[2], "Mirror factions have ambiguous identities")
	# Headquarters loss alone is not elimination. The full rebuild grace remains.
	_units(rival, "CommandCenter")[0].hp = 0
	await _frames(3)
	game._check_outcome(59.75)
	roster.refresh()
	_check(is_equal_approx(game._defeat_timers[rival], .25), "Rebuild grace changed")
	_check(roster.rows[rival].status.text == "In battle", "HQ loss prematurely marked elimination")
	_check(_eliminations.is_empty(), "HQ grace emitted an elimination announcement")
	_check(not roster._announcement.visible, "HQ grace showed an elimination toast")
	# A completed rebuild still resets the timer without announcing elimination.
	var headquarters = load("res://source/match/units/CommandCenter.tscn").instantiate()
	game._setup_and_spawn_unit(headquarters, Transform3D(Basis(), Vector3(50, 0, 50)), rival, false)
	game._check_outcome(0)
	_check(game._defeat_timers[rival] == 60.0, "Completed rebuild failed to reset grace")
	_check(_eliminations.is_empty(), "Successful rebuilding emitted elimination")
	headquarters.hp = 0
	await _frames(3)
	game._check_outcome(60.0)
	await _frames(3)
	_check(not game.finished, "First free-for-all elimination ended the match")
	_check(_eliminations == [1], "Actual elimination was not announced exactly once")
	_check(
		roster.rows[rival].status.text == "Eliminated", "Actual elimination lacks persistent label"
	)
	_check(roster._announcement.visible, "Actual elimination lacks a visible announcement")
	_check(roster._announcement_detail.text == names[1], "Announcement identified the wrong rival")
	_check(
		roster._announcement.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Toast blocks commands"
	)
	var notice_left = roster._announcement_left
	game.hud._open_menu()
	roster._process(2.0)
	_check(not roster._announcement.visible, "Toast covers the pause menu")
	_check(roster._announcement_left == notice_left, "Hidden toast expires behind the pause menu")
	game.hud._close_menu()
	roster._process(0.0)
	_check(roster._announcement.visible, "Closing the menu lost the pending toast")
	_check(not rival.is_processing(), "Eliminated AI is still processing")
	_check(
		rival.get_children().all(func(unit): return not "type" in unit), "Eliminated army survived"
	)
	for index in 3:
		game._check_outcome(1.0)
	_check(_eliminations == [1], "Repeated outcome scans replayed elimination")
	# A paused restore reads the existing persistent state without replaying the event.
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Eliminated-player save failed: " + builder.error)
	if snapshot == null:
		return
	var loaded = await Restore.new().restore(self, snapshot)
	_check(loaded.ok, "Eliminated-player restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	players = get_nodes_in_group("players")
	roster = game.hud.commander_roster
	await _frames(3)
	roster.refresh()
	_check(paused, "Restore released caller pause")
	_check(game._defeat_timers[players[1]] == 0.0, "Restore lost eliminated state")
	_check(roster.rows[players[1]].status.text == "Eliminated", "Restore omitted eliminated label")
	_check(roster._announcements.is_empty(), "Restore queued a duplicate announcement")
	_check(roster._announcement_left <= 0.0, "Restore replayed elimination toast")
	_check(not roster._announcement.visible, "Restore displayed old elimination toast")
	_check(roster.rows[players[1]].identity.text == names[1], "Restore changed commander identity")
	# Elimination is also immediate if the commander has no units at all.
	_eliminations.clear()
	game.player_eliminated.connect(func(player): _eliminations.append(player.get_index()))
	for unit in players[2].get_children():
		if "type" in unit:
			unit.queue_free()
	await _frames(3)
	game._check_outcome(0.0)
	await _frames(3)
	_check(_eliminations == [2], "Empty-army elimination lacks one event")
	_check(roster.rows[players[2]].status.text == "Eliminated", "Empty army remains In battle")
	_check(not game.finished, "Second free-for-all elimination ended the match early")
	root.get_node("Globals").options.restore({"language": "zh_CN"})
	roster.refresh()
	_check(roster.rows[players[1]].status.text == "已淘汰", "Elimination status is not localized")
	_check(roster.rows[players[0]].status.text == "战斗中", "Survivor status is not localized")
	_check(roster._announcement_title.text == "指挥官已淘汰", "Announcement is not localized")
	_check(
		roster.rows[players[1]].identity.accessibility_name.contains("已淘汰"),
		"Accessible commander name omits its status"
	)
	_completed += 1
	print(
		"PASS HQ grace/rebuild, actual and empty-army elimination, one event, paused restore, locale"
	)
	paused = false
	game.queue_free()
	await _frames(5)


func _eight_player_case():
	await _battle(8)
	var players = get_nodes_in_group("players")
	var roster = game.hud.commander_roster
	_check(roster.rows.size() == 8, "Eight-player commander list is incomplete")
	_check(roster.get_v_scroll_bar().visible, "Long commander list cannot scroll")
	_check(
		roster.get_v_scroll_bar().focus_mode == Control.FOCUS_ALL and roster.follow_focus,
		"Long commander list lacks keyboard scrolling"
	)
	roster.scroll_vertical = 10000
	await _frames(3)
	_check(
		roster.get_global_rect().encloses(roster.rows[players[-1]].row.get_global_rect()),
		"Last commander cannot be reached"
	)
	for unit in players[-1].get_children():
		if "type" in unit:
			unit.queue_free()
	await _frames(3)
	game._check_outcome(0.0)
	await _frames(3)
	_check(roster.rows[players[-1]].status.text == "已淘汰", "Last commander lacks eliminated label")
	_check(
		roster._announcement_detail.text.begins_with("8 ·"), "Last announcement misidentifies side"
	)
	_completed += 1
	print("PASS eight-player identity, keyboard scroll, last-row elimination")
	paused = false
	game.queue_free()
	await _frames(5)
