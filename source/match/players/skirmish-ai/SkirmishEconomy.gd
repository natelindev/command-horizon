extends RefCounted

const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Labor = preload("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const HOME_RADIUS = 30.0
const GUARD_RADIUS = 10.0


static func contacts(game, player):
	return game.get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player != player
				and not unit.is_queued_for_deletion()
				and unit.hp > 0
				and game.battlefield.is_observed(player, unit)
			)
	)


static func headquarters(units, point):
	var choices = units.filter(
		func(unit): return unit.type == "CommandCenter" and unit.is_constructed()
	)
	choices.sort_custom(
		func(a, b):
			return (
				point.distance_squared_to(a.global_position_yless)
				< point.distance_squared_to(b.global_position_yless)
			)
	)
	return choices[0] if not choices.is_empty() else null


static func danger(point, worker, observed):
	return observed.any(
		func(enemy):
			return (
				Rules.can_target(enemy, worker)
				and (
					point.distance_to(enemy.global_position_yless)
					<= Rules.range_for(enemy, worker) + 6.0
				)
			)
	)


static func available(worker):
	return (
		worker.action == null
		or (worker.action.has_method("needs_assignment") and worker.action.needs_assignment())
	)


static func deposit(game, worker, hq, kind, observed):
	var property = "resource_a" if kind == 1 else "resource_b"
	var choices = game.get_tree().get_nodes_in_group("resource_units").filter(
		func(node):
			return (
				node.can_harvest(worker)
				and property in node
				and node.get(property) > 0
				and safe_approach(node, worker, hq, observed)
				and (not node.is_in_group("salvage_wrecks") or _reachable_wreck(node, worker))
			)
	)
	# Compare round trips from the drop-off, not a stranded worker's proximity
	# to the opponent's economy. Resources are public map objectives.
	choices.sort_custom(func(a, b): return _deposit_score(a, hq) < _deposit_score(b, hq))
	return choices[0] if not choices.is_empty() else null


static func _reachable_wreck(wreck, worker):
	var movement = worker.get_node("Movement")
	var nav = movement.get_navigation_map()
	if (
		not movement._synchronized
		or not nav.is_valid()
		or NavigationServer3D.map_get_iteration_id(nav) == 0
	):
		return false
	var center = wreck.global_position_yless
	var contact = (
		worker.radius + wreck.radius + Utils.Match.Unit.Movement.adherence_margin(worker, wreck)
	)
	# A building may cover a nonblocking wreck after the wreck appeared.
	# Require a path into the existing collection range, including another
	# reachable face when the nearest projected point lies on a separate island.
	for index in 9:
		var target = center
		if index > 0:
			var angle = (index - 1) * TAU / 8.0
			target += Vector3(cos(angle), 0, sin(angle)) * contact
		var point = NavigationServer3D.map_get_closest_point(nav, target)
		if (point * Vector3(1, 0, 1)).distance_to(center) > contact:
			continue
		var path = NavigationServer3D.map_get_path(nav, worker.global_position, point, true)
		if not path.is_empty() and (path[-1] * Vector3(1, 0, 1)).distance_to(center) <= contact:
			return true
	return false


static func safe_approach(node, worker, hq, observed):
	return (
		not danger(node.global_position_yless, worker, observed)
		and _clear_approach(hq.global_position_yless, node.global_position_yless, worker, observed)
	)


static func guarded(units, point):
	return guards(units).any(
		func(unit): return unit.global_position_yless.distance_to(point) <= GUARD_RADIUS
	)


static func guards(units):
	return units.filter(
		func(unit):
			return (
				unit.movement_speed > 0
				and unit.attack_range != null
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and unit.hp >= unit.hp_max * 0.5
			)
	)


static func expansion(game, units, observed):
	var points = expansion_points(game, units, observed)
	return points[0] if not points.is_empty() else null


static func expansion_points(game, units, observed):
	var workers = units.filter(func(unit): return unit.type == "Worker")
	if workers.is_empty():
		return []
	var assignments = Labor.plan(game, workers[0].player, units)
	var active = []
	var pending = []
	for worker in workers:
		var hq = headquarters(units, worker.global_position_yless)
		if hq == null:
			continue
		if (
			worker.action is Harvest
			and worker.action._kind != 0
			and not worker.action.needs_assignment()
		):
			var occupied = worker.action._field_origin
			if occupied.distance_to(hq.global_position_yless) > HOME_RADIUS:
				_add_field(active, occupied, worker.action._kind)
		var next = Labor.queued_target(worker)
		if next == null and assignments.has(worker):
			# Start the guard before the gatherer's delivery-boundary handoff.
			if (
				worker.action is Harvest
				and worker.action._kind == 0
				and not worker.action.needs_assignment()
			):
				continue
			next = deposit(game, worker, hq, assignments[worker], observed)
		if (
			next != null
			and next.global_position_yless.distance_to(hq.global_position_yless) > HOME_RADIUS
		):
			_add_field(pending, next.global_position_yless, 2 if "resource_b" in next else 1)
	for field in pending:
		_add_field(active, field.point, field.kind)
	# One guard per resource approach when they differ, sharing the existing
	# two-unit budget. Existing gatherers take precedence over a new approach.
	return active.slice(0, 2).map(func(field): return field.point)


static func _add_field(fields, point, kind):
	if fields.any(
		func(field):
			return field.kind == kind and field.point.distance_to(point) <= Harvest.FIELD_RADIUS
	):
		return
	fields.append({"point": point, "kind": kind})


static func _clear_approach(origin, destination, worker, observed):
	for enemy in observed:
		if not Rules.can_target(enemy, worker):
			continue
		var closest = Geometry3D.get_closest_point_to_segment(
			enemy.global_position_yless, origin, destination
		)
		if closest.distance_to(enemy.global_position_yless) <= Rules.range_for(enemy, worker) + 4.0:
			return false
	return true


static func _deposit_score(deposit, hq):
	var distance = hq.global_position_yless.distance_squared_to(deposit.global_position_yless)
	# Reclaim nearby observed wrecks while the route is safe; distant scraps never
	# justify abandoning a productive field or charging into unobserved enemy ground.
	return (
		distance * .5
		if deposit.is_in_group("salvage_wrecks") and distance <= HOME_RADIUS * HOME_RADIUS
		else distance
	)
