# Independent guard clauses keep validation and eligibility paths explicit.
# gdlint: disable=max-returns
extends Node

const Players = preload("res://source/match/Players.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const Unit = preload("res://source/match/units/Unit.gd")
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
# Furthest footprint point from a footprinted structure's center (runway airfield).
const FOOTPRINT_REACH = 13.0
const CELL_SIZE = 12.0
const BODY_CELL_SIZE = 3.0
const MAX_OBSERVER_HINTS = 512
const EMPTY_CELLS = {}
const EMPTY_UNITS = []
const TerrainSight = preload("res://source/match/maps/terrain/TerrainSight.gd")
const AIR = Constants.Match.Navigation.Domain.AIR
var native_exploration := false
var native_combat_queries := false
var native_battlefield_index := false
var _frame: int = -1
var _observers: Dictionary = {}
var _bodies: Dictionary = {}
var _platforms: Dictionary = {}
var _units: Dictionary = {}
var _max_sight: float = 0.0
var _max_unit_radius: float = 0.0
var _max_body_step: float = 0.0
var _blockers: Dictionary = {}
var _blockers_dirty: bool = true
var _observer_hints: Dictionary = {}
var _vision_keys: Dictionary = {}
# Authored elevated maps: their TerrainModel adds ground, formation, forest
# and high-ground occlusion to every sight and fire check.
var _terrain: TerrainModel
var _native_queries: RefCounted
var _native_index = false
var _native_index_used = false
var _native_visibility: RefCounted
var _resident_index_used := false
var _match_registry: Node
var _owner_bits := {}


func _ready():
	if get_parent().has_method("get_units"):
		_match_registry = get_parent()
	_native_queries = load("res://source/match/rendering/NativePosePacker.gd").create()
	if _native_queries != null and not _native_queries.has_method("nearby_units_filtered"):
		_native_queries = null
	_native_index = (
		_native_queries != null
		and _native_queries.has_method("index_observers")
		and not "--script-spatial-index" in OS.get_cmdline_user_args()
	)
	var map = get_parent().get("map")
	if map != null and map.is_elevated() and "terrain" in map:
		_terrain = map.terrain
	if (
		"--native-visibility-runtime" in OS.get_cmdline_user_args()
		and ClassDB.class_exists("CopperfinVisibilityRuntime")
	):
		_native_visibility = ClassDB.instantiate("CopperfinVisibilityRuntime")
		if not _native_visibility.configure(self, Unit, _terrain, _blockers):
			_native_visibility = null
		elif "--profile-runtime" in OS.get_cmdline_user_args():
			_native_visibility.profile(true)
	native_exploration = (
		"--native-exploration" in OS.get_cmdline_user_args()
		and _native_visibility != null
		and _native_visibility.has_method("explore_cells")
	)
	native_combat_queries = (
		"--native-combat-queries" in OS.get_cmdline_user_args()
		and _native_visibility != null
		and _native_visibility.has_method("can_fire")
	)
	native_battlefield_index = (
		"--native-battlefield-index" in OS.get_cmdline_user_args()
		and _native_visibility != null
		and _native_visibility.has_method("rebuild_index")
	)
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null:
		signals.unit_spawned.connect(_on_unit_topology_changed)
		signals.unit_died.connect(_on_unit_topology_changed)
		signals.schedule_navigation_rebake.connect(_on_unit_topology_changed)


func _on_unit_topology_changed(_arg = null):
	_owner_bits.clear()
	_frame = -1
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
	_bodies.clear()
	_platforms.clear()
	_units.clear()
	_vision_keys.clear()
	_max_sight = 0.0
	_max_unit_radius = 0.0
	_max_body_step = 0.0
	var physics_delta := get_physics_process_delta_time()
	var observers = (
		_match_registry.get_observers()
		if _match_registry != null
		else (
			get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("vision_sources")
		)
	)
	var resident: Array = (
		_native_visibility.rebuild_index(observers, physics_delta)
		if native_battlefield_index and _native_visibility != null
		else []
	)
	if _resident_index_used and resident.size() != 3 and _native_visibility != null:
		_native_visibility.clear_index()
	_resident_index_used = resident.size() == 3
	var indexed = (
		_native_queries.index_observers(observers, physics_delta)
		if not _resident_index_used and _native_index and _native_queries != null
		else []
	)
	_native_index_used = _resident_index_used or indexed.size() == 6
	if _resident_index_used:
		_max_sight = resident[0]
		_max_unit_radius = resident[1]
		_max_body_step = resident[2]
	elif _native_index_used:
		_observers = indexed[0]
		_bodies = indexed[1]
		_units = indexed[2]
		_max_sight = indexed[3]
		_max_unit_radius = indexed[4]
		_max_body_step = indexed[5]
	else:
		for unit in observers:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion():
				continue
			if unit is Unit:
				_index_unit(unit, physics_delta)
			else:
				_index_other_observer(unit, physics_delta)
	# Drive-on decks include neutral service sites as well as player depots.
	# Index them once per tick instead of scanning every deck for every mover.
	for platform in get_tree().get_nodes_in_group("repair_platforms"):
		_platforms.get_or_add(_body_cell(platform.global_position), []).append(platform)
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
			var low: Vector2i = _cell(center - Vector3.ONE * obstacle.radius)
			var high: Vector2i = _cell(center + Vector3.ONE * obstacle.radius)
			for x in range(low.x, high.x + 1):
				for y in range(low.y, high.y + 1):
					var cell = Vector2i(x, y)
					if not _blockers.has(cell):
						_blockers[cell] = []
					_blockers[cell].append(entry)
		if _native_visibility != null:
			_native_visibility.configure(self, Unit, _terrain, _blockers)


func _index_unit(unit: Unit, delta: float):
	if unit.is_queued_for_deletion() or unit.sight_range == null or unit.player == null:
		return
	var reach: float = unit.effective_sight_range()
	if unit.has_meta("garrison_host"):
		reach += unit.get_meta("garrison_host").radius + 2.0
	var body: bool = unit.is_in_group("units")
	var radius: float = 0.0
	var speed: float = 0.0
	if body:
		# Resolve the trait once; retain live modifiers and obstacle radii.
		var movement = unit._get_navigation_trait()
		radius = movement.radius if movement != null else 0.0
		speed = movement.speed if movement is NavigationAgent3D else 0.0
	_store_observer(unit, unit.player, unit.global_position, reach, body, radius, speed * delta)


func _index_other_observer(unit, delta: float):
	if unit.is_queued_for_deletion() or unit.sight_range == null or unit.player == null:
		return
	var reach: float = _sight_reach(unit)
	if unit.has_meta("garrison_host"):
		reach += unit.get_meta("garrison_host").radius + 2.0
	var body: bool = unit.is_in_group("units")
	_store_observer(
		unit,
		unit.player,
		unit.global_position,
		reach,
		body,
		unit.radius if body else 0.0,
		unit.movement_speed * delta if body else 0.0
	)


func _store_observer(
	unit, player, position: Vector3, reach: float, body: bool, radius: float, step: float
):
	if not _vision_keys.has(player):
		_vision_keys[player] = player.team if "team" in player and player.team >= 0 else player
	var vision_key = _vision_keys[player]
	if not _observers.has(vision_key):
		_observers[vision_key] = {}
	var observer_cells: Dictionary = _observers[vision_key]
	var cell: Vector2i = _cell(position)
	if not observer_cells.has(cell):
		observer_cells[cell] = []
	observer_cells[cell].append(unit)
	_max_sight = maxf(_max_sight, reach)
	if body:
		_max_unit_radius = maxf(_max_unit_radius, radius)
		_max_body_step = maxf(_max_body_step, step)
		# One body grid across owners; narrow phases retain live positions/ownership.
		var body_cell: Vector2i = _body_cell(position)
		if not _bodies.has(body_cell):
			_bodies[body_cell] = []
		_bodies[body_cell].append(unit)
		if not _units.has(cell):
			_units[cell] = []
		_units[cell].append(unit)


func can_observe(observer, target):
	if (
		not is_instance_valid(observer)
		or not is_instance_valid(target)
		or not target.is_inside_tree()
		or target.is_queued_for_deletion()
	):
		return false
	var point = target.global_position
	if target.is_in_group("footprinted_structures"):
		# A long structure is seen wherever its footprint is in sight.
		point = Footprint.closest_point(target, observer.global_position)
	return can_observe_point(observer, point + Vector3.UP * 0.8, target)


func can_observe_point(observer, point: Vector3, ignored_target = null) -> bool:
	if (
		not is_instance_valid(observer)
		or not observer.is_inside_tree()
		or observer.is_queued_for_deletion()
	):
		return false
	if (
		is_instance_valid(ignored_target)
		and "optical_cloak" in ignored_target
		and ignored_target.optical_cloak != null
	):
		if not ignored_target.optical_cloak.detected_by(observer):
			return false
	if _native_visibility != null:
		return _native_visibility.can_observe_point(observer, point, ignored_target)
	if observer is Unit:
		return _unit_can_observe_point(observer, point, ignored_target)
	if observer.sight_range == null or observer.hp == null or observer.hp <= 0:
		return false
	if observer.has_method("is_constructed") and not observer.is_constructed():
		return false
	var origin: Vector3 = observer.global_position + Vector3.UP * 0.8
	var reach = _sight_reach(observer, point - Vector3.UP * 0.8)
	if observer.has_meta("garrison_host"):
		reach += observer.get_meta("garrison_host").radius + 2.0
	if is_instance_valid(ignored_target) and ignored_target.is_in_group("neutral_buildings"):
		reach += ignored_target.radius
	var offset := (point - origin) * Vector3(1, 0, 1)
	return (
		offset.length_squared() <= reach * reach
		and _terrain_visible(observer, origin, point, ignored_target)
		and line_clear(origin, point, observer, ignored_target)
	)


func _unit_can_observe_point(observer: Unit, point: Vector3, ignored_target) -> bool:
	if observer.sight_range == null or observer.hp == null or observer.hp <= 0:
		return false
	if observer.has_method("is_constructed") and not observer.is_constructed():
		return false
	var origin: Vector3 = observer.global_position + Vector3.UP * .8
	var reach: float = observer.effective_sight_range(point - Vector3.UP * .8)
	if observer.has_meta("garrison_host"):
		reach += observer.get_meta("garrison_host").radius + 2.0
	if is_instance_valid(ignored_target) and ignored_target.is_in_group("neutral_buildings"):
		reach += ignored_target.radius
	var offset: Vector3 = (point - origin) * Vector3(1, 0, 1)
	return (
		offset.length_squared() <= reach * reach
		and _terrain_visible(observer, origin, point, ignored_target)
		and line_clear(origin, point, observer, ignored_target)
	)


func _terrain_visible(observer, origin: Vector3, point: Vector3, target) -> bool:
	if _terrain == null or _airborne(observer):
		return true
	var observer_flat = Vector2(origin.x, origin.z)
	var target_flat = Vector2(point.x, point.z)
	var airborne_target = is_instance_valid(target) and _airborne(target)
	if (
		not airborne_target
		and TerrainSight.high_ground_hidden(_terrain, observer_flat, target_flat)
	):
		return false
	return TerrainSight.segment_clear(
		_terrain, _eye(observer_flat), point if airborne_target else _eye(target_flat)
	)


func _sight_reach(unit, point = null):
	if not is_instance_valid(unit):
		return 0.0
	if unit is Unit:
		var body: Unit = unit
		return body.effective_sight_range(point)
	return (
		unit.effective_sight_range(point)
		if unit.has_method("effective_sight_range")
		else unit.sight_range
	)


func _airborne(unit) -> bool:
	if not is_instance_valid(unit):
		return false
	if unit is Unit:
		var body: Unit = unit
		return body.combat_domain() == AIR
	if unit.has_method("combat_domain"):
		return unit.combat_domain() == AIR
	return "movement_domain" in unit and unit.movement_domain == AIR


func _eye(point: Vector2) -> Vector3:
	return Vector3(point.x, _terrain.height_at(point) + TerrainSight.EYE, point.y)


func is_observed(player, target):
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target.is_in_group("field_mines") and get_parent().engineering != null:
		return get_parent().engineering.observed_by(player, target)
	if "player" in target and Players.allied(target.player, player):
		return true
	if "optical_cloak" in target and target.optical_cloak != null:
		if not target.optical_cloak.detected_by_player(player, self):
			return false
	_refresh()
	if _native_visibility != null:
		return _native_visibility.observed(player, target, _observers, _max_sight, _max_body_step)
	if not _observer_hints.has(player):
		_observer_hints[player] = {}
	var hints = _observer_hints[player]
	var target_id = target.get_instance_id()
	var reference = hints.get(target_id)
	var witness = reference.get_ref() if reference != null else null
	# Reuse the last successful observer, never its previous visibility result.
	# Current ownership, life/construction, range and obstruction are checked on every query.
	if (
		is_instance_valid(witness)
		and Players.allied(witness.player, player)
		and can_observe(witness, target)
	):
		return true
	hints.erase(target_id)
	var point = target.global_position * Vector3(1, 0, 1)
	var reach = _max_sight + (target.radius if target.is_in_group("neutral_buildings") else 0.0)
	if target.is_in_group("footprinted_structures"):
		reach += FOOTPRINT_REACH
	# Observers can move after the index is built; cover their maximum step
	# instead of scanning an entire extra ring of twelve-metre cells.
	var low = _cell(point - Vector3.ONE * (reach + _max_body_step))
	var high = _cell(point + Vector3.ONE * (reach + _max_body_step))
	var vision_key = player.team if "team" in player and player.team >= 0 else player
	var cells: Dictionary = _observers.get(vision_key, EMPTY_CELLS)
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for ally in cells.get(Vector2i(x, y), EMPTY_UNITS):
				# Reject distant cells' members before the full visibility query.
				# Live range, ownership and occlusion are still authoritative below.
				if not is_instance_valid(ally) or not Players.allied(ally.player, player):
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


func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))


