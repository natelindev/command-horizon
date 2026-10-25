extends RefCounted

# Procedural locomotion for the shared infantry rig. Stride length follows ground
# speed and a stance foot sweeps back exactly as far as the body travels, so
# soldiers never skate. Stopping takes real recovery steps, firing settles into
# a braced (or kneeling) stance, and the weapon carries low until it is raised.
# Only Geometry descendants are posed; the unit root is never touched.

const THIGH = .26
const SHIN = .26
const REACH = .5199
const HIP_HEIGHT = .55
const KNEEL_HEIGHT = .37
const FOOT_HEIGHT = .045
const CHEST_REST = Vector3(0, .62, 0)
const CARRY_PIVOT = Vector3(0, .25, 0)
const SETTLE_SECONDS = .2
# Render frames between simulation ticks are not a stop command.
const STOP_GRACE_SECONDS = .06
# Weapon and grip targets move together; the arms solve from fixed shoulders.
const CARRIED = [
	"GripLeft",
	"GripRight",
	"RifleStock",
	"RifleReceiver",
	"RifleMagazine",
	"RifleBarrel",
	"RifleMuzzle",
	"StockEmitter",
	"Launcher",
	"LaunchMouth",
	"RocketTip",
	"Optic",
	"ClassMuzzle",
	"PrecisionStock",
	"LongBarrel",
	"Suppressor",
	"Scope",
	"DrumMagazine",
	"BreachingShield",
	"TowerShield",
	"HeavyWarhead",
	"ShieldMark",
	"MarshalShield",
	"Lance",
]
# role: [low-ready pitch, recoil kick, stride scale, upright, kneels to fire,
#        carry yaw/roll across the body, shoulder raise]
const ROLES = {
	"Infantry": [-.30, 1.0, 1.0, 0.0, false, Vector2(.14, -.12), .18],
	"RocketInfantry": [-.12, 1.9, .97, 0.0, true, Vector2(.03, -.02), .18],
	"SniperInfantry": [-.36, 1.5, 1.0, 0.0, true, Vector2(.12, -.1), .27],
	"AssaultInfantry": [-.24, .7, .96, 0.0, false, Vector2(.1, -.08), .18],
	"Hero": [-.18, 1.1, 1.08, .6, false, Vector2(.1, -.08), .18],
}

var rig
var hips
var chest
var head
var head_rest := Vector3.ZERO
var weapon
var legs := []
var arms := []
var blend := 0.0
var phase := 0.0
var speed := 0.0
var aim := 0.0
var brace := 0.0
# Set by the owner before advance(): eased body lean (x forward, y into turns),
# hit flinch (pitch, yaw, roll), head lead toward a new heading and idle fidget.
var lean := Vector2.ZERO
var flinch := Vector3.ZERO
var turn_lead := 0.0
var fidget := 0
var stride_scale := 1.0
var lead_foot := 0
var deferred_job = null
var _role = ROLES["Infantry"]
var _feet: Array[Vector3] = []
var _stance: Array[Vector3] = []
var _start_feet: Array[Vector3] = []
var _start_mix := 1.0
var _settle_foot := -1
var _settle_from := Vector3.ZERO
var _settle_time := 0.0
var _hip_height = HIP_HEIGHT
var _moving := false
var _travel_idle := INF
# Last written poses; unchanged parts are not rewritten (each write dirties a subtree).
var _posed_pelvis = Transform3D()
var _posed_feet: Array[Vector3] = []
var _posed_carry = Transform3D()
var _unit
var _suppressed_target = 0.0
var _pinned_target = 0.0
var _suppressed_pose = 0.0
var _pinned_pose = 0.0


func setup(unit, initial_phase, role = "Infantry"):
	_unit = unit
	rig = unit.get_node("Geometry/InfantryRig")
	hips = rig.get_node("Hips")
	chest = rig.get_node("Chest")
	head = chest.get_node("Head")
	head_rest = head.position
	phase = initial_phase
	var Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")
	_role = ROLES.get(Mercenaries.UNITS.get(role, {}).get("base", role), ROLES["Infantry"])
	stride_scale = _role[2]
	weapon = chest.get_node_or_null("WeaponCarry")
	if weapon == null:
		weapon = Node3D.new()
		weapon.name = "WeaponCarry"
		weapon.position = CARRY_PIVOT
		chest.add_child(weapon)
		_carry(chest, Transform3D.IDENTITY)
	for side in ["Left", "Right"]:
		var arm = chest.get_node("Arm" + side)
		var elbow = arm.get_node("Elbow" + side)
		var wrist = elbow.get_node("Wrist" + side)
		arms.append(
			{
				"upper": arm,
				"lower": elbow,
				"wrist": wrist,
				"grip": weapon.get_node("Grip" + side),
				"upper_rest": elbow.position,
				"lower_rest": wrist.position,
				"pole": Vector3(-1 if side == "Left" else 1, -.8, .25)
			}
		)
	for side in ["Left", "Right"]:
		var hip = hips.get_node("Hip" + side)
		var knee = hip.get_node("Knee" + side)
		legs.append([hip, knee, knee.get_node("Ankle" + side)])
	for index in range(2):
		var foot = _stance_foot(index, 0.0)
		_feet.append(foot)
		_stance.append(foot)
		_start_feet.append(foot)
	advance(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)


