# gdlint: disable=max-file-lines,max-returns
extends RefCounted

## Current-version contracts for tactical state. This validator contains no migration.
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Cache = preload("res://source/utils/RuntimeCache.gd")
var schema:
	get:
		return _schema.get_ref() if _schema != null else null
var _schema: WeakRef


class AbilityOwner:
	extends Node
	var faction = "bastion"


func _init(parent_schema = null):
	_schema = weakref(parent_schema) if parent_schema != null else null


static func commander_defaults() -> Dictionary:
	return {"serial": 0, "states": [], "pending": [], "emp": [], "crates": [], "explored": []}


func definitions(role: String, faction: String) -> Array:
	var key = faction + ":" + role
	if schema != null and not schema.ability_definitions.is_empty():
		return schema.ability_definitions.get(key, [])
	var definitions_cache = Cache.bucket("gameplay_depth_ability_definitions")
	if not definitions_cache.has(key):
		# Read authoritative definitions without entering a scene or running _ready.
		var owner = AbilityOwner.new()
		owner.faction = faction
		var unit = (
			load(load("res://source/match/FactionCatalog.gd").scene_path(faction, role))
			. instantiate()
		)
		owner.add_child(unit)
		var result = unit.ability_definitions()
		result.append_array(
			load("res://source/match/world/FieldEngineering.gd").ability_definitions(unit)
		)
		definitions_cache[key] = result
		owner.free()
	return definitions_cache[key]


func unit_state(unit) -> bool:
	var faction = schema.sides[unit.player].faction
	if (
		unit.damage_visual_band > 2
		or unit.regarrison_lock_left > 3.0
		or unit.permanent_scrap_rank > 2
	):
		return schema._fail("Invalid unit tactical state.")
	if (
		unit.permanent_scrap_rank > 0
		and (faction != "frontier" or unit.role not in ["Tank", "AdvancedTank", "AntiAirVehicle"])
	):
		return schema._fail("Permanent scrap armor is unavailable to this unit.")
	if unit.regarrison_lock_left > 0 and not Catalog.is_infantry(unit.role):
		return schema._fail("Garrison lock on an ineligible unit.")
	var eligible = Catalog.is_infantry(unit.role) and unit.role != "Hero"
	if eligible:
		var pressure = unit.suppression
		if not schema._shape(pressure, "meter:num band:int recovery_left:num near_misses:list"):
			return false
		if (
			pressure.meter > 100
			or pressure.band > 2
			or pressure.recovery_left > 2
			or pressure.near_misses.size() > 256
		):
			return schema._fail("Invalid suppression state.")
		if (
			(pressure.band == 2 and pressure.meter < 80)
			or (pressure.band == 1 and (pressure.meter < 45 or pressure.meter >= 90))
			or (pressure.band == 0 and pressure.meter >= 50)
		):
			return schema._fail("Suppression band disagrees with its meter.")
		var spent = 0.0
		for entry in pressure.near_misses:
			if (
				not schema._shape(entry, "left:num amount:num")
				or entry.left > 1.0
				or entry.amount > 20
			):
				return schema._fail("Invalid near-miss suppression budget.")
			spent += entry.amount
		if spent > 20.000001:
			return schema._fail("Near-miss suppression exceeds its per-second budget.")
	elif not unit.suppression.is_empty():
		return schema._fail("Suppression applied to immune unit.")
	var expected = definitions(unit.role, faction)
	if unit.abilities.size() != expected.size():
		return schema._fail("Ability state does not match the unit's role and faction.")
	for definition in expected:
		if not unit.abilities.has(definition.id):
			return schema._fail("Missing saved unit ability.")
		var ability = unit.abilities[definition.id]
		if not schema._shape(
			ability, "cooldown_left:num active_left:num is_active:bool effect_position:vec"
		):
			return false
		if (
			ability.cooldown_left > definition.cooldown
			or ability.active_left > definition.get("duration", 0.0)
		):
			return schema._fail("Ability timer exceeds its definition.")
		if definition.target_type != "toggle" and ability.is_active != (ability.active_left > 0.0):
			return schema._fail("Ability activation disagrees with its remaining duration.")
	return true


