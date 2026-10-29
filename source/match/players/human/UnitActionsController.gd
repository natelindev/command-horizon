extends Node

const Orders = preload("res://source/match/orders/ManualOrders.gd")
const CombatRules = preload("res://source/match/combat/CombatRules.gd")

const Structure = preload("res://source/match/units/Structure.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")


class Actions:
	const Moving = preload("res://source/match/units/actions/Moving.gd")
	const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
	const Following = preload("res://source/match/units/actions/Following.gd")
	const CollectingResourcesSequentially = preload(
		"res://source/match/units/actions/CollectingResourcesSequentially.gd"
	)
	const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
	const Constructing = preload("res://source/match/units/actions/Constructing.gd")
	const Repairing = preload("res://source/match/units/actions/Repairing.gd")


# The press that issued the latest ground order: units and their order tokens,
# so a drag release can revise those same orders with formation and facing.
var _ground_dispatch = {}
var _next_token = 0


func _ready():
	MatchSignals.terrain_targeted.connect(_on_terrain_targeted)
	MatchSignals.terrain_target_heading_set.connect(_on_terrain_target_heading_set)
	MatchSignals.unit_targeted.connect(_on_unit_targeted)
	MatchSignals.unit_spawned.connect(_on_unit_spawned)
	MatchSignals.navigate_unit_to_rally_point.connect(_on_navigate_unit_to_rally_point)


func _try_navigating_selected_units_towards_position(target_point):
	_ground_dispatch = {"point": target_point, "tokens": {}}
	var units = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and Actions.Moving.is_applicable(unit)
	)
	for tuple in _group_destinations(units, target_point):
		var order = Orders.point_order("move", tuple[1])
		_next_token += 1
		order.token = _next_token
		if _submit(tuple[0], order):
			_ground_dispatch.tokens[tuple[0]] = order.token


func _group_destinations(units, target_point, heading = null):
	var terrain_units_to_move = units.filter(
		func(unit): return unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
	)
	var air_units_to_move = units.filter(
		func(unit): return unit.movement_domain == Constants.Match.Navigation.Domain.AIR
	)
	var new_unit_targets = Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		terrain_units_to_move, target_point, heading
	)
	new_unit_targets += Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		air_units_to_move, target_point, heading
	)
	return new_unit_targets


func _try_setting_rally_points(target_point: Vector3):
	var controlled_structures = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and unit.find_child("RallyPoint") != null
	)
	for structure in controlled_structures:
		var rally_point = structure.find_child("RallyPoint")
		if rally_point != null:
			rally_point.target_unit = null
			rally_point.global_position = target_point
			MatchSignals.unit_order_issued.emit(structure, "move")
			MatchSignals.order_feedback.emit(structure, "rally", target_point, true, false, "")


func _try_ordering_selected_workers_to_construct_structure(potential_structure):
	if not potential_structure is Structure or potential_structure.is_constructed():
		return
	var structure = potential_structure
	var selected_constructors = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and Actions.Constructing.is_applicable(unit, structure)
			)
	)
	for unit in selected_constructors:
		_submit(unit, Orders.target_order("construct", structure))


func _navigate_selected_units_towards_unit(target_unit):
	var at_least_one_unit_navigated = false
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units"):
			continue
		if _navigate_unit_towards_unit(unit, target_unit):
			at_least_one_unit_navigated = true
	return at_least_one_unit_navigated


func _navigate_unit_towards_unit(unit, target_unit, rally = false):
	var kind = context_kind(unit, target_unit)
	if kind == "":
		return false
	if kind == "rally":
		return _try_setting_rally_point_to_unit(unit, target_unit)
	return _submit(unit, Orders.target_order(kind, target_unit), rally)


