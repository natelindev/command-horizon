extends "res://tests/headless/SaveRestoreEdges.gd"

# Paid jets reserve the four stands, including across a paused restore.
# An aircraft displaced by a destroyed airfield must respect those promises.
var _side
var _field
var _alternate


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _prepare_case(faction)
		await _paid_stands()
		await _lost_airfield()
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Airfield operations: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _prepare_case(faction):
	await _skirmish(faction, "res://source/match/maps/BastionDesert.tscn", false)
	_side = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.type == "CommandCenter":
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			unit.queue_free()
	await _frames(5)
	_field = _place("AircraftFactory", Vector3(44, 0, 40))
	_alternate = _place("AircraftFactory", Vector3(20, 0, 20))
	_place("CommandLab", Vector3(40, 0, 12))
	_place("PowerPlant", Vector3(60, 0, 10))
	_place("PowerPlant", Vector3(60, 0, 18))
	_side.resource_a = 10000
	_side.resource_b = 10000
	await _frames(10)


func _paid_stands():
	var queue = _field.production_queue
	var prototype = load("res://source/match/units/Fighter.tscn")
	for index in 4:
		_check(queue.produce(prototype) != null, "Airfield rejected an available stand")
	var funds = Vector2i(_side.resource_a, _side.resource_b)
	_check(queue.produce(prototype) == null, "Airfield sold a fifth stand")
	_check(Vector2i(_side.resource_a, _side.resource_b) == funds, "Rejected jet spent funds")
	var cancelled = queue.get_elements().back()
	var paid = cancelled.paid_cost.duplicate()
	queue.cancel(cancelled)
	_check(
		(
			Vector2i(_side.resource_a, _side.resource_b)
			== funds + Vector2i(paid.get("resource_a", 0), paid.get("resource_b", 0))
		),
		"Cancelled jet did not refund its exact paid cost"
	)
	_check(queue.produce(prototype) != null, "Cancelled jet did not release its reservation")
	queue.get_elements()[0].time_left = 0.5
	paused = true
	if not (await _restore_airfields()).ok:
		paused = false
		return
	queue = _field.production_queue
	_check(queue.size() == 4 and _field.stands_for_production() == 0, "Lost paid stand promises")
	_check(not is_instance_valid(queue.departure), "Restored jet received a rotorcraft departure")
	_check(
		queue.get_elements()[0].departure_endpoint == null,
		"Restoring a parked jet's assembly invented an exit route"
	)
	var visitor = _place("Fighter", Vector3(49, 5, 18))
	visitor.stance = visitor.Stance.HOLD_FIRE
	var flight = visitor.get_node("Movement")
	flight._find_home()
	_check(flight.airfield == _alternate, "Returning jet took a stand promised to production")
	_check(visitor.movement_domain == 0, "Airborne fighter lost its air movement domain")
	_check(visitor.combat_domain() == 0, "Airborne fighter lost its air target domain")
	# Restoring queue promises must not reject claims belonging to existing jets.
	var first_two_seconds = queue.get_elements()[0].time_left + queue.get_elements()[1].time_left
	queue._process(first_two_seconds / _side.production_factor())
	var before_restore = _units(_side, "Fighter").filter(func(plane): return plane != visitor)
	_check(
		before_restore.size() == 2 and queue.size() == 2,
		"Mixed stand fixture did not assemble two jets"
	)
	var mixed = await _restore_airfields(visitor)
	if not mixed.ok:
		paused = false
		return
	visitor = mixed.extra
	queue = _field.production_queue
	var restored_planes = _units(_side, "Fighter").filter(func(plane): return plane != visitor)
	_check(
		restored_planes.size() == 2 and queue.size() == 2,
		"Mixed restore lost parked or queued jets"
	)
	_check(
		_field.free_stands() == 2 and _field.stands_for_production() == 0,
		"Mixed restore lost stand reservations"
	)
	for plane in restored_planes:
		var movement = plane.get_node("Movement")
		_check(
			(
				movement.is_parked()
				and movement.airfield == _field
				and _field.stand_of(plane) == movement.stand
			),
			"Queued reservations rejected an existing parked aircraft during restore"
		)
	queue._process(1000)
	var planes = _units(_side, "Fighter").filter(func(plane): return plane != visitor)
	_check(queue.size() == 0 and planes.size() == 4, "Four paid jets did not complete")
	var stands = {}
	for plane in planes:
		plane.stance = plane.Stance.HOLD_FIRE
		var movement = plane.get_node("Movement")
		_check(movement.is_parked() and movement.airfield == _field, "Paid jet spawned off stand")
		_check(
			plane.movement_domain == 0 and plane.combat_domain() == 1,
			"Parked fighter lost its air movement or ground target domain"
		)
		_check(_field.services(plane), "Parked fighter is not eligible for airfield service")
		stands[movement.stand] = true
	_check(stands.size() == 4 and _field.free_stands() == 0, "Paid jets shared or lost a stand")
	visitor.queue_free()
	await _frames(2)
	paused = false
	print("AIRFIELD PAID STANDS ", _side.faction, " stands=", stands.keys())


