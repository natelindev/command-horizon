# gdlint: disable=max-returns
extends Node

const LIMIT = 16
const ACTIONS = "res://source/match/units/actions/"
var pending = []
var current = {}
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


func submit(order, append = false, audible = true, feedback_kind = ""):
	if append and pending.size() >= LIMIT:
		status = "Queue full · maximum 16 waiting orders."
		_feedback(order, false, append, audible, status, feedback_kind)
		return false
	# A direct shot uses the shelter's firing ports. Movement and Leave building
	# still replace the garrison action and evacuate normally.
	if not append and order.kind == "attack" and unit.has_meta("garrison_host"):
		var target = order.target.get_ref()
		if not is_instance_valid(unit.action) or not unit.action.has_method("attack_from_building"):
			return false
		if not unit.action.attack_from_building(target):
			status = "Target outside building firing range or line of fire."
			_feedback(order, false, append, audible, status, feedback_kind)
			return false
		cancel()
		_active = unit.action
		current = target_order("garrison", unit.get_meta("garrison_host"))
		_engaged = true
		set_physics_process(true)
		status = "Garrisoned · attacking target"
		if audible:
			MatchSignals.unit_order_issued.emit(unit, order.kind)
		_feedback(order, true, append, audible, "", feedback_kind)
		return true
	if not append:
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
	status = tr("%d waiting · manual control") % pending.size()
	if audible:
		MatchSignals.unit_order_issued.emit(unit, order.kind)
	_feedback(order, true, append, audible, "", feedback_kind)
	# Start an order the moment it reaches the head of an idle queue instead of
	# on the next physics tick. Tactical pause keeps orders waiting, and a locked
	# action swap retries on that tick.
	if (
		not is_instance_valid(_active)
		and not unit._action_locked
		and not get_tree().paused
		and not unit.has_meta("breach_pending")
	):
		_start_next()
	return true


func _feedback(order, accepted, queued, audible, reason = "", feedback_kind = ""):
	if audible and unit.is_in_group("controlled_units"):
		var kind = order.kind if feedback_kind.is_empty() else feedback_kind
		MatchSignals.order_feedback.emit(unit, kind, order.point, accepted, queued, reason)


func cancel():
	if unit._match != null and "engineering" in unit._match and unit._match.engineering != null:
		unit._match.engineering.cancel_orders(unit)
	# Replacing or stopping orders also ends an earlier production sidestep.
	# Appending a queued order keeps the current operation and its clearance.
	unit.get_node("Movement").cancel_exit_clearance()
	pending.clear()
	current = {}
	_active = null
	_engaged = false
	set_physics_process(false)
	status = "Hold the queue key and right-click to queue orders."


func _physics_process(delta):
	# Evacuation clears movement only when a legal exit is physically reserved.
	# Keep later orders queued until then so their paths start from that exit.
	if not _engaged or unit.has_meta("breach_pending"):
		return
	if is_instance_valid(_active) and _active.is_inside_tree():
		_track_progress(delta)
		return
	_start_next()


func _start_next():
	_active = null
	current = {}
	if pending.is_empty():
		_engaged = false
		set_physics_process(false)
		status = "Orders complete · holding position."
		return
	# One start/skip per tick bounds work even if a whole queue lost its targets.
	var order = pending.pop_front()
	var action = _make_action(order)
	if action == null:
		status = tr("Skipped unavailable %s target.") % tr(str(order.kind).capitalize())
		return
	current = order
	_still = 0.0
	_progress = unit.global_position
	unit.action = action
	# The unit may replace a generic action with one its movement supports, or
	# reject it and fall back to its idle behavior, which completes the order.
	_active = unit.action
	if is_instance_valid(_active) and _active.has_method("is_idle") and _active.is_idle():
		_active = null
	status = tr("%s · %d waiting") % [tr(str(order.kind).capitalize()), pending.size()]


