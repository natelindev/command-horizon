# gdlint: disable=duplicated-load,max-returns
extends Node

## Match-wide coordinator for Risk-the-Batch Refining:
## - Spilled Refined Core canisters (TacticalCargo integration)
## - Catalyst POI speed auras & Orbital Relay canister drops
## - Bastion Slag Recirculation factory surges
## - Helix Phase Condenser spacing & Harmonic Lattice links
## - Frontier Fuel Injection battlefield buffs

const Profile = preload("res://source/match/economy/RefiningProfile.gd")
const Players = preload("res://source/match/Players.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")

var canisters: Array = []
var slag_surges: Array = []
var fuel_buffs: Array = []
var _serial: int = 0
var _pickup_elapsed: float = 0.0
var _proximity_timers: Dictionary = {}
@onready var game = get_parent()


func _physics_process(delta: float):
	if get_tree().paused:
		return
	_tick_timers(delta)
	_tick_canisters(delta)


func _tick_timers(delta: float):
	for entry in slag_surges.duplicate():
		entry.left = maxf(0.0, entry.left - delta)
		if entry.left <= 0.0 or not is_instance_valid(entry.target.get_ref()):
			slag_surges.erase(entry)
	for entry in fuel_buffs.duplicate():
		entry.left = maxf(0.0, entry.left - delta)
		if entry.left <= 0.0 or not is_instance_valid(entry.unit.get_ref()):
			fuel_buffs.erase(entry)


func _tick_canisters(delta: float):
	var expired = []
	for record in canisters:
		record.left = maxf(0.0, record.left - delta)
		if record.left <= 0.0 or not is_instance_valid(record.node) or record.node.consumed:
			expired.append(record)
	for record in expired:
		_remove_canister(record)
	if canisters.is_empty():
		_proximity_timers.clear()
		return
	_pickup_elapsed += delta
	if _pickup_elapsed < 0.2:
		return
	var step = _pickup_elapsed
	_pickup_elapsed = 0.0
	for record in canisters.duplicate():
		if not is_instance_valid(record.node) or record.node.consumed:
			continue
		var claimer = _nearest_claimer(record.node)
		if claimer == null:
			_proximity_timers.erase(record.id)
			continue
		var elapsed = _proximity_timers.get(record.id, 0.0) + step
		_proximity_timers[record.id] = elapsed
		if elapsed >= Profile.CANISTER_CLAIM_SECONDS:
			collect(record.node, claimer, elapsed)


func _nearest_claimer(cargo):
	if game == null or game.battlefield == null:
		return null
	var reach = cargo.radius + 1.25
	var best = null
	var best_dist = INF
	for unit in game.battlefield.nearby_units(cargo.global_position, reach + 2.0):
		if not cargo.can_collect(unit):
			continue
		var limit = unit.radius + cargo.radius + 0.65
		var dist = unit.global_position_yless.distance_to(cargo.global_position_yless)
		if dist <= limit and dist < best_dist:
			best_dist = dist
			best = unit
	return best


func spawn_canisters(
	origin: Vector3, total_refined: int, source_player = null, scatter: bool = true
) -> Array:
	if total_refined <= 0 or game == null or game.map == null:
		return []
	var count = 1 if (not scatter or total_refined < 10) else (2 if total_refined < 24 else 3)
	var created = []
	var remainder = total_refined
	var base_share = total_refined / count
	for index in count:
		var amount = remainder if index == count - 1 else base_share
		remainder -= amount
		if amount <= 0:
			continue
		var offset = Vector3.ZERO
		if scatter and count > 1:
			var angle = index * TAU / float(count) + fmod(origin.x * 0.37 + origin.z * 0.71, TAU)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * 1.4
		var point = _safe_drop_point(origin + offset)
		var record = _create_canister(point, amount, Profile.CANISTER_LIFETIME, source_player)
		if record != null:
			created.append(record.node)
	return created


func _safe_drop_point(desired: Vector3) -> Vector3:
	var flat = Vector2(desired.x, desired.z)
	if game != null and game.map != null:
		flat = flat.clamp(Vector2(2.0, 2.0), game.map.size - Vector2(2.0, 2.0))
		return game.map.ground_point(flat)
	return desired


func _create_canister(point: Vector3, amount: int, lifetime: float, source_player = null):
	_serial += 1
	var record_id = "core-%d" % _serial
	var cargo = load("res://source/match/world/TacticalCargo.gd").new()
	cargo.manager = self
	cargo.kind = "refined_core"
	cargo.record_id = record_id
	cargo.neutral_id = record_id
	cargo.player = source_player
	cargo.hp = 30.0
	cargo.position = point
	cargo.public_marker = false
	game.map.add_child(cargo)
	var record = {
		"id": record_id,
		"point": point,
		"refined": amount,
		"left": lifetime,
		"source_player": source_player,
		"node": cargo,
	}
	canisters.append(record)
	return record


