extends SceneTree


class MovementState:
	extends Node
	var _synchronized = false


class TerrainState:
	extends RefCounted
	var ticks = 0
	var movement

	func _process(_delta):
		ticks += 1
		movement._synchronized = ticks >= 400

	func is_synchronized():
		return ticks >= 350


func _initialize():
	call_deferred("_run")


func _run():
	# Accelerated frame delivery must not exhaust the asynchronous wall-time
	# budget before terrain and individual agents have both synchronized.
	Engine.physics_ticks_per_second = 1000
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var terrain = TerrainState.new()
	var unit = Node.new()
	var movement = MovementState.new()
	movement.name = "Movement"
	unit.add_child(movement)
	root.add_child(unit)
	terrain.movement = movement
	restore._data = {"units": [{"id": "unit"}], "resources": []}
	restore.entities = {"unit": unit}
	paused = true
	var synchronized = await restore._synchronize(self, {"navigation": {"terrain": terrain}})
	var failures = 0
	if not synchronized or terrain.ticks < 400 or not movement._synchronized:
		push_error("Accelerated frames exhausted save navigation synchronization")
		failures += 1
	if not paused:
		push_error("Synchronization advanced the paused battle")
		failures += 1
	unit.free()
	print("Save navigation timing: %d failures" % failures)
	await root.get_node("Globals").quit_game(0 if failures == 0 else 1)
