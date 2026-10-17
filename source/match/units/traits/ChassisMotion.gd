extends RefCounted

# Visual-only body dynamics for mobile units. It reads the unit's authoritative
# transform (never writes it) and produces a Geometry offset: an eased heading
# instead of instant snaps, suspension pitch/roll from acceleration and turning,
# hover float, aircraft banking and drift, and a warm engine idle after driving.

enum Kind { TRACKED, WHEELED, HOVER, WALKER, AIR, INFANTRY }

const STEP = 1.0 / 60.0
const REST = .0001
# Root turns faster than this are order snaps or filter catch-up: ease them out
# instead of feeding them forward. Slower, steady path turns are followed exactly
# so the hull never crabs or drifts through a curve.
const SNAP_RATE = 4.0
# kind: [heading omega, max heading lag, body omega, body damping ratio,
#        pitch per m/s2, roll per m/s2, tilt limit, velocity smoothing seconds]
const TUNING = {
	Kind.TRACKED: [10.0, .55, 8.0, .42, .0045, .0035, .055, .14],
	Kind.WHEELED: [12.0, .5, 10.0, .38, .005, .0045, .06, .12],
	Kind.HOVER: [8.5, .7, 5.0, .3, .006, -.008, .1, .16],
	Kind.WALKER: [10.0, .6, 9.0, .5, .003, .003, .04, .12],
	Kind.AIR: [7.5, .8, 7.0, .6, -.009, -.022, .42, .12],
	Kind.INFANTRY: [17.0, 1.3, 14.0, .7, .012, .012, .12, .08],
}

var kind = Kind.TRACKED
var velocity := Vector3.ZERO
var accel := Vector2.ZERO
var forward_speed := 0.0
var yaw_lag := 0.0
var pitch := 0.0
var pitch_velocity := 0.0
var roll := 0.0
var roll_velocity := 0.0
var heave := 0.0
var heave_velocity := 0.0
var engine := 0.0
# Long-idle weight from the owner: parked engines keep a faint idle shudder.
var idle := 0.0
var clock := 0.0
var max_speed := 4.0
var length := 2.0
var _tuning := PackedFloat64Array(TUNING[Kind.TRACKED])
var _drift := Vector3.ONE
var _previous := Transform3D.IDENTITY
var _root_yaw := 0.0
var _root_rate := 0.0
var _visual_yaw := 0.0
var _visual_rate := 0.0
var _started := false
var _floating := false
var _engine_driven := true
var _step := 0.0
var _velocity_weight := 0.0
var _accel_weight := 0.0
var _rate_weight := 0.0


func configure(motion_kind, profile, top_speed, body_length):
	kind = motion_kind
	_tuning = PackedFloat64Array(TUNING[kind])
	_tuning[0] *= profile.yaw_response
	_drift = profile.drift_rates
	clock = profile.phase
	max_speed = maxf(.5, top_speed)
	length = body_length
	_floating = kind == Kind.HOVER or kind == Kind.AIR
	_engine_driven = kind == Kind.TRACKED or kind == Kind.WHEELED
	_smoothing(STEP)


func _smoothing(step: float):
	# Exponential smoothing weights for one integration step (cached per step size).
	_step = step
	_velocity_weight = 1.0 - exp(-step / _tuning[7])
	_accel_weight = 1.0 - exp(-step / .08)
	_rate_weight = 1.0 - exp(-step / .06)


static func _yaw(basis: Basis) -> float:
	# Units only ever yaw, so the heading is read straight off the basis.
	return atan2(basis.z.x, basis.z.z)


func reset(current: Transform3D):
	_previous = current
	_root_yaw = _yaw(current.basis)
	_visual_yaw = _root_yaw
	_visual_rate = 0.0
	_root_rate = 0.0
	_started = true
	velocity = Vector3.ZERO
	accel = Vector2.ZERO
	forward_speed = 0.0
	yaw_lag = 0.0


func advance(delta: float, current: Transform3D):
	if delta <= 0.0:
		return
	if not _started:
		reset(current)
	clock += delta
	var travel := (current.origin - _previous.origin) * Vector3(1, 0, 1)
	var yaw := _yaw(current.basis)
	var turn_rate := angle_difference(_root_yaw, yaw) / delta
	_previous = current
	_root_yaw = yaw
	# Spawns, restores and garrison exits relocate instantly; never animate a jump.
	if travel.length_squared() > maxf(1.0, max_speed * delta * 4.0) ** 2:
		reset(current)
		return
	if absf(turn_rate) > SNAP_RATE:
		turn_rate = 0.0
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(-forward.z, 0, forward.x)
	var raw_velocity := travel / delta
	var steps := maxi(1, ceili(delta / STEP - .001))
	var step := delta / steps
	if not is_equal_approx(step, _step):
		_smoothing(step)
	for index in range(steps):
		var previous_velocity := velocity
		velocity = velocity.lerp(raw_velocity, _velocity_weight)
		var change := (velocity - previous_velocity) / step
		accel = accel.lerp(Vector2(change.dot(forward), change.dot(right)), _accel_weight)
		_root_rate = lerpf(_root_rate, turn_rate, _rate_weight)
		_integrate(step)
	forward_speed = velocity.dot(forward)
	var moving := raw_velocity.length_squared() > .0004
	engine = 1.0 if moving else move_toward(engine, 0.0, delta / 1.5)


