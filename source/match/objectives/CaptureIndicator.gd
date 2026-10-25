extends Label3D


func _ready():
	font = load("res://assets/fonts/NotoSansSC.ttf")
	font_size = 34
	pixel_size = 0.014
	outline_size = 8
	outline_modulate = Color("10212b")
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	hide()


func display(elapsed, duration, tint):
	modulate = tint.lightened(0.5)
	var filled = clampi(floori(elapsed / duration * 10), 0, 10)
	text = (
		(tr("Capturing · %d / %d s") % [floori(elapsed), ceili(duration)])
		+ "\n"
		+ "■".repeat(filled)
		+ "□".repeat(10 - filled)
	)
	show()