func collect(cargo_node, unit, elapsed: float) -> bool:
	if (
		not is_instance_valid(cargo_node)
		or cargo_node.consumed
		or elapsed < Profile.CANISTER_CLAIM_SECONDS
		or not is_instance_valid(unit)
		or unit.hp <= 0
		or unit.player == null
	):
		return false
	for record in canisters:
		if record.node != cargo_node:
			continue
		if Footprint.reach_distance(unit, record.point) > unit.radius + cargo_node.radius + 1.4:
			return false
		cargo_node.consumed = true
		unit.player.add_resources({"resource_b": record.refined})
		MatchSignals.resources_mined.emit(unit, "electronics", record.refined)
		if (
			game != null
			and game._get_human_player() == unit.player
			and "hud" in game
			and is_instance_valid(game.hud)
		):
			game.hud.show_notice(tr("Recovered +%d Refined Cores") % record.refined)
		_remove_canister(record)
		return true
	return false


func pickup_description(cargo_node) -> Array:
	for record in canisters:
		if record.node == cargo_node:
			return [
				tr("Refined Core Canister"),
				tr("+%d Refined Cores · %ds remaining") % [record.refined, ceili(record.left)],
				tr("Move any ground unit within reach to claim.")
			]
	return []


func cargo_destroyed(cargo_node):
	for record in canisters.duplicate():
		if record.node == cargo_node:
			_remove_canister(record)


func _remove_canister(record):
	_proximity_timers.erase(record.id)
	if is_instance_valid(record.get("node")):
		record.node.dismiss()
	canisters.erase(record)


func catalyst_bonus(player, point: Vector3) -> float:
	if game == null or game.map == null or not "points_of_interest" in game.map:
		return 0.0
	var limit_sq = Profile.CATALYST_RADIUS * Profile.CATALYST_RADIUS
	for site in game.map.points_of_interest:
		if (
			not is_instance_valid(site)
			or site.is_queued_for_deletion()
			or site.kind != "refinery"
			or site.hp <= 0.0
		):
			continue
		if site.player != null and Players.allied(site.player, player):
			if site.global_position_yless.distance_squared_to(point * Vector3(1, 0, 1)) <= limit_sq:
				return Profile.CATALYST_BONUS
	return 0.0


func trigger_slag_surge(player, origin: Vector3):
	if player == null or not Profile.has_tech(player, "slag_recirculation"):
		return
	var limit_sq = Profile.BASTION_SLAG_SURGE_RADIUS * Profile.BASTION_SLAG_SURGE_RADIUS
	var flat = origin * Vector3(1, 0, 1)
	for unit in player.structure_candidates():
		if (
			not is_instance_valid(unit)
			or unit.is_queued_for_deletion()
			or not unit.is_constructed()
			or unit.hp <= 0.0
			or unit.type not in ["VehicleFactory", "AircraftFactory"]
		):
			continue
		if unit.global_position_yless.distance_squared_to(flat) > limit_sq:
			continue
		slag_surges = slag_surges.filter(func(entry): return entry.target.get_ref() != unit)
		slag_surges.append({"target": weakref(unit), "left": Profile.BASTION_SLAG_SURGE_DURATION})


func production_factor(facility) -> float:
	if not is_instance_valid(facility):
		return 1.0
	for entry in slag_surges:
		if entry.target.get_ref() == facility and entry.left > 0.0:
			return Profile.BASTION_SLAG_SURGE_FACTOR
	return 1.0


func trigger_fuel_injection(player, origin: Vector3) -> int:
	if player == null or not Profile.has_tech(player, "battlefield_alchemy"):
		return 0
	var limit_sq = Profile.FRONTIER_FUEL_INJECT_RADIUS * Profile.FRONTIER_FUEL_INJECT_RADIUS
	var flat = origin * Vector3(1, 0, 1)
	var count = 0
	for unit in player.live_units():
		if (
			not is_instance_valid(unit)
			or unit.hp <= 0.0
			or unit.movement_speed <= 0.0
			or unit.movement_domain != 1
			or unit.type == "CrackRig"
		):
			continue
		if unit.global_position_yless.distance_squared_to(flat) > limit_sq:
			continue
		fuel_buffs = fuel_buffs.filter(func(entry): return entry.unit.get_ref() != unit)
		fuel_buffs.append({"unit": weakref(unit), "left": Profile.FRONTIER_FUEL_INJECT_DURATION})
		count += 1
	return count


func unit_speed_factor(unit) -> float:
	for entry in fuel_buffs:
		if entry.unit.get_ref() == unit and entry.left > 0.0:
			return Profile.FRONTIER_FUEL_INJECT_FACTOR
	return 1.0


func unit_reload_factor(unit) -> float:
	for entry in fuel_buffs:
		if entry.unit.get_ref() == unit and entry.left > 0.0:
			return 1.0 / Profile.FRONTIER_FUEL_INJECT_FACTOR
	return 1.0


