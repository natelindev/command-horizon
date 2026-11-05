extends Node

const Options = preload("res://source/data-model/Options.gd")

var options = _load_options()
var settings_dialog = null
var god_mode = false
var cache = {}
var _quitting = false


func _load_options():
	if ResourceLoader.exists(Constants.OPTIONS_FILE_PATH):
		var stored = load(Constants.OPTIONS_FILE_PATH)
		if stored is Options:
			return stored
	return Options.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	options.changed.connect(_apply_interface_scale)
	options.apply()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func quit_game(exit_code = 0):
	if _quitting:
		return
	_quitting = true
	var tree = get_tree()
	tree.paused = true
	tree.root.set_disable_input(true)
	# Finish the triggering button/window notification before draining audio.
	await tree.process_frame
	# Stop before SceneTree teardown: the audio server releases playback on
	# subsequent mix/update cycles, after AudioStreamPlayer.stop() returns.
	var playbacks: Array[WeakRef] = []
	_stop_audio(tree.root, playbacks)
	get_node("/root/MusicDirector").shutdown()
	# Allow two output buffers and main-loop updates to drain stopped voices.
	# A paused tree or zero time scale must not prevent the drain.
	var drain_seconds = maxf(.1, AudioServer.get_output_latency() * 2.0)
	var drain_until = Time.get_ticks_usec() + int(drain_seconds * 1000000.0)
	var deadline = Time.get_ticks_usec() + int(maxf(2.0, drain_seconds) * 1000000.0)
	# A busy audio thread can outlive the nominal buffer latency. Wait for its
	# actual playback references to drain, with a bound for unavailable devices.
	while (
		Time.get_ticks_usec() < deadline
		and (
			Time.get_ticks_usec() < drain_until
			or playbacks.any(func(playback): return playback.get_ref() != null)
		)
	):
		# Avoid a busy loop (and accelerated test timers under --fixed-fps).
		OS.delay_msec(1)
		await tree.process_frame
	tree.quit(exit_code)


func _stop_audio(node, playbacks: Array[WeakRef]):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node.has_stream_playback():
			var playback = node.get_stream_playback()
			# Positional players can own a prepared playback until their next
			# physics tick; only started voices belong to the audio thread.
			if playback.is_playing():
				playbacks.append(weakref(playback))
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child, playbacks)


func _process(_delta):
	options.settle_display()


func open_settings():
	var saves = get_node("/root/SaveManager")
	if is_instance_valid(settings_dialog) or saves.busy or is_instance_valid(saves.dialog):
		return null
	settings_dialog = load("res://source/main-menu/SettingsDialog.gd").new()
	settings_dialog.options = options
	settings_dialog.save_path = Constants.OPTIONS_FILE_PATH
	add_child(settings_dialog)
	return settings_dialog


func _unhandled_input(event):
	if is_instance_valid(settings_dialog):
		return
	if event.is_action_pressed("toggle_god_mode", false, true):
		_toggle_god_mode()


func _toggle_god_mode():
	if not FeatureFlags.god_mode:
		return
	god_mode = not god_mode
	if god_mode:
		Signals.god_mode_enabled.emit()
	else:
		Signals.god_mode_disabled.emit()


func _apply_interface_scale():
	get_tree().root.content_scale_factor = options.interface_scale
