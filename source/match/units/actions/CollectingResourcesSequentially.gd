extends "res://source/match/units/actions/Action.gd"

enum State { NULL, MOVING_TO_RESOURCE, COLLECTING, MOVING_TO_CC, WAITING, PHASE_RETURN }
enum Wait { NONE, SLOT, DEPLETED, HQ, DELIVERED }
const FIELD_RADIUS = 13.0
# Deposits without an authored field origin group around the engineer's first deposit.
const UNANCHORED_FIELD_RADIUS = 10.0
const WORK_SLOTS = 3
const OPTIMAL_WORK_SLOTS = 2
const Harvesting = preload("res://source/match/economy/HarvestingProfile.gd")
const ASSIGNMENTS = &"harvest_assignments"
const CommandCenter = preload("res://source/match/units/CommandCenter.gd")
const CollectingResourcesWhileInRange = preload(
	"res://source/match/units/actions/CollectingResourcesWhileInRange.gd"
)
const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")
var _state = State.NULL:
	set = _set_state
var _kind = 0
var _field_origin = Vector3.ZERO
var _waiting_reason = Wait.NONE
var _retry_left = 0.0
var _phase_left = 0.0
var _resource_unit = null
var _cc_unit = null
var _sub_action = null
@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(source_unit, target_unit):
	if not is_instance_valid(source_unit) or not is_instance_valid(target_unit):
		return false
	return (
		source_unit is Worker
		and (
			(target_unit is ResourceUnit and target_unit.can_harvest(source_unit))
			or (Harvesting.valid_dropoff(source_unit, target_unit))
		)
	)


func _init(unit):
	if not is_instance_valid(unit):
		return
	if unit is ResourceUnit:
		_kind = 1 if "resource_a" in unit else 2
		_field_origin = (
			unit.harvest_origin if unit.harvest_origin.is_finite() else unit.global_position_yless
		)
		_set_resource_unit(unit)
	elif "type" in unit and unit.type in ["CommandCenter", "ForwardRefinery"]:
		_set_cc_unit(unit)


func _ready():
	add_to_group(ASSIGNMENTS)
	_sync_ghost()
	if restoring:
		return
	if _kind != 0:
		if (
			_unit.resource_a + _unit.resource_b > 0
			and not (
				is_instance_valid(_resource_unit) and _resource_unit.is_in_group("salvage_wrecks")
			)
		):
			_start_return()
		else:
			_start_resource_leg()
	else:
		_start_return()


func _exit_tree():
	var movement = _unit.get_node_or_null("Movement") if is_instance_valid(_unit) else null
	if movement != null:
		movement.ghosted = false


func _process(delta):
	if _state == State.PHASE_RETURN:
		_tick_phase_delivery(delta)
		return
	if (
		_state == State.MOVING_TO_CC
		and is_instance_valid(_cc_unit)
		and Harvesting.valid_dropoff(_unit, _cc_unit)
		and Utils.Match.Unit.Movement.units_adhere(_unit, _cc_unit)
	):
		if is_instance_valid(_sub_action):
			_sub_action.tree_exited.disconnect(_on_sub_action_finished)
			_sub_action.queue_free()
			_sub_action = null
		_finish_delivery()
		return
	if needs_assignment() and _has_pending_orders():
		queue_free()
		return
	if _state != State.WAITING or _waiting_reason != Wait.SLOT:
		return
	_retry_left = maxf(0, _retry_left - delta)
	if _retry_left == 0:
		_start_resource_leg()


func _set_state(value):
	_state = value
	_sync_ghost()


func _sync_ghost():
	# Engineers on a harvest run ghost through ground units, as in other RTS
	# economies: lanes never jam. Waiting or idle engineers are solid again.
	# The @onready unit is still unset while a save restores the state.
	if _unit == null or not is_inside_tree():
		return
	var movement = _unit.get_node_or_null("Movement")
	if movement != null:
		movement.ghosted = (
			_state
			in [State.MOVING_TO_RESOURCE, State.COLLECTING, State.MOVING_TO_CC, State.PHASE_RETURN]
		)


func _to_string():
	return "Harvest(%s)" % harvest_status()


func get_resource_unit():
	return _resource_unit


func is_waiting():
	return _state == State.WAITING


