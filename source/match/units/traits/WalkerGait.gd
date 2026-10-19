extends RefCounted

# Rigid-leg walkers (combat walkers and legged menders). Diagonal leg pairs
# alternate; a stance leg sweeps back exactly as far as the body travels and a
# swinging leg abducts to clear the ground. The hull rides over the planted legs.
# On stopping, legs stay planted and are then re-set one at a time like servos.

const AMPLITUDE = .26
const SWING_ABDUCT = .12
const SETTLE_SECONDS = .28
const START_SECONDS = .16


class Leg:
	var node: Node3D
	var rest: Basis
	var length: float
	var offset: float
	var side: float
	var angle := 0.0
	var abduct := 0.0
	var start := 0.0


var legs: Array[Leg] = []
var phase = 0.0
var heave = 0.0
var brace = 0.0
var _cycle = 1.0
var _moving = false
var _start_mix = 1.0
var _settle_index = -1
var _settle_from = 0.0
var _settle_time = 0.0


func setup(unit, nodes, initial_phase):
	for node in nodes:
		var side = -1.0 if "Left" in str(node.name) else 1.0
		var rear = "Rear" in str(node.name)
		var leg = Leg.new()
		leg.node = node
		leg.rest = node.basis
		leg.length = maxf(.2, _height(node, unit))
		leg.offset = 0.0 if (side < 0.0) != rear else .5
		leg.side = side
		legs.append(leg)
	phase = initial_phase
	if not legs.is_empty():
		_cycle = 4.0 * legs[0].length * sin(AMPLITUDE)


static func _height(node, ancestor):
	# Hip height above the unit's ground plane; valid before entering the tree.
	var point = Vector3.ZERO
	var current = node
	while current != null and current != ancestor:
		if current is Node3D:
			point = current.transform * point
		current = current.get_parent()
	return point.y


func advance(delta: float, distance: float, bracing: float):
	if legs.is_empty():
		return
	brace = move_toward(brace, bracing, delta * 3.0)
	var moving = distance > .0005
	if moving:
		if not _moving:
			_moving = true
			_settle_index = -1
			_start_mix = 0.0
			phase = TAU * .25
			for leg in legs:
				leg.start = leg.angle
		phase = fposmod(phase + distance / _cycle * TAU, TAU)
		_start_mix = minf(1.0, _start_mix + delta / START_SECONDS)
		var mix := smoothstep(0.0, 1.0, _start_mix)
		for leg in legs:
			var gait := _gait(fposmod(phase / TAU + leg.offset, 1.0))
			leg.angle = lerpf(leg.start, gait.x, mix)
			leg.abduct = gait.y * mix
	else:
		_moving = false
		_settle(delta)
	var lowest := 0.0
	for leg in legs:
		var abduct: float = leg.abduct + .1 * brace
		var pose := (
			Basis(Vector3.BACK, leg.side * abduct) * Basis(Vector3.RIGHT, leg.angle) * leg.rest
		)
		if leg.node.basis != pose:
			leg.node.basis = pose
		if leg.abduct < .02:
			lowest = maxf(lowest, leg.length * (1.0 - cos(leg.angle)))
	# Drop the hull so the planted feet stay on the ground; bracing crouches.
	heave = -lowest - legs[0].length * .045 * brace


func _gait(cycle: float) -> Vector2:
	if cycle < .5:
		return Vector2(asin(lerpf(sin(AMPLITUDE), -sin(AMPLITUDE), cycle * 2.0)), 0.0)
	var swing = (cycle - .5) * 2.0
	return Vector2(
		lerpf(-AMPLITUDE, AMPLITUDE, smoothstep(0.0, 1.0, swing)), sin(swing * PI) * SWING_ABDUCT
	)


func _settle(delta: float):
	if _settle_index >= 0:
		var leg: Leg = legs[_settle_index]
		_settle_time = minf(1.0, _settle_time + delta / SETTLE_SECONDS)
		leg.angle = lerpf(_settle_from, 0.0, smoothstep(0.0, 1.0, _settle_time))
		leg.abduct = sin(_settle_time * PI) * SWING_ABDUCT * .8
		if _settle_time >= 1.0:
			leg.abduct = 0.0
			_settle_index = -1
		return
	var widest = .01
	for index in range(legs.size()):
		legs[index].abduct = 0.0
		if absf(legs[index].angle) > widest:
			widest = absf(legs[index].angle)
			_settle_index = index
	if _settle_index >= 0:
		_settle_from = legs[_settle_index].angle
		_settle_time = 0.0
	else:
		for leg in legs:
			leg.angle = 0.0


func is_at_rest():
	return not _moving and _settle_index < 0 and brace <= .001


func copy_from(other):
	# Production exits hand their walking proxy over mid-stride.
	phase = other.phase
	_moving = other._moving
	_start_mix = 1.0
	for index in range(mini(legs.size(), other.legs.size())):
		legs[index].angle = other.legs[index].angle
		legs[index].abduct = other.legs[index].abduct
