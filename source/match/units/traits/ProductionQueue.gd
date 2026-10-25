extends Node

signal element_enqueued(element)
signal element_removed(element)

const Factions = preload("res://source/match/FactionCatalog.gd")

const Departure = preload("res://source/match/effects/ProductionDeparture.gd")
const BastionCatalog = preload("res://source/match/BastionCatalog.gd")
const STREAK_GRACE = 5.0
const STREAK_STEP = .08


class ProductionQueueElement:
	extends Resource
	var unit_prototype = null
	var time_total = null
	var paid_cost = {}
	var departure_endpoint = null
	var assembly_started := false
	var assembly_bonus := 0.0
	var time_left = null:
		set(value):
			time_left = value
			emit_changed()

	func progress():
		return (time_total - time_left) / time_total


var departure = null
var exit_blocked = false
var last_completed_role := ""
var completed_streak := 0
var idle_grace_left := 0.0
var _queue = []

@onready var _unit = get_parent()


func _ready():
	set_process(false)


func _process(delta):
	if _queue.is_empty():
		_advance_idle(delta)
		return
	if not _unit.is_constructed():
		return
	delta *= _unit.player.production_factor()
	while _queue.size() > 0 and delta > 0.0:
		var element = _queue.front()
		if not blocked_reason(false).is_empty():
			return
		_start_assembly(element)
		if BastionCatalog.is_fixed_wing(
			BastionCatalog.type_from_path(element.unit_prototype.resource_path)
		):
			# Jets are assembled in place and appear parked on their stand.
			var built = minf(delta, element.time_left)
			element.time_left -= built
			delta -= built
			if element.time_left > 0.0:
				return
			_remove_element(element)
			_finalize_parked(element)
			continue
		# The exit animation consumes the final part of the paid production time.
		var departure_seconds = Departure.seconds(element)
		if element.time_left > departure_seconds:
			var rate = 1.0 + element.assembly_bonus
			var assembly = minf(delta * rate, element.time_left - departure_seconds)
			element.time_left -= assembly
			delta -= assembly / rate
			if delta <= 0:
				return
		if not is_instance_valid(departure):
			departure = Departure.new()
			departure.name = "ProductionDeparture"
			_unit.add_child(departure)
			departure.prepare(_unit, element)
		exit_blocked = not departure.find_route()
		if exit_blocked:
			departure.update_pose(0.0)
			return
		var elapsed = minf(delta, element.time_left)
		element.time_left -= elapsed
		delta -= elapsed
		departure.update_pose(elapsed)
		if element.time_left == 0.0:
			var launch = departure
			departure = null
			_remove_element(element)
			_finalize_production(element, launch)
			launch.queue_free()
	if _queue.is_empty() and delta > 0.0:
		_advance_idle(delta / maxf(.001, _unit.player.production_factor()))


func has_assembly_line() -> bool:
	return _unit.player.faction == "bastion" and _unit.type in ["Barracks", "VehicleFactory"]


func next_assembly_bonus(role: String) -> float:
	if not has_assembly_line() or role == "Hero" or role != last_completed_role:
		return 0.0
	return mini(completed_streak, 3) * STREAK_STEP


func _start_assembly(element):
	if element.assembly_started:
		return
	element.assembly_started = true
	var role = BastionCatalog.type_from_path(element.unit_prototype.resource_path)
	element.assembly_bonus = next_assembly_bonus(role)
	if has_assembly_line() and role != last_completed_role:
		_reset_streak()
	idle_grace_left = 0.0


func _completed(element):
	if not has_assembly_line():
		return
	var role = BastionCatalog.type_from_path(element.unit_prototype.resource_path)
	if role == "Hero":
		_reset_streak()
		return
	completed_streak = mini(3, completed_streak + 1) if role == last_completed_role else 1
	last_completed_role = role
	idle_grace_left = STREAK_GRACE if _queue.is_empty() else 0.0
	set_process(true)


func _advance_idle(delta: float):
	idle_grace_left = maxf(0.0, idle_grace_left - delta)
	if idle_grace_left <= 0.0:
		_reset_streak()
		set_process(not _queue.is_empty())


func _reset_streak():
	last_completed_role = ""
	completed_streak = 0
	idle_grace_left = 0.0


func capture_assembly_state() -> Dictionary:
	return {
		"last_completed_role": last_completed_role,
		"completed_streak": completed_streak,
		"idle_grace_left": idle_grace_left,
	}


func restore_assembly_state(state: Dictionary):
	last_completed_role = state.get("last_completed_role", "")
	completed_streak = state.get("completed_streak", 0)
	idle_grace_left = state.get("idle_grace_left", 0.0)
	set_process(not _queue.is_empty() or idle_grace_left > 0.0)


