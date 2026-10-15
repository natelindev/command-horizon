extends Node

const Rules = preload("res://source/match/combat/CombatRules.gd")
const CELL_SIZE = 12.0
const MAX_OBSERVER_HINTS = 512
var _frame = -1
var _observers = {}
var _max_sight = 0.0
var _max_unit_radius = 0.0
var _blockers = {}
var _blockers_dirty = true
var _observer_hints = {}


func _ready():
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null:
		signals.unit_spawned.connect(_on_unit_topology_changed)
		signals.unit_died.connect(_on_unit_topology_changed)
		signals.schedule_navigation_rebake.connect(_on_unit_topology_changed)


func _on_unit_topology_changed(_arg = null):
	_blockers_dirty = true
	_observer_hints.clear()


func invalidate():
	_frame = -1
	_blockers_dirty = true
	_observer_hints.clear()


func _refresh():
	var frame = Engine.get_physics_frames()
	if _frame == frame:
		return
	_frame = frame
	_observers.clear()
	_max_sight = 0.0
	_max_unit_radius = 0.0
	for unit in (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("vision_sources")
	):
		if unit.is_queued_for_deletion() or unit.sight_range == null:
			continue
		if unit.player == null:
			continue
		if not _observers.has(unit.player):
			_observers[unit.player] = {}
		var cell = _cell(unit.global_position)
		if not _observers[unit.player].has(cell):
			_observers[unit.player][cell] = []
		_observers[unit.player][cell].append(unit)
		var reach = unit.sight_range
		if unit.has_meta("garrison_host"):
			reach += unit.get_meta("garrison_host").radius + 2.0
		_max_sight = maxf(_max_sight, reach)
		if unit.is_in_group("units"):
			_max_unit_radius = maxf(_max_unit_radius, unit.radius)
	if _blockers_dirty:
		_blockers_dirty = false
		_blockers.clear()
		for obstacle in get_tree().get_nodes_in_group("sight_blockers"):
			var body = obstacle.get_parent()
			if not is_instance_valid(body) or body.is_queued_for_deletion():
				continue
			var center = body.global_position
			var entry = {
				"body": body,
				"center": center,
				"radius": obstacle.radius,
				"height": obstacle.sight_height
			}
			var low = _cell(center - Vector3.ONE * obstacle.radius)
			var high = _cell(center + Vector3.ONE * obstacle.radius)
			for x in range(low.x, high.x + 1):
				for y in range(low.y, high.y + 1):
					var cell = Vector2i(x, y)
					if not _blockers.has(cell):
						_blockers[cell] = []
					_blockers[cell].append(entry)


func can_observe(observer, target):
	if (
		not is_instance_valid(target)
		or not target.is_inside_tree()
		or target.is_queued_for_deletion()
	):
		return false
	return can_observe_point(observer, target.global_position + Vector3.UP * 0.8, target)


func can_observe_point(observer, point, ignored_target = null):
	if (
		not is_instance_valid(observer)
		or not observer.is_inside_tree()
		or observer.is_queued_for_deletion()
	):
		return false
	if observer.sight_range == null or observer.hp == null or observer.hp <= 0:
		return false
	if observer.has_method("is_constructed") and not observer.is_constructed():
		return false
	var origin = observer.global_position + Vector3.UP * 0.8
	var reach = observer.sight_range
	if observer.has_meta("garrison_host"):
		reach += observer.get_meta("garrison_host").radius + 2.0
	if is_instance_valid(ignored_target) and ignored_target.is_in_group("neutral_buildings"):
		reach += ignored_target.radius
	var offset = (point - origin) * Vector3(1, 0, 1)
	return (
		offset.length_squared() <= reach * reach
		and line_clear(origin, point, observer, ignored_target)
	)