func _carry(parent, relative):
	# Reparent in rig-local space; the rig may not be inside the tree yet.
	for child in parent.get_children():
		if child == weapon:
			continue
		var local = relative * child.transform
		if str(child.name) in CARRIED:
			parent.remove_child(child)
			weapon.add_child(child)
			child.transform = weapon.transform.affine_inverse() * local
		elif str(child.name) == "ClassEquipment":
			_carry(child, local)


func advance(
	delta: float, distance: float, clock: float, gesture: float, recoil: float, aiming: float
):
	var band = _unit.suppression.band if "suppression" in _unit and _unit.suppression != null else 0
	_suppressed_target = 1.0 if band > 0 else 0.0
	_pinned_target = 1.0 if band == 2 else 0.0
	if deferred_job != null:
		deferred_job.configure(delta, distance, clock, gesture, recoil, aiming)
		return
	advance_pose(delta, distance, clock, gesture, recoil, aiming)


func advance_pose(
	delta: float, distance: float, clock: float, gesture: float, recoil: float, aiming: float
):
	_suppressed_pose = move_toward(_suppressed_pose, _suppressed_target, delta * 4.0)
	_pinned_pose = move_toward(_pinned_pose, _pinned_target, delta * 3.0)
	# Gait runs in rig units; a scaled rig (heroes) must not out-stride its body.
	distance /= rig.scale.z
	# Detect speed, not a fixed distance per rendered frame. Preserve the stride
	# through brief zero-distance samples when rendering outpaces physics.
	var traveling: bool = distance > maxf(.0000001, delta * .02)
	_travel_idle = 0.0 if traveling else _travel_idle + delta
	var moving: bool = traveling or (_moving and _travel_idle < STOP_GRACE_SECONDS)
	if delta > 0.0:
		speed = lerpf(speed, distance / delta, 1.0 - exp(-delta * 10.0))
	if not moving:
		speed = move_toward(speed, 0.0, delta * 6.0)
	blend = move_toward(blend, clampf(speed / 1.4, 0.0, 1.0) if moving else 0.0, delta * 6.0)
	aim = move_toward(aim, aiming, delta * (6.0 if aiming > aim else 2.5))
	var stationary_aim: float = aiming if not moving else 0.0
	brace = move_toward(brace, stationary_aim, delta * (4.0 if stationary_aim > brace else 2.0))
	var kneeling: float = maxf(brace if _role[4] else 0.0, _suppressed_pose * 0.75)
	_hip_height = lerpf(HIP_HEIGHT - .02 * brace, KNEEL_HEIGHT, kneeling)
	_hip_height = lerpf(_hip_height, 0.19, _pinned_pose)
	_update_feet(delta, distance, moving, kneeling)
	for index in range(2):
		var crawl = Vector3(
			(-1.0 if index == 0 else 1.0) * 0.15,
			FOOT_HEIGHT,
			0.55 + sin(phase + index * PI) * blend * 0.12
		)
		_feet[index] = _feet[index].lerp(crawl, _pinned_pose)

	var breath: float = sin(clock * 2.2)
	var stride_wave: float = cos(phase * 2.0)
	var dip: float = (.04 + .012 * stride_wave) * blend * clampf(speed / 2.5, .5, 1.0)
	var shift: float = -sin(phase) * .018 * blend
	if fidget == 1:
		shift += gesture * .03
	# Each part is written once per frame as a whole transform.
	var pelvis: Transform3D = Transform3D(
		Basis.from_euler(Vector3(0, sin(phase) * .035 * blend, -shift * .5)),
		Vector3(shift, _hip_height - dip, 0)
	)
	var upright: float = 1.0 - _role[3] * .5
	var kick: float = recoil * _role[1]
	var torso: Vector3 = Vector3(
		(
			(-.035 - .03 * clampf(speed / 3.5, 0.0, 1.0)) * blend * upright
			- lean.x
			- kick * .035
			- brace * .05
			- kneeling * .06
			+ flinch.x
			+ (gesture * .05 if fidget == 3 else 0.0)
			+ breath * .006
		),
		(
			-sin(phase) * .025 * blend
			+ brace * .1
			+ (gesture * .14 if fidget == 0 else 0.0)
			+ flinch.y
		),
		sin(phase) * .018 * blend + lean.y + flinch.z + (gesture * .018 if fidget != 0 else 0.0)
	)
	torso.x = lerpf(torso.x, -1.25, _pinned_pose)
	chest.transform = Transform3D(
		Basis.from_euler(torso),
		(
			CHEST_REST
			+ Vector3(shift * .6, _hip_height - HIP_HEIGHT - dip + breath * .003, kick * .014)
			+ Vector3(0, 0, flinch.x * .08 - _pinned_pose * 0.18)
		)
	)
	head.position = head_rest + Vector3(.025, -.022, -.018) * aim
	var look: float = gesture * .45 * (1.0 - aim) if fidget == 0 else gesture * .1 * (1.0 - aim)
	head.rotation = Vector3(
		.035 * blend - torso.x * .55 - aim * .12 - (absf(gesture) * .35 if fidget == 2 else 0.0),
		clampf(turn_lead, -.6, .6) + look - brace * .08 + flinch.y * 1.5,
		-torso.z * .6 + flinch.z * 1.4
	)
	head.rotation.x += _pinned_pose * 0.65
	# Low ready while relaxed or moving; raised to the shoulder when aiming.
	var low: float = _role[0] * (1.0 if moving else .7)
	var carry_bob: float = sin(phase * 2.0 + .6) * .035 * blend * (1.0 - aim)
	var carry: Vector3 = Vector3(
		low * (1.0 - aim) + carry_bob + kick * .09 + (absf(gesture) * .25 if fidget == 2 else 0.0),
		_role[5].x * (1.0 - aim),
		_role[5].y * (1.0 - aim) + (gesture * .45 if fidget == 2 else 0.0)
	)
	# Counter-rotate the shoulder assembly so prone rifles stay horizontal.
	carry.x += _pinned_pose * 1.25
	var carried: Transform3D = Transform3D(
		Basis.from_euler(carry), CARRY_PIVOT + Vector3(0, aim * _role[6], kick * .035)
	)
	if carried != _posed_carry:
		_posed_carry = carried
		weapon.transform = carried
		# Arms and grips share chest space; torso motion preserves this local solve.
		_pose_arms()
	# Standing still, the pelvis and boots are often unchanged: skip the leg solve.
	if pelvis != _posed_pelvis or _feet != _posed_feet:
		_posed_pelvis = pelvis
		_posed_feet = _feet.duplicate()
		hips.transform = pelvis
		var to_pelvis: Transform3D = pelvis.affine_inverse()
		for index in range(2):
			_pose_leg(legs[index], to_pelvis * _feet[index], -shift * .5)


