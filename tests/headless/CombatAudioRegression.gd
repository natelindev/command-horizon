extends "res://tests/headless/SettingsRegression.gd"

var combat_audio
var cues = []


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://combat-audio-options-%d.tres" % OS.get_process_id()
	save_path = "user://combat-audio-battle-%d.json" % OS.get_process_id()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	await _audio_settings()
	for faction in ["bastion", "helix"]:
		await _setup(faction)
		combat_audio = game.combat_audio
		combat_audio.cue_started.connect(func(kind, _point): cues.append(kind))
		await _actual_combat(faction)
		await _variants_and_rockets()
		await _audibility()
		await _audio_lifecycle()
		await _audio_restore()
		await _clean_match()
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
	DirAccess.remove_absolute(save_path)
	print("Combat audio regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _audio_settings():
	_check(preferences.effects_volume == 0.75, "Legacy effects default missing")
	preferences.effects_volume = 0.3
	preferences.apply()
	var bus = AudioServer.get_bus_index("Effects")
	_check(bus > 0, "Effects bus missing")
	_check(
		is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.3),
		"Effects gain ignored"
	)
	_check(preferences.persist(archive) == OK, "Effects preference write failed")
	_check(
		is_equal_approx(
			ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE).effects_volume, 0.3
		),
		"Effects preference not persisted"
	)
	preferences.restore({"screen": 1, "effects_volume": INF})
	_check(preferences.effects_volume == 0.75, "Nonfinite effects preference accepted")
	preferences.restore({"screen": 1, "effects_volume": "bad"})
	_check(preferences.effects_volume == 0.75, "Invalid effects preference accepted")
	for _index in range(3):
		preferences.apply()
	_check(AudioServer.get_bus_effect_count(bus) == 1, "Effects limiter duplicated")
	_check(AudioServer.get_bus_effect_count(0) == 1, "Master limiter duplicated")
	for kind in load("res://source/match/audio/CombatAudio.gd").CUES:
		var stream = load("res://assets/audio/combat/%s.wav" % kind)
		_check(stream != null and stream.get_length() > 0.05, "Missing audio: " + kind)
	print(
		"PASS playable effects assets, persistent/bounded gain, legacy defaults and unique limiters"
	)


func _actual_combat(faction):
	cues.clear()
	shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	var sides = _sides()
	var shooter = _spawn_weapon("Tank", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(44, 0, 10))
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(42, 0, 10))
	camera.set_size_safely(28)
	await _frames(40)
	shooter.global_position = Vector3(40, 0, 10)
	target.global_position = Vector3(44, 0, 10)
	game.battlefield.invalidate()
	var hp = target.hp
	shooter.process_mode = Node.PROCESS_MODE_PAUSABLE
	shooter.issue_manual_order(shooting.new(target, 1))
	await _frames(80)
	shooter.process_mode = Node.PROCESS_MODE_DISABLED
	_check(target.hp < hp, "Actual attack did not hit")
	_check(
		cues.has("energy_fire" if faction == "helix" else "cannon_fire"),
		"Actual shot lacks faction cue"
	)
	_check(cues.has("impact_heavy"), "Actual hit lacks impact")
	for role in ["Infantry", "Tank", "CommandCenter"]:
		var victim = _spawn_weapon(role, sides[1], Vector3(44, 0, 10))
		await _frames(3)
		victim.global_position = Vector3(44, 0, 10)
		game.battlefield.invalidate()
		victim.hp = 1
		victim.receive_weapon_hit(shooter)
		await _frames(8)
	for cue in ["infantry_fall", "vehicle_destroy", "structure_destroy"]:
		_check(cues.has(cue), "Actual death lacks " + cue)
	print("PASS actual %s projectile, hit, infantry/vehicle/structure destruction" % faction)


func _audibility():
	var sides = _sides()
	var enemy = _units(sides[1], "CommandCenter")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(enemy.global_position)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(sides[0], enemy), "Fog fixture is observed")
	enemy.visible = true  # A remembered visual must not grant actual auditory observation.
	_check(not combat_audio.shot(enemy, enemy.global_position), "Hidden enemy shot leaked")
	_check(not combat_audio.destruction(enemy), "Hidden enemy destruction leaked")
	var own = _units(sides[0], "Tank")[0]
	_check(not combat_audio.shot(own, own.global_position), "Offscreen shot leaked")
	camera.set_position_safely(own.global_position)
	combat_audio._recent.clear()
	_check(combat_audio.shot(own, own.global_position), "Observed nearby shot was silent")
	_check(not combat_audio.shot(own, own.global_position), "Rapid identical cue was not merged")
	var played = combat_audio.played_count
	game.restoring = true
	combat_audio.destruction(own)
	game.restoring = false
	_check(combat_audio.played_count == played, "Restoration emitted combat audio")
	paused = true
	# Audio synchronizes on render frames; catch-up physics ticks may share one frame.
	await process_frame
	await process_frame
	combat_audio.shot(own, own.global_position)
	_check(combat_audio.played_count == played, "Paused battle generated sound")
	for entry in combat_audio._players:
		if entry.active:
			_check(
				(
					entry.node.stream_paused
					or (not entry.node.can_process() and entry.node.get_playback_position() == 0.0)
				),
				"Tactical pause did not pause active/pending combat audio"
			)
	paused = false
	await _frames(2)
	preferences.effects_volume = 0
	preferences.apply()
	_check(
		AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "Effects zero is not muted"
	)
	_check(not combat_audio.shot(own, own.global_position), "Muted effects created a new voice")
	for entry in combat_audio._players:
		_check(not entry.active, "Mute left active effects")
	preferences.effects_volume = 0.75
	preferences.apply()
	print(
		"PASS current observation/offscreen filters, merge, restoration suppression and pause/mute"
	)


