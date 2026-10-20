extends Control


func _ready():
	name = "HDRCalibration"
	custom_minimum_size = Vector2(360, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = tr("HDR calibration: dark tones, paper white, bright highlights.")
	resized.connect(queue_redraw)


func _draw():
	var levels = [.015, .035, .07, .18, 1.0, 2.0, 4.0, 8.0]
	var width = size.x / levels.size()
	for index in levels.size():
		var light = levels[index]
		draw_rect(Rect2(index * width + 2, 2, width - 4, size.y - 4), Color(light, light, light))