func _integrate(step: float):
	# Heading: critically damped toward the root, with steady turn rates fed forward.
	var omega: float = _tuning[0]
	var error := angle_difference(_visual_yaw, _root_yaw)
	_visual_rate += (omega * omega * error + 2.0 * omega * (_root_rate - _visual_rate)) * step
	_visual_yaw = wrapf(_visual_yaw + _visual_rate * step, -PI, PI)
	clamp_lag(_tuning[1])
	var limit: float = _tuning[6]
	var pitch_target := clampf(accel.x * _tuning[4], -limit, limit)
	var roll_target := clampf(accel.y * _tuning[5], -limit, limit)
	if kind == Kind.AIR:
		# Rotorcraft tip the nose down to cruise and flare when braking.
		pitch_target = clampf(
			pitch_target - .1 * clampf(forward_speed / max_speed, -1.0, 1.0), -limit, limit
		)
	var body: float = _tuning[2]
	var damping: float = 2.0 * _tuning[3] * body
	pitch_velocity += (body * body * (pitch_target - pitch) - damping * pitch_velocity) * step
	pitch += pitch_velocity * step
	roll_velocity += (body * body * (roll_target - roll) - damping * roll_velocity) * step
	roll += roll_velocity * step
	heave_velocity += (-body * body * 1.5 * heave - damping * heave_velocity) * step
	heave += heave_velocity * step


func clamp_lag(limit: float):
	yaw_lag = angle_difference(_root_yaw, _visual_yaw)
	if absf(yaw_lag) > limit:
		yaw_lag = clampf(yaw_lag, -limit, limit)
		_visual_yaw = _root_yaw + yaw_lag
		_visual_rate = lerpf(_visual_rate, _root_rate, .5)


func impulse(push_local: Vector3, strength: float):
	# A hit shoves the body away from the source and lets the suspension ring out.
	pitch_velocity += push_local.z * strength
	roll_velocity -= push_local.x * strength
	heave_velocity -= strength * .25


func is_settled():
	if _floating or _running() > 0.0:
		return false
	return (
		absf(yaw_lag) <= REST
		and absf(_visual_rate) <= REST
		and absf(_root_rate) <= REST
		and absf(pitch) <= REST
		and absf(pitch_velocity) <= REST
		and absf(roll) <= REST
		and absf(roll_velocity) <= REST
		and absf(heave) <= REST
		and absf(heave_velocity) <= REST
	)


func settle():
	_visual_yaw = _root_yaw
	_visual_rate = 0.0
	_root_rate = 0.0
	yaw_lag = 0.0
	pitch = 0.0
	pitch_velocity = 0.0
	roll = 0.0
	roll_velocity = 0.0
	heave = 0.0
	heave_velocity = 0.0


func _running():
	return maxf(engine, idle * .6) if _engine_driven else 0.0


func offset_rotation(extra_pitch = 0.0):
	var running = _running()
	var rumble := 0.0
	if running > 0.0:
		rumble = running * (sin(clock * 31.0) + sin(clock * 47.0 + 1.3)) * .0007
	var bank = roll
	var nose = pitch + extra_pitch
	if kind == Kind.HOVER:
		nose += sin(clock * _drift.z * 1.7) * .012
		bank += sin(clock * _drift.x * 1.4 + .8) * .016
	elif kind == Kind.AIR:
		nose += sin(clock * _drift.z * 1.3) * .02
		bank += sin(clock * _drift.x * 1.9 + .4) * .03
	return Vector3(nose + rumble, yaw_lag, bank + rumble * .6)


func offset_position():
	var lift = heave
	# Keep tilted hulls from dipping their lower edge into the ground.
	if not _floating:
		lift += (absf(pitch) * length + absf(roll) * length * .6) * .32
		lift += _running() * sin(clock * 39.0) * .0012
		return Vector3(0, lift, 0)
	if kind == Kind.HOVER:
		return Vector3(
			0, lift + sin(clock * _drift.y * 2.1) * .03 + sin(clock * _drift.x * 3.3) * .008, 0
		)
	if kind == Kind.AIR:
		var calm = 1.0 - clampf(absf(forward_speed) / max_speed, 0.0, 1.0) * .6
		return Vector3(
			sin(clock * _drift.x) * .04 * calm,
			lift + sin(clock * _drift.y * 1.6) * .045,
			sin(clock * _drift.z + 1.1) * .04 * calm
		)
	return Vector3(0, lift, 0)
