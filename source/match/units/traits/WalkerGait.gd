extends RefCounted

# Articulated four-legged robots. Stance feet stay in world space; diagonal
# pairs lift, transfer and plant with a short overlap of all four supports.
# IK bends the knees and counter-rotates the ankles, including hull suspension.
# Only model pivots are written. Navigation and collision remain authoritative.
const STANCE = .6
const STOP_GRACE_SECONDS = .06
const SETTLE_SECONDS = .22


class Leg:
	var node: Node3D
	var knee: Node3D
	var ankle: Node3D
	var rest: Basis
	var knee_rest: Basis
	var ankle_rest: Basis
	var parent_rest: Transform3D
	var parent_inverse: Transform3D
	var upper: Vector3
	var lower: Vector3
	var rest_upper: Vector3
	var rest_lower: Vector3
	var support_upper: Vector3
	var support_lower: Vector3
	var upper_direction: Vector3
	var lower_direction: Vector3
	var upper_length: float
	var lower_length: float
	var rest_knee: Basis
	var pole: Vector3
	var home: Vector3
	var foot: Vector3
	var start: Vector3
	var landing: Vector3
	var foot_basis: Basis
	var length: float
	var offset: float
	var swing := false
	var progress := 0.0
	var duration := 1.0 - STANCE


var legs: Array[Leg] = []
var phase := 0.0
var heave := 0.0
var brace := 0.0
var _cycle := 1.0
var _moving := false
var _travel_idle := INF
var _blend := 0.0
var _settle_index := -1
var _settle_time := 0.0
var _previous := Transform3D.IDENTITY


static func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	while node != ancestor and node != null:
		result = node.transform * result
		node = node.get_parent() as Node3D
	return result


func setup(unit, nodes, initial_phase):
	legs.clear()
	var geometry = unit.get_node("Geometry")
	for node in nodes:
		var knee = node.find_child("*KneePivot*", true, false)
		var ankle = node.find_child("*AnklePivot*", true, false)
		assert(knee != null and ankle != null, "Walker requires knee and ankle pivots")
		if knee == null or ankle == null:
			continue
		var leg := Leg.new()
		leg.node = node
		leg.knee = knee
		leg.ankle = ankle
		leg.rest = node.basis
		leg.knee_rest = knee.basis
		leg.ankle_rest = ankle.basis
		leg.parent_rest = _relative(node.get_parent(), geometry)
		leg.parent_inverse = leg.parent_rest.affine_inverse()
		leg.upper = knee.position
		leg.lower = knee.basis * ankle.position
		# Authored segment geometry is constant; only the body and joint poses move.
		leg.rest_upper = leg.rest * leg.upper
		leg.rest_lower = leg.rest * leg.lower
		leg.support_upper = leg.parent_rest.basis * leg.rest_upper
		leg.support_lower = leg.parent_rest.basis * leg.rest_lower
		leg.upper_direction = leg.rest_upper.normalized()
		leg.lower_direction = leg.rest_lower.normalized()
		leg.upper_length = leg.rest_upper.length()
		leg.lower_length = leg.rest_lower.length()
		leg.rest_knee = leg.rest * leg.knee_rest
		var side = -1.0 if "Left" in str(node.name) else 1.0
		var rear = "Rear" in str(node.name)
		# Outward knee bend is stable even when the leg is nearly straight.
		leg.pole = Vector3(side, .35, .35 if rear else -.35).normalized()
		leg.offset = 0.0 if (side < 0.0) != rear else .5
		var foot_rest := _relative(ankle, unit)
		leg.home = foot_rest.origin
		leg.foot = leg.home
		leg.start = leg.home
		leg.landing = leg.home
		leg.foot_basis = foot_rest.basis
		leg.length = _relative(node, unit).origin.y
		legs.append(leg)
	phase = fposmod(initial_phase, TAU)
	_previous = unit.global_transform
	if not legs.is_empty():
		_cycle = legs[0].length * .85


func advance(delta: float, distance: float, bracing: float, root: Transform3D):
	if legs.is_empty() or delta <= 0.0:
		return
	var rebase := root.affine_inverse() * _previous
	_previous = root
	# Teleports and production exits are placements, not strides.
	if rebase.origin.length() > 1.0:
		for leg in legs:
			leg.foot = leg.home
			leg.swing = false
		_moving = false
		_settle_index = -1
		rebase = Transform3D.IDENTITY
		distance = 0.0
	var travel := distance
	for leg in legs:
		travel = maxf(travel, leg.home.distance_to(rebase * leg.home))
		leg.foot = rebase * leg.foot
		leg.start = rebase * leg.start
		leg.landing = rebase * leg.landing
	var traveling := travel > maxf(.0000001, delta * .02)
	_travel_idle = 0.0 if traveling else _travel_idle + delta
	var moving := traveling or (_moving and _travel_idle < STOP_GRACE_SECONDS)
	brace = move_toward(brace, bracing, delta * 3.0)
	var recovering := false
	for leg in legs:
		recovering = recovering or leg.swing or leg.foot.distance_to(leg.home) > .002
	_blend = move_toward(_blend, 1.0 if moving or recovering else 0.0, delta * 5.0)
	if moving:
		var starting := not _moving
		if starting:
			# Start with four supports; then transfer the first diagonal pair.
			phase = TAU * (.3 if sin(phase) >= 0.0 else .8)
			_settle_index = -1
		phase = fposmod(phase + travel / _cycle * TAU, TAU)
		for leg in legs:
			var cycle := fposmod(phase / TAU + leg.offset, 1.0)
			if not leg.swing and cycle >= STANCE:
				leg.swing = true
				leg.start = leg.foot
				leg.duration = 1.0 - cycle if starting else 1.0 - STANCE
				leg.progress = 0.0 if starting else (cycle - STANCE) / leg.duration
				var heading := leg.home - rebase * leg.home
				heading.y = 0.0
				leg.landing = (
					leg.home + heading.normalized() * _cycle * (1.0 - cycle + STANCE * .5)
				)
				_step(leg, leg.progress)
			elif leg.swing:
				leg.progress = minf(1.0, leg.progress + travel / (_cycle * leg.duration))
				_step(leg, leg.progress)
				if leg.progress >= 1.0:
					leg.swing = false
	else:
		_settle(delta)
	_moving = moving
	# Lower the chassis into its working stance, opening knee travel. A small
	# compression at each support transfer gives the machine weight.
	heave = -legs[0].length * (.3 * _blend + .07 * brace)
	heave -= legs[0].length * .012 * _blend * pow(sin(phase * 2.0), 2.0)


