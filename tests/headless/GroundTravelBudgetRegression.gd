extends "res://tests/headless/MechanicsRegression.gd"

var _tank
var _ally
var _heavy
var _light
var _delta := 0.0
var _origin := Vector3(40, 0, 40)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		_tank = _spawn("Tank", _human, Vector3(39, 0, 40))
		_ally = _spawn("Infantry", _human, _origin)
		await _frames(20)
		_heavy = _tank.get_node("Movement")
		_light = _ally.get_node("Movement")
		_delta = 1.0 / Engine.physics_ticks_per_second
		_heavy.avoidance_enabled = false
		_light.avoidance_enabled = false
		_heavy._has_destination = true
		_heavy.velocity = Vector3.RIGHT * _heavy.speed
		if "--native-crowd-runtime" in OS.get_cmdline_user_args():
			_check(_light._native_runtime != null, "Requested native motion was not bound")
		_nudge_then_walk()
		_walk_then_nudge()
		_multiple_nudges()
		_blocked_nudge()
		_vertical_settling()
		_phase_reset()
		if faction == "frontier":
			await _transport_reset()
		var origin = _ally.global_position
		var frame = Engine.get_physics_frames()
		while Engine.get_physics_frames() == frame:
			await physics_frame
		_check(
			is_equal_approx(_light._ground_motion_budget(_delta), _light.speed * _delta),
			"New physics frame retained an old motion debit"
		)
		_check(_ally.global_position == origin, "Disabled fixture moved while waiting for its tick")
		_game.queue_free()
		_fixtures.clear()
		await _frames(5)
		print("Ground travel budget faction=", faction, " failures=", _errors.size())
	for message in _errors:
		push_error(message)
	print("Ground travel budget regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _reset():
	_check(_light.relocate(_origin), "Fixture relocation failed")
	_light._has_destination = true
	_light._physics_delta = _delta
	_light.velocity = Vector3.ZERO


func _walk(direction: Vector3):
	var requested = direction * _light.speed
	if _light._native_runtime != null:
		_light._native_runtime.receive_velocity(requested, _light._native_handle)
	else:
		_light._on_velocity_computed(requested)


func _bounded(label: String, origin: Vector3):
	var travelled = ((_ally.global_position - origin) * Vector3(1, 0, 1)).length()
	_check(travelled <= _light.speed * _delta + .00001, label + ": exceeded total tick travel")


func _nudge_then_walk():
	_reset()
	_heavy._update_mass_contacts(_delta)
	var nudged = _ally.global_position - _origin
	_check(nudged.length() > .04, "Nudge then walk did not exercise a real contact")
	_walk(nudged.normalized())
	_bounded("Nudge then walk", _origin)
	_check(
		_ally.global_position.distance_to(_origin) > nudged.length() + .02,
		"Nudge budget prevented the remaining own movement"
	)


func _walk_then_nudge():
	_reset()
	_walk(Vector3.BACK)
	var walked = _ally.global_position
	_check(walked.distance_to(_origin) > .08, "Walk then nudge did not exercise actual walking")
	_heavy._update_mass_contacts(_delta)
	_bounded("Walk then nudge", _origin)
	_check(_ally.global_position == walked, "An exhausted walker received extra contact travel")


func _multiple_nudges():
	_reset()
	for index in 5:
		_heavy._update_mass_contacts(_delta)
	_bounded("Multiple nudges", _origin)
	_check(
		_ally.global_position.distance_to(_origin) > .08,
		"Multiple nudges did not consume their available travel"
	)


func _blocked_nudge():
	_reset()
	_heavy._update_mass_contacts(_delta)
	var side = (_ally.global_position - _origin).normalized()
	_reset()
	var blocker = _spawn("Tank", _human, Vector3(70, 0, 70))
	var distance: float = _light.radius + blocker.radius + .02
	blocker.global_position = _origin + side * distance
	_game.battlefield.invalidate()
	var before = _light._ground_motion_budget(_delta)
	_heavy._update_mass_contacts(_delta)
	_check(_ally.global_position == _origin, "Contact budget bypassed the blocking body")
	_check(
		is_equal_approx(_light._ground_motion_budget(_delta), before),
		"A rejected contact consumed travel"
	)
	blocker.queue_free()
	blocker.remove_from_group("units")
	_game.battlefield.invalidate()


func _phase_reset():
	_reset()
	_walk(Vector3.BACK)
	_check(_light.phase_shift(_origin + Vector3(0, 0, 8)), "Phase destination was rejected")
	var landing = _ally.global_position
	_check(landing.distance_to(_origin) > 7.5, "Phase was clipped by the old walking budget")
	_walk(Vector3.BACK)
	_bounded("Post-phase walking", landing)
	_check(
		_ally.global_position.distance_to(landing) > .08, "Phase did not reset the walking budget"
	)


func _vertical_settling():
	_reset()
	var raised := _origin + Vector3(15, .2, 0)
	_check(_light.relocate(raised), "Vertical settling fixture could not relocate")
	# Exhausting planar travel must not suspend a restored body's descent.
	_light._ground_motion_budget(_delta, _light.speed * _delta)
	_walk(Vector3.ZERO)
	_check(
		((_ally.global_position - raised) * Vector3(1, 0, 1)).length() < .00001,
		"Exhausted planar budget permitted horizontal movement during settling"
	)
	_check(
		_ally.global_position.y < raised.y - .01 and _ally.global_position.y >= -.001,
		"Exhausted planar budget prevented vertical settling or crossed the ground"
	)


func _transport_reset():
	var carrier = _spawn("AdvancedTank", _human, _origin + Vector3(15, 0, 0))
	await _frames(5)
	_check(carrier.garrison_mount != null, "Transport budget fixture has no firing mounts")
	_check(
		_light.relocate(carrier.global_position + Vector3.RIGHT * 2),
		"Transport budget fixture could not relocate its passenger"
	)
	_light._physics_delta = _delta
	var walking_origin = _ally.global_position
	_walk(Vector3.BACK)
	_check(
		_ally.global_position.distance_to(walking_origin) > .08,
		"Transport fixture did not spend its original walking allowance"
	)
	_check(carrier.enter(_ally), "Same-frame passenger embarkation failed")
	_check(not _ally.visible, "Same-frame mounted passenger remained visible")
	carrier.leave(_ally)
	_check(
		not _ally.has_meta("garrison_host") and _ally.visible, "Passenger did not unload visibly"
	)
	var landing = _ally.global_position
	var outward = ((landing - carrier.global_position) * Vector3(1, 0, 1)).normalized()
	_walk(outward)
	_bounded("Post-transport walking", landing)
	_check(
		_ally.global_position.distance_to(landing) > .08,
		"Same-frame transport retained the passenger's old walking debit"
	)
