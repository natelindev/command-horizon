# gdlint: disable=max-returns
extends Node

const LIMIT = 16
const ACTIONS = "res://source/match/units/actions/"
var pending = []
var current = {}
var auto_resume = false
var status = "Hold the queue key and right-click to queue orders."
var _active = null
var _engaged = false
var _still = 0.0
var _progress = Vector3.INF
@onready var unit = get_parent()


static func point_order(kind, point):
	return {"kind": kind, "point": point}


static func target_order(kind, target):
	return {"kind": kind, "point": target.global_position, "target": weakref(target)}


func _ready():
	set_physics_process(false)


func submit(order, append = false):
	if append and pending.size() >= LIMIT:
		status = "Queue full · maximum 16 waiting orders."
		return false
	var programmed = unit.program != null and unit.program.mode != "Manual"
	if unit.program != null:
		unit.program.manual_override()
	if not append or programmed:
		cancel()
		unit.action = null
	elif not _engaged and is_instance_valid(unit.action):
		# Shift after a direct service/rally order preserves that operation.
		var idle = unit.action.has_method("is_idle")
		if not idle:
			_active = unit.action
			current = {"kind": "current"}
	pending.append(order.duplicate())
	_engaged = true
	set_physics_process(true)
	status = "%d waiting · manual control" % pending.size()
	return true


func cancel():
	pending.clear()
	current = {}
	_active = null
	_engaged = false
	set_physics_process(false)
	status = "Hold the queue key and right-click to queue orders."


func _physics_process(delta):
	if not _engaged:
		return
	if is_instance_valid(_active) and _active.is_inside_tree():
		_track_progress(delta)
		return
	_active = null
	current = {}
	if pending.is_empty():
		_engaged = false
		set_physics_process(false)
		status = "Orders complete · holding position."
		if auto_resume and unit.program != null and unit.program.ready_to_run():
			unit.program.run()
			status = "Orders complete · resuming program."
		return
	# One start/skip per tick bounds work even if a whole queue lost its targets.
	var order = pending.pop_front()
	var action = _make_action(order)
	if action == null:
		status = "Skipped unavailable %s target." % order.kind
		return
	current = order
	_still = 0.0
	_progress = unit.global_position
	_active = action
	unit.action = action
	status = "%s · %d waiting" % [str(order.kind).capitalize(), pending.size()]


func _make_action(order):
	match order.kind:
		"move":
			return load(ACTIONS + "Moving.gd").new(order.point)
		"attack_move":
			return load(ACTIONS + "AttackMoving.gd").new(order.point)
	var target = order.target.get_ref()
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return null
	if "player" in target and target.player != unit.player:
		if not unit._match.battlefield.is_observed(unit.player, target):
			# Never sample a hidden enemy's live location when a queued order activates.
			return load(ACTIONS + "Moving.gd").new(order.point)
	match order.kind:
		"attack":
			var script = load(ACTIONS + "AutoAttacking.gd")
			return script.new(target) if script.is_applicable(unit, target) else null
		"repair":
			var script = load(ACTIONS + "Repairing.gd")
			return script.new(target, true) if script.is_applicable(unit, target) else null
		"gather":
			var script = load(ACTIONS + "CollectingResourcesSequentially.gd")
			return script.new(target) if script.is_applicable(unit, target) else null
		"construct":
			var script = load(ACTIONS + "Constructing.gd")
			return script.new(target) if script.is_applicable(unit, target) else null
		"follow":
			return load(ACTIONS + "Following.gd").new(target)
		"approach":
			return load(ACTIONS + "MovingToUnit.gd").new(target)
	return null


func skip():
	if not _engaged:
		return
	if current.is_empty() and not pending.is_empty():
		pending.pop_front()
	_active = null
	current = {}
	unit.action = null
	status = "Order skipped."


func clear_waiting():
	pending.clear()
	status = "Waiting orders cleared."


func _track_progress(delta):
	if current.get("kind") not in ["move", "attack_move"]:
		return
	if "_shot" in _active and is_instance_valid(_active._shot):
		_still = 0.0
		status = "Engaging · %d waiting" % pending.size()
		return
	if unit.global_position.distance_to(_progress) > 0.15:
		_progress = unit.global_position
		_still = 0.0
		status = "%s · %d waiting" % [str(current.kind).capitalize(), pending.size()]
	else:
		_still += delta
		if _still >= 5.0:
			status = "Movement blocked · Skip or issue a new order."