static func context_kind(unit, target_unit):
	if not is_instance_valid(unit) or not is_instance_valid(target_unit):
		return ""
	if target_unit.has_method("can_collect") and target_unit.can_collect(unit):
		return "collect_tactical"
	var repairs = load("res://source/match/combat/RepairService.gd")
	if (
		"type" in target_unit
		and target_unit.type in ["RepairDepot", "Barracks", "AircraftFactory"]
		and repairs.facility_eligible(target_unit, unit)
	):
		return "recover"
	if "player" in target_unit and target_unit.player != unit.player:
		if not unit._match.battlefield.is_observed(unit.player, target_unit):
			return ""
	if target_unit.is_in_group("destructible_obstacles"):
		if (
			target_unit.is_in_group("engineering_entities")
			and target_unit.player == unit.player
			and unit.type == "Worker"
		):
			# Dismantling is an explicit R command; healthy friendly barriers are harmless clicks.
			return "repair_barrier" if target_unit.hp < target_unit.hp_max else ""
		return "force_attack" if CombatRules.can_force_target(unit, target_unit) else ""
	if target_unit.is_in_group("field_mines"):
		if not target_unit.known_to(unit.player):
			return ""
		return "force_attack" if CombatRules.can_force_target(unit, target_unit) else ""
	if target_unit.has_method("can_garrison") and target_unit.can_garrison(unit):
		return "garrison"
	if load("res://source/match/units/actions/Scavenging.gd").eligible(unit, target_unit):
		return "scavenge"
	if Actions.Repairing.is_applicable(unit, target_unit):
		return "repair"
	if Actions.CollectingResourcesSequentially.is_applicable(unit, target_unit):
		return "gather"
	if Actions.AutoAttacking.is_applicable(unit, target_unit):
		return "attack"
	if Actions.Constructing.is_applicable(unit, target_unit):
		return "construct"
	if (
		(target_unit.is_in_group("adversary_units") or target_unit.is_in_group("controlled_units"))
		and Actions.Following.is_applicable(unit)
	):
		return "follow"
	if Actions.MovingToUnit.is_applicable(unit):
		return "approach"
	if unit is Structure and unit.find_child("RallyPoint") != null:
		if (
			target_unit is ResourceUnit
			or ("player" in target_unit and unit.player == target_unit.player)
		):
			return "rally"
	return ""  # gdlint: ignore = max-returns


func _try_setting_rally_point_to_unit(unit, target_unit):
	if not unit is Structure:
		return false
	if not target_unit is ResourceUnit and unit.player != target_unit.player:
		# it's not allowed to set rally point to enemy at the moment as with current implementation
		# the position of enemy unit hidden in the fog of war could be hinted
		return false
	var rally_point = unit.find_child("RallyPoint")
	if rally_point == null:
		return false
	rally_point.target_unit = target_unit
	MatchSignals.unit_order_issued.emit(unit, "move")
	MatchSignals.order_feedback.emit(unit, "rally", target_unit.global_position, true, false, "")
	return true


func _on_terrain_targeted(position):
	_try_navigating_selected_units_towards_position(position)
	_try_setting_rally_points(position)


func _on_terrain_target_heading_set(position, heading):
	# The press already issued these orders (and set any rally point). Revise the
	# same orders with formation slots and facing; nothing is queued twice.
	if _ground_dispatch.get("point") != position:
		return
	var tokens = _ground_dispatch.tokens
	_ground_dispatch = {}
	var units = tokens.keys().filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	for tuple in _group_destinations(units, position, heading):
		tuple[0].manual_orders.revise(tokens[tuple[0]], tuple[1])


func _on_unit_targeted(unit):
	if _navigate_selected_units_towards_unit(unit):
		var targetability = unit.find_child("Targetability")
		if targetability != null:
			targetability.animate()


func _on_unit_spawned(unit):
	_try_ordering_selected_workers_to_construct_structure(unit)


func _on_navigate_unit_to_rally_point(unit, rally_point):
	var target = rally_point.target_unit
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		# Production rallies express a standing destination. They must not send
		# fresh infantry into a garrison or make engineers construct their leader.
		if (
			target is ResourceUnit
			and Actions.CollectingResourcesSequentially.is_applicable(unit, target)
		):
			if _submit(unit, Orders.target_order("gather", target), true):
				return
		elif (
			"player" in target
			and target.player == unit.player
			and target != unit
			and target.hp > 0
			and Actions.Following.is_applicable(unit)
		):
			if _submit(unit, Orders.target_order("follow", target), true):
				unit.stance = unit.Stance.DEFENSIVE
				return
	# Depleted deposits, lost leaders and unit classes that cannot harvest still
	# receive the saved point. Never read a vanished target or silently drop it.
	if rally_point.global_position != rally_point.get_parent().global_position:
		_submit(unit, Orders.point_order("move", rally_point.global_position), true)


func _submit(unit, order, rally = false):
	if unit.manual_orders == null:
		return false
	var append = not rally and Globals.options.selection_modifier_pressed()
	var accepted = unit.manual_orders.submit(order, append, not rally)
	if (
		not accepted
		and "hud" in unit._match
		and unit._match.hud != null
		and unit._match.hud.has_method("show_notice")
	):
		unit._match.hud.show_notice(unit.manual_orders.status)
	return accepted