func can_fire(source, target):
	if not is_instance_valid(source) or not is_instance_valid(target):
		return false
	if (
		"optical_cloak" in target
		and target.optical_cloak != null
		and not target.optical_cloak.detected_by_player(source.player, self)
	):
		return false
	if native_combat_queries:
		_refresh()
		var answer: int = _native_visibility.can_fire(
			source, target, _observers, _max_sight, _max_body_step
		)
		if answer >= 0:
			return answer != 0
	if not Rules.can_target(source, target):
		return false
	if Footprint.reach_distance(target, source.global_position) > Rules.range_for(source, target):
		return false
	return is_observed(source.player, target) and has_line_of_fire(source, target)


func fireable_targets(source):
	return in_range_targets(source).filter(
		func(candidate):
			return is_observed(source.player, candidate) and has_line_of_fire(source, candidate)
	)


# Geometric and weapon eligibility only. Callers must validate observation and
# line of fire before granting a shot; automatic acquisition does so in rank order.
func in_range_targets(source):
	var result = []
	if not is_instance_valid(source) or source.attack_range == null:
		return result
	var origin = source.global_position_yless
	for candidate in nearby_combat_targets(
		origin,
		(
			source.attack_range
			+ Rules.high_ground_range_bonus(source)
			+ (
				source.get_meta("garrison_host").radius + 2.0
				if source.has_meta("garrison_host")
				else 0.0
			)
		),
		source.player
	):
		if (
			Rules.can_target(source, candidate)
			and (
				Footprint.reach_distance(candidate, source.global_position)
				<= Rules.range_for(source, candidate)
			)
		):
			result.append(candidate)
	# Long structures can be in range while their center is not.
	for structure in get_tree().get_nodes_in_group("footprinted_structures"):
		if (
			not Players.allied(structure.player, source.player)
			and not structure in result
			and Rules.can_target(source, structure)
			and (
				Footprint.reach_distance(structure, source.global_position)
				<= Rules.range_for(source, structure)
			)
		):
			result.append(structure)
	return result


