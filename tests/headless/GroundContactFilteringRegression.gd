extends "res://tests/headless/MechanicsRegression.gd"


class SpeedProbe:
	extends NavigationAgent3D
	var domain = 1
	var ghosted = false
	var reads = 0
	var live_speed = 4.0
	var speed:
		get:
			reads += 1
			return live_speed


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _open("bastion")
	var own = _spawn("Tank", _human, Vector3(30, 0, 30))
	var other = _spawn("Tank", _human, Vector3(34, 0, 30))
	await _frames(12)
	var movement = own.get_node("Movement")
	movement.radius = 1.0
	var original = other._get_navigation_trait()
	var probe = SpeedProbe.new()
	probe.radius = 1.0
	other._navigation_trait = probe
	# None of these bodies can hit the segment, even if their speed changes.
	for point in [Vector3(-1, 0, 0), Vector3(1, 0, 4), Vector3(4, 0, 0)]:
		other.position = point
		probe.reads = 0
		var contact = movement._ground_contact_script(Vector3.ZERO, Vector3.RIGHT, [other])
		_check(contact == Vector4(0, 0, 0, 1), "Impossible contact blocked a step")
		_check(probe.reads == 0, "Impossible contact evaluated live speed modifiers")
	other.position = Vector3(2.48, 0, 0)
	probe.reads = 0
	var hit = movement._ground_contact_script(Vector3.ZERO, Vector3.RIGHT, [other])
	_check(absf(hit.w - .5) < .0001, "Swept contact did not stop at the hull")
	_check(hit.x == -1.0 and probe.reads == 1, "Real contact did not read live speed")
	for state in ["stopped", "ghosted", "airborne", "mobile"]:
		probe.live_speed = 0.0 if state == "stopped" else 4.0
		probe.ghosted = state == "ghosted"
		probe.domain = 0 if state == "airborne" else 1
		var contact = movement._ground_contact_script(Vector3.ZERO, Vector3.RIGHT, [other])
		_check(
			absf(contact.w - (.5 if state == "mobile" else 1.0)) < .0001,
			"Contact ignored a same-tick eligibility change: " + state
		)
	other._navigation_trait = original
	probe.free()
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Ground contact filtering: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
