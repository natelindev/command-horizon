extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	var native = load("res://source/match/rendering/NativePosePacker.gd").create()
	if native == null:
		push_error("Native CPU profile regression requires native kernels")
		await root.get_node("Globals").quit_game(1)
		return
	var errors = []
	var profiler = load("res://source/match/rendering/RuntimePhaseProfiler.gd").new()
	# Simulate a probe created before the ordinary numerical solver registered
	# the class. Clock discovery does not change simulation/render activation.
	profiler.native = null
	var discovered = profiler.cpu_sample()
	if profiler.native == null or discovered.size() != 4 or discovered[0] != 1:
		errors.append("Profiler did not discover already registered CPU clocks")
	profiler.free()
	var first = native.cpu_sample()
	var checksum = 0.0
	# Exceed coarse Windows CPU-clock granularity as well as POSIX resolution.
	for index in 2000000:
		checksum += sqrt(float(index + 1))
	var busy = native.cpu_sample()
	var wall = Time.get_ticks_usec()
	OS.delay_msec(40)
	var sleeping = native.cpu_sample()
	var elapsed = Time.get_ticks_usec() - wall
	print("CPU samples first=", first, " busy=", busy, " sleeping=", sleeping)
	if first.size() != 4 or first[0] != 1 or busy.size() != 4 or sleeping.size() != 4:
		errors.append("Native process/thread CPU clocks are unavailable")
	else:
		# The native sampler reads these clocks separately. Compare each with
		# its own previous value; cross-clock absolute ordering is not atomic.
		if busy[1] <= first[1] or busy[2] <= first[2]:
			errors.append("Actual CPU work did not advance monotonic process/thread counters")
		if sleeping[1] < busy[1] or sleeping[2] < busy[2]:
			errors.append("CPU clocks moved backward")
		if sleeping[2] - busy[2] >= elapsed / 2:
			errors.append("Sleeping wall time was misreported as main-thread CPU time")
		print(
			"CPU work checksum=",
			checksum,
			" busy_process_us=",
			busy[1] - first[1],
			" busy_us=",
			busy[2] - first[2],
			" sleep_cpu_us=",
			sleeping[2] - busy[2],
			" sleep_wall_us=",
			elapsed
		)
	for message in errors:
		push_error(message)
	print("Native CPU clocks: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
