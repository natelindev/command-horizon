extends "res://source/match/programs/arena/ArenaBridge.gd"


func _arguments(request_path):
	var args = super(request_path)
	var separator = args.find("--")
	args.insert(separator, "--script")
	args.insert(separator + 1, "res://tests/rendered/ArenaChildDriver.gd")
	return args
