extends "res://tests/headless/MechanicsRegression.gd"


func _run():
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	auto_attack = load("res://source/match/units/actions/AutoAttacking.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		await _builder_handoff()
		await _clear()
		await _guard_return_fire()
		await _clear()
		await _departure_replan()
		await _clear()
		_game.queue_free()
		await _frames(5)
		print("COMPLETION faction=", faction, " cumulative_failures=", _errors.size())
	for message in _errors:
		push_error(message)
	print("Mechanics completion regression: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _builder_handoff():
	var labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	var construct = load("res://source/match/units/actions/Constructing.gd")
	var hq = _spawn("CommandCenter", _human, Vector3(40, 0, 40))
	var foundation = _spawn("PowerPlant", _human, Vector3(50, 0, 40))
	foundation.mark_as_under_construction()
	var outward = _spawn("Worker", _human, Vector3(45, 0, 40))
	var returning = _spawn("Worker", _human, Vector3(41, 0, 44))
	var electronics = _spawn("Worker", _human, Vector3(43, 0, 44))
	await _frames(30)
	for worker in [outward, returning, electronics]:
		worker.action = harvest.new(hq)
		worker.action._kind = 1
		worker.action._state = harvest.State.MOVING_TO_RESOURCE
	returning.action._state = harvest.State.MOVING_TO_CC
	returning.resource_a = 4
	electronics.action._state = harvest.State.MOVING_TO_CC
	electronics.action._kind = 2
	electronics.resource_b = 4
	_check(
		labor.builder([outward, returning, electronics], foundation.position) == returning,
		"Construction did not preserve outward travel and the sole electronics route"
	)
	_check(
		labor.builder([outward], foundation.position) == null,
		"Routine construction interrupted the only active outbound gatherer"
	)
	_check(
		labor.builder([outward], foundation.position, true) == outward,
		"HQ reconstruction cannot recover an active gatherer"
	)
	var action = returning.action
	var funds = _human.resource_a
	labor.assign_construction(returning, foundation)
	_check(
		returning.action == action and returning.resource_a == 4,
		"Construction discarded active cargo"
	)
	_check(
		labor.awaiting_construction(returning), "Delivery-boundary construction was not reserved"
	)
	# Resolve the same completion callback as a real arrival; the archive test
	# separately exercises actual navigation, collection and delivery.
	action._cc_unit = hq
	action._on_sub_action_finished()
	await _frames(2)
	returning.manual_orders._physics_process(0.1)
	_check(
		_human.resource_a == funds + 4 and returning.resource_a == 0,
		"Builder failed to deliver cargo"
	)
	_check(
		is_instance_of(returning.action, construct),
		"Delivered builder did not start its reserved foundation"
	)
	_check(
		returning.manual_orders.pending.is_empty(),
		"Builder retained a duplicate construction order"
	)


func _guard_return_fire():
	# Clear of the builder fixture's HQ footprint, which navigation may still carve.
	var center = Vector3(30, 0, 60)
	var guard = _spawn("Tank", _human, center)
	var victim = _spawn("Worker", _human, center + Vector3(2, 0, 0))
	var attacker = _spawn("Tank", _enemy, center + Vector3(6, 0, 0))
	await _frames(10)
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	_check(behavior.guard(guard, center), "Native guard order was rejected")
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	attacker.action = auto_attack.new(victim)
	attacker.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(150)
	_check(victim.hp < victim.hp_max, "Return-fire fixture did not attack the protected engineer")
	_check(attacker.hp < attacker.hp_max, "Guard ignored an attacker inside its weapon range")
	_check(
		guard.position.distance_to(center) <= 1.0,
		"Guard left its post to pursue: %.2f m" % guard.position.distance_to(center)
	)
	paused = true
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = snapshot.capture(_game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(data != null and schema.validate(data), "Return-fire combat cannot be archived")
	paused = false
	attacker.issue_manual_order(null)
	attacker.process_mode = Node.PROCESS_MODE_DISABLED
	# Observation still governs guard fire, even when the attacker has a legal
	# target pointer. A distant unseen attacker supplies no contact.
	attacker.position = Vector3(130, 0, 100)
	attacker.aim_target = victim
	_game.battlefield.invalidate()
	await _frames(45)
	_check(_engaged_target(guard) != attacker, "Guard return fire tracked a hidden attacker")
	_check(
		guard.position.distance_to(center) <= 1.0,
		"Guard followed a departing attacker: %.2f m" % guard.position.distance_to(center)
	)


func _engaged_target(unit):
	var action = unit.action
	if not is_instance_valid(action) or not "_sub_action" in action:
		return null
	if not is_instance_valid(action._sub_action):
		return null
	return action._sub_action._target_unit


func _departure_replan():
	var factory = _spawn("VehicleFactory", _human, Vector3(50, 0, 50))
	await _frames(30)
	_human.resource_a = 1000
	_human.resource_b = 1000
	var queue = factory.production_queue
	var job = queue.produce(load(Catalog.scene_path("Tank")))
	_check(job != null, "Departure fixture could not purchase a tank")
	if job == null:
		return
	var departure_type = load("res://source/match/effects/ProductionDeparture.gd")
	job.time_left = departure_type.seconds(job)
	queue.restore_departure()
	var departure = queue.departure
	_check(
		is_instance_valid(departure) and not queue.exit_blocked, "Departure fixture starts blocked"
	)
	if not is_instance_valid(departure) or queue.exit_blocked:
		return
	var original = departure.endpoint
	var obstruction = _spawn("Infantry", _human, original)
	await _frames(5)
	obstruction.position = original
	_check(not departure.clear_route(), "Departure obstruction missed the original route")
	_check(departure.find_route(), "Unstarted departure failed to choose a clear alternative")
	_check(
		departure.endpoint.distance_to(original) > 0.1, "Departure retained its blocked endpoint"
	)
	_check(
		job.departure_endpoint == departure.endpoint, "Replanned exit was not retained for saves"
	)
	_check(job.time_left == departure.duration, "Replanning consumed unpaid departure time")
	var chosen = departure.endpoint
	job.time_left = departure.duration * .9
	obstruction.position = chosen
	_check(not departure.find_route(), "Started departure rewrote its obstructed route")
	_check(departure.endpoint == chosen, "Started departure changed its saved endpoint")