func _stance_foot(index: int, kneeling: float) -> Vector3:
	# Relaxed stance is shoulder width; braced shooters blade their feet and
	# kneeling shooters drop the rear knee to the ground.
	var side: float = -1.0 if index == 0 else 1.0
	var relaxed: Vector3 = Vector3(side * .1, FOOT_HEIGHT, side * .04)
	var braced: Vector3 = Vector3(side * .12, FOOT_HEIGHT, side * .13)
	var kneel: Vector3 = Vector3(side * .1, FOOT_HEIGHT, -.2 if index == 0 else .31)
	return relaxed.lerp(braced, brace).lerp(kneel, kneeling)


func _gait_foot(index: int) -> Vector3:
	var stride: float = stride_length()
	var reach: float = stride * .25
	var cycle: float = fposmod(phase / TAU + index * .5, 1.0)
	var z: float = 0.0
	var lift: float = 0.0
	if cycle < .5:
		z = lerpf(-reach, reach, cycle * 2.0)
	else:
		var swing: float = (cycle - .5) * 2.0
		z = lerpf(reach, -reach, smoothstep(0.0, 1.0, swing))
		lift = sin(swing * PI) * clampf(.05 + .018 * speed, .05, .12)
	return Vector3((-1.0 if index == 0 else 1.0) * .09, FOOT_HEIGHT + lift, z)


