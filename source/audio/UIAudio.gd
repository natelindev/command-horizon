extends Node

signal cue_started(kind)

const STREAMS = {
	"click": preload("res://assets/audio/ui/click.wav"),
	"select": preload("res://assets/audio/ui/select.wav"),
	"adjust": preload("res://assets/audio/ui/adjust.wav"),
	"confirm": preload("res://assets/audio/ui/confirm.wav"),
}
const MIN_INTERVAL_MS = 75
const HOVER_INTERVAL_MS = 110
var played_count = 0
var _last_played = -1000
var _last_hover = -1000
var _player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Effects"
	_player.volume_db = -15.0
	add_child(_player)
	_hover_player = AudioStreamPlayer.new()
	_hover_player.bus = "Effects"
	_hover_player.volume_db = -25.0
	_hover_player.pitch_scale = 1.24
	_hover_player.stream = STREAMS["click"]
	add_child(_hover_player)
	get_tree().node_added.connect(_watch)
	Globals.options.changed.connect(_options_changed)
	_watch_tree(get_tree().root)


func _watch_tree(node):
	_watch(node)
	for child in node.get_children():
		_watch_tree(child)


func _watch(node):
	if node is BaseButton:
		_connect_once(node.pressed, _button_pressed.bind(node))
		_connect_once(node.mouse_entered, _button_hovered.bind(node))
	if node is OptionButton:
		_connect_once(node.item_selected, _item_selected.bind(node))
	elif node is TabBar:
		_connect_once(node.tab_clicked, _item_selected.bind(node))
	elif node is ItemList:
		_connect_once(node.item_selected, _item_selected.bind(node))
	elif node is PopupMenu:
		_connect_once(node.id_pressed, _item_selected.bind(node))
	elif node is Slider:
		_connect_once(node.gui_input, _slider_input.bind(node))


func _connect_once(notification, callback):
	if not notification.is_connected(callback):
		notification.connect(callback)


func _button_pressed(button):
	if not button.disabled and _audible(button):
		play("select" if button.toggle_mode else "click")


func _button_hovered(button):
	if button.disabled or not _audible(button):
		return
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		return
	var now = Time.get_ticks_msec()
	if now - _last_hover < HOVER_INTERVAL_MS:
		return
	_last_hover = now
	_hover_player.play()


func _item_selected(_index, control):
	if (
		(
			control is PopupMenu
			and control.can_process()
			and not control.get_meta("silent_audio", false)
		)
		or _audible(control)
	):
		play("confirm" if control is OptionButton or control is PopupMenu else "select")


func _slider_input(event, slider):
	if not slider.editable or not _audible(slider):
		return
	if (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT)
		or (
			event is InputEventKey
			and event.pressed
			and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END]
		)
	):
		play("adjust")


func _audible(control):
	return (
		is_instance_valid(control)
		and not control.is_queued_for_deletion()
		and (control.visible if control is Window else control.is_visible_in_tree())
		and control.can_process()
		and not control.get_meta("silent_audio", false)
	)


func play(kind):
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		return false
	var now = Time.get_ticks_msec()
	var is_error = kind == "error"
	var stream_key = "adjust" if is_error else kind
	if now - _last_played < MIN_INTERVAL_MS or not STREAMS.has(stream_key):
		return false
	_last_played = now
	_player.pitch_scale = 0.68 if is_error else 1.0
	_player.stream = STREAMS[stream_key]
	_player.play()
	played_count += 1
	cue_started.emit(kind)
	return true


func _options_changed():
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		_player.stop()
		_hover_player.stop()
