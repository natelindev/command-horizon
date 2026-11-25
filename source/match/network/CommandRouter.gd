# gdlint: disable=max-returns
extends RefCounted

const Cohesion = preload("res://source/match/orders/CohesionGroup.gd")
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
var session
var error = ""
var _factions


func apply(slot: int, intent: Dictionary) -> bool:
	error = ""
	if _factions == null:
		_factions = load("res://source/match/FactionCatalog.gd")
	if not Protocol.new().valid_intent(intent):
		return _fail("Invalid command.")
	var player = session.entities().get("player-%d" % slot)
	if not is_instance_valid(player) or session.game._defeat_timers.get(player, 0) <= 0:
		return _fail("Commander is no longer active.")
	var intents = Protocol.unpack_batch(intent) if intent.kind == "batch" else [intent]
	var prepared = []
	var cohorts = {}
	# No entry mutates the match until every reference, owner and point in this
	# gesture has passed validation. Live affordability still applies per job.
	for entry in intents:
		var context = _resolve(player, entry, cohorts)
		if context.is_empty():
			return false
		prepared.append(context)
	session.applying = true
	var accepted = false
	for index in intents.size():
		var context = prepared[index]
		accepted = (
			_execute(
				player,
				context.unit,
				context.units,
				context.point,
				context.target,
				intents[index],
				context.cohort
			)
			or accepted
		)
	session.applying = false
	if not accepted and error.is_empty():
		error = "Order is unavailable in the current battle state."
	return accepted


func _resolve(player, intent, cohorts: Dictionary) -> Dictionary:
	var unit = session.entities().get(intent.get("unit", ""))
	if intent.has("unit") and not _owned(unit, player):
		_fail("Command does not own this unit.")
		return {}
	var units = []
	for id in intent.get("units", []):
		var member = session.entities().get(id)
		if not _owned(member, player):
			_fail("Command does not own every selected unit.")
			return {}
		units.append(member)
	var point = Protocol.vector(intent.point) if intent.has("point") else Vector3.INF
	if point.is_finite() and not _inside(point):
		_fail("Order is outside the battlefield.")
		return {}
	var target = session.entities().get(intent.get("target", ""))
	if intent.has("target") and not is_instance_valid(target):
		_fail("Target no longer exists.")
		return {}
	var cohort = null
	if intent.has("members"):
		var key = JSON.stringify(intent.members)
		if not cohorts.has(key):
			var members = intent.members.map(func(id): return session.entities().get(id))
			if not members.all(func(node): return _owned(node, player)):
				_fail("Command does not own every formation member.")
				return {}
			cohorts[key] = Cohesion.new(members)
		cohort = cohorts[key]
	return {"unit": unit, "units": units, "point": point, "target": target, "cohort": cohort}


func _execute(player, unit, units, point, target, intent, cohort = null) -> bool:
	match intent.kind:
		"order":
			var accepted = false
			for member in units:
				if member.manual_orders == null:
					continue
				if intent.order in ["stop", "hold"]:
					member.manual_orders.cancel()
					if intent.order == "hold":
						member.stance = member.Stance.HOLD_POSITION
					member.action = null
					member.get_node("Movement").stop()
					accepted = true
					continue
				if intent.order == "unload":
					if member.has_meta("garrison_host"):
						member.manual_orders.cancel()
						member.action = null
						accepted = true
					elif member.garrison_mount != null:
						for occupant in member.garrison_mount.occupants.duplicate():
							member.garrison_mount.leave(occupant)
						accepted = true
					continue
				var order = {"kind": intent.order, "point": point}
				if intent.has("token"):
					order.token = intent.token
				if cohort != null:
					order.cohort = cohort
				if target != null:
					order.target = weakref(target)
				if intent.has("waypoints"):
					order.waypoints = intent.waypoints.map(Protocol.vector)
				if intent.order == "engineering":
					var angle = deg_to_rad(intent.get("angle", 0) / 1000.0)
					accepted = (
						session.game.engineering.request(
							member, intent.get("id", ""), point, angle, intent.get("append", false)
						)
						or accepted
					)
					continue
				elif (
					intent.order not in ["move", "attack_move", "patrol", "sweep"]
					and target == null
				):
					continue
				accepted = (
					member.manual_orders.submit(order, intent.get("append", false)) or accepted
				)
			return accepted
		"produce":
			if unit.production_queue == null:
				return false
			if intent.role not in _factions.production_options(player.faction, unit.type):
				return false
			return (
				unit.production_queue.produce(
					load(_factions.scene_path(player.faction, intent.role))
				)
				!= null
			)
		"cancel_production":
			if (
				unit.production_queue == null
				or intent.index < 0
				or intent.index >= unit.production_queue._queue.size()
			):
				return false
			unit.production_queue.cancel(unit.production_queue._queue[intent.index])
			return true
		"research":
			return player.technology.enqueue(intent.id, unit)
		"cancel_research":
			if intent.index < 0:
				if player.coordination_left > 0:
					player.cancel_coordination()
					return true
				return player.technology.cancel()
			return player.technology.cancel_queued(intent.index)
		"ability":
			return unit.abilities != null and unit.abilities.trigger(intent.id, point, target)
		"exchange":
			return player.market_exchange(intent.direction)
		"hire_aircraft":
			return (
				load("res://source/match/economy/FrontierAirContracts.gd").get_for(player).hire(
					intent.role
				)
				!= null
			)
		"signature":
			return player.signatures.activate(units, point) > 0
		"commander":
			return session.game.commander_support.activate(player, point)
		"stance":
			for member in units:
				member.stance = intent.value
			return true
		"formation":
			for member in units:
				if member.manual_orders != null:
					member.manual_orders.formation = intent.value
			return true
		"cohesion":
			var group = Cohesion.new(units)
			for member in units:
				if member.manual_orders != null:
					member.manual_orders.configure_cohesion(intent.value, group)
			return true
		"build":
			return _build(player, point, intent)
		"rally":
			var rally = unit.get_node_or_null("RallyPoint")
			if (
				rally == null
				or (
					target != null
					and not target.is_in_group("resource_units")
					and (not "player" in target or target.player != player)
				)
			):
				return false
			rally.target_unit = target
			rally.global_position = point
			return true
		"revise_order":
			return (
				unit.manual_orders != null
				and unit.manual_orders.revise(
					intent.token, point, intent.get("waypoints", []).map(Protocol.vector)
				)
			)
		"cancel_build":
			return unit.has_method("cancel_construction") and unit.cancel_construction()
		"hire_mercenary":
			return target.is_in_group("points_of_interest") and target.hire(player, intent.role)
		"cancel_mercenary":
			return (
				target.is_in_group("points_of_interest")
				and target.cancel_hire(player, intent.index)
			)
		"surrender":
			session.game.surrender(player)
			return true
	return false


