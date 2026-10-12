extends RefCounted

var rig
var hips
var chest
var head
var legs = []
var blend = 0.0
var phase = 0.0
var _chest_rest = Vector3(0, .62, 0)


func setup(unit, initial_phase):
	rig = unit.get_node("Geometry/InfantryRig")
	hips = rig.get_node("Hips")
	chest = rig.get_node("Chest")
	head = chest.get_node("Head")
	phase = initial_phase
	for side in ["Left", "Right"]:
		var hip = hips.get_node("Hip" + side)
		var knee = hip.get_node("Knee" + side)
		legs.append([hip, knee, knee.get_node("Ankle" + side)])
	advance(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)


func advance(delta, distance, clock, gesture, recoil, aiming):
	# Distance drives the gait, so blocked orders never run in place. Blend only
	# the pose on acceleration/stopping; each stance foot travels back linearly.
	var speed = distance / maxf(delta, .001)
	blend = move_toward(blend, clampf(speed / 1.8, 0.0, 1.0), delta * 7.0)
	phase = fposmod(phase + distance * TAU / .95, TAU)
	var breath = sin(clock * 2.2)
	var dip = (.045 + .012 * cos(phase * 2.0)) * blend
	hips.position.y = .55 - dip
	hips.rotation.y = sin(phase) * .035 * blend
	chest.position = _chest_rest + Vector3(0, -dip + breath * .003, recoil * .012)
	chest.rotation = Vector3(
		-.055 * blend - recoil * .035,
		-sin(phase) * .025 * blend,
		sin(phase) * .018 * blend + gesture * .018
	)
	head.rotation = Vector3(.035 * blend, gesture * .12 * (1.0 - aiming), -chest.rotation.z * .6)
	for index in range(2):
		var cycle = fposmod(phase / TAU + index * .5, 1.0)
		var z = 0.0
		var lift = 0.0
		if cycle < .5:
			z = lerpf(-.2375, .2375, cycle * 2.0)
		else:
			var swing = (cycle - .5) * 2.0
			z = lerpf(.2375, -.2375, smoothstep(0.0, 1.0, swing))
			lift = sin(swing * PI) * .105
		z = lerpf(-.045 if index == 0 else .045, z, blend)
		var y = .045 + lift * blend - hips.position.y
		_pose_leg(legs[index], y, z)


func _pose_leg(parts, y, z):
	# Analytic two-bone solve: knees bend forward, ankles counter-rotate so
	# soles stay flat. The foot remains at ground height throughout stance.
	var reach = minf(Vector2(y, z).length(), .5199)
	var bend = acos(clampf(reach / .52, 0.0, 1.0))
	parts[0].rotation.x = atan2(-z, -y) + bend
	parts[1].rotation.x = -2.0 * bend
	parts[2].rotation.x = -parts[0].rotation.x - parts[1].rotation.x