func needs_assignment():
	return _state == State.WAITING and _waiting_reason != Wait.SLOT


func harvest_status():
	var name = "Materials" if _kind == 1 else "Electronics"
	match _state:
		State.MOVING_TO_RESOURCE:
			return name + " · approaching work slot"
		State.COLLECTING:
			return name + " · collecting"
		State.MOVING_TO_CC:
			return "Returning cargo to drop-off"
		State.PHASE_RETURN:
			return tr("Phase delivery · %.1fs") % _phase_left
		State.WAITING:
			return (
				{
					Wait.SLOT: name + " · waiting for a work slot",
					Wait.DEPLETED: name + " field depleted · choose a new field",
					Wait.HQ: "No drop-off · choose a friendly HQ or refinery",
					Wait.DELIVERED: "Cargo delivered · choose a resource field"
				}
				. get(_waiting_reason, "Waiting for assignment")
			)
	return "Preparing resource assignment"


func holds_harvest_slot(deposit):
	return (
		not is_queued_for_deletion()
		and is_inside_tree()
		and not _unit.is_queued_for_deletion()
		and _resource_unit == deposit
		and _state in [State.MOVING_TO_RESOURCE, State.COLLECTING]
	)


func can_work(deposit):
	if not deposit.can_harvest(_unit):
		return false
	# Scene order decides which assignments hold a deposit's limited work slots.
	var index = 0
	for action in get_tree().get_nodes_in_group(ASSIGNMENTS):
		if action.holds_harvest_slot(deposit):
			if action == self:
				return index < WORK_SLOTS
			index += 1
	return false


func gathering_efficiency(deposit) -> float:
	var index = 0
	for assignment in get_tree().get_nodes_in_group(ASSIGNMENTS):
		if assignment.holds_harvest_slot(deposit):
			if assignment == self:
				return 1.0 if index < OPTIMAL_WORK_SLOTS else (0.6 if index < WORK_SLOTS else 0.0)
			index += 1
	return 0.0


func _slot_counts():
	var counts = {}
	for action in get_tree().get_nodes_in_group(ASSIGNMENTS):
		if action == self:
			continue
		var deposit = action.get_resource_unit()
		if is_instance_valid(deposit) and action.holds_harvest_slot(deposit):
			counts[deposit] = counts.get(deposit, 0) + 1
	return counts


func _field_deposits():
	var property = "resource_a" if _kind == 1 else "resource_b"
	return get_tree().get_nodes_in_group("resource_units").filter(
		func(deposit):
			return (
				_kind != 0
				and deposit.can_harvest(_unit)
				and property in deposit
				and deposit.get(property) > 0
				and (
					deposit.harvest_origin.is_equal_approx(_field_origin)
					if deposit.harvest_origin.is_finite()
					else (
						deposit.global_position_yless.distance_squared_to(_field_origin)
						<= UNANCHORED_FIELD_RADIUS * UNANCHORED_FIELD_RADIUS
					)
				)
			)
	)


func _start_resource_leg():
	if _kind == 0:
		_wait(Wait.DELIVERED)
		return
	var deposits = _field_deposits()
	if deposits.is_empty():
		if _unit.resource_a + _unit.resource_b > 0:
			_start_return()
		else:
			_wait(Wait.DEPLETED)
		return
	var counts = _slot_counts()
	var best = null
	var best_cost = INF
	var collecting_time = (
		Constants.Match.Resources.A.COLLECTING_TIME_S
		if _kind == 1
		else Constants.Match.Resources.B.COLLECTING_TIME_S
	)
	# A second worker competes for the approach/exit lane. Prefer an unused nearby
	# pile when its extra travel costs less than one loading cycle.
	var congestion_cost: float = collecting_time * _unit.resources_max
	for deposit in deposits:
		var occupied: int = counts.get(deposit, 0)
		if occupied >= WORK_SLOTS:
			continue
		var contact = (
			_unit.radius
			+ deposit.radius
			+ Utils.Match.Unit.Movement.adherence_margin(_unit, deposit)
		)
		var route: float = Utils.Match.Unit.Movement.path_distance_to(
			_unit, deposit.global_position_yless, contact
		)
		var cost: float = route / maxf(.01, _unit.movement_speed) + occupied * congestion_cost
		# Drain the field evenly instead of repeatedly emptying its closest piles.
		# Remaining work per reserved slot predicts the end-of-field backlog;
		# travel and the third slot's congestion still resolve comparable nodes.
		var amount: int = deposit.get("resource_a" if _kind == 1 else "resource_b")
		cost -= amount * collecting_time / float(occupied + 1)
		if cost < best_cost:
			best_cost = cost
			best = deposit
	if best != null:
		_set_resource_unit(best)
		_state = State.MOVING_TO_RESOURCE
		_waiting_reason = Wait.NONE
		_child(MovingToUnit.new(best))
		return
	_wait(Wait.SLOT)


