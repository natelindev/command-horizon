extends Control


func _ready():
	var args = OS.get_cmdline_user_args()
	if "--room-server" in args:
		_start_server.call_deferred("res://source/match/network/RoomServer.gd")
		return
	if "--dedicated-server" in args or "--server" in args:
		_start_server.call_deferred("res://source/match/network/DedicatedServer.gd")
		return
	var logos = load("res://source/Logos.tscn").instantiate()
	logos.tree_exited.connect(
		get_tree().change_scene_to_file.bind("res://source/main-menu/Main.tscn")
	)
	add_child(logos)


func _start_server(script_path: String):
	get_tree().root.add_child(load(script_path).new())