func _audio_lifecycle():
	var human = game._get_human_player()
	var own = _units(human, "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(own.global_position)
	combat_audio._recent.clear()
	combat_audio.destruction(own)
	var dialog = root.get_node("Globals").open_settings()
	dialog.save_path = archive
	await _frames(2)
	dialog._preview("effects_volume", 0.2)
	_check(dialog._effects_sample.bus == "Effects", "Settings sample bypasses Effects bus")
	dialog._effects_sample.play()
	_check(dialog._effects_sample.playing, "Settings sample does not play")
	dialog._finish(false)
	await _frames(2)
	_check(preferences.effects_volume == 0.75, "Cancel did not restore Effects gain")
	# Distinct simultaneous sources pressure the shared pool. Deaths can replace shots.
	game.settings.visibility = game.settings.Visibility.FULL
	camera.set_size_safely(60)
	camera.set_position_safely(Vector3(40, 0, 32))
	combat_audio._recent.clear()
	for z in range(5):
		for x in range(8):
			combat_audio.shot(own, Vector3(18 + x * 6, 0, 20 + z * 6))
	_check(combat_audio._players.size() == 24, "Burst fixture failed to fill bounded pool")
	_check(combat_audio.dropped_count > 0, "Burst failed to apply overload policy")
	own.global_position = Vector3(40, 0, 32)
	combat_audio._recent.clear()
	_check(combat_audio.destruction(own), "Destruction lost to saturated shot pool")
	_check(combat_audio._players.size() == 24, "Audio pool exceeded cap")
	game.finished = true
	_check(not combat_audio.shot(own, own.global_position), "Ended battle creates shots")
	paused = true
	# Audio synchronizes on render frames; catch-up physics ticks may share one frame.
	await process_frame
	await process_frame
	var destruction_tail_continues = false
	for entry in combat_audio._players:
		if entry.active and entry.priority == 3 and not entry.node.stream_paused:
			destruction_tail_continues = true
	_check(destruction_tail_continues, "Battle result cut off an accepted destruction tail")
	paused = false
	game.finished = false
	print(
		"PASS Settings sample/Cancel, saturated 24-voice cap, destruction priority and finished gate"
	)


func _audio_restore():
	# Save while an effect is active; only authoritative battle state may return.
	var own = _units(game._get_human_player(), "Tank")[0]
	own.hp -= 3
	combat_audio._recent.clear()
	combat_audio.destruction(own)
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Audio archive capture failed: " + builder.error)
	if data == null:
		return
	var store = FileStore.new()
	_check(store.write_file(save_path, data), "Audio archive write failed: " + store.error)
	var result = await Restore.new().restore(self, store.read_file(save_path))
	_check(result.ok, "Audio archive restore failed: " + result.get("error", ""))
	game = current_scene
	combat_audio = game.combat_audio
	await _frames(3)
	_check(
		combat_audio.played_count == 0 and combat_audio._players.is_empty(),
		"Archive replayed transient effects"
	)
	for side in get_nodes_in_group("players"):
		if side != game._get_human_player():
			side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	await _frames(8)
	_check(combat_audio.played_count == 0, "Deferred restore events emitted effects")
	print(
		"PASS damaged battle disk save/load omits active sounds and resumes without reconstruction audio"
	)


func _variants_and_rockets():
	var sides = _sides()
	var own = _units(sides[0], "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(own.global_position)
	var previous = null
	for _index in range(8):
		combat_audio._recent.clear()
		_check(combat_audio.shot(own, own.global_position), "Variant shot was dropped")
		var kind = combat_audio.weapon_cue(own)
		var selected = combat_audio._streams[kind][combat_audio._last_variant[kind]]
		_check(selected != previous, "Weapon repeated the same sample take")
		previous = selected
		for entry in combat_audio._players:
			entry.node.stop()
			entry.active = false
	var rocket = _spawn_weapon("RocketInfantry", sides[0], own.global_position + Vector3.RIGHT)
	combat_audio._recent.clear()
	combat_audio.impact(own, rocket, own.global_position)
	_check(cues.back() == "impact_heavy", "Rocket infantry still has light impact audio")
	rocket.queue_free()
	await _frames(2)
	print("PASS nonrepeating sample variants and rocket explosive impact")
