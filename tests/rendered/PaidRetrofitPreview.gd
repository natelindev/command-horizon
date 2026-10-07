extends "res://tests/rendered/CargoReturnPreview.gd"

const INSTALLING = (
	"res://docs/playtests/2026-10-06/paid-retrofit/" + "earned-2-case2-10-retrofit_installing.json"
)


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	if capture_prefix == "":
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(2).timeout
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(INSTALLING))
	_check(loaded.ok, "Paid installation archive failed to load")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	owner = game._get_human_player()
	var install = load("res://source/match/programs/ChipInstalling.gd")
	var tanks = _units(owner, "Tank").filter(
		func(unit): return is_instance_of(unit.action, install)
	)
	_check(tanks.size() == 1, "Archive does not have one active retrofit")
	if tanks.size() != 1:
		quit(1)
		return
	var tank = tanks[0]
	var target = tank.action.service
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(24)
	camera.set_position_safely(target.position)
	await _select_units([tank])
	game.fog_of_war._physics_process(0.0)
	var clock = game.simulation_time
	var left = tank.program.install_left
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	await _frames(10)
	_check(
		(
			paused
			and game.simulation_time == clock
			and left == tank.program.install_left
			and funds == Vector2i(owner.resource_a, owner.resource_b)
		),
		"Paused archive changed paid installation"
	)
	await _capture("installing")
	print("RETROFIT NATIVE initial_time=", clock, " install_left=", left, " funds=", funds)
	await _wait_input(func(): return not paused, "Space: finish earned paid retrofit")
	while (
		is_instance_valid(tank) and not tank.program.installed and game.simulation_time - clock < 60
	):
		await _frames(1)
	game.hud._toggle_pause()
	_check(
		is_instance_valid(tank) and tank.program.installed,
		"Earned native retrofit did not complete"
	)
	if not is_instance_valid(tank) or not tank.program.installed:
		quit(1)
		return
	await _frames(10)
	await _capture("installed")
	funds = Vector2i(owner.resource_a, owner.resource_b)
	clock = game.simulation_time
	print("RETROFIT NATIVE: click Apply & run in the program panel")
	await _wait_input(func(): return tank.program.mode == "Ready", "Apply & run while paused")
	_check(
		(
			paused
			and game.simulation_time == clock
			and funds == Vector2i(owner.resource_a, owner.resource_b)
		),
		"Program activation advanced pause or charged another fee"
	)
	await _capture("ready")
	await _wait_input(func(): return not paused, "Space: run installed program")
	await _frames(15)
	_check(tank.program.mode == "Running", "Installed program did not run after resume")
	game.hud._toggle_pause()
	await _frames(8)
	await _capture("running")
	print("RETROFIT NATIVE mode=", tank.program.mode, " installed=", tank.program.installed)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Paid retrofit native: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
