# gdlint: disable=max-returns
extends Node

const LIMIT = 16
const ACTIONS = "res://source/match/units/actions/"
const DEFERRED_ACTIONS = {
	ACTIONS + "WaitingForTargets.gd": true,
	ACTIONS + "Moving.gd": true,
	ACTIONS + "AttackMoving.gd": true,
	ACTIONS + "Patrolling.gd": true,
	ACTIONS + "AutoAttacking.gd": true
}
const ActivationQueue = preload("res://source/match/orders/OrderActivationQueue.gd")
const CohesionGroup = preload("res://source/match/orders/CohesionGroup.gd")
const NetworkGate = preload("res://source/match/network/NetworkGate.gd")
var formation = "line"
var cohesion_enabled = false
var pending = []
var current = {}
var status = "Hold the queue key and right-click to queue orders."
var _active = null
var _engaged = false
var _still = 0.0
var _progress = Vector3.INF
var _activation_queue: Node
var _activation_queued := false
var _suspended_action: WeakRef
var _suspended_mode := Node.PROCESS_MODE_INHERIT
@onready var unit = get_parent()


static func point_order(kind, point):
	return {"kind": kind, "point": point}


static func target_order(kind, target):
	return {"kind": kind, "point": target.global_position, "target": weakref(target)}


static func group_point_order(kind, point, units):
	var order = point_order(kind, point)
	order.cohort = CohesionGroup.new(units)
	return order


func configure_cohesion(enabled: bool, group = null):
	cohesion_enabled = enabled
	var movement = unit.get_node_or_null("Movement")
	if movement != null:
		if movement.cohesion_group != null:
			movement.cohesion_group.invalidate()
		if group != null:
			movement.cohesion_group = group
			group.invalidate()
		movement.refresh_cohesion()


func capture_tactics(reference: Callable) -> Dictionary:
	var movement = unit.get_node_or_null("Movement")
	return {
		"formation": formation,
		"cohesion_enabled": cohesion_enabled,
		"cohesion_members":
		(
			movement.cohesion_group.references(reference)
			if movement != null and movement.cohesion_group != null
			else []
		),
	}


func restore_tactics(saved: Dictionary, resolve: Callable):
	formation = saved.get("formation", "line")
	cohesion_enabled = saved.get("cohesion_enabled", false)
	var members = []
	for reference in saved.get("cohesion_members", []):
		var member = resolve.call(reference)
		if is_instance_valid(member):
			members.append(member)
	if not members.is_empty():
		var cache = unit._match.get_meta("restored_cohesion_groups", {})
		var identities = members.map(func(member): return member.get_instance_id())
		identities.sort()
		var key = str(identities)
		if not cache.has(key):
			cache[key] = CohesionGroup.new(members)
		unit._match.set_meta("restored_cohesion_groups", cache)
		unit.get_node("Movement").cohesion_group = cache[key]
	unit.get_node("Movement").refresh_cohesion()


func _ready():
	set_physics_process(false)


func submit(order, append = false, audible = true, feedback_kind = ""):
	if NetworkGate.intercept_order(unit, order, append):
		return true
	if append and pending.size() >= LIMIT:
		status = "Queue full · maximum 16 waiting orders."
		_feedback(order, false, append, audible, status, feedback_kind)
		return false
	var deferred_point = _deferred_point(order)
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
		# An immediate point order replaces the action below. Clearing it first
		# makes combat units create an idle action only to discard it again.
		# Paused/locked orders and shelter evacuation still stop immediately.
		var immediate_point = (
			order.kind in ["move", "attack_move", "patrol"]
			and (not get_tree().paused or deferred_point)
			and not unit._action_locked
			and not unit.has_meta("breach_pending")
			and not unit.has_meta("garrison_host")
		)
		if not immediate_point:
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
	if deferred_point and not is_instance_valid(_active):
		resume_waiting_activation()
	# Start an order the moment it reaches the head of an idle queue instead of
	# on the next physics tick. Tactical pause keeps orders waiting, and a locked
	# action swap retries on that tick.
	if (
		not is_instance_valid(_active)
		and not unit._action_locked
		and not get_tree().paused
		and not unit.has_meta("breach_pending")
		and not _activation_queued
	):
		_start_next()
	return true


func _feedback(order, accepted, queued, audible, reason = "", feedback_kind = ""):
	if audible and unit.is_in_group("controlled_units"):
		var kind = order.kind if feedback_kind.is_empty() else feedback_kind
		MatchSignals.order_feedback.emit(unit, kind, order.point, accepted, queued, reason)


