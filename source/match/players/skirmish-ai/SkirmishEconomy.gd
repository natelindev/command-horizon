extends RefCounted

const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Labor = preload("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const Players = preload("res://source/match/Players.gd")
const HOME_RADIUS = 30.0
const GUARD_RADIUS = 10.0
const THREAT_CELL = 16.0
const THREAT_CELL_RADIUS = 11.315


static func contacts(game, player):
	if player.has_meta("decision_contacts"):
		return player.get_meta("decision_contacts")
	return game.get_units().filter(
		func(unit):
			return (
				not Players.allied(unit.player, player)
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
	for threat in _threat_candidates(worker, observed, point, point, 6.0):
		var reach: float = threat[2] + 6.0
		if point.distance_squared_to(threat[1]) > reach * reach:
			continue
		if (
			Rules.can_target(threat[0], worker)
			and point.distance_to(threat[1]) <= Rules.range_for(threat[0], worker) + 6.0
		):
			return true
	return false


static func _threat_snapshot(worker, observed):
	var cache = (
		worker.player.get_meta("decision_approaches")
		if worker.player.has_meta("decision_approaches")
		else null
	)
	if cache != null:
		var snapshot = cache.get("threat_snapshot")
		if snapshot != null and is_same(snapshot.observed, observed):
			return snapshot
	# Decision caches exist only for one synchronous AI call. No enemy can move
	# between these reads; direct calls outside a decision always sample live data.
	var entries = []
	var cells = {}
	var reach: float = 0.0
	for enemy in observed:
		if enemy.attack_range != null:
			var point: Vector3 = enemy.global_position_yless
			var maximum: float = threat_reach(enemy, 0.0)
			var entry = [enemy, point, maximum]
			entries.append(entry)
			var cell = Vector2i(floori(point.x / THREAT_CELL), floori(point.z / THREAT_CELL))
			cells.get_or_add(cell, []).append(entry)
			reach = maxf(reach, maximum)
	var snapshot = {"observed": observed, "entries": entries, "cells": cells, "reach": reach}
	if cache != null:
		cache.threat_snapshot = snapshot
	return snapshot


static func _threat_candidates(
	worker, observed, origin: Vector3, end: Vector3, padding: float
) -> Array:
	var snapshot = _threat_snapshot(worker, observed)
	if snapshot.entries.size() <= 8:
		return snapshot.entries
	var candidates = []
	var reach: float = snapshot.reach + padding
	if origin == end:
		var low = Vector2i(
			floori((origin.x - reach) / THREAT_CELL), floori((origin.z - reach) / THREAT_CELL)
		)
		var high = Vector2i(
			floori((origin.x + reach) / THREAT_CELL), floori((origin.z + reach) / THREAT_CELL)
		)
		for x in range(low.x, high.x + 1):
			for z in range(low.y, high.y + 1):
				candidates.append_array(snapshot.cells.get(Vector2i(x, z), []))
	else:
		# Test occupied bins against a conservative corridor before touching their
		# members. The half-diagonal covers every point in a bin, including corners.
		var envelope: float = reach + THREAT_CELL_RADIUS
		for cell in snapshot.cells:
			var centre = Vector3((cell.x + .5) * THREAT_CELL, 0, (cell.y + .5) * THREAT_CELL)
			var nearest = Geometry3D.get_closest_point_to_segment(centre, origin, end)
			if nearest.distance_squared_to(centre) <= envelope * envelope:
				candidates.append_array(snapshot.cells[cell])
	return candidates


static func available(worker):
	return (
		worker.action == null
		or (worker.action.has_method("needs_assignment") and worker.action.needs_assignment())
	)


static func deposit(game, worker, hq, kind, observed):
	var property = "resource_a" if kind == 1 else "resource_b"
	var choices = []
	for node in game.get_tree().get_nodes_in_group("resource_units"):
		if node.can_harvest(worker) and property in node and node.get(property) > 0:
			choices.append([_deposit_score(node, hq), choices.size(), node])
	# Compare round trips from the drop-off, not a stranded worker's proximity
	# to the opponent's economy. Validate in score order and stop at the first
	# safe reachable field, instead of testing every remote field for every
	# worker. Equal scores retain the resource registry's deterministic order.
	choices.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	for choice in choices:
		var node = choice[2]
		if (
			safe_approach(node, worker, hq, observed)
			and (not node.is_in_group("salvage_wrecks") or _reachable_wreck(node, worker))
		):
			return node
	return null


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
	var cache = (
		worker.player.get_meta("decision_approaches")
		if worker.player.has_meta("decision_approaches")
		else null
	)
	var key = [node, worker, hq]
	if cache != null and cache.has(key):
		return cache[key]
	var safe = (
		not danger(node.global_position_yless, worker, observed)
		and _clear_approach(hq.global_position_yless, node.global_position_yless, worker, observed)
	)
	if cache != null:
		cache[key] = safe
	return safe


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
	var low: Vector3 = origin.min(destination)
	var high: Vector3 = origin.max(destination)
	for threat in _threat_candidates(worker, observed, origin, destination, 4.0):
		var point: Vector3 = threat[1]
		var reach: float = threat[2] + 4.0
		if (
			point.x < low.x - reach
			or point.x > high.x + reach
			or point.z < low.z - reach
			or point.z > high.z + reach
		):
			continue
		var closest = Geometry3D.get_closest_point_to_segment(point, origin, destination)
		if closest.distance_squared_to(point) > reach * reach:
			continue
		var enemy = threat[0]
		if (
			Rules.can_target(enemy, worker)
			and closest.distance_to(point) <= Rules.range_for(enemy, worker) + 4.0
		):
			return false
	return true


static func threat_reach(enemy, padding: float) -> float:
	if enemy.attack_range == null:
		return 0.0
	# Conservative upper bound: downhill bonus and every garrison extension.
	# The exact target rules still decide all candidates inside this bound.
	return (
		enemy.attack_range * 1.25
		+ padding
		+ (enemy.get_meta("garrison_host").radius + 2.0 if enemy.has_meta("garrison_host") else 0.0)
	)


static func _deposit_score(deposit, hq):
	var distance = hq.global_position_yless.distance_squared_to(deposit.global_position_yless)
	# Reclaim nearby observed wrecks while the route is safe; distant scraps never
	# justify abandoning a productive field or charging into unobserved enemy ground.
	return (
		distance * .5
		if deposit.is_in_group("salvage_wrecks") and distance <= HOME_RADIUS * HOME_RADIUS
		else distance
	)
