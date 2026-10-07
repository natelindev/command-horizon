extends "res://tests/headless/WeaponModeRegression.gd"

var preferences
var original
var archive


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://settings-test-%d.tres" % OS.get_process_id()
	var fixture = preferences.DEFAULTS.duplicate()
	fixture.screen = preferences.Screen.WINDOW
	preferences.restore(fixture)
	await _storage()
	await _setup("bastion")
	await _battle_dialog()
	await _clean_match()
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
	print("Settings regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _storage():
	var values = preferences.capture()
	preferences.master_volume = 0.0
	preferences.voice_volume = 0.35
	preferences.interface_scale = 1.25
	preferences.camera_speed = 1.5
	preferences.zoom_speed = 2.0
	preferences.edge_scrolling = false
	preferences.reduced_flashes = true
	preferences.apply()
	_check(root.content_scale_factor == 1.25, "Interface size was not applied")
	_check(AudioServer.is_bus_mute(0), "Master zero does not mute")
	var voice = AudioServer.get_bus_index("Voice")
	_check(
		voice > 0 and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(voice)), 0.35),
		"Voice gain not applied"
	)
	_check(preferences.persist(archive) == OK, "Settings file write failed")
	var loaded = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(
		loaded != null and loaded.capture() == preferences.capture(),
		"Settings file lost preferences"
	)
	var broken = preferences.capture()
	broken.interface_scale = NAN
	broken.camera_speed = INF
	broken.master_volume = -5.0
	broken.zoom_speed = 999.0
	broken.edge_scrolling = "invalid"
	preferences.restore(broken)
	_check(
		(
			preferences.camera_speed == 1
			and preferences.interface_scale == 1.0
			and preferences.master_volume == 0
			and preferences.zoom_speed == 3
			and preferences.edge_scrolling
		),
		"Invalid settings were not bounded"
	)
	preferences.restore({"screen": 1, "mouse_restricted": false})
	_check(
		(
			preferences.camera_speed == 1
			and preferences.voice_volume == 0.8
			and preferences.interface_scale == 1.0
		),
		"Legacy settings do not receive defaults"
	)
	preferences.restore(values)
	print("PASS: actual settings round trip, legacy defaults, bounds and audio gain/mute")


func _battle_dialog():
	var globals = root.get_node("Globals")
	var saves = root.get_node("SaveManager")
	var camera = game.get_node("IsometricCamera3D")
	var unit = _units(game._get_human_player(), "Tank")[0]
	unit.get_node("Selection").select()
	var original_action = unit.action
	var original_camera_mode = camera.process_mode
	for was_paused in [false, true]:
		paused = was_paused
		var before = preferences.capture()
		var clock = game.simulation_time
		var position = camera.position
		var dialog = globals.open_settings()
		dialog.save_path = archive
		await _frames(5)
		_check(not saves.can_open(), "Archive can open over settings")
		dialog._preview("master_volume", 0.25)
		dialog._preview("camera_speed", 1.8)
		dialog._preview("interface_scale", 1.5)
		await _frames(30)
		_check(
			(
				game.simulation_time == clock
				and camera.position == position
				and unit.action == original_action
			),
			"Settings advanced battle/camera/orders"
		)
		_check(
			(
				camera.process_mode == Node.PROCESS_MODE_INHERIT
				and game.process_mode == Node.PROCESS_MODE_DISABLED
			),
			"Always-processing battle nodes were not frozen"
		)
		dialog._finish(false)
		await _frames(2)
		_check(
			(
				preferences.capture() == before
				and paused == was_paused
				and root.content_scale_factor == before.interface_scale
			),
			"Cancel lost preferences or pause"
		)
		_check(
			camera.process_mode == original_camera_mode, "Camera processing mode was not restored"
		)
	paused = false
	var dialog = globals.open_settings()
	dialog.save_path = "user://settings-missing-%d/options.tres" % OS.get_process_id()
	dialog._preview("voice_volume", 0.45)
	dialog._finish(true)
	_check(
		(
			is_instance_valid(globals.settings_dialog)
			and paused
			and not dialog._status.text.is_empty()
		),
		"Write failure silently closed settings"
	)
	dialog.save_path = archive
	dialog._finish(true)
	await _frames(3)
	_check(
		not is_instance_valid(globals.settings_dialog) and not paused,
		"Successful Save did not return to battle"
	)
	_check(
		is_equal_approx(
			ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE).voice_volume, 0.45
		),
		"Saved preview missing from disk"
	)
	preferences.edge_scrolling = false
	var held_key = InputMap.action_get_events("move_map_right")[0].duplicate()
	held_key.keycode = held_key.physical_keycode
	held_key.pressed = true
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	_check(
		camera._calculate_screen_move_vector() == Vector2.RIGHT,
		"Disabling edge scroll disabled keyboard pan"
	)
	camera.set_position_safely(Vector3(32, 0, 32))
	var start = camera.position
	preferences.camera_speed = 0.5
	camera._try_handling_movement(0.1)
	var slow = camera.position.distance_to(start)
	camera.position = start
	preferences.camera_speed = 1.5
	camera._try_handling_movement(0.1)
	_check(
		slow > 0 and is_equal_approx(camera.position.distance_to(start), slow * 3),
		"Camera ignores pan speed"
	)
	held_key = held_key.duplicate()
	held_key.pressed = false
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	preferences.zoom_speed = 2.0
	camera.set_size_safely(28)
	camera._zoom_in()
	_check(camera.size == 26, "Camera does not use zoom preference")
	var human = game._get_human_player()
	_check(
		human.get_node("VoiceNarratorController")._voice._audio.bus == "Voice",
		"Narrator not routed through voice volume"
	)
	_check(
		human.get_node("UnitVoicesController")._voice._audio.bus == "Voice",
		"Unit responses not routed through voice volume"
	)
	print(
		"PASS: battle modal pause/order authority, cancel/save/write failure, camera and voice routing"
	)
