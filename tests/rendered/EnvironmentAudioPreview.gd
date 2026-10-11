extends "res://tests/headless/EnvironmentAudioRegression.gd"

var capture
var master_capture
var recorded = PackedVector2Array()
var measurements = {}
var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Environment audio rendered deadline exceeded")
		quit(1)
	return false


func _run():
	soundscape_rules = load("res://source/match/audio/EnvironmentAudio.gd")
	preferences = root.get_node("Globals").options
	original_options = preferences.capture()
	options_path = "user://environment-render-options-%d.tres" % OS.get_process_id()
	# Isolate ambience for silence assertions; the battle preview covers the default full mix.
	preferences.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"voice_volume": 0.0,
			"music_volume": 0.0,
			"interface_scale": 1.5
		}
	)
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	capture = AudioEffectCapture.new()
	capture.buffer_length = 12
	master_capture = AudioEffectCapture.new()
	master_capture.buffer_length = 12
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Ambience"), capture)
	AudioServer.add_bus_effect(0, master_capture)
	for map_name in REGIONS:
		await _environment_match("bastion", map_name)
		_clear_mix()
		await create_timer(1.4).timeout
		var mix = _read_mix(REGIONS[map_name])
		_check(mix.peak > .002 and mix.rms > .0002, "Rendered regional ambience is silent")
		_check(mix.peak < .36, "Ambience exceeded its limiter ceiling")
		environment_audio._bed.seek(environment_audio._bed.stream.get_length() - .25)
		await create_timer(.6).timeout
		_check(
			environment_audio._bed.playing and environment_audio._bed.get_playback_position() < 1,
			"Regional bed stopped at loop boundary"
		)
		if map_name == "CoastalFoundry":
			await _render_lifecycle()
			await _spatial_output()
			await _combat_and_speech()
			await _settings_controls()
		await _remove_environment_match()
	_save_recording()
	AudioServer.remove_bus_effect(
		AudioServer.get_bus_index("Ambience"),
		AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Ambience")) - 1
	)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	preferences.restore(original_options)
	DirAccess.remove_absolute(options_path)
	for error in errors:
		push_error(error)
	print("Environment audio rendered: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _render_lifecycle():
	paused = true
	await create_timer(.2).timeout
	var position = environment_audio._bed.get_playback_position()
	_clear_mix()
	await create_timer(.35).timeout
	_check(_read_mix("paused").master_peak < .00001, "Paused soundscape leaked into Master")
	_check(
		absf(environment_audio._bed.get_playback_position() - position) < .035,
		"Paused loop advanced"
	)
	paused = false
	await create_timer(.25).timeout
	_check(environment_audio._bed.get_playback_position() > position + .1, "Loop did not resume")
	preferences.ambience_volume = 0
	preferences.apply()
	await create_timer(.2).timeout
	_clear_mix()
	await create_timer(.3).timeout
	_check(_read_mix("ambience_muted").master_peak < .00001, "Ambience mute was not silent")
	preferences.ambience_volume = .55
	preferences.apply()
	await create_timer(1.6).timeout
	preferences.master_volume = 0
	preferences.apply()
	await create_timer(.2).timeout
	_clear_mix()
	await create_timer(.3).timeout
	_check(_read_mix("master_muted").master_peak < .00001, "Master mute was not silent")
	preferences.master_volume = .8
	preferences.apply()
	await create_timer(1.6).timeout
	print("PASS real audio freeze/thaw and silent Ambience/Master mute")


func _spatial_output():
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(64, 0, 30))
	camera.set_size_safely(40)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var life = game.map.get_node("AmbientLife")
	life.set_physics_process(false)
	var tug = life.actors.filter(func(actor): return actor.entry.kind == "tug")[0]
	for actor in life.actors:
		if actor != tug:
			actor.position = Vector3(10, 0, 95)
	await _frames(20)
	environment_audio.set_process(false)
	for side in ["left", "right"]:
		var rect = root.get_visible_rect()
		var screen = rect.size * Vector2(.2 if side == "left" else .8, .5)
		tug.position = Plane(Vector3.UP, -.5).intersects_ray(
			camera.project_ray_origin(screen), camera.project_ray_normal(screen)
		)
		environment_audio._refresh_sources()
		environment_audio._process(.5)
		environment_audio._bed.stop()
		_check(environment_audio._locals.size() == 1, "Spatial fixture did not isolate tug")
		await create_timer(.2).timeout
		_clear_mix()
		await create_timer(.7).timeout
		var mix = _read_mix("tug_" + side)
		_check(mix.peak > .001, "Tug engine produced no real output")
		_check(
			mix.left > mix.right * 1.5 if side == "left" else mix.right > mix.left * 1.5,
			"Neutral source stereo direction was incorrect"
		)
	environment_audio.set_process(true)
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	for unit in get_nodes_in_group("units"):
		unit.position = Vector3(8, 0, 95)
	game.battlefield.invalidate()
	await _frames(3)
	_check(
		environment_audio._locals.all(func(entry): return not entry.node.playing),
		"Live fog loss leaked tug"
	)
	print("PASS real neutral engine output, camera-relative stereo and current-fog cutoff")


