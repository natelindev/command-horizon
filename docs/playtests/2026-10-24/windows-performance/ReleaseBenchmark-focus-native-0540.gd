class_name ReleaseBenchmark
extends "res://tests/rendered/ScaleFrameBenchmark.gd"

var _focus_phase = "waiting"
var _focus_exit_count = 0
var _native_focus_token = ""


func _run():
	if is_instance_valid(current_scene):
		current_scene.free()
		current_scene = null
	root.title = "Open RTS Benchmark"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	root.focus_entered.connect(_record_focus.bind(true))
	root.focus_exited.connect(_record_focus.bind(false))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--focus-start-token="):
			_native_focus_token = argument.trim_prefix("--focus-start-token=")
	if "--await-focus" in OS.get_cmdline_user_args():
		if _native_focus_token.is_empty():
			push_error("Native focus gate requires a per-run token path")
			quit(1)
			return
		var label = Label.new()
		label.text = "Click this window to start the performance check"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 32)
		root.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		print(
			"FOCUS_GATE_READY pid=",
			OS.get_process_id(),
			" title=",
			root.title,
			" godot_focused=",
			root.has_focus(),
			" native_token_ready=",
			_native_token_ready()
		)
		while not root.has_focus() or not _native_token_ready():
			await process_frame
		label.free()
	_focus_phase = "setup"
	print(
		"FOCUS_GATE_START pid=",
		OS.get_process_id(),
		" focused=",
		root.has_focus(),
		" native_token_ready=",
		_native_token_ready()
	)
	await super()


func _record_focus(focused):
	if not focused:
		_focus_exit_count += 1
	print(
		"FOCUS_EVENT phase=",
		_focus_phase,
		" focused=",
		focused,
		" ticks_us=",
		Time.get_ticks_usec()
	)


func _measure(label, frames):
	_focus_phase = label
	var exits_before = _focus_exit_count
	var began_focused = root.has_focus()
	print("FOCUS_PHASE_BEGIN phase=", label, " focused=", began_focused)
	_check(began_focused, "Benchmark phase began without window focus")
	await super(label, frames)
	var ended_focused = root.has_focus()
	var exits_during = _focus_exit_count - exits_before
	var valid = began_focused and ended_focused and exits_during == 0
	print(
		"FOCUS_PHASE_END phase=",
		label,
		" focused=",
		ended_focused,
		" lost_focus_events=",
		exits_during,
		" focus_valid=",
		valid
	)
	_check(valid, "Benchmark phase lost window focus")
	_focus_phase = "between"


func _native_token_ready():
	return (
		not _native_focus_token.is_empty()
		and FileAccess.file_exists(_native_focus_token)
		and (
			FileAccess.get_file_as_string(_native_focus_token).strip_edges()
			== str(OS.get_process_id())
		)
	)
