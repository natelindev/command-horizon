extends Control

@onready var _logos = find_child("Logos")


func _ready():
	var args = OS.get_cmdline_user_args()
	var arena_index = args.find("--program-arena")
	if arena_index >= 0 and arena_index + 1 < args.size():
		hide()
		_open_arena.call_deferred(args[arena_index + 1])
		return
	_logos.tree_exited.connect(
		get_tree().change_scene_to_file.bind("res://source/main-menu/Main.tscn")
	)


func _open_arena(request_path):
	var arena = load("res://source/match/programs/arena/ArenaWindow.gd").new()
	arena.request_path = request_path
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	queue_free()
