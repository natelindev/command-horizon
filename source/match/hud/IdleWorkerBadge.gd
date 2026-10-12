extends Button

var _handler = null
var _last_count = -1


func _ready():
	theme_type_variation = "BattleQuietButton"
	custom_minimum_size = Vector2(80, 32)
	add_theme_font_size_override("font_size", 12)
	tooltip_text = "Idle Harvesters (F1 / .)\nClick or press hotkey to cycle idle workers."
	pressed.connect(_on_pressed)
	hide()


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
			show()
		else:
			hide()


func _on_pressed():
	if _handler != null and is_instance_valid(_handler):
		_handler.cycle_idle_worker()
