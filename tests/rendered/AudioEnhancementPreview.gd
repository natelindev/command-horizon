extends "res://tests/headless/AudioEnhancementRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-11/audio-enhancement/"
var _capture_effect
var _deadline = 0


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 120000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Audio preview exceeded deadline")
		quit(1)
	return false


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore(
		{"screen": 1, "edge_scrolling": false, "music_volume": 0.5, "ambience_volume": 0.55}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	root.get_node("SaveManager").autosaves_enabled = false
	_capture_effect = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _capture_effect)
	for faction in ["bastion", "helix", "frontier"]:
		await _setup(faction)
		_attach_voice()
		_capture_effect.set_recording_active(true)
		var human = game._get_human_player()
		var infantry = _units(human, "Infantry")[0]
		await _frames(180)
		var ui = root.get_node("UIAudio")
		var count = ui.played_count
		await _click(game.hud._pause_button)
		_check(paused and ui.played_count == count + 1, "Real pause button click lacked UI cue")
		_reset_speech()
		infantry.get_node("Selection").select()
		await _frames(12)
		_check(
			voice.current.get("stream", "").contains("/Infantry/select_"),
			"Real selection lacks role voice"
		)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + faction + "-unit-caption.png")
		await _frames(180)
		var order = load("res://source/match/orders/ManualOrders.gd").point_order(
			"attack_move", infantry.global_position + Vector3(3, 0, 0)
		)
		infantry.manual_orders.submit(order)
		await _frames(120)
		var attacker = _units(_sides()[1], "Tank")[0]
		_units(human, "CommandCenter")[0].receive_weapon_hit(attacker)
		await _frames(12)
		_check(
			voice.current.get("event") == EVENTS.BASE_UNDER_ATTACK,
			"Real hit lacks announcer warning"
		)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + faction + "-announcer-caption.png")
		await _frames(180)
		var lab = _units(human, "CommandLab")[0]
		human.resource_a = 500
		human.resource_b = 500
		human.technology.start("weapons_1", lab)
		human.technology._physics_process(1000)
		await _frames(180)
		_capture_effect.set_recording_active(false)
		var recording = _capture_effect.get_recording()
		_check(recording != null and recording.get_length() > 10, "Live mix capture is empty")
		recording.save_to_wav(OUTPUT + faction + "-live-mix.wav")
		await _clean_match()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	preferences.restore(original)
	print("Audio rendered preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _click(control):
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)
