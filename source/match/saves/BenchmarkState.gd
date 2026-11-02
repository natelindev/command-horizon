extends RefCounted


## Versioned gameplay state, kept separate from rendering and live references.
static func player_state(player, reference: Callable) -> Dictionary:
	return {
		"logistics": player.logistics,
		"logistics_left": player.logistics_left,
		"market_pressure": player.market_pressure,
		"air_contract_left":
		player.get_node("AirContracts").cooldown_left if player.has_node("AirContracts") else 0.0,
		"harvesting": _harvesting(player.harvesting_boosts, reference),
		"production": _boosts(player.production_boosts, reference),
	}


static func _harvesting(boosts, reference: Callable) -> Array:
	var result = []
	for boost in boosts:
		if boost.left > 0.0:
			result.append(
				{
					"target": reference.call(boost.target.get_ref()),
					"field": boost.field,
					"anchored": boost.anchored,
					"left": boost.left
				}
			)
	return result


static func _boosts(boosts, reference: Callable) -> Array:
	var result = []
	for boost in boosts:
		var target = boost.target.get_ref()
		if is_instance_valid(target) and not target.is_queued_for_deletion() and boost.left > 0.0:
			result.append({"target": reference.call(target), "left": boost.left})
	return result


static func restore_player(player, saved: Dictionary, entities: Dictionary):
	player.logistics = saved.logistics
	player.logistics_left = saved.logistics_left
	player.market_pressure = saved.market_pressure
	if saved.air_contract_left > 0.0:
		load("res://source/match/economy/FrontierAirContracts.gd").get_for(player).cooldown_left = (
			saved.air_contract_left
		)
	player.harvesting_boosts = saved.harvesting.map(
		func(boost):
			return {
				"target": _weak_target(entities.get(boost.target)),
				"field": boost.field,
				"anchored": boost.anchored,
				"left": boost.left
			}
	)
	player.production_boosts = saved.production.map(
		func(boost): return {"target": weakref(entities[boost.target]), "left": boost.left}
	)


static func _weak_target(target) -> WeakRef:
	return weakref(target) if is_instance_valid(target) else WeakRef.new()


static func unit_state(unit, reference: Callable) -> Dictionary:
	var movement = unit.get_node_or_null("Movement")
	return {
		"tactics":
		unit.manual_orders.capture_tactics(reference) if unit.manual_orders != null else {},
		"ion_stall_left": movement.ion_stall_left if movement != null else 0.0,
		"refinery_remainder": unit.smelting_remainder if unit.type == "ForwardRefinery" else 0.0,
		"hq_energy": unit.energy if unit.type == "CommandCenter" else 0.0,
		"shield_withdrawing": unit.get_meta("shield_withdrawing", false),
		"cloak_left": unit.optical_cloak.idle_left if unit.optical_cloak != null else 0.0,
		"mercenary":
		(
			unit.get_node("MercenarySortie").capture_state()
			if unit.has_node("MercenarySortie")
			else {}
		),
		"prism_target":
		(
			reference.call(unit.prism_lock_target)
			if unit.type == "AdvancedTank" and unit.player.faction == "helix"
			else ""
		),
		"prism_seconds":
		(
			unit.prism_lock_seconds
			if unit.type == "AdvancedTank" and unit.player.faction == "helix"
			else 0.0
		),
	}


static func valid_player(schema, side) -> bool:
	var state = side.economy
	if not (schema._shape(
		state,
		(
			"logistics:num logistics_left:num market_pressure:signed "
			+ "air_contract_left:num harvesting:list production:list"
		)
	)):
		return false
	if (
		state.logistics > 100
		or state.logistics_left > 5
		or absf(state.market_pressure) > 20
		or state.air_contract_left > 20.0
	):
		return schema._fail("Invalid logistics or market reserve.")
	for kind in ["harvesting", "production"]:
		if state[kind].size() > 100:
			return schema._fail("Too many macro effects.")
		for boost in state[kind]:
			if (
				not schema._shape(
					boost,
					(
						"target:text left:num"
						+ (" field:vec anchored:bool" if kind == "harvesting" else "")
					)
				)
				or boost.left <= 0.0
				or boost.left > (30.0 if kind == "harvesting" else 25.0)
			):
				return schema._fail("Invalid macro effect timer.")
	return true


