extends SceneTree

var errors = []


class CinematicFixture:
	extends Node
	var settings = {"mission_id": ""}


func _initialize():
	_run.call_deferred()


func _camera():
	var camera = load("res://source/match/IsometricCamera3D.gd").new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees.x = -30
	root.add_child(camera)
	camera.set_process(false)
	return camera


func _run():
	var distances = []
	for fps in [30, 60, 144, 240]:
		var camera = _camera()
		var start = camera.position
		for frame in fps:
			camera._advance_pan(Vector3(20, 0, 8), 1.0 / fps)
		var released = camera.position
		for frame in fps:
			camera._advance_pan(Vector3.ZERO, 1.0 / fps)
		distances.append(camera.position - start)
		_check(camera.position.distance_to(released) > .5, "Pan stops without inertia")
		_check(camera._pan_velocity.is_zero_approx(), "Pan damping never settles")
		camera.free()
	for distance in distances:
		_check(distance.distance_to(distances[0]) < .0002, "Pan travel differs by display cadence")
	var camera = _camera()
	var pointer = root.get_visible_rect().size * .5
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.position = pointer
	press.pressed = true
	camera._try_handling_mouse_rotation(press)
	_check(camera._grab_anchor != null and not camera._is_rotating(), "MMB did not start map grab")
	var anchor = camera._grab_anchor
	var yaw = camera.rotation.y
	var motion = InputEventMouseMotion.new()
	motion.position = pointer + Vector2(80, 30)
	camera._input(motion)
	_check(is_equal_approx(yaw, camera.rotation.y), "Map grab rotated the view")
	var under_pointer = camera.get_ray_intersection_with_plane(
		motion.position, Plane(Vector3.UP, anchor.y)
	)
	_check(anchor.distance_to(under_pointer) < .001, "Map grab slipped from its world anchor")
	press.pressed = false
	camera._input(press)
	_check(camera._grab_anchor == null, "Release over HUD did not end map grab")
	press.pressed = true
	press.alt_pressed = true
	camera._try_handling_mouse_rotation(press)
	_check(
		camera._is_rotating() and camera._grab_anchor == null, "Alt + MMB did not start rotation"
	)
	camera._try_handling_mouse_rotation(motion)
	_check(not is_equal_approx(yaw, camera.rotation.y), "Alt + MMB did not rotate")
	camera._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not camera._is_rotating(), "Focus loss left rotation active")
	camera._pan_velocity = Vector3.ONE * 20
	camera.set_position_safely(Vector3(40, 0, 40))
	_check(camera._pan_velocity == Vector3.ZERO, "Minimap teleport retained pan inertia")
	camera.bounding_planes.assign([Plane(Vector3.RIGHT, 0), Plane(Vector3.LEFT, -50)])
	for frame in 120:
		camera._advance_pan(Vector3(200, 0, 0), 1.0 / 60)
	_check(camera._calculate_pivot_point().x <= 50.001, "Inertia crossed the map boundary")
	camera.free()
	_test_cinematic_authority()
	for message in errors:
		push_error(message)
	print("Camera feel regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(ok, message):
	if not ok:
		errors.append(message)


func _test_cinematic_authority():
	var game = CinematicFixture.new()
	root.add_child(game)
	var camera = _camera()
	camera.reparent(game)
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	_check(not camera.begin_campaign_cinematic(), "Skirmish opened cinematic impulse authority")
	_check(not camera.cinematic_impulse(.5), "Skirmish accepted explicit impulse")
	camera.trauma = .9
	camera.h_offset = .3
	camera._update_trauma(.1)
	_check(camera.trauma == 0 and camera.h_offset == 0, "Skirmish restored stale offsets")
	game.settings.mission_id = "first_orders"
	camera.add_trauma(.5)
	_check(camera.trauma == 0, "Ordinary Campaign combat shook camera")
	_check(not camera.cinematic_impulse(.5), "Campaign impulse needs explicit cinematic scope")
	_check(camera.begin_campaign_cinematic(), "Campaign script cannot open cinematic")
	_check(camera.cinematic_impulse(.5), "Explicit cinematic impulse rejected")
	camera._update_trauma(.1)
	_check(
		camera.trauma > 0 and camera.trauma < .5 and camera.h_offset != 0,
		"Cinematic impulse absent"
	)
	paused = true
	var before = camera.trauma
	camera._update_trauma(.1)
	_check(camera.trauma == before, "Pause advanced cinematic impulse")
	paused = false
	camera.end_campaign_cinematic()
	_check(
		camera.trauma == 0 and camera.h_offset == 0 and camera.v_offset == 0,
		"Cinematic end retained offsets"
	)
	camera.begin_campaign_cinematic()
	camera.cinematic_impulse(.5)
	game.settings.mission_id = ""
	camera._update_trauma(.01)
	_check(
		camera.trauma == 0 and not camera._cinematic_active, "Mode switch retained camera impulse"
	)
	game.settings.mission_id = "first_orders"
	options.reduced_flashes = true
	_check(
		not camera.begin_campaign_cinematic() and not camera.cinematic_impulse(.5),
		"Reduced motion allowed impulse"
	)
	options.reduced_flashes = reduced
	game.free()
