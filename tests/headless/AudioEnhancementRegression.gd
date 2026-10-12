extends "res://tests/headless/SpeechRegression.gd"

const Bank = preload("res://source/match/audio/UnitVoiceBank.gd")
const Roster = preload("res://source/match/BastionCatalog.gd")
var announcer_paths = []


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	_catalog_coverage()
	for faction in ["bastion", "helix", "frontier"]:
		await _setup(faction)
		_attach_voice()
		voice.set_process(false)
		announcer_paths.append(voice._audio.stream.resource_path)
		_check(voice.current.speaker != "Command", "Faction announcer lacks identity")
		await _identity_and_bursts(faction)
		_all_unit_speakers(faction)
		await _research_events()
		await _power_transitions()
		await _mechanical_and_lifecycle()
		await _clean_match()
	_check(
		(
			announcer_paths.size() == 3
			and announcer_paths[0] != announcer_paths[1]
			and announcer_paths[1] != announcer_paths[2]
			and announcer_paths[0] != announcer_paths[2]
		),
		"Faction announcers share a recording"
	)
	await _ui_events()
	preferences.restore(original)
	print("Audio enhancement regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _catalog_coverage():
	var bank = Bank.new()
	var count = 0
	for faction in ["bastion", "helix", "frontier"]:
		var catalog = bank._catalog[faction]
		for event in Lines.TEXT:
			if event in Lines.UNIT_EVENTS:
				_check(
					bank.announcer(faction, Lines.EVENTS.find_key(event)).is_empty(),
					"Unit reply leaked into announcer bank"
				)
				continue
			_check(
				not bank.announcer(faction, Lines.EVENTS.find_key(event)).is_empty(),
				faction + " missing announcer event"
			)
		var roles = Roster.NAMES.keys() + Roster.MISSION_NAMES.keys()
		for role in roles:
			_check(catalog.units.has(role), faction + " missing voice role " + role)
			for kind in ["select", "move", "attack", "ready", "stop"]:
				_check(catalog.units[role].has(kind), faction + ":" + role + " missing " + kind)
		for line in catalog.announcer.values():
			_check_clip(line)
			count += 1
		for role in catalog.units.values():
			for variants in role.values():
				for line in variants:
					_check_clip(line)
					count += 1
	print(
		(
			"PASS %d playable clips, every faction, unit, structure, mission transport and announcer event"
			% count
		)
	)


func _check_clip(line):
	var stream = load(line.stream)
	_check(
		stream is AudioStreamOggVorbis and stream.get_length() > 0.03 and stream.get_length() < 8,
		"Invalid clip " + line.stream
	)
	_check(not line.text.is_empty(), "Clip lacks matching caption " + line.stream)
	_check(not line.get("speaker_id", "").is_empty(), "Clip lacks cast identity")


func _all_unit_speakers(faction):
	var human = game._get_human_player()
	var bank = voice._bank._catalog[faction]
	var identities = []
	for role in bank.units:
		var unit
		if role in Roster.MISSION_NAMES:
			# Mission transports retain their authored geometry, outside skirmish models.
			unit = load("res://source/match/units/%s.tscn" % role).instantiate()
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			human.add_child(unit)
		else:
			unit = _spawn_weapon(role, human, Vector3(50, 0, 50))
		var identity = ""
		for kind in bank.units[role]:
			_reset_speech()
			_check(voice.say_unit(unit, kind), role + ":" + kind + " rejected")
			var line = voice.current
			_check(not line.stream.contains("/Command/"), "Unit borrowed announcer audio")
			if identity.is_empty():
				identity = line.speaker_id
			_check(line.speaker_id == identity, "Unit changed speaker between events")
			_check(game.subtitles._card._text.text == line.text, "Unit caption mismatch")
		_check(not identity in identities, "Two unit types share a cast identity")
		_check(identity != bank.announcer.MATCH_STARTED.speaker_id, "Unit uses announcer")
		identities.append(identity)
		_reset_speech()
		unit.free()
	for event in Lines.UNIT_EVENTS:
		_reset_speech()
		_check(not voice.say(event), "Sourceless reply reached announcer")
		_check(heard.is_empty() and voice._pending.is_empty(), "Sourceless reply was scheduled")
	print("PASS %s all unit/event identities, captions and exclusive announcer routing" % faction)


func _identity_and_bursts(faction):
	_reset_speech()
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var infantry = _units(human, "Infantry")[0]
	var signals = root.get_node("MatchSignals")
	signals.unit_selected.emit(tank)
	var first = voice.current.duplicate()
	_check(
		first.speaker == load("res://source/match/FactionCatalog.gd").title(faction, "Tank"),
		"Wrong unit speaker"
	)
	_check(first.stream.contains("/%s/Tank/select_" % faction), "Selection uses generic voice")
	for index in 100:
		signals.unit_selected.emit(infantry if index % 2 else tank)
		signals.unit_order_issued.emit(infantry, "attack")
	_check(
		heard.size() == 1 and voice._pending.is_empty(),
		"Mixed selection/order burst flooded speech"
	)
	voice._process(5)
	signals.unit_selected.emit(tank)
	_check(
		voice.current.stream != first.stream,
		"Suppressed selections advanced/repeated the voice variant"
	)
	voice._process(5)
	var order = load("res://source/match/orders/ManualOrders.gd").point_order(
		"attack_move", Vector3(35, 0, 35)
	)
	tank.manual_orders.submit(order)
	_check(
		voice.current.stream.contains("/Tank/attack_"), "Accepted attack-move lacks attack reply"
	)
	_reset_speech()
	tank.manual_orders.cancel()
	tank.manual_orders.submit(order, false, false)
	_check(heard.is_empty(), "Automatic rally movement generated chatter")
	for index in tank.manual_orders.LIMIT:
		tank.manual_orders.submit(order, true, false)
	_check(
		not tank.manual_orders.submit(order, true) and heard.is_empty(),
		"Rejected full queue was acknowledged"
	)
	tank.manual_orders.cancel()
	_reset_speech()
	for unit in [tank, infantry]:
		signals.unit_production_finished.emit(unit, _units(human, "CommandCenter")[0])
	_check(
		heard.size() == 1 and voice._pending.is_empty(),
		"Mixed production batch was not deduplicated"
	)
	_check(voice.current.stream.contains("/Tank/ready_"), "Unit ready used generic announcer")
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	_check(
		voice.current.event == EVENTS.BASE_UNDER_ATTACK and voice._audio.bus == "Voice",
		"Urgent warning failed to interrupt unit channel"
	)
	for index in 80:
		signals.unit_selected.emit(tank)
		signals.unit_order_issued.emit(tank, "move")
	_check(
		voice.current.event == EVENTS.BASE_UNDER_ATTACK and voice._pending.is_empty(),
		"Chatter interrupted or queued behind urgent warning"
	)
	_reset_speech()
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	for event in [
		EVENTS.UNIT_LOST,
		EVENTS.UNIT_UNDER_ATTACK,
		EVENTS.RESEARCH_COMPLETED,
		EVENTS.UNIT_PRODUCTION_FINISHED,
		EVENTS.UNIT_CONSTRUCTION_FINISHED,
		EVENTS.LOW_POWER
	]:
		voice.say(event)
	_check(voice._pending.size() <= voice.MAX_PENDING, "Notification queue exceeded its cap")
	voice._process(10)
	_check(
		voice.current.is_empty() and voice._pending.is_empty(),
		"Expired messages played after a burst"
	)
	print(
		(
			"PASS %s unit identities, mixed bursts, accepted orders, rally silence and alert priority"
			% faction
		)
	)


func _research_events():
	_reset_speech()
	var human = game._get_human_player()
	var enemy = _sides()[1]
	var lab = _units(human, "CommandLab")[0]
	human.resource_a = 500
	human.resource_b = 500
	_check(human.technology.start("weapons_1", lab), "Could not start paid research")
	human.technology._physics_process(1000)
	_check(
		(
			"weapons_1" in human.technology.completed
			and voice.current.get("event") == EVENTS.RESEARCH_COMPLETED
		),
		"Actual research completion was silent"
	)
	_check(
		voice._audio.stream.resource_path.contains("/Command/RESEARCH_COMPLETED"),
		"Research lacks faction announcer"
	)
	_reset_speech()
	human.coordination_unlocked = false
	human.coordination_left = -1
	_check(human.start_coordination(lab), "Could not start paid Coordination")
	human._physics_process(1000)
	_check(
		human.coordination_unlocked and voice.current.get("event") == EVENTS.RESEARCH_COMPLETED,
		"Coordination completion was silent"
	)
	_reset_speech()
	root.get_node("MatchSignals").research_completed.emit(enemy, "weapons_1")
	_check(heard.is_empty(), "Enemy research leaked to player")
	game.restoring = true
	root.get_node("MatchSignals").research_completed.emit(human, "weapons_1")
	root.get_node("MatchSignals").unit_selected.emit(lab)
	_check(heard.is_empty(), "Restore reconstruction generated audio")
	game.restoring = false
	print(
		"PASS real paid technology/Coordination completion, enemy isolation and restore suppression"
	)


func _power_transitions():
	var human = game._get_human_player()
	var narrator = human.get_node("VoiceNarratorController")
	for plant in _units(human, "PowerPlant"):
		plant.hp = 0
	var factory = _spawn_weapon("AircraftFactory", human, Vector3(40, 0, 30))
	factory.construct(1.0)
	await _frames(3)
	_reset_speech()
	narrator._power_check_left = 0
	narrator._process(.1)
	_check(voice.current.get("event") == EVENTS.LOW_POWER, "Low-power transition was silent")
	for index in 50:
		narrator._power_check_left = 0
		narrator._process(.1)
	_check(heard.size() == 1, "Persistent low power spammed speech")
	# The advanced base plus airfield consumes 25; HQ + one plant supplies 20.
	for index in 2:
		var restored = _spawn_weapon("PowerPlant", human, Vector3(40 + index * 7, 0, 35))
		restored.construct(1.0)
	_check(human.production_factor() == 1.0, "Power recovery fixture remains underpowered")
	_reset_speech()
	narrator._power_check_left = 0
	narrator._process(.1)
	_check(voice.current.get("event") == EVENTS.POWER_RESTORED, "Power recovery was silent")
	_reset_speech()
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	_check(not voice.say(EVENTS.UNIT_LOST), "Lesser warning bypassed shared danger cooldown")
	voice.say(EVENTS.LOW_POWER)
	voice.say(EVENTS.POWER_RESTORED)
	_check(
		voice._pending.size() == 1 and voice._pending[0].event == EVENTS.POWER_RESTORED,
		"Contradictory power states queued together"
	)
	print("PASS power state cues, suppression, obsolete-state replacement and danger budget")


func _mechanical_and_lifecycle():
	_reset_speech()
	var human = game._get_human_player()
	var robot = _spawn_weapon("RepairRobot", human, Vector3(32, 0, 32))
	root.get_node("MatchSignals").unit_selected.emit(robot)
	_check(
		voice.current.get("mechanical", false) and voice._audio.bus == "Effects",
		"Autonomous machine was voiced as a person"
	)
	_check(voice.current.text.begins_with("["), "Machine subtitle invents spoken dialogue")
	_reset_speech()
	var building = _units(human, "CommandCenter")[0]
	root.get_node("MatchSignals").unit_selected.emit(building)
	_check(
		voice.current.get("mechanical", false) and voice.current.stream.contains("CommandCenter"),
		"Structure selection is silent/generic"
	)
	_reset_speech()
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	root.get_node("MatchSignals").unit_production_finished.emit(robot, building)
	robot.queue_free()
	await _frames(2)
	voice._process(4)
	_check(voice.current.is_empty(), "Dead unit played queued ready response")
	_reset_speech()
	voice.finish("Victory")
	_check(
		not voice.say_unit(building, "select") and not voice.say(EVENTS.RESEARCH_COMPLETED),
		"Terminal result accepted new audio"
	)
	print("PASS machine/building effects, honest captions, dead-source expiry and terminal latch")


func _ui_events():
	var ui = root.get_node("UIAudio")
	var panel = Control.new()
	root.add_child(panel)
	var button = Button.new()
	button.text = "Audio test"
	panel.add_child(button)
	var toggle = CheckButton.new()
	panel.add_child(toggle)
	var slider = HSlider.new()
	panel.add_child(slider)
	await _frames(2)
	ui._last_played = -1000
	var before = ui.played_count
	button.pressed.emit()
	for index in 100:
		button.pressed.emit()
	_check(ui.played_count == before + 1, "UI click burst was not deduplicated")
	ui._last_played = -1000
	button.disabled = true
	button.pressed.emit()
	button.disabled = false
	button.hide()
	button.pressed.emit()
	_check(ui.played_count == before + 1, "Disabled/hidden UI made click sounds")
	button.show()
	ui._last_played = -1000
	toggle.set_pressed_no_signal(true)
	slider.value = 50
	_check(ui.played_count == before + 1, "Programmatic UI refresh made sounds")
	toggle.pressed.emit()
	_check(ui.played_count == before + 2, "Toggle lacks selection sound")
	ui._last_played = -1000
	var event = InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.pressed = true
	slider.gui_input.emit(event)
	_check(ui.played_count == before + 3, "Keyboard slider lacks feedback")
	ui._last_played = -1000
	preferences.effects_volume = 0
	preferences.apply()
	button.pressed.emit()
	_check(ui.played_count == before + 3 and not ui._player.playing, "Muted UI still played")
	preferences.effects_volume = 0.75
	preferences.apply()
	panel.queue_free()
	await _frames(2)
	print("PASS UI inputs, burst limits, disabled controls, quiet refresh and mute")
