extends Node

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

const Rules = preload("res://source/match/combat/CombatRules.gd")
const INTERVAL = 0.25
const FACILITY_RANGE = 5.0
var _elapsed = 0.0
@onready var _match = get_parent()


static func mobile_eligible(source, target):
	return (
		is_instance_valid(target)
		and target != source
		and "hp" in target
		and target.hp != null
		and target.hp > 0
		and not target.is_queued_for_deletion()
		and "player" in target
		and target.player == source.player
		and Rules.armor_for(target.type) != 0
		and target.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
		and (not target.has_method("is_constructed") or target.is_constructed())
	)


static func facility_for_role(role):
	if InfantryRoster.is_infantry(role):
		return "Barracks"
	if role in ["Drone", "Helicopter"]:
		return "AircraftFactory"
	return "RepairDepot"


static func facility_eligible(service, unit):
	return (
		is_instance_valid(service)
		and not service.is_queued_for_deletion()
		and service.hp > 0
		and service.player == unit.player
		and service.type == facility_for_role(unit.type)
		and service.has_method("is_constructed")
		and service.is_constructed()
		and (not service.has_method("service_active") or service.service_active())
		and unit.movement_speed > 0
	)


static func stationary(unit):
	var movement = unit.get_node_or_null("Movement")
	return (
		movement == null
		or (not movement._has_destination and movement.velocity.length_squared() < 0.01)
	)


static func mobile_distance(source, target):
	var distance = source.global_position_yless.distance_to(target.global_position_yless)
	# A robot services a building at its footprint, not at its inaccessible center.
	# Mobile targets retain the existing center-to-center channel range.
	if target.has_method("is_constructed"):
		distance -= target.radius
	return maxf(0.0, distance)


func _physics_process(delta):
	_elapsed += delta
	if _elapsed < INTERVAL:
		return
	var elapsed = _elapsed
	_elapsed = 0.0
	service(elapsed)


func service(delta):
	var providers = []
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if (
			unit.is_queued_for_deletion()
			or not unit.can_process()
			or unit.hp == null
			or unit.hp <= 0
		):
			continue
		var upgrade = (
			unit.player.technology.service_factor() if unit.player.technology != null else 1.0
		)
		if unit.type == "RepairRobot":
			if (
				stationary(unit)
				and (unit.action == null or unit.action.has_method("repair_target"))
			):
				providers.append({"unit": unit, "rate": 0.025 * upgrade, "slots": 1, "range": 3.0})
		elif unit.type in ["RepairDepot", "AircraftFactory", "Barracks"] and unit.is_constructed():
			providers.append(
				{
					"unit": unit,
					"rate": 0.04 * unit.player.production_factor() * upgrade,
					"slots": 2,
					"range": FACILITY_RANGE
				}
			)
	for site in load("res://source/match/world/PointOfInterestCatalog.gd").sites(_match):
		if site.kind == "repair" and site.operational():
			providers.append({"unit": site, "rate": 0.04, "slots": 2, "range": FACILITY_RANGE})
	providers.sort_custom(func(a, b): return a.rate > b.rate)
	var assigned = {}
	for provider in providers:
		var source = provider.unit
		var candidates = []
		for target in _match.battlefield.nearby_bodies(
			source.global_position, provider.range, source.player
		):
			if _eligible(provider, target) and not assigned.has(target):
				candidates.append(target)
		candidates.sort_custom(func(a, b): return float(a.hp) / a.hp_max < float(b.hp) / b.hp_max)
		source.set_meta("service_used", mini(provider.slots, candidates.size()))
		for target in candidates.slice(0, provider.slots):
			assigned[target] = provider.rate
	for target in assigned:
		var effectiveness = (
			0.25 if _match.simulation_time - target.last_enemy_damage_time < 3.0 else 1.0
		)
		target.hp = minf(
			target.hp_max, target.hp + target.hp_max * assigned[target] * effectiveness * delta
		)


func _eligible(provider, target):
	var source = provider.unit
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target == source:
		return false
	if (
		target.player != source.player
		or target.hp == null
		or target.hp <= 0
		or target.hp >= target.hp_max
	):
		return false
	var distance = (
		mobile_distance(source, target)
		if source.type == "RepairRobot"
		else source.global_position_yless.distance_to(target.global_position_yless)
	)
	if distance > provider.range:
		return false
	if target.has_method("is_constructed") and not target.is_constructed():
		return false
	match source.type:
		"RepairRobot":
			if source.action != null and source.action.repair_target() != target:
				return false
			return mobile_eligible(source, target)
		"RepairDepot":
			return mobile_eligible(source, target) and target.movement_speed > 0
		"AircraftFactory":
			return (
				target.movement_domain == Constants.Match.Navigation.Domain.AIR
				and stationary(target)
			)
		"Barracks":
			return InfantryRoster.is_infantry(target.type) and stationary(target)
	return false  # gdlint: ignore = max-returns