func automatic_target(source, eligible_targets = null):
	var targets = in_range_targets(source) if eligible_targets == null else eligible_targets
	if eligible_targets != null:
		targets = targets.filter(func(target): return Rules.can_target(source, target))
	if targets.is_empty():
		return null
	var incoming = _incoming_damage(source, targets)
	var facts = Rules.damage_facts(source)
	var ranked = []
	for target in targets:
		var may_attack = target.attack_range != null
		var value = target_score(source, target, incoming.get(target, 0.0), true, facts, may_attack)
		if is_finite(value):
			# Preserve the original candidate order at equal scores. Air defense
			# tries every eligible aircraft before falling back to ground targets.
			var priority = 0 if source.type == "AntiAirTurret" and _airborne(target) else 1
			ranked.append([priority, value, ranked.size(), target, may_attack])
	ranked.sort_custom(
		func(a, b):
			if a[0] != b[0]:
				return a[0] < b[0]
			return a[1] < b[1] if a[1] != b[1] else a[2] < b[2]
	)
	# The preliminary score assumes armed targets can attack back. It is a lower
	# bound: exact eligibility can only add 100. Stop when no remaining candidate
	# can improve the best fully validated score, retaining original-order ties.
	var best = null
	var best_score = INF
	var best_priority = 2
	var best_index = 0
	for candidate in ranked:
		if best != null and (candidate[0] > best_priority or candidate[1] > best_score):
			break
		var value = candidate[1]
		if candidate[4] and not Rules.can_target(candidate[3], source):
			# Recombine in the original arithmetic order, preserving score ties.
			value = target_score(
				source, candidate[3], incoming.get(candidate[3], 0.0), true, facts, false
			)
		if (
			best != null
			and (value > best_score or (value == best_score and candidate[2] >= best_index))
		):
			continue
		if can_fire(source, candidate[3]):
			best = candidate[3]
			best_score = value
			best_priority = candidate[0]
			best_index = candidate[2]
	return best


