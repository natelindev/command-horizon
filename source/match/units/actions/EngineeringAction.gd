extends "res://source/match/units/actions/Action.gd"

## The manual order owns movement and cancellable work; the match owns entities,
## reservations and paid resources. All progress is simulation-time state.
var operation = ""
var point = Vector3.ZERO
var angle = 0.0
var reservation = ""
var phase = 0
var elapsed = 0.0
var search_index = 0
var unreachable = 0
var search_path = []
var skipped_mines = []
var _blocked_elapsed = 0.0
var _progress_position = Vector3.ZERO
var _target = null
@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.get_node("Movement")
@onready var _engineering = _unit._match.engineering


func _init(kind, location = Vector3.ZERO, rotation_angle = 0.0, token = ""):
	operation = kind
	point = location
	angle = rotation_angle
	reservation = token


func _ready():
	if restoring:
		return
	_progress_position = _unit.global_position
	if operation == "sweep":
		search_path = _engineering.search_points(point)


func _physics_process(delta):
	if _engineering == null or _unit.hp <= 0.0:
		queue_free()
		return
	if operation == "sweep":
		_sweep(delta)
	elif operation in ["repair_barrier", "dismantle"]:
		_service(delta)
	else:
		_deploy(delta)


func _deploy(delta):
	if phase == 0:
		if not _approach(point, 3.0, delta):
			if _blocked_elapsed >= 5.0:
				_finish("Deployment position unreachable.")
			return
		_target = _engineering.begin_deployment(_unit, reservation)
		if not is_instance_valid(_target):
			queue_free()
			return
		if operation == "barricade":
			reservation = ""
			queue_free()
			return
		phase = 1
	if not is_instance_valid(_target) or _target.hp <= 0.0:
		queue_free()
		return
	_movement.stop()
	_target.deploy_left = maxf(0.0, _target.deploy_left - delta)
	elapsed += delta
	if _target.deploy_left == 0.0:
		_engineering.complete_deployment(reservation)
		reservation = ""
		queue_free()


func _sweep(delta):
	if is_instance_valid(_target):
		if _target.hp <= 0.0 or not _engineering.observed_by(_unit.player, _target):
			_target = null
			elapsed = 0.0
		else:
			if _approach(_target.global_position, 3.0, delta, _target):
				elapsed += delta
				if elapsed >= 1.0:
					_target.clear()
					_target = null
					elapsed = 0.0
			elif _blocked_elapsed >= 5.0:
				_skip_target()
			return
	var mines = _engineering.known_mines(_unit.player, point)
	mines = mines.filter(func(mine): return mine.neutral_id not in skipped_mines)
	mines.sort_custom(
		func(first, second):
			return (
				first.global_position.distance_squared_to(_unit.global_position)
				< second.global_position.distance_squared_to(_unit.global_position)
			)
	)
	for mine in mines:
		if _engineering.reachable(_unit, mine.global_position):
			_target = mine
			_blocked_elapsed = 0.0
			_progress_position = _unit.global_position
			return
		unreachable += 1
		skipped_mines.append(mine.neutral_id)
	if search_index >= search_path.size():
		_finish(
			(
				"Mine clearance complete."
				if unreachable == 0
				else "Mine clearance finished; some ground remains unreachable."
			)
		)
		return
	var destination = search_path[search_index]
	if not _engineering.reachable(_unit, destination):
		unreachable += 1
		search_index += 1
		_blocked_elapsed = 0.0
		return
	if _approach(destination, 0.6, delta) or _blocked_elapsed >= 5.0:
		if _blocked_elapsed >= 5.0:
			unreachable += 1
		search_index += 1
		_blocked_elapsed = 0.0
		_progress_position = _unit.global_position


func _skip_target():
	skipped_mines.append(_target.neutral_id)
	unreachable += 1
	_target = null
	elapsed = 0.0
	_blocked_elapsed = 0.0


func _service(delta):
	if not is_instance_valid(_target) or _target.hp <= 0 or _target.player != _unit.player:
		queue_free()
		return
	if not _approach(_target.global_position, 3.0, delta, _target):
		if _blocked_elapsed >= 5.0:
			_finish("Barricade unreachable.")
		return
	elapsed += delta
	if operation == "dismantle":
		if elapsed >= 2.0:
			_target.breach(false)
			queue_free()
	elif _target.hp >= _target.hp_max:
		queue_free()
	elif elapsed >= 1.0:
		if not _unit.player.has_resources({"resource_a": 1}):
			_finish("Not enough Materials to repair the barricade.")
			return
		_unit.player.subtract_resources({"resource_a": 1})
		_target.hp = minf(_target.hp_max, _target.hp + 10.0)
		elapsed -= 1.0


func _approach(destination, reach, delta, target = null) -> bool:
	var close = _engineering._flat_distance(_unit.global_position, destination) <= reach
	if (
		close
		and (
			target == null
			or _unit._match.battlefield.line_clear(
				_unit.global_position + Vector3.UP * 0.8,
				destination + Vector3.UP * 0.3,
				_unit,
				target
			)
		)
	):
		_movement.stop()
		_blocked_elapsed = 0.0
		return true
	if _unit.global_position.distance_to(_progress_position) > 0.15:
		_progress_position = _unit.global_position
		_blocked_elapsed = 0.0
	else:
		_blocked_elapsed += delta
	_movement.move(destination)
	return false


func _finish(message):
	_engineering._notice(_unit, message)
	queue_free()


func _exit_tree():
	if is_instance_valid(_movement):
		_movement.stop()
	if reservation != "" and is_instance_valid(_engineering):
		_engineering.release(reservation)


func _to_string():
	if operation == "sweep":
		return "Clearing mine area"
	if operation == "dismantle":
		return "Dismantling barricade"
	if operation == "repair_barrier":
		return "Repairing barricade"
	return "Deploying field equipment"
