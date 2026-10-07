extends "res://tests/headless/CargoReturnRegression.gd"

var active_neighbors = false


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	active_neighbors = "--active-neighbors" in OS.get_cmdline_user_args()
	for faction in ["bastion", "helix", "frontier"]:
		await _cargo_fixture(faction)
		var hq = _units(owner, "CommandCenter")[0]
		var choices = get_nodes_in_group("resource_units").filter(
			func(node): return "resource_a" in node and node.position.distance_to(hq.position) > 30
		)
		choices.sort_custom(
			func(a, b):
				return a.position.distance_to(hq.position) < b.position.distance_to(hq.position)
		)
		var target = choices[0]
		carrier.resource_a = 0
		carrier.resource_b = 0
		carrier.issue_manual_order(harvest_rules.new(target))
		var funds = owner.resource_a
		var collected = false
		var delivered = false
		var started = game.simulation_time
		game.hud._toggle_pause()
		for frame in 3600:
			await _frames(1)
			collected = collected or carrier.resource_a > 0
			if frame % 120 == 0:
				_trace(faction)
			if frame == 1199:
				game.hud.pause_after_load()
				var builder = Snapshot.new()
				var data = builder.capture(game)
				var file = (
					"res://docs/playtests/2026-10-07/departure-recovery/%s-%s-%d.json"
					% ["active" if active_neighbors else "frozen", faction, OS.get_process_id()]
				)
				FileStore.new().write_file(file, data)
				print("ARCHIVE ", file, " carrier=", builder._reference(carrier))
				game.hud._toggle_pause()
			if collected and carrier.resource_a == 0 and owner.resource_a >= funds + 4:
				delivered = true
				break
		print(
			"DEPARTURE ",
			faction,
			" active=",
			active_neighbors,
			" collected=",
			collected,
			" delivered=",
			delivered,
			" seconds=",
			game.simulation_time - started
		)
		paused = false
		game.queue_free()
		await _frames(5)
	quit()


func _freeze_other_actors():
	super()
	if not active_neighbors:
		return
	for unit in get_nodes_in_group("units"):
		if unit == carrier:
			continue
		unit.process_mode = Node.PROCESS_MODE_INHERIT
		unit.issue_manual_order(null)


func _trace(faction):
	var movement = carrier.get_node("Movement")
	var nearby = []
	for unit in get_nodes_in_group("units"):
		if unit != carrier and unit.position.distance_to(carrier.position) < 4:
			nearby.append(
				{
					"type": unit.type,
					"position": str(unit.position),
					"radius": unit.radius,
					"action": str(unit.action)
				}
			)
	print(
		"DEPARTURE TRACE ",
		JSON.stringify(
			{
				"faction": faction,
				"time": game.simulation_time,
				"position": str(carrier.position),
				"action": str(carrier.action),
				"velocity": str(movement.velocity),
				"progress": str(movement._progress_position),
				"elapsed": movement._progress_elapsed,
				"recovery": movement._recovery_left,
				"direction": str(movement._recovery_direction),
				"path": str(movement.get_current_navigation_path()),
				"index": movement.get_current_navigation_path_index(),
				"nearby": nearby
			}
		)
	)