func stride_length() -> float:
	# Short steps when creeping, full strides at a run.
	return clampf(.5 + .13 * speed, .55, 1.0) * stride_scale


func _update_feet(delta: float, distance: float, moving: bool, kneeling: float):
	if moving:
		if not _moving:
			# Step off from a near-neutral pose with the unit's lead foot.
			_moving = true
			_settle_foot = -1
			phase = TAU * (.25 if lead_foot == 0 else .75)
			_start_mix = 0.0
			for index in range(2):
				_start_feet[index] = _feet[index]
		phase = fposmod(phase + distance * TAU / stride_length(), TAU)
		_start_mix = minf(1.0, _start_mix + delta / .14)
		var mix: float = smoothstep(0.0, 1.0, _start_mix)
		for index in range(2):
			_feet[index] = _start_feet[index].lerp(_gait_foot(index), mix)
		return
	_moving = false
	for index in range(2):
		_stance[index] = _stance_foot(index, kneeling)
	if _settle_foot >= 0:
		_settle_time += delta / SETTLE_SECONDS
		var progress: float = minf(1.0, _settle_time)
		var target: Vector3 = _stance[_settle_foot]
		var foot: Vector3 = _settle_from.lerp(target, smoothstep(0.0, 1.0, progress))
		foot.y += sin(progress * PI) * minf(.07, .02 + _settle_from.distance_to(target) * .3)
		_feet[_settle_foot] = foot
		if progress >= 1.0:
			_settle_foot = -1
		return
	# Recovery steps: move the foot farthest from its stance target, one at a time.
	var farthest: int = -1
	var gap: float = .015
	for index in range(2):
		var offset: float = _feet[index].distance_to(_stance[index])
		if offset > gap:
			gap = offset
			farthest = index
	if farthest >= 0:
		_settle_foot = farthest
		_settle_from = _feet[farthest]
		_settle_time = 0.0
	else:
		for index in range(2):
			_feet[index] = _stance[index]


func raise_for_shot():
	# Snap most of the way to the shoulder at the shot; the rest eases in.
	var raised: float = maxf(aim, .6)
	if aim < 1.0:
		weapon.rotation *= (1.0 - raised) / (1.0 - aim)
		weapon.position.y = CARRY_PIVOT.y + raised * _role[6]
		_posed_carry = weapon.transform
	aim = raised
	_pose_arms()


func _pose_arms():
	for arm in arms:
		_solve_arm(arm, weapon)


static func _solve_arm(arm: Dictionary, carried):
	# Solve in chest space. Unlike rotating a rigid arm+gun assembly, shoulder
	# sockets stay attached while both wrists track the moving weapon exactly.
	var upper = arm.upper
	var lower = arm.lower
	var wrist = arm.wrist
	var target: Vector3 = carried.transform * arm.grip.position
	var offset: Vector3 = target - upper.position
	var upper_length: float = arm.upper_rest.length()
	var lower_length: float = arm.lower_rest.length()
	var distance: float = clampf(offset.length(), .02, upper_length + lower_length - .0001)
	var direction: Vector3 = offset.normalized()
	var along: float = (
		(distance * distance + upper_length * upper_length - lower_length * lower_length)
		/ (2.0 * distance)
	)
	var pole: Vector3 = arm.pole
	var outward: Vector3 = (pole - direction * pole.dot(direction)).normalized()
	var elbow: Vector3 = (
		direction * along + outward * sqrt(maxf(0.0, upper_length * upper_length - along * along))
	)
	upper.basis = Basis(Quaternion(arm.upper_rest.normalized(), elbow.normalized()))
	var forearm: Vector3 = direction * distance - elbow
	lower.basis = (
		upper.basis.inverse() * Basis(Quaternion(arm.lower_rest.normalized(), forearm.normalized()))
	)
	wrist.basis = (upper.basis * lower.basis).inverse() * carried.basis


func is_at_rest() -> bool:
	return (
		blend <= .001
		and brace <= .001
		and aim <= .001
		and _settle_foot < 0
		and not _moving
		and _suppressed_pose <= .001
		and _suppressed_target <= .001
		and (not "suppression" in _unit or _unit.suppression == null or _unit.suppression.band == 0)
	)