static func valid_links(schema, data) -> bool:
	for side in data.players:
		if side.economy.air_contract_left > 0.0 and schema.sides[side.id].faction != "frontier":
			return schema._fail("Air contracts are unavailable to this faction.")
		for boost in side.economy.harvesting:
			if (
				(boost.target != "" and not schema.entities.get(boost.target, {}).has("amount"))
				or not schema._position(boost.field)
				or schema.sides[side.id].faction != "bastion"
			):
				return schema._fail("Invalid harvesting macro target.")
		for boost in side.economy.production:
			var target = schema.entities.get(boost.target, {})
			if (
				target.get("player") != side.id
				or (
					target.get("role")
					not in ["Barracks", "VehicleFactory", "AircraftFactory", "CommandLab"]
				)
				or schema.sides[side.id].faction != "helix"
			):
				return schema._fail("Invalid resonance target.")
	for unit in data.units:
		var state = unit.benchmark
		if not (
			schema
			. _shape(
				state,
				(
					"tactics:dict ion_stall_left:num refinery_remainder:num hq_energy:num "
					+ "shield_withdrawing:bool cloak_left:num mercenary:dict prism_target:text prism_seconds:num"
				)
			)
		):
			return false
		if (
			state.ion_stall_left > 2.5
			or state.refinery_remainder >= 1.0
			or state.prism_seconds > 4.0
			or state.hq_energy > 100.0
			or state.cloak_left > 3.0
		):
			return schema._fail("Invalid benchmark unit timer.")
		if not state.mercenary.is_empty():
			if (
				not schema._shape(state.mercenary, "fuel_left:num departing:bool exit:vec")
				or schema.sides[unit.player].faction != "frontier"
				or unit.role not in ["Helicopter", "Fighter", "Bomber"]
				or state.mercenary.fuel_left > 90.0
				or not schema._airspace_position(state.mercenary.exit)
			):
				return schema._fail("Invalid mercenary aircraft sortie.")
		if (
			state.hq_energy > 0.0
			and (unit.role != "CommandCenter" or schema.sides[unit.player].faction != "helix")
		):
			return schema._fail("Nexus energy on an ineligible unit.")
		if (
			state.cloak_left > 0.0
			and (unit.role != "SniperInfantry" or schema.sides[unit.player].faction != "helix")
		):
			return schema._fail("Optical cloak on an ineligible unit.")
		if unit.role != "ForwardRefinery" and state.refinery_remainder != 0.0:
			return schema._fail("Refining state on a non-refinery.")
		if unit.role in load("res://source/match/BastionCatalog.gd").STRUCTURES:
			if not state.tactics.is_empty() or state.ion_stall_left != 0.0:
				return schema._fail("Mobile tactical state on a structure.")
		else:
			if (
				not schema._shape(
					state.tactics, "formation:text cohesion_enabled:bool cohesion_members:list"
				)
				or not valid_tactics(schema, state.tactics, unit)
			):
				return false
		if state.prism_target != "":
			if (
				unit.role != "AdvancedTank"
				or schema.sides[unit.player].faction != "helix"
				or not schema._unit_reference(state.prism_target)
			):
				return schema._fail("Invalid prism focus target.")
	return true


static func valid_tactics(schema, state, unit) -> bool:
	if (
		state.formation not in ["line", "box", "flank", "staggered"]
		or state.cohesion_members.size() > 140 * schema.sides.size()
	):
		return schema._fail("Invalid formation posture or group size.")
	var seen = []
	for id in state.cohesion_members:
		var member = schema.entities.get(id, {}) if id is String else {}
		if member.get("player") != unit.player or member.get("construction") != null or id in seen:
			return schema._fail("Invalid formation group member.")
		seen.append(id)
	return true