func assembly_state(unit) -> bool:
	var state = unit.production.assembly_state
	if not schema._shape(
		state, "last_completed_role:text completed_streak:int idle_grace_left:num"
	):
		return false
	var eligible = (
		schema.sides[unit.player].faction == "bastion"
		and unit.role in ["Barracks", "VehicleFactory"]
	)
	if (
		state.completed_streak > 3
		or state.idle_grace_left > 5.0
		or (state.last_completed_role == "") != (state.completed_streak == 0)
	):
		return schema._fail("Invalid completed-unit production streak.")
	if (
		state.completed_streak > 0
		and (
			not eligible
			or state.last_completed_role not in Catalog.PRODUCES[unit.role]
			or state.last_completed_role == "Hero"
		)
	):
		return schema._fail("Production streak is unavailable to this factory.")
	if state.idle_grace_left > 0.0 and not unit.production.jobs.is_empty():
		return schema._fail("Busy factory retains an idle production grace period.")
	for index in unit.production.jobs.size():
		var job = unit.production.jobs[index]
		if (
			not job is Dictionary
			or not job.get("assembly_started") is bool
			or not schema._type(job.get("assembly_bonus"), "num")
		):
			return schema._fail("Missing production assembly state.")
		if (
			(index > 0 and job.assembly_started)
			or (
				job.assembly_bonus > 0
				and (not eligible or not job.assembly_started or job.get("role") == "Hero")
			)
		):
			return schema._fail("Invalid started assembly job.")
		if not [0.0, 0.08, 0.16, 0.24].any(
			func(amount): return is_equal_approx(amount, job.assembly_bonus)
		):
			return schema._fail("Invalid assembly production bonus.")
	return true


func evacuation_state(building) -> bool:
	if (
		building.entry_points.size() != building.occupants.size()
		or building.evacuating.size() > building.occupants.size()
	):
		return schema._fail("Missing garrison evacuation state.")
	for point in building.entry_points:
		if not schema._type(point, "vec") or not schema._position(point):
			return schema._fail("Invalid original garrison approach.")
	var seen = []
	for id in building.evacuating:
		if id not in building.occupants or id in seen:
			return schema._fail("Invalid pending garrison evacuation.")
		seen.append(id)
		if schema.entities[id].regarrison_lock_left > 0:
			return schema._fail("Re-entry timer began before physical exit.")
	return true


func round_state(round) -> bool:
	if round.suppression.size() > 400:
		return schema._fail("Too many projectile suppression contributions.")
	var seen = []
	for entry in round.suppression:
		if (
			not schema._shape(entry, "unit:text amount:num")
			or not schema._unit_reference(entry.unit)
			or entry.amount > 16
			or entry.unit in seen
		):
			return schema._fail("Invalid projectile suppression contribution.")
		seen.append(entry.unit)
		if (
			schema.entities.has(entry.unit)
			and (
				not Catalog.is_infantry(schema.entities[entry.unit].get("role", ""))
				or schema.entities[entry.unit].role == "Hero"
			)
		):
			return schema._fail("Projectile suppressed an immune unit.")
	return true


func manager_states(data) -> bool:
	return (
		_engineering(data.engineering)
		and _commander(data.commander)
		and _grenades(data.grenades)
		and _events(data.events, data.settings)
	)


func _grenades(saved) -> bool:
	if not schema._shape(saved, "serial:int pending:list") or saved.pending.size() > 400:
		return schema._fail("Invalid pending grenade collection.")
	var seen = []
	for grenade in saved.pending:
		if not (schema._shape(
			grenade,
			(
				"serial:int player:text shooter:text type:text origin:vec point:vec "
				+ "radius:num building:text left:num"
			)
		)):
			return false
		if (
			grenade.serial >= saved.serial
			or grenade.serial in seen
			or not schema.sides.has(grenade.player)
			or grenade.type != "Infantry"
			or grenade.radius != 3.5
			or grenade.left > 0.6
			or not schema._position(grenade.point)
			or not schema._position(grenade.origin)
			or not schema._unit_reference(grenade.shooter)
			or (grenade.building != "" and not schema._neutral_ids.get(grenade.building, false))
		):
			return schema._fail("Invalid committed grenade payload.")
		seen.append(grenade.serial)
	return true