func _start_return():
	_waiting_reason = Wait.NONE
	_state = State.MOVING_TO_CC  # Release the work slot during the return trip.
	var phase = _unit.player.faction == "helix" and _unit.is_full()
	# Field work chooses the best receiver on every trip, so a newly completed
	# forward refinery immediately shortens the haul. An explicit return order
	# continues to honor its chosen destination.
	if _kind != 0 or not Harvesting.valid_dropoff(_unit, _cc_unit, phase):
		_set_cc_unit(_find_cc_closest_to_unit(_unit, phase))
	if _cc_unit == null:
		_wait(Wait.HQ)
		return
	if phase:
		_state = State.PHASE_RETURN
		_phase_left = Harvesting.PHASE_CHANNEL
		_unit.get_node("Movement").stop()
		_unit.action_updated.emit()
	else:
		_child(MovingToUnit.new(_cc_unit))


func _tick_phase_delivery(delta):
	if not Harvesting.valid_dropoff(_unit, _cc_unit, true):
		_phase_left = 0.0
		_wait(Wait.HQ)
		return
	_phase_left = maxf(0.0, _phase_left - delta)
	if _phase_left > 0.0:
		return
	var arrival = _phase_arrival_point()
	# A packed landing zone waits without losing cargo or restarting its cast.
	if not arrival.is_finite():
		return
	var movement = _unit.get_node("Movement")
	movement.stop()
	movement.relocate(arrival)
	_finish_delivery()


func _phase_arrival_point() -> Vector3:
	var movement = _unit.get_node("Movement")
	if not movement._synchronized:
		return Vector3.INF
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = movement.get_navigation_map()
	var direction = (_unit.global_position_yless - _cc_unit.global_position_yless).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var blockers = get_tree().get_nodes_in_group("units").filter(
		func(other):
			return (
				other != _unit
				and not other.has_meta("garrison_host")
				and other.movement_domain == _unit.movement_domain
			)
	)
	blockers.append_array(get_tree().get_nodes_in_group("resource_units"))
	blockers.append_array(_unit._match.battlefield.nearby_obstacles(_cc_unit.global_position, 12.0))
	# Try the field-facing landing lane before rotating around the headquarters.
	# A slightly wider clear ring avoids choosing the far side solely because
	# rasterization blocked one inner-ring sample.
	for slot in 32:
		var radial = direction.rotated(Vector3.UP, slot * TAU / 32.0)
		for ring in 4:
			var desired = (
				_cc_unit.global_position
				+ radial * (_cc_unit.radius + _unit.radius + .3 + ring * .8)
			)
			desired.y = _unit._match.map.height_at(Vector2(desired.x, desired.z))
			var projected = NavigationServer3D.map_get_closest_point(
				nav, desired + Vector3.UP * movement.path_height_offset
			)
			var point = movement._navigation_position(projected)
			if Vector2(point.x - desired.x, point.z - desired.z).length() > .3:
				continue

			if (
				placement.validate_agent_placement_position(
					point, _unit.radius + .02, blockers, nav, _unit._match.map
				)
				== placement.VALID
			):
				return point

	return Vector3.INF


func _finish_delivery():
	Harvesting.deliver(_unit, _cc_unit)
	if _unit.manual_orders != null and not _unit.manual_orders.pending.is_empty():
		queue_free()
	else:
		_start_resource_leg()