func _step(leg: Leg, amount: float):
	# Lift before the main transfer, then lower after it; soles never paddle.
	var transfer := smoothstep(.12, .88, amount)
	leg.foot = leg.start.lerp(leg.landing, transfer)
	var lift := smoothstep(0.0, .28, amount) * (1.0 - smoothstep(.65, 1.0, amount))
	leg.foot.y += leg.length * .22 * lift


func _settle(delta: float):
	if _settle_index < 0:
		# Recover airborne feet first, then re-center remaining feet one at a time.
		var largest := .002
		for index in range(legs.size()):
			var leg := legs[index]
			var error := leg.foot.distance_to(leg.home) + (1.0 if leg.swing else 0.0)
			if error > largest:
				largest = error
				_settle_index = index
		if _settle_index < 0:
			return
		var leg := legs[_settle_index]
		leg.start = leg.foot
		leg.landing = leg.home
		_settle_time = 0.0
	var leg := legs[_settle_index]
	_settle_time = minf(1.0, _settle_time + delta / SETTLE_SECONDS)
	_step(leg, _settle_time)
	if _settle_time >= 1.0:
		leg.swing = false
		_settle_index = -1


func support_body(body: Transform3D) -> Transform3D:
	# An instant navigation start or turn can precede the suspension's crouch.
	# Keep the hull inside the planted legs' reach instead of stretching the
	# joints and letting the soles slide while the suspension catches up.
	var drop := 0.0
	for leg in legs:
		var parent := body * leg.parent_rest
		var hip := parent * leg.node.position
		var reach := (
			(body.basis * leg.support_upper).length()
			+ (body.basis * leg.support_lower).length()
			- .001
		)
		var horizontal := Vector2(leg.foot.x - hip.x, leg.foot.z - hip.z).length_squared()
		var height := sqrt(maxf(0.0, reach * reach - horizontal))
		drop = minf(drop, leg.foot.y + height - hip.y)
	body.origin.y += maxf(drop, -legs[0].length * .4) if not legs.is_empty() else 0.0
	return body


func pose(body: Transform3D):
	var body_inverse := body.affine_inverse()
	for leg in legs:
		var parent := body * leg.parent_rest
		var target := leg.parent_inverse * (body_inverse * leg.foot) - leg.node.position
		var a := leg.upper_length
		var b := leg.lower_length
		var reach := clampf(target.length(), absf(a - b) + .0001, a + b - .0001)
		var direction := target.normalized()
		var pole := leg.pole - direction * leg.pole.dot(direction)
		pole = pole.normalized()
		var along := (a * a - b * b + reach * reach) / (2.0 * reach)
		var knee := direction * along + pole * sqrt(maxf(0.0, a * a - along * along))
		var hip_basis := Basis(Quaternion(leg.upper_direction, knee.normalized())) * leg.rest
		var shin_basis := Basis(
			Quaternion(leg.lower_direction, (direction * reach - knee).normalized())
		)
		leg.node.basis = hip_basis
		leg.knee.basis = hip_basis.inverse() * shin_basis * leg.rest_knee
		# Cancel both joint rotation and chassis pitch/roll at the sole.
		leg.ankle.basis = (parent.basis * hip_basis * leg.knee.basis).inverse() * leg.foot_basis


func is_at_rest():
	if _moving or _settle_index >= 0 or brace > .001 or _blend > .001:
		return false
	for leg in legs:
		if leg.swing or leg.foot.distance_to(leg.home) > .002:
			return false
	return true


func copy_from(other):
	# Production exits hand their walking proxy over mid-stride. Foot coordinates
	# are local to each unit, so relocation does not retain the proxy's world root.
	phase = other.phase
	_moving = other._moving
	_travel_idle = other._travel_idle
	_blend = other._blend
	heave = other.heave
	brace = other.brace
	_settle_index = other._settle_index
	_settle_time = other._settle_time
	for index in range(mini(legs.size(), other.legs.size())):
		var leg := legs[index]
		var source: Leg = other.legs[index]
		leg.foot = source.foot
		leg.start = source.start
		leg.landing = source.landing
		leg.swing = source.swing
		leg.progress = source.progress
		leg.duration = source.duration