func _engineering(saved) -> bool:
	if (
		not schema._shape(saved, "next_id:int entities:list cooldowns:list reservations:list")
		or saved.next_id < 1
	):
		return schema._fail("Invalid field engineering state.")
	if (
		saved.entities.size() > 60 * schema.sides.size()
		or saved.reservations.size() > 60 * schema.sides.size()
		or saved.cooldowns.size() > 400
	):
		return schema._fail("Field engineering exceeds its population limits.")
	var counts = {}
	var ids = []
	for entry in saved.entities:
		if not entry is Dictionary:
			return schema._fail("Invalid field structure.")
		var mine = entry.get("kind") == "mine"
		var bunker = entry.get("kind") == "bunker"
		var spec = (
			"id:text owner:text kind:text point:vec angle:signed hp:num"
			+ (" deploy_left:num arm_left:num fuse_left:signed" if mine else "")
			+ (" garrison:dict" if bunker else "")
		)
		if not schema._shape(entry, spec):
			return false
		var faction = schema.sides.get(entry.owner, {}).get("faction", "")
		var completed = schema.sides.get(entry.owner, {}).get("technology", [])
		var maximum = (
			1.0 if mine else (320.0 if bunker else (200.0 if entry.kind == "tank_trap" else 80.0))
		)
		if bunker:
			maximum *= (
				(1.5 if "bunker_reinforcements" in completed else 1.0)
				* (1.3 if "fortress_doctrine" in completed else 1.0)
			)
		elif entry.kind == "barricade" and "fortress_doctrine" in completed:
			maximum *= 2.0
		if (
			entry.kind not in ["mine", "barricade", "bunker", "tank_trap"]
			or not schema.sides.has(entry.owner)
			or (
				faction != "frontier"
				if mine
				else (
					faction
					not in (["bastion", "frontier"] if entry.kind == "barricade" else ["bastion"])
				)
			)
			or not _serial_id(entry.id, "engineering-" + entry.kind + "-", saved.next_id, 1)
			or entry.id in ids
			or entry.hp <= 0.0
			or entry.hp > maximum
			or not schema._position(entry.point)
			or absf(entry.angle) > TAU
		):
			return schema._fail("Invalid field structure owner, identity or placement.")
		if (
			mine
			and (
				entry.deploy_left > 3.0
				or entry.arm_left > 2.0
				or entry.fuse_left < -1.0
				or entry.fuse_left > 0.35
				or (entry.fuse_left < 0.0 and entry.fuse_left != -1.0)
			)
		):
			return schema._fail("Invalid mine deployment, arming or fuse timer.")
		ids.append(entry.id)
		var key = entry.owner + ":" + entry.kind
		counts[key] = counts.get(key, 0) + 1
		_register(
			entry.id,
			{
				"mine": "FieldMine",
				"barricade": "FieldBarricade",
				"bunker": "FieldBunker",
				"tank_trap": "FieldTankTrap"
			}[entry.kind],
			entry.owner,
			entry.point
		)
	for entry in saved.reservations:
		if not schema._shape(entry, "id:text unit:text kind:text point:vec angle:signed mine:text"):
			return false
		if (
			not _serial_id(entry.id, "engineering-reservation-", saved.next_id, 1)
			or entry.id in ids
			or not schema.entities.has(entry.unit)
			or entry.kind not in ["mine", "barricade", "bunker", "tank_trap"]
			or not schema._position(entry.point)
			or absf(entry.angle) > TAU
		):
			return schema._fail("Invalid field deployment reservation.")
		ids.append(entry.id)
		var unit = schema.entities[entry.unit]
		if not _engineer_role(unit, entry.kind):
			return schema._fail("Field deployment reservation belongs to an ineligible unit.")
		if entry.mine != "":
			if (
				entry.kind != "mine"
				or not schema._tactical_ids.has(entry.mine)
				or schema.entities[entry.mine].player != unit.player
			):
				return schema._fail("Deployment reservation lost its mine.")
		else:
			var key = unit.player + ":" + entry.kind
			counts[key] = counts.get(key, 0) + 1
	for key in counts:
		var owner = key.get_slice(":", 0)
		var kind = key.get_slice(":", 1)
		var limit = (
			24
			if kind == "mine" and "guerrilla_insurgency" in schema.sides[owner].technology
			else 12
		)
		if counts[key] > limit:
			return schema._fail("Field deployment exceeds the per-player cap.")
	var cooldown_units = []
	for entry in saved.cooldowns:
		if (
			not schema._shape(entry, "unit:text left:num")
			or not schema.entities.has(entry.unit)
			or entry.left > 15.0
			or entry.unit in cooldown_units
		):
			return schema._fail("Invalid barricade deployment cooldown.")
		if not _engineer_role(schema.entities[entry.unit], "barricade"):
			return schema._fail("Barricade cooldown belongs to an ineligible unit.")
		cooldown_units.append(entry.unit)
	return true