func restore_departure():
	if _queue.is_empty() or not _unit.is_constructed():
		return
	var element = _queue.front()
	if BastionCatalog.is_fixed_wing(
		BastionCatalog.type_from_path(element.unit_prototype.resource_path)
	):
		return
	if element.time_left > Departure.seconds(element):
		return
	if not is_instance_valid(departure):
		departure = Departure.new()
		departure.name = "ProductionDeparture"
		_unit.add_child(departure)
		departure.prepare(_unit, element)
	exit_blocked = not departure.find_route()
	departure.update_pose(0.0)


func size():
	return _queue.size()


func get_elements():
	return _queue


func blocked_reason(include_exit = true):
	if _queue.is_empty():
		return ""
	if not _unit.is_constructed():
		return "Finish construction to resume this queue."
	var first = _queue.front()
	var role = BastionCatalog.type_from_path(first.unit_prototype.resource_path)
	if BastionCatalog.is_fixed_wing(role) and _unit.first_free_stand() < 0:
		return "Free an aircraft stand to resume this queue."
	var required = Factions.requirement(_unit.player, role)
	if required != "" and not _unit.player.has_completed_structure(required):
		return "Rebuild %s to resume this queue." % Factions.title(_unit.player.faction, required)
	if not Factions.available(_unit.player, role, false, first):
		return (
			"A hero is already alive or in training."
			if role == "Hero"
			else "Research Coordination to resume this queue."
		)
	return (
		"Clear the production exit to release this unit." if include_exit and exit_blocked else ""
	)


func produce(unit_prototype, ignore_limit = false):
	var unit_type = BastionCatalog.type_from_path(unit_prototype.resource_path)
	if not _unit.is_constructed():
		return null
	if not unit_type in BastionCatalog.PRODUCES.get(_unit.type, []):
		return null
	if not Factions.available(_unit.player, unit_type):
		return null
	if _unit.player.population(true) >= BastionCatalog.POPULATION_LIMIT:
		return null
	if not ignore_limit and _queue.size() >= Constants.Match.Units.PRODUCTION_QUEUE_LIMIT:
		return null
	# Every jet needs a stand to park and rearm on; it is promised at queue time.
	if BastionCatalog.is_fixed_wing(unit_type) and _unit.stands_for_production() <= 0:
		return null
	var production_cost = Factions.cost(_unit.player, unit_type).duplicate()
	if not _unit.player.has_resources(production_cost):
		MatchSignals.not_enough_resources_for_production.emit(_unit.player)
		return null
	_unit.player.subtract_resources(production_cost)
	var queue_element = ProductionQueueElement.new()
	queue_element.unit_prototype = unit_prototype
	queue_element.paid_cost = production_cost.duplicate()
	queue_element.time_total = Factions.duration(_unit.player, unit_type)
	queue_element.time_left = queue_element.time_total
	_enqueue_element(queue_element)
	MatchSignals.unit_production_started.emit(unit_prototype, _unit)
	return queue_element  # gdlint: ignore = max-returns


func cancel_all():
	for element in _queue.duplicate():
		cancel(element)


func cancel(element):
	if not element in _queue:
		return
	if element == _queue.front():
		_reset_streak()
	var production_cost = element.paid_cost
	_unit.player.add_resources(production_cost)
	_remove_element(element)


func _enqueue_element(element):
	_queue.push_back(element)
	idle_grace_left = 0.0
	set_process(true)
	element_enqueued.emit(element)


func _remove_element(element):
	if is_instance_valid(departure) and departure.job == element:
		departure.queue_free()
		departure = null
		exit_blocked = false
	_queue.erase(element)
	set_process(not _queue.is_empty() or idle_grace_left > 0.0)
	element_removed.emit(element)


func _finalize_parked(former_queue_element):
	_completed(former_queue_element)
	var index = _unit.first_free_stand()
	var produced_unit = former_queue_element.unit_prototype.instantiate()
	# The new aircraft claims this stand as it settles (FixedWingFlight).
	var placement = _unit.stand_transform(index) if index >= 0 else _unit.global_transform
	MatchSignals.setup_and_spawn_unit.emit(produced_unit, placement, _unit.player)
	MatchSignals.unit_production_finished.emit(produced_unit, _unit)
	var rally_point = _unit.find_child("RallyPoint")
	if rally_point != null:
		MatchSignals.navigate_unit_to_rally_point.emit(produced_unit, rally_point)


func _finalize_production(former_queue_element, launch):
	_completed(former_queue_element)
	var produced_unit = former_queue_element.unit_prototype.instantiate()
	var placement = launch.global_transform
	MatchSignals.setup_and_spawn_unit.emit(produced_unit, placement, _unit.player)
	launch.handoff(produced_unit)
	MatchSignals.unit_production_finished.emit(produced_unit, _unit)

	var rally_point = _unit.find_child("RallyPoint")
	if rally_point != null:
		MatchSignals.navigate_unit_to_rally_point.emit(produced_unit, rally_point)
