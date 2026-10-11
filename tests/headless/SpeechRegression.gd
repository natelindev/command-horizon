extends "res://tests/headless/SettingsRegression.gd"

const Lines = preload("res://source/match/audio/VoiceLines.gd")
const EVENTS = Lines.EVENTS

var voice
var heard = []


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://speech-options-%d.tres" % OS.get_process_id()
	save_path = "user://speech-battle-%d.json" % OS.get_process_id()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	_storage_speech()
	for faction in ["bastion", "helix"]:
		await _setup(faction)
		_attach_voice()
		_check(voice.current.get("event") == EVENTS.MATCH_STARTED, "Opening line lost before HUD")
		_check(game.subtitles._card.visible, "Opening caption not visible")
		voice.set_process(false)
		_check(await _combat_speech() == true, "Combat speech suite aborted")
		_check(await _routine_speech() == true, "Routine speech suite aborted")
		_check(await _production_speech() == true, "Paid production speech suite aborted")
		_check(await _settings_speech() == true, "Speech settings suite aborted")
		_check(await _restore_speech() == true, "Speech restoration suite aborted")
		_result_speech()
		await _clean_match()
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
	DirAccess.remove_absolute(save_path)
	print("Speech regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _attach_voice():
	voice = game._get_human_player().get_node("BattleVoice")
	voice.caption_changed.connect(
		func(line):
			if not line.is_empty():
				heard.append(line.duplicate())
	)


func _reset_speech():
	voice._clear()
	voice._pending.clear()
	voice._spoken_at.clear()
	voice._ended = false
	heard.clear()


func _storage_speech():
	_check(
		preferences.subtitles and preferences.subtitle_size == 22,
		"Legacy subtitle defaults missing"
	)
	preferences.restore({"screen": 1, "subtitles": "false", "subtitle_size": 999})
	_check(
		preferences.subtitles and preferences.subtitle_size == 22, "Malformed subtitles accepted"
	)
	preferences.subtitles = false
	preferences.subtitle_size = 26
	preferences.apply()
	_check(preferences.persist(archive) == OK, "Speech options failed to save")
	var stored = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(not stored.subtitles and stored.subtitle_size == 26, "Disk lost speech options")
	preferences.restore({"screen": 1, "edge_scrolling": false})
	for event in root.get_node("Constants").Match.VoiceNarrator.EVENT_TO_ASSET_MAPPING:
		_check(
			Lines.TEXT.has(event) and not Lines.TEXT[event].is_empty(),
			"Spoken line lacks transcript"
		)
		_check(
			(
				(
					root
					. get_node("Constants")
					. Match
					. VoiceNarrator
					. EVENT_TO_ASSET_MAPPING[event]
					. get_length()
				)
				> 0
			),
			"Spoken line lacks playable audio"
		)
	print("PASS legacy announcement transcripts, defaults, invalid preferences and persistence")


func _combat_speech():
	_reset_speech()
	var human = game._get_human_player()
	var enemy = _sides()[1]
	var tank = _units(human, "Tank")[0]
	var attacker = _units(enemy, "Infantry")[0]
	var hq = _units(human, "CommandCenter")[0]
	# Generic HP changes and real foundation initialization are not incoming fire.
	tank.hp -= 1
	var building = _spawn_weapon("PowerPlant", human, Vector3(32, 0, 32))
	_check(heard.is_empty(), "HP initialization falsely announced an attack")
	building.queue_free()
	await _frames(2)
	tank.receive_weapon_hit(attacker)
	_check(voice.current.get("event") == EVENTS.UNIT_UNDER_ATTACK, "First real hit was suppressed")
	_check(game.subtitles._card._text.text == "Unit under attack.", "Attack caption mismatch")
	for second in 11:
		voice._process(1.0)
		tank.receive_weapon_hit(attacker)
	_check(
		heard.filter(func(line): return line.event == EVENTS.UNIT_UNDER_ATTACK).size() == 2,
		"Continuous hits starved or spammed attack warnings"
	)
	hq.receive_weapon_hit(attacker)
	_check(
		voice.current.get("event") == EVENTS.BASE_UNDER_ATTACK,
		"Unit attack cooldown suppressed urgent base warning"
	)
	var base_line = voice.current.duplicate()
	root.get_node("MatchSignals").unit_selected.emit(tank)
	root.get_node("MatchSignals").unit_production_finished.emit(tank, hq)
	_check(voice.current == base_line, "Routine speech interrupted base warning")
	_reset_speech()
	var enemy_tank = _units(enemy, "Tank")[0]
	enemy_tank.receive_weapon_hit(tank)
	root.get_node("MatchSignals").unit_selected.emit(enemy_tank)
	root.get_node("MatchSignals").unit_production_finished.emit(
		enemy_tank, _units(enemy, "CommandCenter")[0]
	)
	root.get_node("MatchSignals").unit_construction_finished.emit(_units(enemy, "CommandCenter")[0])
	root.get_node("MatchSignals").not_enough_resources_for_production.emit(enemy)
	_check(heard.is_empty() and voice._pending.is_empty(), "Enemy activity leaked into speech")
	for index in 6:
		var unit = _spawn_weapon("Infantry", human, Vector3(32 + index, 0, 34))
		unit.hp = 0
	await _frames(3)
	_check(
		heard.size() == 1 and voice.current.get("event") == EVENTS.UNIT_LOST,
		"Simultaneous casualties interrupted one another"
	)
	print(
		(
			"PASS %s combat speech: first/sustained/base damage, foundations, casualties, enemy isolation"
			% human.faction
		)
	)
	return true


func _routine_speech():
	_reset_speech()
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	root.get_node("MatchSignals").deselect_all_units.emit()
	paused = true
	var clock = game.simulation_time
	tank.get_node("Selection").select()
	_check(
		voice.current.get("event") == EVENTS.UNIT_HELLO and voice._audio.playing,
		"Paused selection did not start shared speech"
	)
	_check(
		voice.can_process() and voice._audio.can_process(), "Paused speech channel cannot process"
	)
	voice._process(4)
	root.get_node("MatchSignals").terrain_targeted.emit(tank.position + Vector3(3, 0, 0))
	_check(
		voice.current.get("event") in [EVENTS.UNIT_ACK_1, EVENTS.UNIT_ACK_2],
		"Paused order lacked acknowledgement"
	)
	_check(game.simulation_time == clock, "Speech advanced paused simulation")
	voice._process(4)
	_check(
		voice.current.is_empty() and not game.subtitles._card.visible, "Finished subtitle lingered"
	)
	paused = false
	_reset_speech()
	var hq = _units(human, "CommandCenter")[0]
	voice.say(EVENTS.UNIT_UNDER_ATTACK)
	root.get_node("MatchSignals").unit_production_finished.emit(tank, hq)
	root.get_node("MatchSignals").unit_construction_finished.emit(hq)
	root.get_node("MatchSignals").not_enough_resources_for_production.emit(human)
	for index in 20:
		root.get_node("MatchSignals").unit_production_finished.emit(tank, hq)
	_check(voice._pending.size() == 3, "Repeated production grew speech backlog")
	voice._process(3)
	_check(voice.current.get("event") == EVENTS.NOT_ENOUGH_RESOURCES, "Pending priority failed")
	voice._process(10)
	_check(voice._pending.is_empty() and voice.current.is_empty(), "Stale queued lines played late")
	_reset_speech()
	for event in Lines.TEXT:
		_reset_speech()
		if event in Lines.UNIT_EVENTS:
			_check(not voice.say(event), "Sourceless unit reply used an announcer")
			_check(heard.is_empty(), "Rejected unit event still played audio")
			continue
		_check(voice.say(event), "Mapped spoken line was rejected")
		_check(
			(
				voice.current.text == Lines.TEXT[event]
				and game.subtitles._card._text.text == Lines.TEXT[event]
			),
			"Published subtitle did not match accepted speech"
		)
	_reset_speech()
	print(
		"PASS paused orders, shared channel, bounded priority/repeat/stale queue and every transcript"
	)
	return true


func _settings_speech():
	_reset_speech()
	voice.set_process(true)
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	var before = preferences.capture()
	preferences.master_volume = 0
	preferences.voice_volume = 0
	preferences.subtitle_size = 26
	preferences.apply()
	_check(
		(
			game.subtitles._card.visible
			and game.subtitles._card._text.get_theme_font_size("font_size") == 26
		),
		"Muted audio hid or failed to resize subtitles"
	)
	preferences.subtitles = false
	preferences.apply()
	_check(not game.subtitles._card.visible, "Disabling subtitles left visible text")
	preferences.subtitles = true
	preferences.apply()
	var dialog = root.get_node("Globals").open_settings()
	dialog.save_path = archive
	var time_left = voice._remaining
	var clock = game.simulation_time
	await _frames(12)
	_check(
		(
			not voice.can_process()
			and not voice._audio.can_process()
			and voice._remaining == time_left
		),
		"Settings froze audio but advanced caption lifetime"
	)
	_check(game.simulation_time == clock, "Speech settings advanced battle")
	dialog._preview("subtitle_size", 18)
	dialog._preview("subtitles", false)
	dialog.save_path = "user://speech-missing-%d/options.tres" % OS.get_process_id()
	dialog._finish(true)
	_check(
		(
			is_instance_valid(dialog)
			and "Could not save" in dialog._status.text
			and preferences.subtitle_size == 18
			and not preferences.subtitles
		),
		"Failed subtitle save discarded preview or closed recovery"
	)
	dialog._finish(false)
	await _frames(2)
	_check(preferences.subtitles and preferences.subtitle_size == 26, "Cancel lost speech rollback")
	_check(voice.can_process(), "Closing settings failed to restore speech processing")
	preferences.restore(before)
	voice.set_process(false)
	print("PASS muted captions, live text sizing, disable/enable, modal freeze and Cancel rollback")
	return true


func _restore_speech():
	_reset_speech()
	var human = game._get_human_player()
	_units(human, "Tank")[0].hp -= 5
	paused = true
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Speech archive capture failed: " + snapshot.error)
	if data == null:
		return false
	var store = FileStore.new()
	_check(store.write_file(save_path, data), "Speech archive write failed: " + store.error)
	var loaded = store.read_file(save_path)
	var result = await Restore.new().restore(self, loaded)
	_check(result.ok, "Speech archive restore failed: " + result.get("error", ""))
	game = current_scene
	_attach_voice()
	await _frames(3)
	_check(
		voice.current.is_empty() and voice._pending.is_empty() and not voice._audio.playing,
		"Restoration replayed startup, HP, production or selection speech"
	)
	_check(not game.subtitles._card.visible, "Restoration retained old subtitle")
	voice.set_process(false)
	_reset_speech()
	game.hud._toggle_pause()
	for side in get_nodes_in_group("players"):
		if side != game._get_human_player():
			side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(8)
	_check(heard.is_empty(), "Deferred restoration speech leaked after resume")
	print(
		"PASS actual disk restoration omits transient speech and suppresses reconstruction events"
	)
	return true


func _result_speech():
	_reset_speech()
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	game.result = "Victory"
	game.finished = true
	game.hud.show_result("Victory")
	_check(
		(
			voice.current.get("event") == EVENTS.MATCH_FINISHED_WITH_VICTORY
			and voice._pending.is_empty()
		),
		"Playable result did not preempt speech"
	)
	voice.say(EVENTS.UNIT_LOST)
	voice.say(EVENTS.UNIT_PRODUCTION_FINISHED)
	voice._process(5)
	_check(
		voice.current.is_empty() and voice._pending.is_empty(), "Post-result activity was spoken"
	)
	_reset_speech()
	voice.finish("Defeat")
	_check(voice.current.get("event") == EVENTS.MATCH_FINISHED_WITH_DEFEAT, "Defeat line missing")
	_reset_speech()
	voice.say(EVENTS.UNIT_LOST)
	voice.finish("Draw")
	_check(voice.current.is_empty() and voice._ended, "Draw falsely announced victory/defeat")
	print("PASS playable result priority, terminal latch and silent draw")


func _production_speech():
	_reset_speech()
	var human = game._get_human_player()
	var hq = _units(human, "CommandCenter")[0]
	var queue = hq.get_node("ProductionQueue")
	var before_count = _units(human, "Worker").size()
	var materials = human.resource_a
	var job = queue.produce(load("res://source/match/units/Worker.tscn"))
	_check(
		job != null and human.resource_a < materials, "Paid voice production did not reserve cost"
	)
	if job == null:
		return false
	_check(
		voice.current.get("event") == EVENTS.UNIT_PRODUCTION_STARTED,
		"Paid queue lacked training line"
	)
	queue._process(job.time_left)
	voice._process(3)
	_check(
		(
			_units(human, "Worker").size() == before_count + 1
			and voice.current.get("event") == EVENTS.UNIT_PRODUCTION_FINISHED
		),
		"Actual completed production lacked unit-ready line"
	)
	await _frames(2)
	print("PASS actual paid production emits Training and Unit ready with shared subtitles")
	return true