func _restore_airfields(extra_unit = null):
	var capture = Snapshot.new()
	var snapshot = capture.capture(game)
	_check(snapshot != null, "Queued stand snapshot failed: " + capture.error)
	if snapshot == null:
		return {"ok": false}
	var ids = [capture._reference(_field), capture._reference(_alternate)]
	if extra_unit != null:
		ids.append(capture._reference(extra_unit))
	var restore = Restore.new()
	var result = await restore.restore(self, snapshot)
	_check(result.ok, "Queued stand restore failed: " + result.get("error", ""))
	if not result.ok:
		return {"ok": false}
	game = result.game
	_side = game._get_human_player()
	_field = restore.entities[ids[0]]
	_alternate = restore.entities[ids[1]]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	return {"ok": true, "extra": restore.entities[ids[2]] if ids.size() > 2 else null}


func _lost_airfield():
	# Keep two paid aircraft and release two spaces for the displaced pair.
	var planes = _units(_side, "Fighter")
	for plane in planes.slice(0, 2):
		plane.queue_free()
	await _frames(3)
	var parked = _place("Fighter", _alternate.stand_point(0))
	parked.stance = parked.Stance.HOLD_FIRE
	var returning = _place("Bomber", Vector3(7, 5, 43))
	returning.stance = returning.Stance.HOLD_FIRE
	_check(
		returning.movement_domain == 0 and returning.combat_domain() == 0,
		"Airborne bomber lost its air movement or target domain"
	)
	var flight = returning.get_node("Movement")
	flight._find_home()
	_check(flight.airfield == _alternate, "Displaced-aircraft fixture selected the wrong home")
	flight.return_to_base()
	# A returner may already have captured the old airfield's outer approach fix.
	flight._landing_end = 0
	flight._approach_entry = true
	_alternate.hp = 0
	flight._find_home()
	_check(flight.airfield == _field, "Returning aircraft did not claim the surviving airfield")
	_check(
		not flight._approach_entry and flight._landing_end == -1,
		"Reassignment reused the destroyed airfield's approach"
	)
	parked.action = load("res://source/match/units/actions/AirReturn.gd").new()
	var parked_flight = parked.get_node("Movement")
	var escaped = false
	var landed = false
	for frame in range(Engine.physics_ticks_per_second * 120):
		await physics_frame
		escaped = escaped or parked_flight.is_airborne()
		if parked_flight.is_parked() and flight.is_parked():
			landed = true
			break
	_check(escaped, "Aircraft stayed parked on its destroyed airfield")
	_check(landed, "Displaced aircraft did not land at the surviving airfield")
	_check(
		not parked_flight._has_destination and not flight._has_destination,
		"Completed return still has a travel destination"
	)
	_check(
		returning.movement_domain == 0 and returning.combat_domain() == 1,
		"Parked bomber lost its air movement or ground target domain"
	)
	_check(
		_field.services(parked) and _field.services(returning),
		"Returned aircraft are not eligible for stand service"
	)
	_check(
		(
			parked_flight.airfield == _field
			and flight.airfield == _field
			and parked_flight.stand != flight.stand
		),
		"Displaced aircraft shared a stand"
	)
	parked.hp = parked.hp_max * 0.5
	returning.hp = returning.hp_max * 0.5
	for store in parked.stores:
		parked.stores[store] = 0
	for store in returning.stores:
		returning.stores[store] = 0
	for frame in range(Engine.physics_ticks_per_second * 20):
		await physics_frame
	_check(parked.stores_full() and returning.stores_full(), "Displaced aircraft failed to rearm")
	_check(parked.hp == parked.hp_max and returning.hp == returning.hp_max, "Stand repair failed")
	print("AIRFIELD REASSIGNMENT ", _side.faction, " escaped=", escaped, " landed=", landed)


func _place(role, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), _side, false)
	return unit
