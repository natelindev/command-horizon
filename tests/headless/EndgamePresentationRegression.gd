extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{"screen": 1, "hud_motion": true, "reduced_flashes": false, "edge_scrolling": false}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.set_physics_process(false)
	var human = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var enemy_hq = _units(opponent, "CommandCenter")[0]
	var human_hq = _units(human, "CommandCenter")[0]
	var presentation = game.get_node("BattlePresentation")
	var camera = game.get_node("IsometricCamera3D")
	var starting_transform = camera.global_transform
	_check(not presentation.inspect_battlefield(), "Inspection disclosed an ongoing match")
	_check(not presentation.can_present_collapse(human_hq), "Friendly HQ triggered enemy climax")
	enemy_hq.hide()
	_check(
		not presentation.can_present_collapse(enemy_hq),
		"Unseen HQ collapse disclosed a hidden base"
	)
	game.settings.visibility = game.settings.Visibility.FULL
	enemy_hq.show()
	_check(
		presentation.can_present_collapse(enemy_hq), "Visible enemy HQ did not qualify for climax"
	)
	Engine.time_scale = .8
	_check(
		presentation.begin_collapse(enemy_hq.global_position), "Collapse presentation did not start"
	)
	_check(
		is_equal_approx(Engine.time_scale, .24),
		"Cinematic did not retain the previous simulation speed"
	)
	presentation._process(.24)
	_check(camera.global_transform != starting_transform, "Collapse did not drift the camera")
	paused = true
	presentation._process(.01)
	_check(not presentation.cinematic and paused, "Canceling climax changed tactical pause")
	_check(is_equal_approx(Engine.time_scale, .8), "Pause leaked the cinematic time scale")
	_check(
		camera.global_transform.is_equal_approx(starting_transform),
		"Pause lost original camera transform"
	)
	paused = false
	Engine.time_scale = 1.0
	options.reduced_flashes = true
	_check(
		not presentation.begin_collapse(enemy_hq.position),
		"Reduced flashes ignored cinematic motion"
	)
	options.reduced_flashes = false
	options.hud_motion = false
	_check(
		not presentation.begin_collapse(enemy_hq.position),
		"Reduced motion ignored cinematic motion"
	)
	options.hud_motion = true
	presentation.begin_collapse(enemy_hq.position)
	presentation._process(.3 * presentation.COLLAPSE_SECONDS)
	_check(
		not presentation.cinematic and Engine.time_scale == 1.0,
		"Climax did not finish after 2.5 real seconds"
	)
	_check(
		not game.finished and game._defeat_timers[opponent] > 0, "Climax bypassed HQ rebuild grace"
	)
	await _music_response(human, opponent)
	_music_speech(human)
	await _save_lifecycle(presentation, enemy_hq.position)
	presentation = game.get_node("BattlePresentation")
	# Inspecting never resumes battles, even when camera input is active.
	game.finished = true
	game.result = "Victory"
	game.hud.show_result("Victory")
	var simulation_before = game.simulation_time
	var resources_before = game._get_human_player().resource_a
	var inspector = game.hud._overlay.find_child("InspectBattlefieldButton", true, false)
	_check(inspector != null and not inspector.disabled, "Results lack inspection action")
	inspector.pressed.emit()
	_check(
		presentation.inspecting and paused and not game.fog_of_war.visible,
		"Inspection did not freeze/reveal battlefield"
	)
	_check(not game.get_node("HUD").visible, "Inspection left interactive battle HUD visible")
	_check(
		not game.hud._overlay.get_child(0).visible,
		"Results canvas still covers inspected battlefield"
	)
	await _frames(15)
	_check(game.simulation_time == simulation_before, "Inspection advanced the ended simulation")
	_check(
		game._get_human_player().resource_a == resources_before,
		"Inspection changed the final economy"
	)
	presentation.show_results()
	_check(not presentation.inspecting and paused, "Returning to results resumed combat")
	_check(
		game.hud._overlay.get_child(0).visible, "Returning to results did not restore its canvas"
	)
	# Restart frees the presentation while preserving no global cinematic state.
	game.finished = false
	paused = false
	presentation.begin_collapse(Vector3(30, 0, 30))
	game.restart()
	await _frames(10)
	_check(Engine.time_scale == 1.0, "Restart inherited cinematic slow motion")
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Endgame presentation regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _save_lifecycle(presentation, point):
	presentation.begin_collapse(point)
	paused = true
	var snapshot = Snapshot.new()
	var saved = snapshot.capture(game)
	_check(saved != null, "Cinematic prevented a valid battle save: " + snapshot.error)
	_check(
		not presentation.cinematic and Engine.time_scale == 1.0,
		"Save captured temporary cinematic state"
	)
	if saved == null:
		return
	var loaded = await Restore.new().restore(self, saved)
	_check(loaded.ok, "Cinematic battle did not reload: " + loaded.get("error", ""))
	if loaded.ok:
		game = loaded.game
		_check(Engine.time_scale == 1.0 and paused, "Load leaked speed/pause state")
		_check(
			not game.get_node("BattlePresentation").cinematic, "Load resumed an expired cinematic"
		)


