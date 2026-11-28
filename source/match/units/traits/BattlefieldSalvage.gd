extends Node

## Frontier wreck reuse. Persistent state stays on the unit so existing snapshots,
## native combat queries and scrap-plate visuals share one authoritative value.
const SCAVENGER_ROLES = ["Tank", "AntiAirVehicle", "AdvancedTank"]
const VEHICLE_ROLES = [
	"Worker", "Tank", "AntiAirVehicle", "AdvancedTank", "RepairRobot", "CombatRobot"
]
const MAX_RANK = 2
const HARDENED_SECONDS = 60.0
const REPAIR_SHARE = 0.35
const ARMOR_PER_RANK = 0.05
const CANNIBALIZATION_YIELD = 1.5
const CANNIBALIZATION_REPAIR = 25.0
const FIELD_REPAIR = 15.0
const CANNIBALIZATION_RADIUS = 8.0

var _unit


func _init(unit):
	_unit = unit
	name = "BattlefieldSalvage"


static func eligible(unit) -> bool:
	return (
		is_instance_valid(unit)
		and unit.player != null
		and unit.player.faction == "frontier"
		and (unit.type == "Worker" or unit.type in SCAVENGER_ROLES)
	)


static func vehicle_eligible(unit) -> bool:
	return (
		eligible(unit)
		and unit.type in SCAVENGER_ROLES
		and unit.hp != null
		and unit.hp > 0
		and not unit.is_queued_for_deletion()
	)


func can_scavenge() -> bool:
	return vehicle_eligible(_unit)


func scavenge(wreck) -> bool:
	if not can_scavenge() or not _valid_wreck(wreck) or not wreck.consume_by(_unit):
		return false
	_unit.hp = minf(_unit.hp_max, _unit.hp + _unit.hp_max * REPAIR_SHARE)
	_unit.permanent_scrap_rank = mini(MAX_RANK, _unit.permanent_scrap_rank + 1)
	_unit.scrap_hardened_tiers = mini(MAX_RANK, _unit.scrap_hardened_tiers + 1)
	_unit.scrap_hardened_left = HARDENED_SECONDS
	_unit.action_updated.emit()
	return true


func tick(delta):
	if _unit.scrap_hardened_left > 0.0:
		_unit.scrap_hardened_left = maxf(0.0, _unit.scrap_hardened_left - delta)
		if _unit.scrap_hardened_left == 0.0:
			_unit.scrap_hardened_tiers = 0
			_unit.action_updated.emit()


func damage_factor() -> float:
	return 1.0 - ARMOR_PER_RANK * clampi(_unit.permanent_scrap_rank, 0, MAX_RANK)


func dismantle(wreck) -> bool:
	if (
		not eligible(_unit)
		or _unit.type != "Worker"
		or not _valid_wreck(wreck)
		or not wreck.can_harvest(_unit)
	):
		return false
	var amount = wreck.resource_a
	var refined = wreck.refined_b if "refined_b" in wreck else 0
	var center = wreck.global_position
	# Debiting first makes worker/vehicle races atomic even within one frame.
	if not wreck.consume_by(_unit):
		return false
	var completed = _unit.player.technology.completed if _unit.player.technology != null else []
	if "scrap_cannibalization" in completed:
		amount = floori(amount * CANNIBALIZATION_YIELD)
		_repair_nearby_vehicles(center, CANNIBALIZATION_REPAIR)
	else:
		_repair_nearby_vehicles(center, FIELD_REPAIR)
	if "battlefield_alchemy" in completed and refined == 0:
		refined = 4
	if "salvage_war_machine" in completed:
		if refined > 0:
			refined = ceili(refined * 1.5)
		_assemble_buggy(center)
	_unit.player.resource_a += amount
	MatchSignals.resources_mined.emit(_unit, "materials", amount)
	if refined > 0:
		_unit.player.resource_b += refined
		MatchSignals.resources_mined.emit(_unit, "electronics", refined)
	return true


func _repair_nearby_vehicles(center, amount):
	for ally in _unit.player.get_children():
		if (
			ally.is_in_group("units")
			and ally.type in VEHICLE_ROLES
			and not ally.is_queued_for_deletion()
			and ally.hp != null
			and ally.hp_max != null
			and ally.hp > 0
			and ally.global_position.distance_squared_to(center) <= pow(CANNIBALIZATION_RADIUS, 2)
		):
			ally.hp = minf(ally.hp_max, ally.hp + amount)


static func _valid_wreck(wreck) -> bool:
	return (
		is_instance_valid(wreck)
		and wreck.is_in_group("salvage_wrecks")
		and not wreck.is_queued_for_deletion()
		and wreck.resource_a > 0
		and wreck.salvage_left > 0.0
	)


func _assemble_buggy(center):
	var catalog = load("res://source/match/FactionCatalog.gd")
	if _unit.player.population(true) >= catalog.Bastion.POPULATION_LIMIT:
		return
	var buggy = load(catalog.scene_path("frontier", "Tank")).instantiate()
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = _unit._match.navigation.get_navigation_map_rid_by_domain(1)
	var blockers = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	blockers.append_array(_unit._match.battlefield.nearby_obstacles(center, 10.0))
	for ring in [0.0, 2.0, 3.5, 5.0, 7.0]:
		for index in 1 if ring == 0.0 else 16:
			var desired = (
				center + Vector3(cos(index * TAU / 16.0), 0, sin(index * TAU / 16.0)) * ring
			)
			desired.y = _unit._match.map.height_at(Vector2(desired.x, desired.z))
			var surface = NavigationServer3D.map_get_closest_point(nav, desired + Vector3.UP * .6)
			var point = Vector3(surface.x, desired.y, surface.z)
			if Vector2(point.x - desired.x, point.z - desired.z).length() > .2:
				continue
			if (
				placement.validate_agent_placement_position(
					point, buggy.radius + .05, blockers, nav, _unit._match.map
				)
				!= placement.VALID
			):
				continue
			_unit._match._setup_and_spawn_unit(
				buggy, Transform3D(Basis(), point), _unit.player, false
			)
			return
	buggy.free()
