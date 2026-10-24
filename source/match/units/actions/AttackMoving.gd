extends "res://source/match/units/actions/Action.gd"

const PointMovement = preload("res://source/match/units/actions/Moving.gd")
const Shooting = preload("res://source/match/units/actions/AttackingWhileInRange.gd")
var destination = Vector3.ZERO
var _shot = null
var _elapsed = 0.0
var _arrival_elapsed = 0.0
var _arrival_progress = null
@onready var _unit = get_parent()
@onready var _movement = _unit.find_child("Movement")


func _init(point):
	destination = point


func _ready():
	_movement.movement_finished.connect(_on_movement_finished)
	if restoring:
		return
	_movement.move(destination)


func _process(delta):
	if is_instance_valid(_shot) and not _shot.is_queued_for_deletion():
		# Combat pauses travel. A later trip must observe fresh movement before
		# deciding that a settled ally occupies its final reachable point.
		_arrival_elapsed = 0.0
		_arrival_progress = null
		return
	if PointMovement.occupied_arrival(self, _movement, _unit, delta):
		_movement.stop()
		_arrived()


func _physics_process(delta):
	_elapsed += delta
	# Check promptly at the range boundary: fast units otherwise travel another
	# metre toward the target before braking, compressing the firing line.
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	if is_instance_valid(_shot) and not _shot.is_queued_for_deletion():
		return
	_shot = null
	var target = (
		_unit._match.battlefield.automatic_target(_unit) if _unit.attack_range != null else null
	)
	if target != null:
		_movement.stop()
		_shot = Shooting.new(target)
		add_child(_shot)
	elif _unit.global_position_yless.distance_to(destination * Vector3(1, 0, 1)) < 1.0:
		_arrived()
	else:
		_movement.move(destination)


func _on_movement_finished():
	# Navigation may end at the reachable edge of an occupied destination.
	# Stop retrying that same point and allow queued orders to continue.
	if not is_instance_valid(_shot) or _shot.is_queued_for_deletion():
		_arrived()


func _arrived():
	queue_free()


func _exit_tree():
	if is_instance_valid(_movement):
		_movement.stop()