func target_score(
	source, target, incoming_damage = 0.0, eligible = false, facts = null, armed_hint = null
):
	# Acquisition has already checked weapon legality without yielding. Avoid
	# repeating that work for each score; public callers still validate by default.
	var damage = (
		Rules.damage_with_facts(facts, target)
		if eligible and facts != null
		else (Rules._damage(source, target) if eligible else Rules.damage(source, target))
	)
	if damage <= 0:
		return INF
	# Armed opposition, effective counters and finishing comparable wounded
	# targets. Explicit attacks retain authority.
	var effectiveness = (
		damage / maxf(0.01, facts.damage if eligible and facts != null else source.attack_damage)
	)
	var shots = maxf(1, ceilf(target.hp / damage))
	var distance = source.global_position_yless.distance_to(target.global_position_yless)
	var armed = Rules.can_target(target, source) if armed_hint == null else armed_hint
	return (
		(0.0 if armed else 100.0)
		+ (20.0 if incoming_damage >= target.hp else 0.0)
		- effectiveness * 4.0
		- 1.0 / shots
		+ distance / maxf(1.0, Rules.range_for(source, target)) * 0.25
	)


func _incoming_damage(source, targets):
	if targets.is_empty():
		return {}
	# Rounds re-check line of fire on arrival, so blocked ones are excluded.
	return get_parent().projectile_system.incoming_damage(source.player, targets)