func _commander(saved) -> bool:
	if not schema._shape(
		saved, "serial:int states:list pending:list emp:list crates:list explored:list"
	):
		return false
	if (
		saved.states.size() > schema.sides.size()
		or saved.pending.size() > schema.sides.size()
		or saved.emp.size() > 400
		or saved.crates.size() > schema.sides.size()
		or saved.explored.size() > schema.sides.size()
	):
		return schema._fail(
			(
				(
					"Commander state exceeds match limits: sides=%d states=%d "
					+ "pending=%d emp=%d crates=%d explored=%d."
				)
				% [
					schema.sides.size(),
					saved.states.size(),
					saved.pending.size(),
					saved.emp.size(),
					saved.crates.size(),
					saved.explored.size()
				]
			)
		)
	var seen = []
	for charge in saved.states:
		if (
			not schema._shape(charge, "player:text started:bool left:num")
			or not schema.sides.has(charge.player)
			or charge.player in seen
			or charge.left > 150
		):
			return schema._fail("Invalid commander charge.")
		seen.append(charge.player)
	var ids = []
	for entry in saved.pending:
		if not schema._shape(
			entry,
			"id:text owner:text kind:text point:vec age:num index:int pattern:list carrier:dict"
		):
			return false
		if (
			not _serial_id(entry.id, "commander:", saved.serial)
			or entry.id in ids
			or not schema.sides.has(entry.owner)
			or (
				entry.kind
				!= {"bastion": "barrage", "helix": "emp", "frontier": "airdrop"}[
					schema.sides[entry.owner].faction
				]
			)
			or not schema._position(entry.point)
			or entry.index > 6
			or entry.age > 12.1
		):
			return schema._fail("Invalid committed commander effect.")
		ids.append(entry.id)
		if entry.kind == "barrage":
			if entry.pattern.size() != 6 or not entry.carrier.is_empty():
				return schema._fail("Invalid frozen artillery pattern.")
			for point in entry.pattern:
				if (
					not schema._type(point, "vec")
					or not schema._position(point)
					or point.distance_to(entry.point) > 8.0
				):
					return schema._fail("Artillery impact outside the committed target.")
		else:
			if not entry.pattern.is_empty() or entry.index != 0:
				return schema._fail("Unexpected artillery progress on commander power.")
		if entry.kind != "airdrop" and not entry.carrier.is_empty():
			return schema._fail("Unexpected commander transport.")
		if entry.kind == "airdrop":
			schema.sides[entry.owner].mobile += 2
			if (
				not entry.carrier.is_empty()
				and not _cargo(entry.carrier, entry.owner, "carrier", entry.id)
			):
				return false
	seen.clear()
	for entry in saved.emp:
		if (
			not schema._shape(entry, "unit:text left:num")
			or not schema.entities.has(entry.unit)
			or entry.unit in seen
			or entry.left > 6.0
		):
			return schema._fail("Invalid EMP duration or victim.")
		seen.append(entry.unit)
		var role = schema.entities[entry.unit].get("role", "")
		if (
			role
			not in [
				"Worker",
				"RepairRobot",
				"Tank",
				"AdvancedTank",
				"AntiAirVehicle",
				"CombatRobot",
				"SupplyTruck",
				"AntiGroundTurret",
				"AntiAirTurret"
			]
		):
			return schema._fail("EMP movement/fire status applied to an ineligible unit.")
	for entry in saved.crates:
		if (
			not schema._shape(entry, "owner:text cargo:dict left:num")
			or not schema.sides.has(entry.owner)
			or entry.left > 60.0
		):
			return schema._fail("Invalid airdrop repair crate.")
		if not _cargo(entry.cargo, entry.owner, "repair", entry.cargo.get("record_id", "")):
			return false
	seen.clear()
	var cells = ceili(schema.map_size.x / 2.0) * ceili(schema.map_size.y / 2.0)
	for entry in saved.explored:
		if (
			not schema._shape(entry, "player:text cells:list")
			or not schema.sides.has(entry.player)
			or entry.player in seen
			or entry.cells.size() > cells
		):
			return schema._fail("Invalid commander exploration state.")
		seen.append(entry.player)
		var unique = {}
		for cell in entry.cells:
			if not cell is int or cell < 0 or cell >= cells or unique.has(cell):
				return schema._fail("Invalid explored terrain cell.")
			unique[cell] = true
	return true


