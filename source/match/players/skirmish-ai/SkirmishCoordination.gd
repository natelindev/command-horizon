extends RefCounted

const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")
const KINDS = ["assault", "guard", "capture", "scout"]
const COMMIT_SECONDS = 90.0
const FIELD_GROUP_RADIUS = 12.0


static func command(game, player, units, available, observed):
	var response = player._defend_economy(available, observed)
	var groups = []
	for defense in response.groups:
		groups.append(_group("defense", defense.point, defense.members, game.simulation_time))
	var fields = _fields(game, units, observed)
	var free = available.filter(func(unit): return unit not in response.units)
	var old_groups = player._army_groups
	for old in old_groups:
		if old.kind == "defense":
			continue
		var members = old.members.filter(
			func(unit):
				return (
					is_instance_valid(unit)
					and unit in free
					and (old.kind != "guard" or unit.hp >= unit.hp_max * 0.5)
				)
		)
		old.members = members
		if groups.size() >= player.difficulty + 1:
			if old.kind == "guard":
				_retire_guard(old, units)
			continue
		if members.is_empty() or _completed(game, player, old, fields):
			if old.kind == "guard":
				_retire_guard(old, units)
			continue
		if old.retiring:
			_retire_guard(old, units)
			if not _returning(old, units):
				continue
		elif game.simulation_time - old.started >= COMMIT_SECONDS:
			if _alternative(game, player, old.kind, groups, free, fields):
				if old.kind != "guard":
					continue
				old.retiring = true
				_retire_guard(old, units)
				if not _returning(old, units):
					continue
		# Keep the assault's core committed. Its reinforcements remain available
		# for bounded guard/capture teams when a second task slot opens up.
		if old.kind == "assault" and members.size() > 3:
			members = members.slice(0, 3)
			old.members = members
		groups.append(old)
		for unit in members:
			free.erase(unit)
	while groups.size() < player.difficulty + 1:
		var next = _choose(game, player, groups, free, fields)
		if next.is_empty():
			break
		groups.append(next)
		for unit in next.members:
			free.erase(unit)
	# Guards/capturers get their bounded teams before the assault receives reserves.
	for group in groups:
		if group.kind == "assault":
			var reserves = free.filter(_combatant)
			group.members.append_array(reserves)
			for unit in reserves:
				free.erase(unit)
	player._army_groups = groups
	var assigned = []
	for group in groups:
		assigned.append_array(group.members)
		_apply(game, player, group, units, observed, response.threats)
	_attach_scouts(groups, free, assigned)
	for unit in available:
		if unit in assigned or unit.type in ["Worker", "RepairRobot"] or unit.movement_speed <= 0:
			continue
		_regroup(player, unit, units)
	return {"units": assigned, "defenders": response.units}


static func allows_expansion(player, point):
	return player._army_groups.any(
		func(group):
			return (
				group.kind == "guard"
				and not group.retiring
				and group.point.distance_to(point) <= FIELD_GROUP_RADIUS
			)
	)


static func _group(kind, point, members, now):
	return {
		"kind": kind,
		"point": point,
		"members": members,
		"started": now,
		"retiring": false,
		"workers": []
	}


static func _combatant(unit):
	return unit.movement_speed > 0 and unit.attack_range != null


static func _fields(game, units, observed):
	var fields = []
	for point in Economy.expansion_points(game, units, observed):
		if fields.all(func(field): return field.distance_to(point) > FIELD_GROUP_RADIUS):
			fields.append(point)
	return fields


static func _completed(game, player, group, fields):
	if group.kind == "guard":
		return (
			not group.retiring
			and fields.all(func(point): return point.distance_to(group.point) > FIELD_GROUP_RADIUS)
		)
	if group.kind == "capture":
		return _relays(game).all(
			func(relay):
				return relay.position.distance_to(group.point) > 3 or relay.captured_by == player
		)
	if group.kind == "scout":
		return group.members.all(
			func(unit): return unit.global_position_yless.distance_to(group.point) < 5
		)
	return false


static func _alternative(game, player, kind, groups, free, fields):
	for candidate in KINDS:
		if (
			candidate not in [kind, "scout"]
			and not _candidate(game, player, candidate, groups, free, fields).is_empty()
		):
			return true
	return false


static func _choose(game, player, groups, free, fields):
	for offset in KINDS.size():
		var index = (player._army_cursor + offset) % KINDS.size()
		var candidate = _candidate(game, player, KINDS[index], groups, free, fields)
		if candidate.is_empty():
			continue
		player._army_cursor = (index + 1) % KINDS.size()
		return candidate
	return {}


static func _candidate(game, player, kind, groups, free, fields):
	var now = game.simulation_time
	if kind == "assault":
		if groups.any(func(group): return group.kind == kind) or not player._wave_ready():
			return {}
		var soldiers = free.filter(_combatant)
		if soldiers.size() >= 3:
			return _group(kind, _enemy_start(game), soldiers.slice(0, 3), now)
	elif kind == "guard":
		var used = 0
		for group in groups:
			if group.kind == kind:
				used += group.members.size()
		var choices = fields.filter(
			func(point): return _unassigned(groups, kind, point, FIELD_GROUP_RADIUS)
		)
		var guards = Economy.guards(free)
		if not choices.is_empty() and not guards.is_empty() and used < 2:
			var point = choices[0]
			_nearest(guards, point)
			var count = mini(2 - used, 1 if fields.size() > 1 else 2)
			return _group(kind, point, guards.slice(0, count), now)
	elif kind == "capture":
		var relays = _relays(game).filter(
			func(relay):
				return (
					relay.captured_by != player and _unassigned(groups, kind, relay.position, 3.0)
				)
		)
		var infantry = free.filter(func(unit): return unit.type == "Infantry")
		if not relays.is_empty() and not infantry.is_empty():
			_nearest(relays, infantry[0].position)
			var point = relays[0].position * Vector3(1, 0, 1)
			_nearest(infantry, point)
			var multiple = relays.size() > 1 and groups.size() < player.difficulty
			return _group(kind, point, infantry.slice(0, 1 if multiple else 2), now)
	elif kind == "scout":
		# Reconnaissance joins another task when there is one to support.
		if not groups.is_empty():
			return {}
		var scouts = free.filter(func(unit): return unit.type == "Drone")
		if not scouts.is_empty():
			return _group(kind, _enemy_start(game), scouts.slice(0, 1), now)
	return {}