func _make_action(order):
	match order.kind:
		"engineering":
			return load(ACTIONS + "EngineeringAction.gd").new(
				order.engineering_kind, order.point, order.get("angle", 0.0), order.reservation
			)
		"sweep":
			return load(ACTIONS + "EngineeringAction.gd").new("sweep", order.point)
		"move":
			return load(ACTIONS + "Moving.gd").new(order.point)
		"attack_move":
			return load(ACTIONS + "AttackMoving.gd").new(order.point)
		"patrol":
			return load(ACTIONS + "Patrolling.gd").new(order.point)
	var target = order.target.get_ref()
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return null
	if order.kind == "recover":
		var recovery = load(ACTIONS + "RecoveringAtService.gd")
		return (
			recovery.new(target, true) if recovery.Repairs.facility_eligible(target, unit) else null
		)
	if "player" in target and target.player != unit.player:
		var public_cargo = (
			order.kind == "collect_tactical" and "public_marker" in target and target.public_marker
		)
		if not public_cargo and not unit._match.battlefield.is_observed(unit.player, target):
			# Never sample a hidden enemy's live location when a queued order activates.
			return load(ACTIONS + "Moving.gd").new(order.point)
	match order.kind:
		"collect_tactical":
			return (
				load(ACTIONS + "CollectTacticalCargo.gd").new(target)
				if target.has_method("can_collect") and target.can_collect(unit)
				else null
			)
		"repair_barrier", "dismantle":
			if (
				unit.type != "Worker"
				or target.player != unit.player
				or not target.is_in_group("engineering_entities")
				or target.is_in_group("field_mines")
			):
				return null
			var action = load(ACTIONS + "EngineeringAction.gd").new(order.kind)
			action._target = target
			return action
		"garrison":
			return (
				load(ACTIONS + "Garrisoning.gd").new(target)
				if target.has_method("can_garrison") and target.can_garrison(unit)
				else null
			)
		"attack", "force_attack":
			var script = load(ACTIONS + "AutoAttacking.gd")
			var forced = order.kind == "force_attack"
			return (
				script.new(target, forced)
				if load("res://source/match/combat/CombatRules.gd").can_target(unit, target, forced)
				else null
			)
		"repair":
			var script = load(ACTIONS + "Repairing.gd")
			return script.new(target, true) if script.is_applicable(unit, target) else null
		"scavenge":
			var script = load(ACTIONS + "Scavenging.gd")
			return script.new(target) if script.eligible(unit, target) else null
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


func revise(token, point):
	# A right-click drag sets formation and facing after the press already issued
	# the order. Update that same order in place: no second queue entry or voice.
	if current.get("token") == token:
		current.point = point
		if current.kind in ["move", "attack_move"] and is_instance_valid(_active):
			var action = _make_action(current)
			_still = 0.0
			_progress = unit.global_position
			unit.action = action
			_active = unit.action
		return true
	for order in pending:
		if order.get("token") == token:
			order.point = point
			return true
	return false


func skip():
	if not _engaged:
		return
	if current.is_empty() and not pending.is_empty():
		var order = pending.pop_front()
		if order.has("reservation") and unit._match.engineering != null:
			unit._match.engineering.release(order.reservation)
	_active = null
	current = {}
	unit.action = null
	status = "Order skipped."


func clear_waiting():
	if unit._match != null and "engineering" in unit._match and unit._match.engineering != null:
		for order in pending:
			if order.has("reservation"):
				unit._match.engineering.release(order.reservation)
	pending.clear()
	status = "Waiting orders cleared."


func _track_progress(delta):
	if current.get("kind") == "recover":
		if not _active.Repairs.facility_eligible(_active._target, unit):
			skip()
			status = "Recovery facility lost · continuing queued orders."
		else:
			status = tr("%s · %d waiting") % [str(_active), pending.size()]
		return
	if current.get("kind") not in ["move", "attack_move", "patrol"]:
		return
	if "_shot" in _active and is_instance_valid(_active._shot):
		_still = 0.0
		status = tr("Engaging · %d waiting") % pending.size()
		return
	if unit.global_position.distance_to(_progress) > 0.15:
		_progress = unit.global_position
		_still = 0.0
		status = tr("%s · %d waiting") % [tr(str(current.kind).capitalize()), pending.size()]
	else:
		_still += delta
		if _still >= 5.0:
			status = "Movement blocked · Skip or issue a new order."
