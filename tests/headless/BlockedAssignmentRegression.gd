extends "res://tests/headless/SaveRestoreEdges.gd"

const BLOCKED_ARCHIVE = (
	"res://docs/playtests/2026-10-04/" + "mixed-operations-allocation-repeat-bastion-stall.json"
)
const Areas = preload("res://source/match/hud/ProgramAssignments.gd")
const Visual = preload("res://source/match/programs/VisualRules.gd")
const Application = preload("res://source/match/programs/ProgramApplication.gd")
const Schema = preload("res://source/match/saves/SnapshotSchema.gd")


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		for mode in ["lua", "preset", "visual"]:
			await _blocked_recovery(faction, mode)
	await _ordinary_blockage()
	for error in errors:
		push_error(error)
	print("Blocked assignment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_capture(faction = "bastion"):
	if faction == "helix":
		return await _fresh_guard()
	var data = FileStore.new().read_file(BLOCKED_ARCHIVE)
	var restore = Restore.new()
	var result = await restore.restore(self, data)
	_check(result.ok, "Blocked archive failed to restore: " + result.get("error", ""))
	if not result.ok:
		return null
	game = result.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	return restore.entities["unit-23"]


func _fresh_guard():
	paused = false
	await _skirmish("helix", "res://source/match/maps/DesertFrontier.tscn")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for other in get_nodes_in_group("units"):
		other.process_mode = Node.PROCESS_MODE_DISABLED
	var human = game._get_human_player()
	var factory = load("res://source/match/units/AircraftFactory.tscn").instantiate()
	game._setup_and_spawn_unit(factory, Transform3D(Basis(), Vector3(40, 0, 21)), human, false)
	var unit = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(41.26, 0, 24.05)), human, false)
	await _frames(60)
	unit.program.installed = true
	var original = FileStore.new().read_file(BLOCKED_ARCHIVE)
	var entry = original.units.filter(func(row): return row.id == "unit-23")[0]
	_check(unit.program.configure_lua(entry.program.lua_source).ok, "Helix guard compile failed")
	unit.program.anchor = Vector3(40.5, 0, 22.5)
	unit.program.safe_point = Vector3(34, 0, 20)
	return unit


func _blocked_recovery(faction, mode):
	var unit = await _open_capture(faction)
	if unit == null:
		return
	if mode == "preset":
		unit.program.configure(
			load("res://source/match/programs/ProgramLibrary.gd").defaults("guard")
		)
	elif mode == "visual":
		var record = Record.visual("Field guard", 1, Visual.starter(1), ["Tank"])
		_check(Application.apply(record, [unit], unit.player).ok, "Visual guard was rejected")
	_check(unit.program.run(), "Captured program did not resume")
	paused = false
	await _frames(720)
	_check(unit.program.mode == "Blocked", "Inaccessible anchor did not remain Blocked")
	_check(
		(
			unit.program.reason
			== "Assigned point is inside a friendly structure. Choose a clear point."
		),
		"Obstructed assignment lacks an actionable reason"
	)
	_check(not unit.get_node("Movement")._has_destination, "Blocked program kept moving")
	var overlay = Areas.new()
	_check(overlay._shows_guard_area(unit), "Blocked guard lost its assignment boundary")
	paused = true
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var id = snapshotter._reference(unit)
	var entry = data.units.filter(func(row): return row.id == id)[0]
	if mode != "preset":
		var invalid = data.duplicate(true)
		var bad = invalid.units.filter(func(row): return row.id == id)[0]
		bad.action.state["_guarding_area"] = "true"
		_check(not Schema.new().validate(invalid), "Archive accepted an invalid guard flag")
		var legacy = data.duplicate(true)
		legacy.units.filter(func(row): return row.id == id)[0].action.state.erase("_guarding_area")
		_check(Schema.new().validate(legacy), "Older action state became unreadable")
		_check(
			entry.action.state.get("_guarding_area", false),
			"Snapshot omitted active guard boundary"
		)
	var disk = "user://blocked-assignment-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, data), "Blocked archive disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(loaded.ok, "Blocked disk archive failed to restore")
	if not loaded.ok:
		overlay.free()
		return
	game = loaded.game
	unit = restore.entities[id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var start = unit.position
	var runtime = unit.program.lua_runtime.checkpoint() if mode != "preset" else {}
	await _frames(90)
	_check(
		unit.position == start and unit.program.mode == "Blocked", "Paused Blocked state changed"
	)
	_check(overlay._shows_guard_area(unit), "Paused restore hid the blocked guard boundary")
	if mode != "preset":
		_check(unit.program.lua_runtime.checkpoint() == runtime, "Paused archive executed Lua")
	overlay.free()
	unit.program.anchor = Vector3(47, 0, 26) if faction == "helix" else Vector3(25, 0, 38)
	_check(unit.program.run(), "Clear assignment did not resume")
	paused = false
	await _frames(600)
	_check(unit.program.mode == "Running", "Clear assignment did not recover")
	_check(
		unit.position.distance_to(unit.program.anchor) < 1, "Guard did not reach clear assignment"
	)
	unit.issue_manual_order(null)
	await _frames(30)
	_check(unit.program.mode == "Manual", "Recovered guard ignored manual Stop")
	print("CHECKED blocked assignment ", faction, " ", mode, " recovered at ", unit.position)
	game.queue_free()
	await _frames(5)


func _ordinary_blockage():
	var unit = await _open_capture()
	unit.program.anchor = Vector3(25, 0, 38)
	unit.get_node("Movement").speed = 0
	unit.program.run()
	paused = false
	await _frames(480)
	_check(unit.program.mode == "Blocked", "Genuine route blockage did not stop")
	_check(
		unit.program.reason == "No progress for 5 seconds. Reassign or Resume to retry.",
		"Clear destination incorrectly blamed a structure"
	)
	var action = unit.action
	var factory = _units(unit.player, "AircraftFactory")[0]
	action._destination = factory.global_position_yless
	_check(
		not action._blocked_reason().contains("friendly structure"),
		"Combat approach blamed assignment"
	)
	unit.program.anchor = action._destination
	var original_domain = unit.movement_domain
	unit.get_node("Movement").domain = root.get_node("Constants").Match.Navigation.Domain.AIR
	_check(
		not action._blocked_reason().contains("friendly structure"),
		"Ground footprint blamed air route"
	)
	unit.get_node("Movement").domain = original_domain
	var owner = factory.player
	var enemy = get_nodes_in_group("players").filter(func(player): return player != owner)[0]
	factory.reparent(enemy, true)
	_check(
		not action._blocked_reason().contains("friendly structure"),
		"Enemy geometry leaked into reason"
	)
	factory.reparent(owner, true)
	var hp = factory.hp
	factory.hp = 0
	_check(
		not action._blocked_reason().contains("friendly structure"),
		"Dead structure blamed assignment"
	)
	factory.hp = hp
	print("CHECKED ordinary blockage, air, combat, enemy and dead-structure feedback bounds")
	game.queue_free()
	await _frames(5)