static func _apply(game, player, group, units, observed, threats):
	if group.kind == "defense":
		return
	if group.kind == "guard":
		var points = Economy.expansion_points(game, units, observed).filter(
			func(point): return point.distance_to(group.point) <= FIELD_GROUP_RADIUS
		)
		if points.is_empty():
			points = [group.point]
		for index in group.members.size():
			var unit = group.members[index]
			var point = points[index % points.size()]
			var hq = Economy.headquarters(units, point)
			if hq != null:
				point += (hq.global_position_yless - point).normalized() * 5.0
			_order(player, unit, point)
	elif group.kind == "capture":
		for index in group.members.size():
			_order(
				player,
				group.members[index],
				group.point + Vector3(2 if index % 2 == 0 else -2, 0, 0)
			)
	elif group.kind == "assault":
		if player._wave_ready() and group.members.size() >= 3:
			group.point = player._offensive_goal(
				group.members,
				observed.filter(func(enemy): return enemy not in threats),
				_enemy_start(game)
			)
			player._last_wave = game.simulation_time
			player.attacks_launched += 1
		for unit in group.members:
			_order(
				player, unit, group.point + Vector3(unit.get_index() % 3, 0, unit.get_index() % 2)
			)
	elif group.kind == "scout":
		for unit in group.members:
			_move(unit, group.point)


static func _order(player, unit, point):
	if unit.action is AttackMove:
		if unit.action.destination.distance_to(point) <= 2:
			return
		if is_instance_valid(unit.action._shot):
			# Update the route after this engagement without restarting preparation.
			unit.action.destination = point
			return
	if unit.global_position_yless.distance_to(point) <= 2.5 and player._idle_order(unit):
		return
	unit.issue_manual_order(AttackMove.new(point))


static func _move(unit, point):
	if unit.action is Moving and unit.action._target_position.distance_to(point) < 2:
		return
	if unit.global_position_yless.distance_to(point) > 2.5:
		unit.issue_manual_order(Moving.new(point))
	elif (
		unit.action is AttackMove
		or (
			unit.get_node("Movement")._has_destination
			and unit.get_node("Movement").target_position.distance_to(point) > 2
		)
	):
		# Arrival also retires the previous task. An attack-move can be stopped
		# for a shot while still retaining a route to its now-unassigned goal.
		unit.issue_manual_order(null)


static func _attach_scouts(groups, free, assigned):
	if groups.is_empty():
		return
	var candidates = groups.filter(func(group): return group.kind != "scout")
	if candidates.is_empty():
		return
	for drone in free.filter(func(unit): return unit.type == "Drone"):
		candidates.sort_custom(
			func(a, b):
				return drone.position.distance_to(a.point) < drone.position.distance_to(b.point)
		)
		_move(drone, candidates[0].point)
		assigned.append(drone)


static func _retire_guard(group, units):
	group.retiring = true
	for worker in units:
		if worker.type != "Worker" or not worker.action is Harvest or worker.action._kind == 0:
			continue
		if worker.action._field_origin.distance_to(group.point) > FIELD_GROUP_RADIUS:
			continue
		var hq = Economy.headquarters(units, worker.global_position_yless)
		if hq == null:
			continue
		if worker not in group.workers:
			group.workers.append(worker)
		worker.manual_orders.clear_waiting()
		worker.issue_manual_order(Harvest.new(hq))


static func _returning(group, units):
	for worker in group.workers:
		if not is_instance_valid(worker) or worker.is_queued_for_deletion() or worker not in units:
			continue
		# A new construction/withdrawal authority is not overwritten to finish a patrol.
		if (
			worker.action is Harvest
			and worker.action._kind == 0
			and not worker.action.needs_assignment()
		):
			return true
	return false


static func _regroup(player, unit, units):
	var hq = Economy.headquarters(units, unit.global_position_yless)
	if hq == null:
		if not player._idle_order(unit):
			unit.issue_manual_order(null)
		return
	var point = hq.global_position_yless + Vector3(-5 - unit.get_index() % 3 * 2, 0, -5)
	if (
		unit.global_position_yless.distance_to(hq.global_position_yless) < 10
		and player._idle_order(unit)
	):
		return
	_move(unit, point)


static func _relays(game):
	return game.map.relays if "relays" in game.map else []


static func _enemy_start(game):
	return game.map.find_child("SpawnPoints").get_child(0).position * Vector3(1, 0, 1)


static func _nearest(units, point):
	units.sort_custom(
		func(a, b):
			return (
				(a.global_position * Vector3(1, 0, 1)).distance_squared_to(point)
				< (b.global_position * Vector3(1, 0, 1)).distance_squared_to(point)
			)
	)


static func _unassigned(groups, kind, point, distance):
	return groups.all(
		func(group): return group.kind != kind or group.point.distance_to(point) > distance
	)