func has_line_of_fire(source, target):
	if _native_visibility != null:
		return _native_visibility.has_line_of_fire(source, target)
	# Shots pass through forest canopy but not through ground or formations.
	if _terrain != null and not _airborne(source):
		var source_flat = Vector2(source.global_position.x, source.global_position.z)
		var target_flat = Vector2(target.global_position.x, target.global_position.z)
		if not TerrainSight.segment_clear(
			_terrain,
			_eye(source_flat),
			(
				target.global_position + Vector3.UP * TerrainSight.EYE
				if _airborne(target)
				else _eye(target_flat)
			),
			false
		):
			return false
	return line_clear(
		source.global_position + Vector3.UP * 0.8,
		target.global_position + Vector3.UP * 0.8,
		source,
		target
	)


func line_clear(
	origin: Vector3, end: Vector3, ignored_source = null, ignored_target = null
) -> bool:
	_refresh()
	if _native_visibility != null:
		return _native_visibility.line_clear(origin, end, ignored_source, ignored_target)
	if is_instance_valid(ignored_source) and ignored_source.has_meta("garrison_host"):
		ignored_source = ignored_source.get_meta("garrison_host")
	var low = _cell(origin.min(end))
	var high = _cell(origin.max(end))
	var checked = {}
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for entry in _blockers.get(Vector2i(x, y), EMPTY_UNITS):
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