func _combat_and_speech():
	var human = game._get_human_player()
	var own = _units(human, "Tank")[0]
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var target = _units(enemy, "Tank")[0]
	own.position = Vector3(34, 0, 65)
	target.position = Vector3(38, 0, 65)
	game.get_node("IsometricCamera3D").set_position_safely(Vector3(36, 0, 65))
	game.get_node("IsometricCamera3D").set_size_safely(28)
	game.battlefield.invalidate()
	own.process_mode = Node.PROCESS_MODE_PAUSABLE
	var hp = target.hp
	own.issue_manual_order(
		load("res://source/match/units/actions/AttackingWhileInRange.gd").new(target, 1)
	)
	_clear_mix()
	await create_timer(1.3).timeout
	_check(target.hp < hp, "Mix fixture never dealt actual combat damage")
	_check(environment_audio._duck < -3.5, "Audible combat did not duck ambience")
	var mix = _read_mix("combat_with_environment")
	_check(
		mix.master_peak > .01 and mix.master_peak < .9, "Combined combat/environment mix invalid"
	)
	own.process_mode = Node.PROCESS_MODE_DISABLED
	preferences.voice_volume = .8
	preferences.apply()
	var voice = human.get_node("BattleVoice")
	voice.say(root.get_node("Constants").Match.VoiceNarrator.Events.BASE_UNDER_ATTACK)
	await create_timer(.25).timeout
	_check(environment_audio._duck < -7.5, "Audible speech did not duck ambience")
	await _shot("environment-audio-combat-720p")
	preferences.voice_volume = 0
	preferences.effects_volume = 0
	preferences.apply()
	await create_timer(1.8).timeout
	_check(is_zero_approx(environment_audio._duck), "Muted voice/effects kept ambience ducked")
	preferences.effects_volume = .75
	preferences.apply()
	print("PASS real combat and speech priority, mute-aware ducking and bounded combined output")


func _settings_controls():
	paused = true
	var dialog = root.get_node("Globals").open_settings()
	dialog.save_path = options_path
	await _frames(5)
	var position = environment_audio._bed.get_playback_position()
	var control = dialog.controls.ambience_volume
	control.grab_focus()
	await _key(KEY_RIGHT)
	_check(is_equal_approx(preferences.ambience_volume, .6), "Keyboard ambience adjustment failed")
	await _shot("environment-audio-settings-720p")
	var buttons = dialog.find_children("*", "Button", true, false)
	var sample = buttons.filter(func(button): return button.text == "Test ambience")[0]
	await _click(sample)
	_check(sample.text == "Stop ambience sample", "Playing sample has no Stop label")
	_clear_mix()
	await create_timer(.6).timeout
	_check(_read_mix("settings_ambience_sample").master_peak > .001, "Clicked sample was silent")
	_check(
		absf(environment_audio._bed.get_playback_position() - position) < .035,
		"Settings advanced battle sound"
	)
	await _click(sample)
	_check(not dialog._ambience_sample.playing, "Second click did not stop sample")
	_check(sample.text == "Test ambience", "Stopped sample kept its Stop label")
	await _click(dialog._save)
	await _frames(5)
	var saved = ResourceLoader.load(options_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(is_equal_approx(saved.ambience_volume, .6), "Mouse Save lost ambience setting")
	_check(paused, "Save changed prior tactical pause")
	dialog = root.get_node("Globals").open_settings()
	dialog.save_path = options_path
	await _frames(5)
	dialog.controls.ambience_volume.grab_focus()
	await _key(KEY_LEFT)
	await _key(KEY_ESCAPE)
	_check(is_equal_approx(preferences.ambience_volume, .6), "Escape did not roll back ambience")
	paused = false
	await _frames(5)
	print(
		"PASS 720p/150% keyboard slider, mouse sample toggle/Save, Esc rollback and pause ownership"
	)


func _clear_mix():
	capture.clear_buffer()
	master_capture.clear_buffer()


func _read_mix(label):
	var frames = capture.get_buffer(capture.get_frames_available())
	var master = master_capture.get_buffer(master_capture.get_frames_available())
	var result = {
		"frames": frames.size(), "peak": 0.0, "master_peak": 0.0, "left": 0.0, "right": 0.0
	}
	for frame in frames:
		result.peak = maxf(result.peak, maxf(absf(frame.x), absf(frame.y)))
		result.left += frame.x * frame.x
		result.right += frame.y * frame.y
	for frame in master:
		result.master_peak = maxf(result.master_peak, maxf(absf(frame.x), absf(frame.y)))
	result.rms = sqrt((result.left + result.right) / maxf(1, frames.size() * 2))
	_check(not frames.is_empty() and not master.is_empty(), "Audio capture returned no frames")
	recorded.append_array(master)
	measurements[label] = result
	print("ENVIRONMENT MIX ", label, " ", JSON.stringify(result))
	return result


func _save_recording():
	var bytes = PackedByteArray()
	bytes.resize(recorded.size() * 4)
	for index in recorded.size():
		bytes.encode_s16(index * 4, roundi(clampf(recorded[index].x, -1, 1) * 32767))
		bytes.encode_s16(index * 4 + 2, roundi(clampf(recorded[index].y, -1, 1) * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = roundi(AudioServer.get_mix_rate())
	stream.data = bytes
	_check(
		stream.save_to_wav("res://art/audio/environment-runtime.wav") == OK, "Audio export failed"
	)
	var file = FileAccess.open("res://art/audio/environment-runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "\t"))
	file.close()


func _click(control):
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await _frames(3)
		ancestor = ancestor.get_parent()
	var point = root.get_final_transform() * control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(3)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(3)


func _shot(label):
	await _frames(4)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Environment capture resolution changed")
	frame.save_png("res://art/skirmish/%s.png" % label)