func condenser_spacing_ok(player, point: Vector3, ignore = null) -> bool:
	if player == null:
		return true
	var flat = point * Vector3(1, 0, 1)
	var min_sq = Profile.HELIX_MIN_SPACING * Profile.HELIX_MIN_SPACING
	for unit in player.structure_candidates("PhaseCondenser"):
		if (
			unit == ignore
			or not is_instance_valid(unit)
			or unit.is_queued_for_deletion()
			or unit.hp <= 0.0
		):
			continue
		if unit.global_position_yless.distance_squared_to(flat) < min_sq:
			return false
	return true


func lattice_partner(condenser):
	if (
		not is_instance_valid(condenser)
		or condenser.player == null
		or not Profile.has_tech(condenser.player, "harmonic_lattice")
		or not condenser.is_constructed()
		or condenser.hp <= 0.0
	):
		return null
	var limit_sq = Profile.HELIX_LATTICE_RANGE * Profile.HELIX_LATTICE_RANGE
	var origin = condenser.global_position_yless
	var best = null
	var best_sq = INF
	for other in condenser.player.structure_candidates("PhaseCondenser"):
		if (
			other == condenser
			or not is_instance_valid(other)
			or other.is_queued_for_deletion()
			or not other.is_constructed()
			or other.hp <= 0.0
		):
			continue
		var dist_sq = other.global_position_yless.distance_squared_to(origin)
		if dist_sq <= limit_sq and dist_sq < best_sq:
			best_sq = dist_sq
			best = other
	return best


func shield_aura_bonus(unit) -> float:
	if (
		not is_instance_valid(unit)
		or unit.player == null
		or unit.player.faction != "helix"
		or unit.shields_max <= 0.0
		or not Profile.has_tech(unit.player, "harmonic_lattice")
	):
		return 0.0
	var limit_sq = Profile.HELIX_LATTICE_AURA_RADIUS * Profile.HELIX_LATTICE_AURA_RADIUS
	var pos = unit.global_position_yless
	for condenser in unit.player.structure_candidates("PhaseCondenser"):
		if (
			not is_instance_valid(condenser)
			or condenser.is_queued_for_deletion()
			or not condenser.is_constructed()
			or condenser.hp <= 0.0
		):
			continue
		var refining = condenser.get_node_or_null("Refining")
		if refining == null or not refining.is_lattice_aura_active():
			continue
		if condenser.global_position_yless.distance_squared_to(pos) <= limit_sq:
			return Profile.HELIX_LATTICE_SHIELD_AURA
	return 0.0


func capture_state(reference: Callable) -> Dictionary:
	var saved_canisters = []
	for record in canisters:
		if not is_instance_valid(record.node) or record.node.consumed:
			continue
		(
			saved_canisters
			. append(
				{
					"id": record.id,
					"point": record.point,
					"refined": record.refined,
					"left": record.left,
					"source_player":
					(
						reference.call(record.source_player)
						if is_instance_valid(record.source_player)
						else ""
					),
				}
			)
		)
	var saved_surges = []
	for entry in slag_surges:
		var target = entry.target.get_ref()
		if is_instance_valid(target) and entry.left > 0.0:
			var ref = reference.call(target)
			if ref != "":
				saved_surges.append({"target": ref, "left": entry.left})
	var saved_buffs = []
	for entry in fuel_buffs:
		var unit = entry.unit.get_ref()
		if is_instance_valid(unit) and entry.left > 0.0:
			var ref = reference.call(unit)
			if ref != "":
				saved_buffs.append({"unit": ref, "left": entry.left})
	return {
		"serial": _serial,
		"canisters": saved_canisters,
		"slag_surges": saved_surges,
		"fuel_buffs": saved_buffs,
	}


func restore_state(saved: Dictionary, entities: Dictionary):
	for record in canisters.duplicate():
		_remove_canister(record)
	slag_surges.clear()
	fuel_buffs.clear()
	_proximity_timers.clear()
	_serial = int(saved.get("serial", 0))
	for item in saved.get("canisters", []):
		var source_player = entities.get(item.get("source_player", ""))
		var cargo = load("res://source/match/world/TacticalCargo.gd").new()
		cargo.manager = self
		cargo.kind = "refined_core"
		cargo.record_id = item.id
		cargo.neutral_id = item.id
		cargo.player = source_player
		cargo.hp = 30.0
		cargo.position = item.point
		cargo.public_marker = false
		game.map.add_child(cargo)
		(
			canisters
			. append(
				{
					"id": item.id,
					"point": item.point,
					"refined": int(item.refined),
					"left": float(item.left),
					"source_player": source_player,
					"node": cargo,
				}
			)
		)
	for item in saved.get("slag_surges", []):
		var target = entities.get(item.get("target", ""))
		if is_instance_valid(target):
			slag_surges.append({"target": weakref(target), "left": float(item.left)})
	for item in saved.get("fuel_buffs", []):
		var unit = entities.get(item.get("unit", ""))
		if is_instance_valid(unit):
			fuel_buffs.append({"unit": weakref(unit), "left": float(item.left)})