# The first sight blocker a moving round enters between origin and end, as
# {"body", "t"} with t the fraction along the segment; empty when clear.
func first_blocker(origin: Vector3, end: Vector3, ignored_source = null, ignored_target = null):
	_refresh()
	if is_instance_valid(ignored_source) and ignored_source.has_meta("garrison_host"):
		ignored_source = ignored_source.get_meta("garrison_host")
	var low = _cell(origin.min(end))
	var high = _cell(origin.max(end))
	var best = {}
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for entry in _blockers.get(Vector2i(x, y), EMPTY_UNITS):
				var body = entry.body
				# Drive-over salvage rubble hides low sight lines but does not stop rounds.
				if (
					not is_instance_valid(body)
					or body.is_queued_for_deletion()
					or body == ignored_source
					or body == ignored_target
					or body.is_in_group("salvage_wrecks")
					or (body.has_method("is_constructed") and not body.is_constructed())
				):
					continue
				var t = segment_cylinder_entry(
					origin, end, entry.center, entry.radius, entry.height
				)
				if t >= 0.0 and (best.is_empty() or t < best.t):
					best = {"body": body, "t": t}
	return best


# Fraction along origin→end where the segment first enters the finite upright
# cylinder standing on `base`, or -1 when it never does.
static func segment_cylinder_entry(
	origin: Vector3, end: Vector3, base: Vector3, radius: float, height: float
) -> float:
	var direction := end - origin
	var offset := origin - base
	var a := direction.x * direction.x + direction.z * direction.z
	var b := 2.0 * (offset.x * direction.x + offset.z * direction.z)
	var c := offset.x * offset.x + offset.z * offset.z - radius * radius
	var low := 0.0
	var high := 1.0
	if a < 0.000001:
		if c > 0:
			return -1.0
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant < 0:
			return -1.0
		var root := sqrt(discriminant)
		low = maxf(low, (-b - root) / (2.0 * a))
		high = minf(high, (-b + root) / (2.0 * a))
	if abs(direction.y) < 0.000001:
		if offset.y < 0 or offset.y > height:
			return -1.0
	else:
		var bottom := -offset.y / direction.y
		var top := (height - offset.y) / direction.y
		low = maxf(low, minf(bottom, top))
		high = minf(high, maxf(bottom, top))
	return low if low <= high else -1.0


# Intersection with the finite cylinder, including sloping airborne sight lines.
static func segment_hits_cylinder(
	origin: Vector3, end: Vector3, center: Vector3, radius: float, height: float
) -> bool:
	var direction := end - origin
	var offset := origin - center
	var a := direction.x * direction.x + direction.z * direction.z
	var b := 2.0 * (offset.x * direction.x + offset.z * direction.z)
	var c := offset.x * offset.x + offset.z * offset.z - radius * radius
	var low := 0.0
	var high := 1.0
	if a < 0.000001:
		if c > 0:
			return false
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant < 0:
			return false
		var root := sqrt(discriminant)
		low = maxf(low, (-b - root) / (2.0 * a))
		high = minf(high, (-b + root) / (2.0 * a))
	if abs(direction.y) < 0.000001:
		if offset.y < 0 or offset.y > height:
			return false
	else:
		var bottom := -offset.y / direction.y
		var top := (height - offset.y) / direction.y
		low = maxf(low, minf(bottom, top))
		high = minf(high, maxf(bottom, top))
	return low <= high


func observed_enemies_near(source, radius):
	# Only currently observed enemies leave this query.
	var result = []
	for candidate in nearby_combat_targets(source.global_position_yless, radius, source.player):
		if Rules.can_target(source, candidate) and is_observed(source.player, candidate):
			result.append(candidate)
	return result


func nearby_bodies(point, margin, player_filter = null):
	_refresh()
	return nearby_units(point * Vector3(1, 0, 1), _max_unit_radius + margin, player_filter)


func nearby_repair_platforms(point: Vector3) -> Array:
	_refresh()
	if _native_queries != null:
		return _native_queries.nearby_units(
			_platforms, point, 2.0, BODY_CELL_SIZE, 2.0 + _max_body_step
		)
	return get_tree().get_nodes_in_group("repair_platforms").filter(
		func(platform):
			return (
				not platform.is_queued_for_deletion()
				and (
					(platform.global_position * Vector3(1, 0, 1)).distance_squared_to(
						point * Vector3(1, 0, 1)
					)
					<= 4.0
				)
			)
	)


# Body contact queries need a much finer grid than shared vision queries.
# Keep live positions in the narrow phase, including changes within this tick.
func _body_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / BODY_CELL_SIZE), floori(point.z / BODY_CELL_SIZE))