func _build(player, point, intent) -> bool:
	if (
		intent.role not in load("res://source/match/BastionCatalog.gd").STRUCTURES
		or not _factions.roster(player.faction).allows(intent.role, true)
		or not _factions.available(player, intent.role, true)
	):
		return false
	var price = _factions.cost(player, intent.role, true)
	if not player.has_resources(price):
		return false
	var prototype = load(_factions.scene_path(player.faction, intent.role)).instantiate()
	var radius = prototype.radius
	var site = Transform3D(Basis(Vector3.UP, deg_to_rad(intent.get("angle", 0) / 1000.0)), point)
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var footprint = load("res://source/match/utils/Footprint.gd")
	var existing = (
		session.game.get_cached_group("units") + session.game.get_cached_group("resource_units")
	)
	var nav_rid = session.game.navigation.get_navigation_map_rid_by_domain(
		Constants.Match.Navigation.Domain.TERRAIN
	)
	var valid = placement.VALID
	if session.game.field_position_reserved(point, radius):
		valid = placement.COLLIDES_WITH_AGENT
	elif footprint.has_outline(prototype):
		var polygon = footprint.outline_at(footprint.local_outline(prototype), site)
		var map_polygon = session.game.map.get_topdown_polygon_2d()
		if not Array(polygon).all(func(p): return Geometry2D.is_point_in_polygon(p, map_polygon)):
			valid = placement.NOT_NAVIGABLE
		else:
			valid = placement.validate_footprint_placement(
				polygon, existing, nav_rid, session.game.map
			)
	else:
		valid = placement.validate_agent_placement_position(
			point, radius, existing, nav_rid, session.game.map
		)
	if valid != placement.VALID:
		prototype.free()
		return _fail("Building foundation is blocked or cannot be reached.")
	var workers = player.live_units().filter(func(worker): return worker.type == "Worker")
	if workers.is_empty():
		prototype.free()
		return false
	player.subtract_resources(price)
	session.game._setup_and_spawn_unit(prototype, site, player)
	workers.sort_custom(
		func(a, b):
			return (
				a.global_position.distance_squared_to(point)
				< b.global_position.distance_squared_to(point)
			)
	)
	workers[0].manual_orders.submit(
		{"kind": "construct", "point": point, "target": weakref(prototype)}
	)
	return true


func _owned(unit, player) -> bool:
	return (
		is_instance_valid(unit)
		and "player" in unit
		and unit.player == player
		and unit.hp > 0
		and not unit.is_queued_for_deletion()
	)


func _inside(point: Vector3) -> bool:
	return (
		point.x >= 0
		and point.z >= 0
		and point.x <= session.game.map.size.x
		and point.z <= session.game.map.size.y
		and absf(point.y) <= 128
	)


func _fail(message: String) -> bool:
	error = message
	return false
