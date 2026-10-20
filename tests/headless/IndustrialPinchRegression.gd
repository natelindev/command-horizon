extends "res://tests/headless/HQTrafficRegression.gd"

const PINCH = (
	"res://docs/playtests/2026-10-06/construction-safety/"
	+ "control6-earned-case6-10-worker_withdrawal.json"
)
var checkpoints = [-1, -1, -1, 1, 12, 36]
var restored_elapsed = 0.0
var pinch_started = 0.0
var pinch_casualties = {}


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for index in checkpoints.size():
		case_label = "replay-%d" % index
		await _open_pinch()
		if checkpoints[index] >= 0:
			await _pinch_reload(checkpoints[index])
		await _complete_pinch()
	await _replace_pinch_order()
	for message in errors:
		push_error(message)
	print("Industrial pinch: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_pinch():
	var restore = Restore.new()
	var data = FileStore.new().read_file(PINCH)
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Industrial pinch archive failed to restore")
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
	pinch_casualties.clear()
	var hit_signal = root.get_node("MatchSignals").unit_weapon_hit
	if not hit_signal.is_connected(_record_pinch_casualty):
		hit_signal.connect(_record_pinch_casualty)
	starting = watched.map(func(unit): return unit.position)
	pinch_started = game.simulation_time
	restored_elapsed = 0.0
	_check(
		starting[0].distance_to(Vector3(10.94714, 0, 52.38223)) < .001, "Wrong captured engineer"
	)
	_check(watched[0].resource_a == 0, "Captured worker cargo changed")
	var actions = watched.map(func(unit): return unit.action)
	await _frames(20)
	_check(paused and game.simulation_time == data.simulation_time, "Paused pinch advanced time")
	_check(watched.map(func(unit): return unit.position) == starting, "Paused pinch moved")
	_check(watched.map(func(unit): return unit.action) == actions, "Paused pinch changed orders")
	await _review_traffic("before")


func _record_pinch_casualty(target, source):
	var index = watched.find(target)
	if index < 0 or target.hp > 0:
		return
	pinch_casualties[index] = {
		"role": target.type,
		"time": game.simulation_time - pinch_started,
		"attacker": source.type,
		"faction": source.player.faction,
		"enemy": source.player != target.player,
	}


func _pinch_reload(frames):
	game.hud._toggle_pause()
	await _frames(frames)
	game.hud.pause_after_load()
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = watched.map(func(unit): return builder._reference(unit))
	var positions = watched.map(func(unit): return unit.position)
	var destinations = watched.map(func(unit): return unit.get_node("Movement").target_position)
	var orders = watched.map(func(unit): return str(unit.action))
	var cargo = watched[0].resource_a
	var file = "user://industrial-pinch-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Pinch checkpoint write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Pinch checkpoint restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	watched = ids.map(func(id): return restore.entities[id])
	restored_elapsed = game.simulation_time - pinch_started
	_check(game.simulation_time == data.simulation_time and paused, "Pinch reload advanced time")
	_check(watched.map(func(unit): return unit.position) == positions, "Pinch reload moved units")
	_check(
		watched.map(func(unit): return str(unit.action)) == orders, "Pinch reload changed actions"
	)
	_check(watched[0].resource_a == cargo, "Pinch reload changed cargo")
	_check(
		watched.map(func(unit): return unit.get_node("Movement").target_position) == destinations,
		"Pinch reload changed destinations"
	)
	await _review_traffic("reloaded")


func _complete_pinch():
	var worker = watched[0]
	var infantry = watched[1]
	var target = infantry.action.destination
	var previous = watched.map(func(unit): return unit.position)
	var maximum_speed_ratio = 0.0
	minimum_clearance = INF
	maximum_off_mesh = 0.0
	var escaped = -1.0
	var infantry_arrived = -1.0
	var collection = -1.0
	var delivery = -1.0
	var last_cargo = worker.resource_a
	game.hud._toggle_pause()
	for frame in 1200:
		var deposit = worker.action.get_resource_unit()
		var stock = deposit.resource_a if is_instance_valid(deposit) else -1
		var funds = worker.player.resource_a
		# Process frames can contain more than one physics step under load.
		# Sample each physics boundary for the per-tick speed/clearance checks.
		await physics_frame
		var elapsed = game.simulation_time - pinch_started
		if not is_instance_valid(worker) or worker.hp <= 0:
			_check(false, "Captured engineer died before completing its work")
			break
		if not is_instance_valid(infantry) or infantry.hp <= 0:
			# Its original guard arrival is complete before later combat begins.
			# A later casualty must not prevent the living engineer's delivery.
			if infantry_arrived < 0 or not pinch_casualties.get(1, {}).get("enemy", false):
				_check(false, "Captured infantry died before completing its guard arrival")
				break
		for index in watched.size():
			var unit = watched[index]
			if not is_instance_valid(unit) or unit.hp <= 0:
				continue
			maximum_speed_ratio = maxf(
				maximum_speed_ratio,
				(
					unit.position.distance_to(previous[index])
					/ (unit.movement_speed / Engine.physics_ticks_per_second)
				)
			)
			previous[index] = unit.position
			_measure_clearance(unit)
		if escaped < 0 and worker.position.distance_to(starting[0]) > 2:
			escaped = elapsed
		if infantry_arrived < 0 and not infantry.get_node("Movement")._has_destination:
			_check(
				infantry.position.distance_to(target) < 1.2,
				"Infantry falsely finished far from goal"
			)
			infantry_arrived = elapsed
		if worker.resource_a > last_cargo:
			if collection < 0:
				collection = elapsed
			_check(
				(
					is_instance_valid(deposit)
					and root.get_node("Utils").Match.Unit.Movement.units_adhere(worker, deposit)
				),
				"Pinch recovery collected outside contact range"
			)
			_check(
				(
					is_instance_valid(deposit)
					and stock - deposit.resource_a >= worker.resource_a - last_cargo
				),
				"Pinch recovery created cargo without consuming finite stock"
			)
		if delivery < 0 and last_cargo > 0 and worker.resource_a == 0:
			delivery = elapsed
			_check(
				worker.player.resource_a >= funds + last_cargo, "Delivered cargo missing from funds"
			)
			_check(
				root.get_node("Utils").Match.Unit.Movement.units_adhere(
					worker, _units(worker.player, "CommandCenter")[0]
				),
				"Pinch recovery delivered away from HQ"
			)
		last_cargo = worker.resource_a
		if frame == 119:
			await _review_traffic("escaped")
		if delivery >= 0 and infantry_arrived >= 0:
			break
	_check(escaped >= 0 and escaped <= 5, "Engineer did not escape within five seconds")
	_check(
		infantry_arrived >= 0 and infantry_arrived <= 5, "Infantry did not reach its guard point"
	)
	_check(collection >= 0 and collection <= 10, "Engineer failed actual collection")
	_check(delivery >= 0 and delivery <= 20, "Engineer failed actual cargo delivery")
	_check(maximum_speed_ratio <= 1.04, "Recovery exceeded unit speed")
	_check(minimum_clearance >= -.05, "Recovery crossed another mobile body")
	_check(maximum_off_mesh <= .16, "Recovery left the navigation boundary")
	print(
		"INDUSTRIAL PINCH ",
		JSON.stringify(
			{
				"case": case_label,
				"checkpoint": restored_elapsed,
				"escape": escaped,
				"infantry_arrival": infantry_arrived,
				"collection": collection,
				"delivery": delivery,
				"casualties": pinch_casualties.values(),
				"maximum_speed_ratio": maximum_speed_ratio,
				"minimum_clearance": minimum_clearance,
				"maximum_off_mesh": maximum_off_mesh
			}
		)
	)
	await _review_traffic("delivered")
	await _close_pinch()


func _replace_pinch_order():
	case_label = "manual"
	await _open_pinch()
	var worker = watched[0]
	var goal = Vector3(13, 0, 44)
	worker.manual_orders.submit({"kind": "move", "point": goal})
	game.hud._toggle_pause()
	await _frames(600)
	_check(worker.position.distance_to(goal) < .5, "Recovery overrode manual replacement")
	_check(worker.resource_a == 0, "Cancelled harvesting still collected cargo")
	await _close_pinch()


func _close_pinch():
	paused = false
	game.queue_free()
	await _frames(5)
	game = null
