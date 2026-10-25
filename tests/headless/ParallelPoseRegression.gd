extends "res://tests/headless/ChassisSpringRegression.gd"

const Batch = preload("res://source/match/rendering/ParallelPoseBatch.gd")


class Probe:
	extends RefCounted
	var job = Batch.Job.new()
	var thread_id := 0

	func solve():
		thread_id = OS.get_thread_caller_id()
		for step in 100:
			job.root.origin.x += .01
			job.solve()


func _run():
	var serial := []
	var parallel := []
	for index in 128:
		for jobs in [serial, parallel]:
			var probe := Probe.new()
			probe.job.chassis = _motion(index % Chassis.Kind.size())
			probe.job.delta = 1.0 / 30.0
			probe.job.mode = 3
			jobs.append(probe)
	var batch := Batch.new()
	batch.solve(serial, false)
	batch.solve(parallel, true)
	var threads := {}

	for index in serial.size():
		var expected = _state(serial[index].job.chassis)
		var actual = _state(parallel[index].job.chassis)
		for component in expected.size():
			_check(
				absf(expected[component] - actual[component]) < 1e-12,
				"Parallel solve changed body dynamics"
			)
		_check(
			serial[index].job.chassis.velocity == parallel[index].job.chassis.velocity,
			"Parallel solve changed velocity"
		)
		threads[parallel[index].thread_id] = true
	if OS.get_processor_count() >= 4:
		_check(threads.size() > 1, "Parallel solve did not use multiple threads")
	batch.solve([serial[0]], true)
	_check(batch.last_worker_count == 0, "Small batches incurred worker dispatch")
	for message in failures:
		push_error(message)
	print(
		(
			"Parallel pose regression: %d failures; %d executing threads"
			% [failures.size(), threads.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
