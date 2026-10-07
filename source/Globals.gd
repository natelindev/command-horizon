extends Node

const Options = preload("res://source/data-model/Options.gd")

var options = _load_options()
var settings_dialog = null
var god_mode = false
var cache = {}


func _load_options():
	if ResourceLoader.exists(Constants.OPTIONS_FILE_PATH):
		var stored = load(Constants.OPTIONS_FILE_PATH)
		if stored is Options:
			return stored
	return Options.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	options.changed.connect(_apply_interface_scale)
	options.apply()


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
