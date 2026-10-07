extends "res://tests/headless/HQTrafficRegression.gd"

const PINCH = (
	"res://docs/playtests/2026-10-06/construction-safety/"
	+ "control6-earned-case6-10-worker_withdrawal.json"
)

var safe_velocities = {}


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(PINCH))
	_check(loaded.ok, "Industrial pinch failed to restore")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var workers = _units(game._get_human_player(), "Worker")
	workers.sort_custom(
		func(a, b):
			return (
				a.position.distance_to(Vector3(10.94714, 0, 52.38223))
				< b.position.distance_to(Vector3(10.94714, 0, 52.38223))
			)
	)
	watched = [workers[0], restore.entities["unit-14"]]
	for unit in watched:
		unit.get_node("Movement").velocity_computed.connect(func(v): safe_velocities[unit] = v)
	print("PINCH START ", game.simulation_time)
	paused = false
	for frame in 2400:
		await _frames(1)
		if frame % 120 != 0:
			continue
		for unit in watched:
			if not is_instance_valid(unit):
				continue
			var movement = unit.get_node("Movement")
			print(
				"PINCH ",
				JSON.stringify(
					{
						"time": game.simulation_time,
						"role": unit.type,
						"position": str(unit.position),
						"action": str(unit.action),
						"cargo":
						[unit.resource_a, unit.resource_b] if unit.type == "Worker" else [],
						"destination": str(movement.target_position),
						"recovery_left": movement._recovery_left,
						"velocity": str(movement.velocity),
						"safe_velocity": str(safe_velocities.get(unit, Vector3.ZERO)),
						"direction": str(movement._recovery_direction),
						"occupied": movement.has_occupied_endpoint(false)
					}
				)
			)
			if frame < 600:
				_describe_recovery(unit)
	for error in errors:
		push_error(error)
	print("Industrial pinch probe: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