func _cargo(cargo, owner: String, kind: String, record_id: String) -> bool:
	if not schema._shape(cargo, "id:text record_id:text kind:text point:vec hp:num"):
		return false
	if (
		cargo.id != record_id + ":" + kind
		or cargo.record_id != record_id
		or cargo.kind != kind
		or not record_id.begins_with("commander:")
		or cargo.hp <= 0.0
		or cargo.hp > (120.0 if kind == "carrier" else 30.0)
		or not schema._airspace_position(cargo.point)
		or schema._tactical_ids.has(cargo.id)
	):
		return schema._fail("Invalid commander cargo identity or health.")
	_register(cargo.id, "TacticalCargo", owner, cargo.point)
	return true


func _events(saved, settings) -> bool:
	var sites = (
		load("res://source/match/maps/terrain/BattlefieldRegistry.gd")
		. layout(settings.map_path)
		. get("events", [])
	)
	if saved.is_empty():
		return (
			(not settings.battlefield_events or sites.is_empty() or settings.mission_id != "")
			or schema._fail("Missing enabled battlefield event state.")
		)
	if not settings.battlefield_events or sites.is_empty():
		return schema._fail("Battlefield events are unavailable in this match.")
	if not schema._shape(saved, "occurrences:list radar:list"):
		return false
	if saved.occurrences.size() != 2 or saved.radar.size() > 2:
		return schema._fail("Invalid battlefield event schedule or radar count.")
	var kind = sites[0].kind
	for index in saved.occurrences.size():
		var event = saved.occurrences[index]
		if not schema._shape(
			event,
			(
				"id:text kind:text state:text scheduled_at:num warning_delivered:bool "
				+ "activation_delivered:bool expires_at:num cargos:list"
			)
		):
			return false
		if (
			event.id != "event-%d" % index
			or event.kind != kind
			or event.state not in ["scheduled", "announced", "active", "claimed", "expired"]
			or event.scheduled_at != [300.0, 660.0][index]
			or event.cargos.size() != sites.size()
		):
			return schema._fail("Invalid authored battlefield occurrence.")
		var activated = event.state in ["active", "claimed", "expired"]
		var expires = event.scheduled_at + (60.0 if kind == "alpine" else 180.0)
		if (
			event.warning_delivered != (event.state != "scheduled")
			or event.activation_delivered != activated
			or event.expires_at != (expires if activated else 0.0)
		):
			return schema._fail(
				"Battlefield event announcement or expiry disagrees with its state."
			)
		var claims = 0
		var available = 0
		var rotation = posmod(settings.match_seed, sites.size())
		for cargo_index in event.cargos.size():
			var cargo = event.cargos[cargo_index]
			if not schema._shape(
				cargo, "id:text point:vec materials:int electronics:int status:text claimant:text"
			):
				return false
			var share = posmod(cargo_index - rotation - index, sites.size())
			var budget = load("res://source/match/world/BattlefieldEvents.gd").reward_budget(kind)
			var materials = budget.x
			var electronics = budget.y
			if (
				cargo.id != "%s-%d" % [event.id, cargo_index]
				or not schema._position(cargo.point)
				or cargo.status not in ["pending", "available", "claimed", "cancelled"]
				or cargo.materials != _event_share(materials, share, sites.size())
				or cargo.electronics != _event_share(electronics, share, sites.size())
				or (cargo.status == "pending") != (not activated)
				or (cargo.status == "available" and event.state != "active")
				or (cargo.status == "claimed" and not schema.sides.has(cargo.claimant))
				or (cargo.status != "claimed" and cargo.claimant != "")
			):
				return schema._fail("Invalid battlefield cargo status, distribution or claimant.")
			if cargo.status == "claimed":
				claims += 1
			if cargo.status == "available":
				available += 1
				_register(cargo.id, "TacticalCargo", "", cargo.point)
		if (
			(event.state == "active" and available == 0)
			or (event.state == "claimed" and claims == 0)
			or (kind == "alpine" and (claims > 1 or (claims == 1 and event.state != "claimed")))
		):
			return schema._fail("Battlefield event completion disagrees with its cargo.")
	for snapshot in saved.radar:
		if (
			not schema._shape(snapshot, "player:text left:num points:list")
			or kind != "alpine"
			or not schema.sides.has(snapshot.player)
			or snapshot.left > 3.0
			or snapshot.points.size() > 140 * schema.sides.size()
		):
			return schema._fail("Invalid temporary radar snapshot.")
		for point in snapshot.points:
			if not schema._type(point, "vec") or not schema._airspace_position(point):
				return schema._fail("Invalid radar snapshot position.")
	return true