func _owner_bit(player) -> int:
	if player == null:
		return -1
	if not _owner_bits.has(player):
		if _owner_bits.size() >= 63:
			return 0  # Unbounded/editor fixtures retain the script path.
		_owner_bits[player] = 1 << _owner_bits.size()
	return _owner_bits[player]


func nearby_units(point: Vector3, radius: float, player_filter = null, excluded_player = null):
	_refresh()
	if _resident_index_used:
		return _native_visibility.nearby_indexed(point, radius, player_filter, excluded_player)
	var result = []
	var coarse := radius >= CELL_SIZE * 0.5
	var cell_size := CELL_SIZE if coarse else BODY_CELL_SIZE
	var cells: Dictionary = _units if coarse else _bodies
	# Avoidance callbacks move bodies sequentially after this tick's index is
	# built. Include one speed-bounded step so crossing a cell cannot hide a body.
	var indexed_reach := radius + _max_body_step
	if _native_queries != null:
		if player_filter == null and excluded_player == null:
			return _native_queries.nearby_units(cells, point, radius, cell_size, indexed_reach)
		var included := _owner_bit(player_filter)
		var excluded := _owner_bit(excluded_player)
		# Reserve the sign bit for owners absent from this dictionary. Excluding
		# one player must still include a newly captured, previously unseen owner.
		if included != 0 and excluded != 0:
			var allowed := included if player_filter != null else -1
			if excluded_player != null:
				allowed &= ~excluded
			return _native_queries.nearby_units_filtered(
				cells, point, radius, cell_size, indexed_reach, _owner_bits, allowed
			)
	var low := Vector2i(
		floori((point.x - indexed_reach) / cell_size), floori((point.z - indexed_reach) / cell_size)
	)
	var high := Vector2i(
		floori((point.x + indexed_reach) / cell_size), floori((point.z + indexed_reach) / cell_size)
	)
	var radius_squared := radius * radius
	# Ground-plane distance: on elevated maps the query point stands on its tier.
	var flat := Vector3(point.x, 0.0, point.z)
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for unit in cells.get(Vector2i(x, y), EMPTY_UNITS):
				if not is_instance_valid(unit):
					continue
				var body: Node3D = unit
				if body.is_queued_for_deletion():
					continue
				if player_filter != null or excluded_player != null:
					var owner = unit.player
					if (
						owner == excluded_player
						or (player_filter != null and owner != player_filter)
					):
						continue
				var position := body.global_position
				position.y = 0.0
				if position.distance_squared_to(flat) <= radius_squared:
					result.append(unit)
	return result


func nearby_combat_targets(point, radius, excluded_player = null):
	var result = nearby_units(point, radius, null, excluded_player)
	if excluded_player != null:
		# Automatic acquisition cannot attack teammates. Reject them before
		# weapon, visibility and terrain checks; explicit force attacks use can_fire.
		result = result.filter(func(unit): return not Players.allied(unit.player, excluded_player))
	var flat = Vector3(point.x, 0.0, point.z)
	for obstacle in nearby_obstacles(point, radius):
		if obstacle.player != null and not Players.allied(obstacle.player, excluded_player):
			result.append(obstacle)
	for cargo in get_tree().get_nodes_in_group("tactical_cargo"):
		if (
			cargo.can_take_damage()
			and cargo.hp > 0
			and not Players.allied(cargo.player, excluded_player)
		):
			if cargo.global_position_yless.distance_to(flat) <= radius:
				result.append(cargo)
	for building in get_tree().get_nodes_in_group("neutral_buildings"):
		if (
			building.player != null
			and not Players.allied(building.player, excluded_player)
			and building.hp > 0
		):
			if (
				building.global_position_yless.distance_squared_to(flat)
				<= (radius + building.radius) * (radius + building.radius)
			):
				result.append(building)
	return result


func nearby_obstacles(point: Vector3, reach: float) -> Array:
	var result = []
	for obstacle in get_tree().get_nodes_in_group("destructible_obstacles"):
		if obstacle.hp <= 0.0 or obstacle.is_queued_for_deletion():
			continue
		if (
			obstacle.global_position_yless.distance_to(point * Vector3(1, 0, 1))
			<= reach + obstacle.radius
		):
			result.append(obstacle)
	return result