func is_observed(player, target):
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if "player" in target and target.player == player:
		return true
	_refresh()
	if not _observer_hints.has(player):
		_observer_hints[player] = {}
	var hints = _observer_hints[player]
	var target_id = target.get_instance_id()
	var reference = hints.get(target_id)
	var witness = reference.get_ref() if reference != null else null
	# Reuse the last successful observer, never its previous visibility result.
	# Current ownership, life/construction, range and obstruction are checked on every query.
	if is_instance_valid(witness) and witness.player == player and can_observe(witness, target):
		return true
	hints.erase(target_id)
	var point = target.global_position * Vector3(1, 0, 1)
	var reach = _max_sight + (target.radius if target.is_in_group("neutral_buildings") else 0.0)
	var low = _cell(point - Vector3.ONE * (reach + CELL_SIZE))
	var high = _cell(point + Vector3.ONE * (reach + CELL_SIZE))
	var cells = _observers.get(player, {})
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for ally in cells.get(Vector2i(x, y), []):
				# Reject distant cells' members before the full visibility query.
				# Live range, ownership and occlusion are still authoritative below.
				if not is_instance_valid(ally) or ally.player != player:
					continue
				if (
					(ally.global_position * Vector3(1, 0, 1)).distance_squared_to(point)
					> reach * reach
				):
					continue
				if can_observe(ally, target):
					if hints.size() >= MAX_OBSERVER_HINTS:
						hints.clear()
					hints[target_id] = weakref(ally)
					return true
	return false


func _cell(point):
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))


func can_fire(source, target):
	if not Rules.can_target(source, target):
		return false
	var reach = Rules.range_for(source, target)
	if (
		source.global_position_yless.distance_squared_to(target.global_position_yless)
		> reach * reach
	):
		return false
	return is_observed(source.player, target) and has_line_of_fire(source, target)


func fireable_targets(source):
	var result = []
	if not is_instance_valid(source) or source.attack_range == null:
		return result
	var origin = source.global_position_yless
	for candidate in nearby_combat_targets(
		origin,
		(
			source.attack_range
			+ (
				source.get_meta("garrison_host").radius + 2.0
				if source.has_meta("garrison_host")
				else 0.0
			)
		)
	):
		if can_fire(source, candidate):
			result.append(candidate)
	return result


func automatic_target(source, eligible_targets = null):
	var best = null
	var score = INF
	var targets = fireable_targets(source) if eligible_targets == null else eligible_targets
	if targets.is_empty():
		return null
	var incoming = _incoming_damage(source, targets)
	for target in targets:
		var value = target_score(source, target, incoming.get(target, 0.0))
		if value < score:
			score = value
			best = target
	return best


func target_score(source, target, incoming_damage = 0.0):
	var damage = Rules.damage(source, target)
	if damage <= 0:
		return INF
	# Armed opposition, effective counters and finishing comparable wounded
	# targets. Explicit attacks and saved/programmed priorities retain authority.
	var effectiveness = damage / maxf(0.01, source.attack_damage)
	var shots = maxf(1, ceilf(target.hp / damage))
	var distance = source.global_position_yless.distance_to(target.global_position_yless)
	return (
		(0.0 if Rules.can_target(target, source) else 100.0)
		+ (20.0 if incoming_damage >= target.hp else 0.0)
		- effectiveness * 4.0
		- 1.0 / shots
		+ distance / maxf(1.0, Rules.range_for(source, target)) * 0.25
	)


func _incoming_damage(source, targets):
	var incoming = {}
	if targets.is_empty():
		return incoming
	var target_set = {}
	for target in targets:
		target_set[target] = true
	# Both projectile types join this group, including restored shots.
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if (
			not is_instance_valid(projectile)
			or projectile.is_queued_for_deletion()
			or not "_resolved" in projectile
			or projectile._resolved
			or not "target_unit" in projectile
			or not target_set.has(projectile.target_unit)
		):
			continue
		var ally = projectile.get_parent()
		if (
			not is_instance_valid(ally)
			or ally.player != source.player
			or ally.is_queued_for_deletion()
			or not ally.can_process()
		):
			continue
		var target = projectile.target_unit
		# Shots re-check line of fire on impact, so blocked ones will miss.
		if has_line_of_fire(ally, target):
			incoming[target] = incoming.get(target, 0.0) + Rules.damage(ally, target)
	return incoming


