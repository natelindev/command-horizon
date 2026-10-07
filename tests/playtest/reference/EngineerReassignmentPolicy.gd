extends "res://tests/playtest/reference/EngineerSafetyPolicy.gd"


func _destination_available(worker, point, units):
	for state in states.values():
		var other = state.worker.get_ref()
		if is_instance_valid(other) and other != worker:
			if point.distance_to(state.safe) < worker.radius + other.radius + .6:
				return false
	for other in units:
		if (
			other != worker
			and point.distance_to(other.position) < worker.radius + other.radius + .3
		):
			return false
	return true


func _resume_target(game, worker, state, hq, observed):
	var work = super(game, worker, state, hq, observed)
	if (
		work.ready
		and is_instance_valid(work.target)
		and not work.target.is_queued_for_deletion()
		and _work_target_allowed(game, worker, hq, work.target, work.kind)
	):
		return work
	var original = state.target.get_ref() if state.target != null else null
	var kind = 2 if is_instance_valid(original) and "resource_b" in original else 1
	# Preserve the former resource channel first. If it is wholly unsafe, a
	# safe productive task is preferable to waiting without income indefinitely.
	for channel in [kind, 3 - kind]:
		var target = economy.deposit(game, worker, hq, channel, observed)
		if (
			target == null
			or not _work_target_allowed(game, worker, hq, target, "gather")
			or not _safe_route(worker, target, observed)
		):
			continue
		state.record.alternative = true
		state.record.alternative_kind = channel
		state.record.alternative_position = [target.position.x, target.position.z]
		return {"ready": true, "target": target, "kind": "gather"}
	# Stay protected when no alternative exists; routine economy assignment
	# must not send the worker straight back into the observed raid.
	return {"ready": false}


func _work_target_allowed(_game, _worker, _hq, _target, _kind):
	return true


func _safe_route(worker, target, observed):
	var movement = worker.get_node("Movement")
	var nav = movement.get_navigation_map()
	var point = NavigationServer3D.map_get_closest_point(nav, target.position)
	var contact = (
		worker.radius + target.radius + Utils.Match.Unit.Movement.adherence_margin(worker, target)
	)
	if (point * Vector3(1, 0, 1)).distance_to(target.position) > contact:
		return false
	var path = NavigationServer3D.map_get_path(nav, worker.position, point, true)
	if path.is_empty() or path[-1].distance_to(point) > .2:
		return false
	for index in range(1, path.size()):
		if not economy._clear_approach(path[index - 1], path[index], worker, observed):
			return false
	return true
