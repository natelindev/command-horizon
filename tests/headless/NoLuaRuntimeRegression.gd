extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	var runtime = load("res://source/match/programs/LuaRuntime.gd")
	if ClassDB.class_exists("RtsLuaSandbox") or runtime.available():
		push_error("The retired Lua runtime is still registered")
		quit(1)
		return
	print("Retired Lua runtime: absent")
	quit(0)
