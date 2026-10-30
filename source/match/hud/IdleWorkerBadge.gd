extends Button

const Bindings = preload("res://source/input/KeyBindings.gd")

var _handler = null
var _last_count = -1


func _ready():
	theme_type_variation = "BattleQuietButton"
	custom_minimum_size = Vector2(80, 32)
	add_theme_font_size_override("font_size", 12)
	_update_tooltip()
	pressed.connect(_on_pressed)
	gui_input.connect(_on_gui_input)
	hide()


func _update_tooltip():
	tooltip_text = (
		tr("Idle Harvesters") + " [%s]\n" % Bindings.label("cycle_idle_worker")
		+ tr("Click to cycle · Shift/Ctrl+Click to select all [%s]") % Bindings.label("select_all_idle_workers")
	)


func _process(_delta):
	if _handler == null or not is_instance_valid(_handler):
		_handler = get_tree().root.find_child("IdleWorkerHandler", true, false)
	if _handler == null:
		return
	var count = _handler.get_idle_workers().size()
	if count != _last_count:
		_last_count = count
		if count > 0:
			text = "⚒ Idle: %d" % count
			add_theme_color_override("font_color", Color("f0b429"))
			_update_tooltip()
			show()
		else:
			hide()


func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.shift_pressed or event.ctrl_pressed:
			if _handler != null and is_instance_valid(_handler):
				_handler.select_all_idle_workers()
				accept_event()


func _on_pressed():
	if _handler != null and is_instance_valid(_handler):
		_handler.cycle_idle_worker()