func cancel():
	_cancel_activation()
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
	if not _engaged or unit.has_meta("breach_pending") or _activation_queued:
		return
	if is_instance_valid(_active) and _active.is_inside_tree():
		_track_progress(delta)
		return
	if not pending.is_empty() and _deferred_point(pending[0]):
		_active = null
		current = {}
		resume_waiting_activation()
		return
	_start_next()


func _deferred_point(order: Dictionary) -> bool:
	var cohort = order.get("cohort")
	return (
		order.kind in ["move", "attack_move", "patrol"]
		and cohort != null
		and cohort.members.size() >= ActivationQueue.GROUP_THRESHOLD
		and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
		and not unit.has_meta("garrison_host")
		and not unit.has_meta("breach_pending")
		and not unit._action_locked
		and _action_can_wait()
	)


func _action_can_wait() -> bool:
	# Operational actions release cargo channels, service jobs and reservations
	# during teardown. Keep their replacement synchronous.
	var action = unit.action
	if not is_instance_valid(action):
		return true
	var action_script = action.get_script()
	return action_script != null and DEFERRED_ACTIONS.has(action_script.resource_path)


func resume_waiting_activation():
	# The same existing v22 state also represents a paused queue saved before
	# its first start. Rebuild scheduling from those intents after restoration.
	if (
		not _engaged
		or not current.is_empty()
		or pending.is_empty()
		or not _deferred_point(pending[0])
	):
		return
	if is_instance_valid(unit.action) and _suspended_action == null:
		_suspended_action = weakref(unit.action)
		_suspended_mode = unit.action.process_mode
		unit.action.process_mode = Node.PROCESS_MODE_DISABLED
	unit.get_node("Movement").stop()
	var session = NetworkGate.session_for(unit)
	if session != null and not session.authority:
		# Replicas display authoritative snapshots; they never schedule starts.
		set_physics_process(false)
		return
	_activation_queue = ActivationQueue.acquire(unit._match)
	_activation_queued = true
	_activation_queue.enqueue(self)


func can_activate_waiting_order() -> bool:
	return (
		_activation_queued
		and _engaged
		and not pending.is_empty()
		and not unit._action_locked
		and not unit.has_meta("breach_pending")
		and not get_tree().paused
	)


func activate_waiting_order():
	_activation_queued = false
	_resume_suspended_action()
	_start_next()


func _resume_suspended_action():
	if _suspended_action != null:
		var previous = _suspended_action.get_ref()
		if is_instance_valid(previous) and previous == unit.action:
			previous.process_mode = _suspended_mode
		_suspended_action = null


func _cancel_activation():
	if is_instance_valid(_activation_queue):
		_activation_queue.cancel(self)
	_activation_queued = false
	_resume_suspended_action()


func _exit_tree():
	_cancel_activation()


func _start_next():
	if _activation_queued:
		_cancel_activation()
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
	var movement = unit.get_node("Movement")
	movement.cohesion_group = order.get("cohort")
	movement.refresh_cohesion()
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


func revise(token, point, waypoints = []):
	var gate = NetworkGate
	if gate.intercept(
		unit,
		{
			"kind": "revise_order",
			"unit": gate.id_for(unit),
			"token": token,
			"point": gate.Protocol.quantize(point),
			"waypoints": Array(waypoints).map(gate.Protocol.quantize)
		}
	):
		return true
	# A right-click drag sets formation and facing after the press already issued
	# the order. Update that same order in place: no second queue entry or voice.
	if current.get("token") == token:
		current.point = point
		current.waypoints = waypoints
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
			order.waypoints = waypoints
			return true
	return false


func skip():
	if not _engaged:
		return
	_cancel_activation()
	if current.is_empty() and not pending.is_empty():
		var order = pending.pop_front()
		if order.has("reservation") and unit._match.engineering != null:
			unit._match.engineering.release(order.reservation)
	_active = null
	current = {}
	unit.action = null
	status = "Order skipped."
	resume_waiting_activation()


func clear_waiting():
	var awaiting_activation = _activation_queued
	_cancel_activation()
	if unit._match != null and "engineering" in unit._match and unit._match.engineering != null:
		for order in pending:
			if order.has("reservation"):
				unit._match.engineering.release(order.reservation)
	pending.clear()
	if awaiting_activation:
		unit.action = null
		_engaged = false
		set_physics_process(false)
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