func _pose_leg(parts: Array, target: Vector3, pelvis_roll: float):
	# Two-bone solve in the leg plane (target is in pelvis space). The hip rolls
	# so a foot can stay planted while the pelvis shifts; knees bend forward and
	# soles stay level: the ankle cancels hip, knee and pelvis roll, leaving yaw.
	var offset: Vector3 = target - parts[0].position
	var roll: float = atan2(offset.x, -offset.y)
	var height: float = -Vector2(offset.x, offset.y).length()
	var reach: float = minf(Vector2(height, offset.z).length(), REACH)
	var bend: float = acos(clampf(reach / (THIGH + SHIN), 0.0, 1.0))
	var pitch: float = atan2(-offset.z, -height) + bend
	parts[0].basis = Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, pitch)
	parts[1].basis = Basis(Vector3.RIGHT, -2.0 * bend)
	parts[2].basis = (
		Basis(Vector3.RIGHT, 2.0 * bend - pitch) * Basis(Vector3.BACK, -(roll + pelvis_roll))
	)


static func pose_death(geometry, progress, style):
	# Wreck copies keep the articulated rig: knees buckle first, then the torso
	# and weapon go limp while the whole body topples (driven by the wreck tilt).
	var rig = geometry.get_node_or_null("InfantryRig")
	if rig == null:
		return
	var buckle = smoothstep(0.0, .45, progress)
	var slump = smoothstep(.15, .8, progress)
	var relax = smoothstep(.55, 1.0, progress)
	var hips = rig.get_node("Hips")
	var chest = rig.get_node("Chest")
	hips.position.y = lerpf(lerpf(HIP_HEIGHT, .36 if style != 1 else .45, buckle), .49, relax)
	chest.position.y = CHEST_REST.y + hips.position.y - HIP_HEIGHT
	var forward = 1.0 if style == 0 else -1.0
	chest.rotation.x = lerpf(-.45 * forward * slump, .03 * forward, relax)
	chest.rotation.z = lerpf((.25 if style == 2 else .08) * slump, .04, relax)
	chest.get_node("Head").rotation = Vector3(
		lerpf(-.5 * forward * slump, .03 * forward, relax),
		.3 * slump,
		lerpf(.2 * slump, .04, relax)
	)
	var carried = chest.get_node_or_null("WeaponCarry")
	if carried != null:
		# After impact the limbs relax and the rifle lies along the body,
		# instead of propping the corpse up on a barrel pointed into the floor.
		carried.rotation = Vector3(-.9 * slump, .4 * slump, -.5 * slump).lerp(
			Vector3(-PI / 2, 0, 0), relax
		)
		carried.position.y = lerpf(carried.position.y, CARRY_PIVOT.y, relax)
		carried.position.z = -.02 * relax
		for side in ["Left", "Right"]:
			var arm = chest.get_node("Arm" + side)
			var elbow = arm.get_node("Elbow" + side)
			var wrist = elbow.get_node("Wrist" + side)
			_solve_arm(
				{
					"upper": arm,
					"lower": elbow,
					"wrist": wrist,
					"grip": carried.get_node("Grip" + side),
					"upper_rest": elbow.position,
					"lower_rest": wrist.position,
					"pole": Vector3(-1 if side == "Left" else 1, -.8, .25)
				},
				carried
			)
	else:
		# A blast can separate the weapon; empty hands relax instead of gripping air.
		for side in ["Left", "Right"]:
			var arm = chest.get_node("Arm" + side)
			var elbow = arm.get_node("Elbow" + side)
			arm.rotation = Vector3(.2, 0, (-.25 if side == "Left" else .25) * slump)
			elbow.rotation.x = .3 * slump
	for side in ["Left", "Right"]:
		var hip = hips.get_node("Hip" + side)
		var knee = hip.get_node("Knee" + side)
		# Keep the boots on the ground while the hips sink, one knee further forward.
		var bend = acos(clampf((hips.position.y - FOOT_HEIGHT) / (THIGH + SHIN), 0.0, 1.0))
		bend = lerpf(bend, .12 if side == "Left" else .20, relax)
		var stagger = (.18 if side == "Left" else -.1) * buckle * (1.0 - relax * .6)
		hip.basis = Basis(Vector3.RIGHT, bend + stagger)
		knee.basis = Basis(Vector3.RIGHT, -2.0 * bend)
		knee.get_node("Ankle" + side).basis = Basis(Vector3.RIGHT, bend - stagger)


func copy_from(other):
	# Production exits hand their walking proxy over without restarting the gait.
	phase = other.phase
	blend = other.blend
	speed = other.speed
	_moving = other._moving
	_travel_idle = other._travel_idle
	_start_mix = 1.0
	for index in range(2):
		_feet[index] = other._feet[index]
	advance(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
