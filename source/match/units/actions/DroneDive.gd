extends "res://source/match/units/actions/Action.gd"

# Kamikaze attack: approach the target as a hovering drone, then commit to a
# powered dive with a limited turn rate. The airframe is the warhead; it
# detonates on contact or on the ground. A committed dive does not abort if the
# target dies, and anti-air can still shoot the drone down on the way in.

const Weapons = preload("res://source/match/combat/WeaponCatalog.gd")
const DIVE_RANGE = 6.0
const DIVE_SPEED = 15.0
const DIVE_ACCELERATION = 24.0
const TURN_RATE = 4.0
const CONTACT_MARGIN = 0.35

var diving = false
var force_attack = false
var _target_unit = null
var _velocity = Vector3.ZERO
var _aim_point = Vector3.ZERO

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.get_node("Movement")


func _init(target_unit, forced = false):
	_target_unit = target_unit
	force_attack = forced


func _ready():
	if restoring:
		if diving:
			_begin_dive()
		return
	if not _valid_target():
		queue_free()
		return
	_unit.aim_target = _target_unit


func _physics_process(delta):
	if diving:
		_dive(delta)
		return
	if not _valid_target():
		queue_free()
		return
	var offset = (_target_unit.global_position - _unit.global_position) * Vector3(1, 0, 1)
	if offset.length() <= DIVE_RANGE:
		_begin_dive()
		return
	_movement.move(_target_unit.global_position * Vector3(1, 0, 1))


func _begin_dive():
	diving = true
	_movement.stop()
	# The airframe now flies itself; navigation and avoidance let go of it.
	_movement.set_physics_process(false)
	_movement.avoidance_enabled = false
	if _velocity == Vector3.ZERO:
		_velocity = _movement.velocity
	_aim_point = _impact_point()


func _dive(delta):
	if _valid_target():
		_aim_point = _impact_point()
	var speed = minf(DIVE_SPEED, _velocity.length() + DIVE_ACCELERATION * delta)
	var direction = _velocity.normalized() if _velocity.length() > 0.1 else Vector3.DOWN
	var desired = _unit.global_position.direction_to(_aim_point)
	var angle = direction.angle_to(desired)
	if angle > 0.0001:
		direction = direction.slerp(desired, minf(1.0, TURN_RATE * delta / angle)).normalized()
	_velocity = direction * speed
	var start = _unit.global_position
	var end = start + _velocity * delta
	_unit.global_position = end
	if _velocity.length() > 0.1:
		_unit.look_at(end + _velocity, Vector3.UP)
	var system = _unit._match.projectile_system
	var struck = (
		_valid_target()
		and (
			(
				Geometry3D
				. get_closest_point_to_segment(system.center_of(_target_unit), start, end)
				. distance_to(system.center_of(_target_unit))
			)
			<= system.hitbox(_target_unit).x + CONTACT_MARGIN
		)
	)
	if struck or end.y <= system._ground_height(end) + 0.05:
		_strike(end)


func _strike(point):
	set_physics_process(false)
	_unit._match.projectile_system.detonate(_unit, _target_unit, point, Weapons.DRONE_WARHEAD)
	# Expended, not lost: the airframe was the weapon.
	_unit.queue_free()


func _impact_point():
	if not _valid_target():
		return _aim_point
	return _unit._match.projectile_system.center_of(_target_unit)


func _valid_target():
	return (
		is_instance_valid(_target_unit)
		and not _target_unit.is_queued_for_deletion()
		and _target_unit.hp > 0
	)


func weapons_free():
	return true
