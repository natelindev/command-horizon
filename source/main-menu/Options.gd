extends Control


func _ready():
	_open.call_deferred()


func _open():
	var dialog = Globals.open_settings()
	if dialog != null:
		dialog.closed.connect(_back)


func _back():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
