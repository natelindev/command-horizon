extends "res://source/match/players/Player.gd"

const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Construct = preload("res://source/match/units/actions/Constructing.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")
const Repair = preload("res://source/match/units/actions/Repairing.gd")
const RepairService = preload("res://source/match/combat/RepairService.gd")
const Coordination = preload("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
const Recovery = preload("res://source/match/players/skirmish-ai/SkirmishRecovery.gd")
const Labor = preload("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
const Sites = preload("res://source/match/players/skirmish-ai/SkirmishSites.gd")
const ManualOrders = preload("res://source/match/orders/ManualOrders.gd")
const Production = preload("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Defense = preload("res://source/match/players/skirmish-ai/SkirmishDefense.gd")
const Composition = preload("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
const Technologies = preload("res://source/match/research/TechnologyCatalog.gd")
const CombatRules = preload("res://source/match/combat/CombatRules.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const AirfieldLayout = preload("res://source/match/units/AirfieldLayout.gd")
const Expansion = preload("res://source/match/players/skirmish-ai/SkirmishExpansion.gd")
const Tactics = preload("res://source/match/players/skirmish-ai/SkirmishTactics.gd")
const Surrender = preload("res://source/match/players/skirmish-ai/SkirmishSurrender.gd")

# Optional facilities follow a growing army instead of consuming its opening budget.
const OPTIONAL_ARMY_STEP = 5
const OPTIONAL_ARMY_LIMIT = 20

var structures_built = 0
var attacks_launched = 0
var _elapsed = 0.0
var _last_wave = 0.0
var _production_index = 0
var _army_groups = []
var _army_cursor = 0
var _hopeless_seconds = 0.0
# Authored expansion site chosen for the next headquarters, if any.
var _expansion_site = null
@onready var _match = find_parent("Match")


func _process(delta):
	_elapsed += delta
	if _elapsed < profile().decision_interval or not _match.is_node_ready():
		return
	var step = _elapsed
	_elapsed = 0.0
	var units = _units()
	if units.is_empty():
		return
	if _check_surrender(units, step):
		return
	# All subsystems in this synchronous decision share one live contact scan.
	set_meta("decision_contacts", Economy.contacts(_match, self))
	set_meta("decision_approaches", {})
	var desired = _next_building(units)
	_build(units, desired)
	units = _units()
	_harvest(units)
	_research(units, desired)
	_train(units, desired)
	Sites.recruit(_match, self, _units(), desired)
	_command_army(units)
	remove_meta("decision_contacts")
	remove_meta("decision_approaches")


func profile():
	return Difficulty.of(difficulty)


func _units():
	return live_units()


func _check_surrender(units: Array, delta: float) -> bool:
	if Surrender.evaluates_as_hopeless(_match, self, units):
		_hopeless_seconds += delta
		if _hopeless_seconds >= Surrender.PERSISTENCE:
			_surrender(units)
			return true
	else:
		_hopeless_seconds = 0.0
	return false


func _surrender(units: Array) -> void:
	if _match != null and _match.has_method("surrender"):
		_match.surrender(self)
	elif _match != null and _match.has_method("_eliminate"):
		_match._eliminate(self, units)


func _of_type(units, role):
	return units.filter(func(unit): return unit.type == role)


func _next_building(units):
	_expansion_site = null
	if _of_type(units, "CommandCenter").is_empty():
		return "CommandCenter"
	# Once the core base stands, a due expansion comes first: a headquarters
	# needs no power and supplies its own.
	if (
		not _of_type(units, "Barracks").is_empty()
		and not _of_type(units, "VehicleFactory").is_empty()
	):
		_expansion_site = Expansion.next_site(_match, self, units, Economy.contacts(_match, self))
		if _expansion_site != null:
			return "CommandCenter"
	var power = power_totals()
	if (
		power.x < power.y + 6
		and _of_type(units, "PowerPlant").all(func(unit): return unit.is_constructed())
	):
		return "PowerPlant"
	for role in ["Barracks", "VehicleFactory"]:
		if _of_type(units, role).is_empty():
			return _power_ready_building(units, role)
	if _of_type(units, "AntiAirTurret").is_empty() and Composition.observed(_match, self).air > 0:
		return _power_ready_building(units, "AntiAirTurret")
	var optional = _expansion_building(units)
	return _power_ready_building(units, optional) if optional != "" else ""


func _expansion_building(units):
	var expansion = {
		"CommandLab": 100.0,
		"AircraftFactory": 150.0,
		"RepairDepot": 200.0,
		"AntiAirTurret": 220.0,
		"AntiGroundTurret": 260.0
	}
	if faction == "bastion":
		expansion = {
			"RepairDepot": 85.0,
			"CommandLab": 115.0,
			"AircraftFactory": 165.0,
			"AntiAirTurret": 220.0,
			"AntiGroundTurret": 260.0
		}
	elif faction == "helix":
		expansion = {
			"AircraftFactory": 75.0,
			"CommandLab": 100.0,
			"RepairDepot": 180.0,
			"AntiAirTurret": 220.0,
			"AntiGroundTurret": 260.0
		}
	elif faction == "frontier":
		expansion = {
			"RepairDepot": 75.0,
			"CommandLab": 130.0,
			"AircraftFactory": 165.0,
			"AntiAirTurret": 220.0,
			"AntiGroundTurret": 260.0
		}
	var scale = profile().timing_scale
	var order = 0
	for role in expansion:
		order += 1
		if _match.simulation_time >= expansion[role] * scale and _of_type(units, role).is_empty():
			return role if _army_supports_optional(units, order) else ""
	# Additional capacity must not compete with the army it should produce.
	if (
		_match.simulation_time >= Difficulty.EXTRA_FACTORY_TIME
		and _of_type(units, "VehicleFactory").size() < 1 + profile().extra_factories
		and _can_fund_extra_factory(units)
	):
		return "VehicleFactory"
	return ""


func _army_supports_optional(units, order):
	# Queued units already have their production cost paid. Capped commanders
	# can finish their base after reaching their current army limit.
	var needed = mini(OPTIONAL_ARMY_STEP * order, OPTIONAL_ARMY_LIMIT)
	var cap = Difficulty.army_cap(difficulty, _match.simulation_time)
	if cap > 0:
		needed = mini(needed, cap)
	return Production.army_size(Composition.inventory(units)) >= needed


func _can_fund_extra_factory(units):
	var budget = Production.reserve(self, units, "VehicleFactory")
	for job in Production.requests(_match, self, units, true):
		budget += Vector2i(job.cost.resource_a, job.cost.resource_b)
	return resource_a >= budget.x and resource_b >= budget.y


func _power_ready_building(units, role):
	var power = power_totals()
	if (
		power.x < power.y + Catalog.POWER_USAGE.get(role, 0)
		and _of_type(units, "PowerPlant").all(func(unit): return unit.is_constructed())
	):
		return "PowerPlant"
	return role


func _build(units, desired):
	var workers = _of_type(units, "Worker")
	if (
		workers.is_empty()
		or workers.any(
			func(unit): return unit.action is Construct or Labor.awaiting_construction(unit)
		)
	):
		return
	var pending = units.filter(
		func(unit): return unit.has_method("is_constructed") and not unit.is_constructed()
	)
	if not pending.is_empty():
		var builder = Labor.builder(
			workers, pending[0].global_position_yless, not has_completed_structure("CommandCenter")
		)
		if builder != null:
			Labor.assign_construction(builder, pending[0])
		return
	if (
		desired == ""
		or not Factions.available(self, desired, true)
		or not has_resources(Factions.cost(self, desired, true))
	):
		return
	var cost = Factions.cost(self, desired, true)
	var emergency = Production.emergency_budget(_match, self, units, desired)
	if resource_a < cost.resource_a + emergency.x or resource_b < cost.resource_b + emergency.y:
		return
	var reference = _of_type(units, "CommandCenter")
	var origin = (
		reference[0].global_position if not reference.is_empty() else workers[0].global_position
	)
	var building = load(Catalog.scene_path(desired)).instantiate()
	var navmap = _match.navigation.get_navigation_map_rid_by_domain(building.movement_domain)
	var site = Transform3D.IDENTITY
	if Footprint.has_outline(building):
		site = _find_footprint_site(origin, Footprint.local_outline(building), navmap)
	elif desired == "CommandCenter" and _expansion_site != null:
		site.origin = _expansion_position(_expansion_site, building.radius, navmap)
	else:
		site.origin = _find_site(origin, building.radius, navmap)
	var position_to_build = site.origin
	if not position_to_build.is_finite():
		building.free()
		return
	var builder = Labor.builder(workers, position_to_build, desired == "CommandCenter")
	if builder == null:
		building.free()
		return
	subtract_resources(Factions.cost(self, desired, true))
	_match._setup_and_spawn_unit(building, site, self)
	Labor.assign_construction(builder, building)
	structures_built += 1


# The authored site itself, else the nearest level spot beside it.
func _expansion_position(site, radius, navmap):
	var obstacles = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	# Guards and gatherers often stand on the site itself; try rings around it.
	for distance in [0.0, 2.0, 4.0, 6.0, 8.0]:
		for index in range(1 if distance == 0.0 else 12):
			var point = (
				site + Vector3(cos(index * TAU / 12.0), 0, sin(index * TAU / 12.0)) * distance
			)
			point = _match.map.ground_point(Vector2(point.x, point.z))
			if (
				Utils.Match.Unit.Placement.validate_agent_placement_position(
					point, radius, obstacles, navmap, _match.map
				)
				== Utils.Match.Unit.Placement.VALID
			):
				return point
	return Vector3.INF


func _find_site(origin, radius, navmap):
	var obstacles = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	for distance in [7.0, 10.0, 14.0, 18.0, 22.0]:
		for index in range(16):
			var angle = index * TAU / 16.0
			var point = origin + Vector3(cos(angle), 0, sin(angle)) * distance
			if (
				point.x < radius + 1
				or point.z < radius + 1
				or point.x > _match.map.size.x - radius - 1
				or point.z > _match.map.size.y - radius - 1
			):
				continue
			if not _leaves_base_access(point, radius, obstacles):
				continue
			if _match.map.is_elevated():
				point = _match.map.ground_point(Vector2(point.x, point.z))
			var validity = Utils.Match.Unit.Placement.validate_agent_placement_position(
				point, radius, obstacles, navmap, _match.map
			)
			if validity == Utils.Match.Unit.Placement.VALID:
				return point
	return Vector3.INF


# Long structures (the runway airfield) try several headings at each candidate.
func _find_footprint_site(origin, outline, navmap):
	var obstacles = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	var map_polygon = _match.map.get_topdown_polygon_2d()
	for distance in [16.0, 20.0, 24.0, 28.0, 32.0]:
		for index in range(16):
			var angle = index * TAU / 16.0
			var point = origin + Vector3(cos(angle), 0, sin(angle)) * distance
			if _match.map.is_elevated():
				point = _match.map.ground_point(Vector2(point.x, point.z))
			for heading in [0.0, PI * 0.5, PI * 0.25, PI * 0.75]:
				var site = Transform3D(Basis(Vector3.UP, heading), point)
				var polygon = Footprint.outline_at(outline, site)
				if not Array(polygon).all(
					func(corner): return Geometry2D.is_point_in_polygon(corner, map_polygon)
				):
					continue
				if not AirfieldLayout.approach_fits(site, _match.map.size):
					continue
				if not _polygon_leaves_base_access(polygon, obstacles):
					continue
				var validity = Utils.Match.Unit.Placement.validate_footprint_placement(
					polygon, obstacles, navmap, _match.map
				)
				if validity == Utils.Match.Unit.Placement.VALID:
					return site
	return Transform3D(Basis(), Vector3.INF)


func _polygon_leaves_base_access(polygon, obstacles):
	var navigation = Constants.Match.Terrain.Navmesh
	var passage = 2.0 * (navigation.MAX_AGENT_RADIUS + navigation.CELL_SIZE)
	for unit in obstacles:
		var obstacle = unit.get_node_or_null("MovementObstacle")
		if (
			unit.is_queued_for_deletion()
			or obstacle == null
			or not obstacle.affect_navigation_mesh
			or obstacle.domain != Constants.Match.Navigation.Domain.TERRAIN
		):
			continue
		var other = Footprint.world_outline(unit)
		if other.is_empty():
			var center = Vector2(unit.global_position.x, unit.global_position.z)
			if Footprint.polygon_touches_circle(polygon, center, unit.radius + passage):
				return false
		elif Footprint.polygons_touch(Geometry2D.offset_polygon(polygon, passage)[0], other):
			return false
	return true


func _leaves_base_access(point, radius, obstacles):
	# Collision-free footprints can still close an entire navigation corridor.
	# Leave room for erosion on both sides plus a cell on each boundary, so
	# later base construction does not seal engineers into tiny mesh islands.
	var navigation = Constants.Match.Terrain.Navmesh
	var passage = 2.0 * (navigation.MAX_AGENT_RADIUS + navigation.CELL_SIZE)
	for unit in obstacles:
		var obstacle = unit.get_node_or_null("MovementObstacle")
		if (
			unit.is_queued_for_deletion()
			or obstacle == null
			or not obstacle.affect_navigation_mesh
			or obstacle.domain != Constants.Match.Navigation.Domain.TERRAIN
		):
			continue
		if Footprint.reach_distance(unit, point) < radius + unit.radius + passage:
			return false
	return true


func _harvest(units):
	var observed = Economy.contacts(_match, self)
	var assignments = Labor.plan(_match, self, units)
	var changed = false
	for worker in _of_type(units, "Worker"):
		var hq = Economy.headquarters(units, worker.global_position_yless)
		if hq == null:
			continue
		if (
			worker.action is Harvest
			and Economy.danger(worker.global_position_yless, worker, observed)
			and not Economy.danger(hq.global_position_yless, worker, observed)
			and worker.global_position_yless.distance_to(hq.global_position_yless) > 8.0
		):
			var approach = worker.global_position_yless - hq.global_position_yless
			var safe = (
				hq.global_position_yless + approach.normalized() * (hq.radius + worker.radius + 1.0)
			)
			worker.issue_manual_order(Moving.new(safe))
			continue
		var queued = Labor.queued_target(worker)
		if queued != null and not Economy.safe_approach(queued, worker, hq, observed):
			worker.manual_orders.clear_waiting()
		if worker.manual_orders != null and not worker.manual_orders.pending.is_empty():
			continue
		if not assignments.has(worker):
			continue
		var available = Economy.available(worker)
		var handoff = not changed and Labor.handoff_ready(worker)
		if not available and not handoff:
			continue
		if available and worker.resource_a + worker.resource_b > 0:
			worker.issue_manual_order(Harvest.new(hq))
			continue
		var deposit = Economy.deposit(_match, worker, hq, assignments[worker], observed)
		if deposit == null:
			continue
		if handoff and assignments[worker] == worker.action._kind:
			# Keep productive fields unless Frontier can collect a preferred
			# nearby wreck after delivering this load. Wrecks in the current
			# field are already included by the harvest action.
			if (
				faction != "frontier"
				or not deposit.is_in_group("salvage_wrecks")
				or (
					deposit.global_position_yless.distance_to(hq.global_position_yless)
					> Economy.HOME_RADIUS
				)
				or (
					deposit.global_position_yless.distance_to(worker.action._field_origin)
					<= Harvest.FIELD_RADIUS
				)
			):
				continue
		if (
			(
				deposit.global_position_yless.distance_to(hq.global_position_yless)
				> Economy.HOME_RADIUS
			)
			and (
				not Coordination.allows_expansion(self, deposit.global_position_yless)
				or not Economy.guarded(units, deposit.global_position_yless)
			)
		):
			continue
		if handoff:
			changed = worker.manual_orders.submit(
				ManualOrders.target_order("gather", deposit), true
			)
		else:
			worker.issue_manual_order(Harvest.new(deposit))


func _train(units, desired):
	var reserve = Production.reserve(self, units, desired)
	var research = _research_candidate(units)
	var urgent = (
		desired in Production.OPTIONAL_BUILDINGS and Production.under_raid(_match, self, units)
	)
	for job in Production.requests(_match, self, units):
		var price = Vector2i(job.cost.resource_a, job.cost.resource_b)
		var protected = Vector2i.ZERO if job.role == "Worker" else reserve
		if urgent and job.priority <= 2:
			protected = Vector2i.ZERO
		if job.priority >= 6 and not research.is_empty():
			# Accumulate the selected technology across deliveries before buying
			# another routine vehicle. Urgent production keeps its precedence.
			protected += research.cost
		# Protect each stockpile from spending, not from a shortage in the other.
		# Materials-only infantry can use surplus materials while electronics
		# accumulate for a higher-priority building or unit.
		if (
			(price.x > 0 and resource_a < price.x + protected.x)
			or (price.y > 0 and resource_b < price.y + protected.y)
		):
			# Keep this higher-priority job's budget while considering other
			# producers, instead of spending its next delivery on cheaper armor.
			reserve += price
			continue
		if job.producer.production_queue.produce(load(Catalog.scene_path(job.role))) != null:
			if job.producer.type == "VehicleFactory":
				_production_index += 1


func _command_army(units):
	var enemies = Economy.contacts(_match, self)
	var tactical = Tactics.command(_match, self, units, enemies)
	var free = units.filter(func(unit): return unit not in tactical)
	var recovering = Recovery.command(_match, free, enemies, profile().retreat_health)
	var available = free.filter(func(unit): return unit not in recovering)
	var capturers = Sites.command(_match, self, units, available, enemies)
	available = available.filter(func(unit): return unit not in capturers)
	var response = Coordination.command(_match, self, units, available, enemies)
	_choose_weapon_modes(available.filter(func(unit): return unit not in response.defenders))
	# Maneuver supports existing retreat and regroup routes too. Activation never
	# replaces their orders; the other signatures still belong to assigned combatants.
	_use_signatures(units if faction == "frontier" else response.units)
	_command_support(available, response.units)


func _wave_ready():
	return (
		_match.simulation_time > profile().first_wave
		and _match.simulation_time - _last_wave >= profile().wave_interval
	)


func _offensive_goal(soldiers, contacts, enemy_start):
	# Waves pressure the enemy economy. Mobile combatants are encountered through
	# attack-move, while economy raids have their own bounded defense assignment.
	# A scout over our HQ must not redirect the ground army back into its own base.
	var priority = {
		"CommandCenter": 0,
		"VehicleFactory": 1,
		"AircraftFactory": 1,
		"Barracks": 1,
		"CommandLab": 2,
		"PowerPlant": 3,
		"RepairDepot": 4,
		"Worker": 6
	}
	var center = Vector3.ZERO
	for unit in soldiers:
		center += unit.global_position_yless
	center /= max(1, soldiers.size())
	var best = null
	var best_priority = INF
	var best_distance = INF
	for target in contacts:
		if (
			target.is_queued_for_deletion()
			or target.hp <= 0
			or is_allied_with(target.player)
			or target.movement_domain != Constants.Match.Navigation.Domain.TERRAIN
			or (target.type != "Worker" and not target.has_method("is_constructed"))
			or not _match.battlefield.is_observed(self, target)
		):
			continue
		var can_engage = soldiers.any(
			func(unit):
				return (
					CombatRules.can_target(unit, target)
					or (
						unit.type == "CombatRobot"
						and faction == "helix"
						and unit.hp > 0
						and not unit.is_queued_for_deletion()
					)
				)
		)
		if not can_engage:
			continue
		var rank = priority.get(target.type, 5)
		var distance = center.distance_squared_to(target.global_position_yless)
		if rank < best_priority or (rank == best_priority and distance < best_distance):
			best = target
			best_priority = rank
			best_distance = distance
	return best.global_position_yless if best != null else enemy_start * Vector3(1, 0, 1)


func _defend_economy(units, contacts):
	var defenders = []
	var plan = Defense.plan(_match, self, units, contacts)
	for assignment in plan.assignments:
		var unit = assignment.unit
		defenders.append(unit)
		if unit.type == "CombatRobot" and faction == "helix":
			unit.request_weapon_mode(
				(
					"interception"
					if assignment.target.movement_domain == Constants.Match.Navigation.Domain.AIR
					else "precision"
				)
			)
		if unit.action is AttackMove:
			if unit.action.destination.distance_to(assignment.point) <= 2.0:
				continue
			if is_instance_valid(unit.action._shot):
				unit.action.destination = assignment.point
				continue
		unit.issue_manual_order(AttackMove.new(assignment.point))
	return {"units": defenders, "threats": plan.threats, "groups": plan.groups}


func _command_support(units, active_units = null):
	if active_units == null:
		active_units = units
	var claimed = []
	for robot in _of_type(units, "RepairRobot"):
		if not _idle_order(robot) and not robot.action is Repair:
			continue
		var current = robot.action.repair_target() if robot.action is Repair else null
		var candidates = units.filter(
			func(unit):
				return (
					unit not in claimed
					and RepairService.mobile_eligible(robot, unit)
					and (
						unit.hp < unit.hp_max
						or (
							unit in active_units
							and unit.movement_speed > 0
							and unit.attack_range != null
						)
					)
				)
		)
		if candidates.is_empty():
			if robot.action is Repair:
				robot.action = null
			continue
		# Finish an existing legal repair before switching. Healthy armor is an
		# escort fallback; a wounded machine takes priority over that fallback.
		var target = current
		if current not in candidates or current.hp >= current.hp_max:
			candidates.sort_custom(
				func(a, b):
					var a_hurt = a.hp < a.hp_max
					var b_hurt = b.hp < b.hp_max
					if a_hurt != b_hurt:
						return a_hurt
					return (
						robot.global_position.distance_squared_to(a.global_position)
						< robot.global_position.distance_squared_to(b.global_position)
					)
			)
			target = candidates[0]
		claimed.append(target)
		if current != target:
			robot.action = Repair.new(target)


func _research_candidate(units):
	if (
		coordination_left > 0
		or technology.active != ""
		or not has_completed_structure("CommandLab")
		or not lab_research_unlocked()
	):
		return {}
	var id = "coordination"
	var cost = Vector2i(COORDINATION_COST.resource_a, COORDINATION_COST.resource_b)
	if coordination_unlocked:
		if Economy.guards(units).size() < profile().research_guards:
			return {}
		id = ""
		for option in profile().research:
			if option not in technology.completed:
				id = option
				cost = Technologies.ITEMS[id].cost
				break
		if id == "":
			return {}
	return {"id": id, "cost": cost}


func _research(units, desired):
	var candidate = _research_candidate(units)
	if candidate.is_empty():
		return
	var id = candidate.id
	var cost = candidate.cost
	var reserve = Production.reserve(self, units, desired)
	for job in Production.requests(_match, self, units):
		if job.priority < 6:
			reserve += Vector2i(job.cost.resource_a, job.cost.resource_b)
	if resource_a < cost.x + reserve.x or resource_b < cost.y + reserve.y:
		return
	for lab in _of_type(units, "CommandLab"):
		var started = start_coordination(lab) if id == "coordination" else technology.start(id, lab)
		if started:
			return


func _idle_order(unit):
	return unit.action == null or (unit.action.has_method("is_idle") and unit.action.is_idle())


func _use_signatures(units):
	if not coordination_unlocked or not profile().signatures:
		return
	var ready = units.filter(
		func(unit):
			return (
				signatures.eligible(unit)
				and (
					unit.get_node("Movement")._has_destination
					if faction == "frontier"
					else not unit.get_node("Movement")._has_destination
				)
				and not _match.battlefield.observed_enemies_near(unit, unit.sight_range).is_empty()
			)
	)
	if ready.is_empty():
		return
	var point = ready[0].global_position_yless
	if faction == "bastion":
		ready = ready.filter(func(unit): return unit.global_position_yless.distance_to(point) <= 6)
	signatures.activate(ready, point)


func _choose_weapon_modes(units):
	if faction != "helix":
		return
	for unit in _of_type(units, "CombatRobot"):
		if unit.weapon_switch_left > 0:
			continue
		# Mode choice belongs to the opponent commander.
		# Keep the current stance when no contact is observed; never inspect hidden forces.
		var contacts = _match.battlefield.nearby_units(unit.global_position_yless, unit.sight_range)
		contacts = contacts.filter(
			func(other):
				return (
					not is_allied_with(other.player)
					and other.hp > 0
					and _match.battlefield.is_observed(self, other)
				)
		)
		if contacts.is_empty():
			continue
		var air = contacts.any(
			func(other): return other.movement_domain == Constants.Match.Navigation.Domain.AIR
		)
		unit.request_weapon_mode("interception" if air else "precision")