func _child(action):
	_sub_action = action
	_sub_action.tree_exited.connect(_on_sub_action_finished, CONNECT_DEFERRED)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _wait(reason):
	_state = State.WAITING
	_waiting_reason = reason
	_retry_left = 0.5
	_unit.get_node("Movement").stop()
	_unit.action_updated.emit()
	if needs_assignment() and _has_pending_orders():
		queue_free()
	elif reason in [Wait.DEPLETED, Wait.HQ]:
		var game = _unit._match
		if (
			_unit.player == game._get_human_player()
			and "hud" in game
			and is_instance_valid(game.hud)
		):
			game.hud.show_notice("Engineer · " + harvest_status())


func _has_pending_orders():
	return _unit.manual_orders != null and not _unit.manual_orders.pending.is_empty()


func _set_resource_unit(deposit):
	if (
		is_instance_valid(_resource_unit)
		and _resource_unit.tree_exited.is_connected(_on_resource_unit_removed)
	):
		_resource_unit.tree_exited.disconnect(_on_resource_unit_removed)
	_resource_unit = deposit
	if is_instance_valid(deposit):
		deposit.tree_exited.connect(_on_resource_unit_removed)


func _set_cc_unit(cc):
	if is_instance_valid(_cc_unit) and _cc_unit.tree_exited.is_connected(_on_cc_unit_removed):
		_cc_unit.tree_exited.disconnect(_on_cc_unit_removed)
	_cc_unit = cc
	if is_instance_valid(cc):
		cc.tree_exited.connect(_on_cc_unit_removed)


static func _find_cc_closest_to_unit(unit, hq_only = false):
	var choices = unit.get_tree().get_nodes_in_group("units").filter(
		func(receiver): return Harvesting.valid_dropoff(unit, receiver, hq_only)
	)
	var best = null
	var distance = INF
	for receiver in choices:
		var contact = (
			unit.radius
			+ receiver.radius
			+ Utils.Match.Unit.Movement.adherence_margin(unit, receiver)
		)
		var route = (
			unit.global_position_yless.distance_to(receiver.global_position_yless)
			if hq_only
			else Utils.Match.Unit.Movement.path_distance_to_unit(unit, receiver, contact)
		)
		if route < distance:
			best = receiver
			distance = route
	if best != null or hq_only or choices.is_empty():
		return best
	# When a neighboring building sits along the direct ray to a drop-off's
	# center, a center-targeted path stops on the far side of that obstacle even
	# though other faces of the HQ/refinery are open. Probe perimeter faces
	# before declaring no reachable drop-off.
	for receiver in choices:
		var contact = (
			unit.radius
			+ receiver.radius
			+ Utils.Match.Unit.Movement.adherence_margin(unit, receiver)
		)
		var probe_radius = maxf(receiver.radius + 0.2, contact - 0.3)
		for index in 8:
			var angle = index * TAU / 8.0
			var probe = receiver.global_position + Vector3(cos(angle), 0, sin(angle)) * probe_radius
			var route = Utils.Match.Unit.Movement.path_distance_to(unit, probe, 0.75)
			if route < distance:
				best = receiver
				distance = route
	return best


func _on_sub_action_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sub_action = null
	match _state:
		State.MOVING_TO_RESOURCE:
			if (
				not is_instance_valid(_resource_unit)
				or _resource_unit.is_queued_for_deletion()
				or not can_work(_resource_unit)
			):
				_start_resource_leg()
			elif _resource_unit.is_in_group("salvage_wrecks") and _resource_unit.dismantle(_unit):
				if _has_pending_orders():
					queue_free()
				else:
					_start_resource_leg()
			elif _unit.is_full():
				_start_return()
			else:
				_state = State.COLLECTING
				_child(CollectingResourcesWhileInRange.new(_resource_unit))
		State.COLLECTING:
			if (
				_unit.is_full()
				or not is_instance_valid(_resource_unit)
				or _resource_unit.is_queued_for_deletion()
			):
				_start_return()
			else:
				_start_resource_leg()
		State.MOVING_TO_CC:
			if (
				not is_instance_valid(_cc_unit)
				or _cc_unit.is_queued_for_deletion()
				or not _cc_unit.is_constructed()
			):
				if _kind != 0:
					_start_return()
				else:
					_wait(Wait.HQ)
				return
			if not Utils.Match.Unit.Movement.units_adhere(_unit, _cc_unit):
				_start_return()
				return
			_finish_delivery()


func _on_resource_unit_removed():
	_resource_unit = null


func _on_cc_unit_removed():
	_cc_unit = null
