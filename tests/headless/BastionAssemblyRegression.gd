extends "res://tests/headless/UnitAnimationRegression.gd"


class DepartureFixture:
	extends Node3D
	var job
	var allowed := true
	var elapsed := 0.0

	func find_route():
		return allowed

	func update_pose(delta):
		elapsed += delta

	func handoff(_unit):
		pass


func _run():
	await _fixture("bastion")
	var owner = _players[0]
	owner.resource_a = 10000
	owner.resource_b = 10000
	var factory = _spawn("Barracks", 0, Vector3(30, 0, 18))
	var queue = factory.get_node("ProductionQueue")
	var infantry = load(Catalog.scene_path("Infantry"))
	var rockets = load(Catalog.scene_path("RocketInfantry"))
	for expected in [0.0, .08, .16, .24, .24]:
		var job = queue.produce(infantry)
		_check(job != null, "Could not create assembly job")
		if job == null:
			break
		var exit = DepartureFixture.new()
		exit.job = job
		factory.add_child(exit)
		queue.departure = exit
		var departure_seconds = queue.Departure.seconds(job)
		var work = job.time_total - departure_seconds
		queue._process((work / (1.0 + expected)) / owner.production_factor())
		_check(is_equal_approx(job.assembly_bonus, expected), "Completed-unit bonus incorrect")
		_check(
			is_equal_approx(job.time_left, departure_seconds), "Assembly crossed departure phase"
		)
		_check(is_zero_approx(exit.elapsed), "Assembly accelerated departure animation")
		exit.allowed = false
		queue._process(100)
		_check(is_equal_approx(job.time_left, departure_seconds), "Blocked exit consumed progress")
		_check(is_equal_approx(job.assembly_bonus, expected), "Blocked exit cleared locked bonus")
		exit.allowed = true
		queue._process(.5 / owner.production_factor())
		_check(
			is_equal_approx(job.time_left, departure_seconds - .5),
			"Departure inherited assembly bonus"
		)
		queue._process((departure_seconds - .5) / owner.production_factor())
		_check(queue.size() == 0, "Paid production did not complete")
	_check(queue.completed_streak == 3, "Streak did not cap at three completed bonuses")
	queue._process(4.9)
	_check(queue.completed_streak == 3, "Idle grace expired early")
	var active = queue.produce(infantry)
	queue._process(.1)
	var waiting = queue.produce(rockets)
	queue.cancel(waiting)
	_check(
		queue.completed_streak == 3 and is_equal_approx(active.assembly_bonus, .24),
		"Waiting cancellation changed active job"
	)
	queue.cancel(active)
	_check(queue.completed_streak == 0, "Active cancellation retained streak")
	queue.restore_assembly_state(
		{"last_completed_role": "Infantry", "completed_streak": 2, "idle_grace_left": 4.0}
	)
	var snapshot = queue.capture_assembly_state()
	queue._process(4.1)
	_check(queue.completed_streak == 0, "Idle timeout retained streak")
	queue.restore_assembly_state(snapshot)
	_check(
		queue.completed_streak == 2 and is_equal_approx(queue.idle_grace_left, 4.0),
		"Streak capture/restore lost grace"
	)
	active = queue.produce(rockets)
	queue._process(.1)
	_check(
		queue.completed_streak == 0 and active.assembly_bonus == 0, "Role switch retained streak"
	)
	queue.cancel(active)
	for index in 8:
		active = queue.produce(infantry)
		queue.cancel(active)
	_check(queue.completed_streak == 0, "Enqueue/cancel manufactured a streak")
	var second = _spawn("Barracks", 0, Vector3(40, 0, 18)).get_node("ProductionQueue")
	_check(second.next_assembly_bonus("Infantry") == 0, "Factories shared streak")
	owner.faction = "helix"
	queue.restore_assembly_state(snapshot)
	_check(queue.next_assembly_bonus("Infantry") == 0, "Non-Bastion producer gained assembly trait")
	await _close()
	for message in _errors:
		push_error(message)
	print("Bastion assembly regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