func has_line_of_fire(source, target):
	return line_clear(
		source.global_position + Vector3.UP * 0.8,
		target.global_position + Vector3.UP * 0.8,
		source,
		target
	)


func line_clear(origin, end, ignored_source = null, ignored_target = null):
	_refresh()
	if is_instance_valid(ignored_source) and ignored_source.has_meta("garrison_host"):
		ignored_source = ignored_source.get_meta("garrison_host")
	var low = _cell(origin.min(end))
	var high = _cell(origin.max(end))
	var checked = {}
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for entry in _blockers.get(Vector2i(x, y), []):
				var body = entry.body
				if not is_instance_valid(body) or body.is_queued_for_deletion():
					continue
				if (
					body == ignored_source
					or body == ignored_target
					or (is_instance_valid(ignored_source) and body.is_ancestor_of(ignored_source))
					or (is_instance_valid(ignored_target) and body.is_ancestor_of(ignored_target))
					or checked.has(body)
				):
					continue
				checked[body] = true
				if body.has_method("is_constructed") and not body.is_constructed():
					continue
				if segment_hits_cylinder(origin, end, entry.center, entry.radius, entry.height):
					return false
	return true


# Intersection with the finite cylinder, including sloping airborne sight lines.
static func segment_hits_cylinder(origin, end, center, radius, height):
	var direction = end - origin
	var offset = origin - center
	var a = direction.x * direction.x + direction.z * direction.z
	var b = 2.0 * (offset.x * direction.x + offset.z * direction.z)
	var c = offset.x * offset.x + offset.z * offset.z - radius * radius
	var low = 0.0
	var high = 1.0
	if a < 0.000001:
		if c > 0:
			return false
	else:
		var discriminant = b * b - 4.0 * a * c
		if discriminant < 0:
			return false
		var root = sqrt(discriminant)
		low = max(low, (-b - root) / (2.0 * a))
		high = min(high, (-b + root) / (2.0 * a))
	if abs(direction.y) < 0.000001:
		if offset.y < 0 or offset.y > height:
			return false
	else:
		var bottom = -offset.y / direction.y
		var top = (height - offset.y) / direction.y
		low = max(low, min(bottom, top))
		high = min(high, max(bottom, top))
	return low <= high


func observed_enemies_near(source, radius):
	# Broad-phase culling belongs to perception, not to a program's world view.
	# Only currently observed enemies leave this query.
	var result = []
	for candidate in nearby_combat_targets(source.global_position_yless, radius):
		if Rules.can_target(source, candidate) and is_observed(source.player, candidate):
			result.append(candidate)
	return result


func nearby_bodies(point, margin, player_filter = null):
	_refresh()
	return nearby_units(point * Vector3(1, 0, 1), _max_unit_radius + margin, player_filter)


func nearby_units(point, radius, player_filter = null):
	_refresh()
	var result = []
	var low = _cell(point - Vector3.ONE * radius)
	var high = _cell(point + Vector3.ONE * radius)
	for player in _observers:
		if player_filter != null and player != player_filter:
			continue
		var cells = _observers[player]
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				for unit in cells.get(Vector2i(x, y), []):
					if (
						is_instance_valid(unit)
						and not unit.is_queued_for_deletion()
						and unit.is_in_group("units")
						and unit.global_position_yless.distance_squared_to(point) <= radius * radius
					):
						result.append(unit)
	return result


func nearby_combat_targets(point, radius):
	var result = nearby_units(point, radius)
	for building in get_tree().get_nodes_in_group("neutral_buildings"):
		if building.player != null and building.hp > 0:
			if (
				building.global_position_yless.distance_squared_to(point)
				<= (radius + building.radius) * (radius + building.radius)
			):
				result.append(building)
	return result
