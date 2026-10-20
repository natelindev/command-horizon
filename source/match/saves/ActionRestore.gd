# gdlint: disable=max-returns
extends RefCounted

var entities = {}
var warnings = []


func restore(saved, unit, parent):
	if saved.is_empty():
		return null
	if not _targets_available(saved):
		warnings.append("An unavailable action target was replaced with Hold.")
		return null
	var kind = saved.kind
	var refs = {}
	for field in saved.references:
		refs[field] = entities.get(saved.references[field])
	var target = refs.get("_target_unit")
	var action = _instantiate(kind, saved.state, refs)
	if action == null:
		warnings.append("An unavailable action target was replaced with Hold.")
		return null
	action.restoring = true
	for field in saved.state:
		var value = saved.state[field]
		if value == null and field in ["_last_known_position", "_progress_position"]:
			value = Vector3.INF
		action.set(field, value)
	for field in refs:
		action.set(field, refs[field])
	if parent == unit:
		unit.action = action
	else:
		parent.add_child(action)
	_bind(action, kind, target, unit)
	for slot in saved.children:
		var child = restore(saved.children[slot], unit, action)
		action.set(slot, child)
		if child == null:
			continue
		if slot == "_sub_action":
			match kind:
				"CollectingResourcesSequentially":
					child.tree_exited.connect(action._on_sub_action_finished, CONNECT_DEFERRED)
				"Following", "Constructing":
					child.tree_exited.connect(action._on_sub_action_finished)
				"WaitingForTargets":
					action._timer.timeout.disconnect(action._on_timer_timeout)
					child.tree_exited.connect(action._on_attack_finished)
	for slot in saved.timers:
		var timer = action.get(slot)
		var state = saved.timers[slot]
		if timer == null:
			continue
		timer.wait_time = state.wait
		timer.paused = state.paused
		if state.stopped:
			timer.stop()
		else:
			timer.start(maxf(0.000001, state.left))
			# start(left) also changes the repeat interval; retain the saved cadence.
			timer.wait_time = state.wait
	return action


func _instantiate(kind, state, refs):
	var script = load("res://source/match/units/actions/%s.gd" % kind)
	var target = refs.get("_target_unit")
	match kind:
		"Moving":
			return script.new(state._target_position)
		"AttackMoving":
			return script.new(state.destination)
		"AutoAttacking", "Garrisoning":
			return script.new(target)
		"WaitingForTargets":
			return script.new()
		"MovingToUnit", "Following", "Constructing", "ConstructingWhileInRange":
			return script.new(target) if target != null else null
		"AttackingWhileInRange":
			return script.new(target, state._shot_limit) if target != null else null
		"FollowingToReachDistance":
			return script.new(target, state._distance_to_reach) if target != null else null
		"CollectingResourcesSequentially":
			return script.new(null)
		"CollectingResourcesWhileInRange":
			return script.new(refs._resource_unit) if refs.get("_resource_unit") != null else null
		"RecoveringAtService":
			return script.new(refs.get("_target"))
		"Repairing":
			return (
				script.new(refs._target, state._finish_when_repaired)
				if refs.get("_target") != null
				else null
			)
	return null


func _bind(action, kind, target, unit):
	var movement = unit.get_node_or_null("Movement")
	match kind:
		"Moving", "MovingToUnit":
			movement.movement_finished.connect(action._on_movement_finished)
			if kind == "MovingToUnit":
				target.tree_exited.connect(action.queue_free)
		"AttackingWhileInRange":
			target.tree_exited.connect(action._on_target_unit_removed)
			unit.aim_target = target
			if movement != null:
				movement.passive_movement_started.connect(action._on_passive_movement_started)
				movement.passive_movement_finished.connect(action._on_passive_movement_finished)
			action._setup_one_shot_timer()
			action._setup_range_check_timer()
			action._update_charge_visual()
		"WaitingForTargets":
			action._timer = _timer(action, action._on_timer_timeout)
		"Following":
			target.tree_exited.connect(action.queue_free)
			action._setup_refresh_timer()
		"FollowingToReachDistance":
			action._timer = _timer(action, action._refresh)
			movement.movement_finished.connect(action._on_movement_finished)
		"CollectingResourcesSequentially":
			if action._resource_unit != null:
				action._resource_unit.tree_exited.connect(action._on_resource_unit_removed)
			if action._cc_unit != null:
				action._cc_unit.tree_exited.connect(action._on_cc_unit_removed)
		"CollectingResourcesWhileInRange":
			action._resource_unit.tree_exited.connect(action.queue_free)
			movement.passive_movement_finished.connect(action._on_passive_movement_finished)
			action._setup_timer()
			unit.get_node("Sparkling").enable()
		"ConstructingWhileInRange":
			target.tree_exited.connect(action.queue_free)
			target.constructed.connect(action.queue_free)
			unit.get_node("Sparkling").enable()
		"Repairing":
			action._target.tree_exiting.connect(action.queue_free)


func _timer(action, callback):
	var timer = Timer.new()
	timer.timeout.connect(callback)
	action.add_child(timer)
	return timer


func _targets_available(saved):
	if saved.is_empty():
		return true
	var required = {
		"MovingToUnit": "_target_unit",
		"Garrisoning": "_target_unit",
		"Following": "_target_unit",
		"FollowingToReachDistance": "_target_unit",
		"Constructing": "_target_unit",
		"ConstructingWhileInRange": "_target_unit",
		"AttackingWhileInRange": "_target_unit",
		"CollectingResourcesWhileInRange": "_resource_unit",
		"Repairing": "_target",
	}
	if saved.kind in required and not entities.has(saved.references[required[saved.kind]]):
		return false
	if saved.kind in ["CollectingResourcesSequentially", "Constructing", "Following"]:
		var child = saved.children.get("_sub_action", {})
		if saved.kind == "CollectingResourcesSequentially" and saved.state._state == 4:
			return child.is_empty()
		if (child.is_empty() and saved.kind != "Following") or not _targets_available(child):
			return false
	return true
