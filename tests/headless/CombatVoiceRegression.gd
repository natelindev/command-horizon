extends "res://tests/headless/SpeechRegression.gd"

const COMBAT_ROLES = [
	"Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero", "Tank",
	"AdvancedTank", "CombatRobot", "Helicopter", "Fighter", "Bomber", "AntiAirVehicle"
]


func _run():
	Engine.physics_ticks_per_second = 60
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "subtitles": true})
	root.get_node("SaveManager").autosaves_enabled = false
	_bank_coverage()
	for faction in ["bastion", "helix", "frontier"]:
		await _setup(faction)
		_attach_voice()
		voice.set_process(false)
		if "--enable-native-kernels" in OS.get_cmdline_user_args():
			var tank = _units(game._get_human_player(), "Tank")[0]
			_check(tank._native_state != null, "Combat voice test did not bind native unit state")
		_hull_warnings()
		await _confirmed_kills()
		await _clean_match()
	preferences.restore(original)
	print("Combat voice: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _bank_coverage():
	var bank = load("res://source/match/audio/UnitVoiceBank.gd").new()
	var clips = []
	var original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	for faction in ["bastion", "helix", "frontier", "mercenary"]:
		var roles = (
			["MercenaryWarden", "MercenaryRanger", "MercenaryLancer"]
			if faction == "mercenary" else COMBAT_ROLES.duplicate()
		)
		if faction == "frontier":
			roles.append("Worker")
		for role in roles:
			var lines = bank.role_lines(faction, role)
			for kind in ["low_health", "kill"]:
				_check(lines.has(kind), "%s:%s missing %s" % [faction, role, kind])
				for line in lines.get(kind, []):
					var stream = load(line.stream)
					_check(
						stream is AudioStreamOggVorbis and stream.get_length() > .5,
						"Combat bark has no playable recording: " + line.stream
					)
					_check(line.speaker_id == faction + "/" + role, "Combat bark changes cast")
					_check(
						TranslationServer.translate(line.text) != line.text,
						"Combat bark lacks its Chinese caption: " + line.text
					)
					_check(not clips.has(line.stream), "Combat roles alias a recording")
					clips.append(line.stream)
	_check(clips.size() == 80, "Expected 80 distinct authored combat clips")
	TranslationServer.set_locale(original_locale)


func _hull_warnings():
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var controller = human.get_node("VoiceNarratorController")
	_reset_speech()
	tank.hp = tank.hp_max * .25
	_check(heard.is_empty(), "Exactly 25 percent hull generated a critical bark")
	voice.say(EVENTS.UNIT_UNDER_ATTACK)
	tank.hp -= 1
	_check(voice.current.get("event") == EVENTS.UNIT_LOW_HEALTH, "Low hull warning missing")
	_check(voice.current.stream.contains("/Tank/low_health_"), "Low hull borrowed an order bark")
	_check(game.subtitles._card.visible, "Critical bark subtitle missing")
	_check(voice._audio.playing and voice._audio.bus == "Voice", "Critical bark not playing")
	for hit in 5:
		voice._process(30)
		tank.hp -= .1
	_check(
		heard.filter(func(line): return line.event == EVENTS.UNIT_LOW_HEALTH).size() == 1,
		"Sustained critical hull spammed unit warnings"
	)
	tank.hp = tank.hp_max * .5
	controller._process(10)
	_reset_speech()
	tank.hp = tank.hp_max * .24
	_check(heard.size() == 1, "Recovered unit did not rearm its low hull warning")
	_reset_speech()
	var enemy = _units(_sides()[1], "Tank")[0]
	enemy.hp = enemy.hp_max * .2
	_check(heard.is_empty(), "Enemy hull state leaked into own radio")
	game.restoring = true
	tank.hp = tank.hp_max
	controller._process(10)
	tank.hp = tank.hp_max * .2
	_check(heard.is_empty(), "Save reconstruction generated a hull report")
	game.restoring = false
	_check(voice._bank.unit_line(tank, "unsupported").is_empty(), "Unknown bark fell back to move")
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	_check(not voice.say_unit(tank, "kill"), "Kill chatter interrupted a base warning")
	voice._spoken_at.clear()
	_check(voice.say_unit(tank, "low_health"), "Critical report failed to queue behind base warning")
	tank.hp = tank.hp_max
	voice._remaining = .1
	voice._process(.2)
	_check(voice.current.is_empty(), "Recovered hull played an obsolete queued warning")


func _confirmed_kills():
	_reset_speech()
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var target = _spawn_weapon("Infantry", _sides()[1], Vector3(40, 0, 30))
	target.shields = 0
	target.receive_damage(tank, target.hp_max * 100)
	_check(voice.current.get("event") == EVENTS.UNIT_KILL_CONFIRMED, "Actual kill lacks confirmation")
	_check(voice.current.stream.contains("/Tank/kill_"), "Kill confirmation borrowed order audio")
	var second = _spawn_weapon("Infantry", _sides()[1], Vector3(41, 0, 30))
	second.shields = 0
	second.receive_damage(tank, second.hp_max * 100)
	_check(heard.size() == 1 and voice._pending.is_empty(), "Multi-kill flooded the radio")
	voice._process(30)
	var third = _spawn_weapon("Infantry", _sides()[1], Vector3(42, 0, 30))
	third.shields = 0
	third.receive_damage(tank, third.hp_max * 100)
	_check(heard.size() == 2, "Kill confirmation did not resume after cooldown")
	_reset_speech()
	var friend = _spawn_weapon("Infantry", human, Vector3(43, 0, 30))
	friend.shields = 0
	friend.receive_damage(tank, friend.hp_max * 100)
	_check(
		not heard.any(func(line): return line.event == EVENTS.UNIT_KILL_CONFIRMED),
		"Friendly fire earned a kill boast"
	)
	await _frames(2)