func _event_share(total: int, index: int, count: int) -> int:
	return total / count + (1 if index < total % count else 0)


func _register(id: String, role: String, owner: String, point: Vector3):
	schema._tactical_ids[id] = true
	schema.entities[id] = {"id": id, "role": role, "player": owner, "position": point}


func _serial_id(id: String, prefix: String, next: int, minimum := 0) -> bool:
	if not id.begins_with(prefix) or id.length() > 64:
		return false
	var number = id.trim_prefix(prefix)
	return (
		number.is_valid_int()
		and str(number.to_int()) == number
		and number.to_int() >= minimum
		and number.to_int() < next
	)


func _engineer_role(unit, operation: String) -> bool:
	var faction = schema.sides[unit.player].faction
	if operation == "mine":
		return unit.role in ["Worker", "Tank"] and faction == "frontier"
	if operation == "barricade":
		return unit.role == "Worker" and faction in ["bastion", "frontier"]
	return operation in ["bunker", "tank_trap"] and unit.role == "Worker" and faction == "bastion"


func engineering_action(state, unit) -> bool:
	if not (schema._shape(
		state,
		(
			"operation:text point:vec angle:signed reservation:text phase:int elapsed:num "
			+ "search_index:int unreachable:int search_path:list skipped_mines:list "
			+ "_blocked_elapsed:num _progress_position:maybevec"
		)
	)):
		return false
	if (
		(
			state.operation
			not in [
				"barricade", "bunker", "tank_trap", "mine", "sweep", "repair_barrier", "dismantle"
			]
		)
		or not schema._position(state.point)
		or absf(state.angle) > TAU
		or state.phase > 1
		or state.elapsed > 6.0
		or state.search_path.size() > 13
		or state.search_index > state.search_path.size()
		or state.skipped_mines.size() > 48
		or state._blocked_elapsed > 6.1
	):
		return schema._fail("Invalid field engineering order progress.")
	if state.operation in ["barricade", "bunker", "tank_trap", "mine"]:
		if not _engineer_role(unit, state.operation):
			return schema._fail("Ineligible field engineer.")
	elif unit.role != "Worker":
		return schema._fail("Only workers clear, service or remove field structures.")
	for point in state.search_path:
		if not schema._type(point, "vec") or not schema._position(point):
			return schema._fail("Invalid mine-clearance search waypoint.")
	for id in state.skipped_mines:
		if not id is String or not id.begins_with("engineering-mine-") or id.length() > 64:
			return schema._fail("Invalid mine-clearance skip identity.")
	return true


func order_state(order, unit) -> bool:
	if order.kind == "sweep":
		return (
			(
				unit.role == "Worker"
				and schema._shape(order, "kind:text point:vec")
				and schema._position(order.point)
			)
			or schema._fail("Invalid mine-clearance area order.")
		)
	if order.kind == "engineering":
		if not schema._shape(
			order, "kind:text point:vec engineering_kind:text angle:signed reservation:text"
		):
			return false
		return (
			(
				_engineer_role(unit, order.engineering_kind)
				and order.engineering_kind in ["barricade", "bunker", "tank_trap", "mine"]
				and schema._position(order.point)
				and absf(order.angle) <= TAU
				and order.reservation.begins_with("engineering-reservation-")
			)
			or schema._fail("Invalid queued field deployment.")
		)
	if (
		not schema._shape(order, "kind:text point:vec target:text")
		or not schema._entity_reference(order.target)
	):
		return false
	if order.kind in ["repair_barrier", "dismantle"] and unit.role != "Worker":
		return schema._fail("Only workers service field barriers.")
	if (
		order.kind == "collect_tactical"
		and (unit.role in Catalog.STRUCTURES or Catalog.is_aircraft(unit.role))
	):
		return schema._fail("Only ground units collect battlefield cargo.")
	return true