func _music_response(human, opponent):
	var director = root.get_node("MusicDirector")
	director.set_process(false)
	director._sync_scene()
	var victim = _units(human, "Infantry")[0]
	var attacker = _units(opponent, "Infantry")[0]
	director._activity.clear()
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	director._on_weapon_hit(attacker, _units(opponent, "Tank")[0])
	_check(director._activity.is_empty(), "Friendly-fire events raised score tension")
	director._on_weapon_hit(attacker, victim)
	_check(director._activity.is_empty(), "Hidden combat raised score tension")
	director._on_weapon_hit(victim, attacker)
	_check(director._activity.size() == 2, "Observed combat did not raise score tension")
	director.current_track = "bastion"
	director._update_intensity(1.0)
	_check(director.intensity > 0, "Combat stem never faded in")
	var fighting = director.intensity
	paused = true
	director._update_intensity(.5)
	_check(director.intensity < fighting, "Tactical pause did not calm music")
	paused = false
	director._update_intensity(10.0)
	_check(director.intensity == 0.0, "Quiet battlefield retained combat percussion")
	director.set_process(true)


func _music_speech(human):
	var director = root.get_node("MusicDirector")
	var options = root.get_node("Globals").options
	var saved_voice = options.voice_volume
	var saved_master = options.master_volume
	options.voice_volume = .8
	options.master_volume = .8
	var voice = human.get_node("BattleVoice")
	voice.set_process(false)
	voice._clear()
	voice._spoken_at.clear()
	voice._ended = false
	voice.say(root.get_node("Constants").Match.VoiceNarrator.Events.BASE_UNDER_ATTACK)
	director._speech_duck = 0.0
	director._update_speech_duck(.075)
	_check(
		director._speech_duck < 0 and director._speech_duck > -3.0,
		"Music speech duck snapped instead of fading"
	)
	director._update_speech_duck(.1)
	_check(is_equal_approx(director._speech_duck, -3.0), "Warning did not duck music by 3 dB")
	paused = true
	director._update_speech_duck(.2)
	_check(director._speech_duck == -3.0, "Tactical pause unducked an audible warning")
	paused = false
	voice._audio.stream_paused = true
	director._update_speech_duck(.3)
	_check(
		director._speech_duck > -3.0 and director._speech_duck < 0,
		"Paused speech did not smoothly release music"
	)
	director._update_speech_duck(.3)
	_check(is_zero_approx(director._speech_duck), "Paused speech retained music duck")
	voice._audio.stream_paused = false
	for muted in ["voice_volume", "master_volume"]:
		director._update_speech_duck(.2)
		options.set(muted, 0.0)
		director._update_speech_duck(.6)
		_check(is_zero_approx(director._speech_duck), muted + " mute retained music duck")
		options.set(muted, .8)
	voice._audio.bus = "Effects"
	director._update_speech_duck(.2)
	_check(is_zero_approx(director._speech_duck), "Mechanical Effects cue ducked music as speech")
	voice._audio.bus = "Voice"
	director._update_speech_duck(.2)
	var previous_scene = director._scene
	director._scene = null
	director._update_speech_duck(.6)
	_check(is_zero_approx(director._speech_duck), "Leaving match retained speech duck")
	director._scene = previous_scene
	director._update_speech_duck(.2)
	voice._clear()
	director._update_speech_duck(.6)
	_check(is_zero_approx(director._speech_duck), "Finished speech retained music duck")
	voice.set_process(true)
	options.voice_volume = saved_voice
	options.master_volume = saved_master
	print("PASS smooth music speech duck, pause/mute recovery, Effects exclusion and scene cleanup")
