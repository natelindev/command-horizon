extends Node

signal element_enqueued(element)
signal element_removed(element)

const FactoryProgram = preload("res://source/match/programs/FactoryProgram.gd")

const Factions = preload("res://source/match/FactionCatalog.gd")

const Departure = preload("res://source/match/effects/ProductionDeparture.gd")
const BastionCatalog = preload("res://source/match/BastionCatalog.gd")


class ProductionQueueElement:
	extends Resource
	var unit_prototype = null
	var time_total = null
	var fitted_chip = false
	var paid_cost = {}
	var program_snapshot = {}
	var departure_endpoint = null
	var time_left = null:
		set(value):
			time_left = value
			emit_changed()

	func progress():
		return (time_total - time_left) / time_total


var fit_chips = false
var program_pin = {}
var program_library_path = "user://program-library.json"
var departure = null
var exit_blocked = false
var _queue = []

@onready var _unit = get_parent()


func _ready():
	set_process(false)


func _process(delta):
	if _queue.is_empty() or not _unit.is_constructed():
		return
	delta *= _unit.player.production_factor()
	while _queue.size() > 0 and delta > 0.0:
		var element = _queue.front()
		if not blocked_reason(false).is_empty():
			return
		# The exit animation consumes the final part of the paid production time.
		var departure_seconds = Departure.seconds(element)
		if element.time_left > departure_seconds:
			var assembly = minf(delta, element.time_left - departure_seconds)
			element.time_left -= assembly
			delta -= assembly
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


func restore_departure():
	if _queue.is_empty() or not _unit.is_constructed():
		return
	var element = _queue.front()
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
	var required = Factions.requirement(_unit.player, role)
	if first.fitted_chip and not _unit.player.has_completed_structure("CommandLab"):
		required = "CommandLab"
	if required != "" and not _unit.player.has_completed_structure(required):
		return "Rebuild %s to resume this queue." % Factions.title(_unit.player.faction, required)
	if not Factions.available(_unit.player, role, false, first):
		if role == "Hero":
			return "A hero is already alive or in training."
		return "Research Coordination to resume this queue."
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
	var production_cost = Factions.cost(_unit.player, unit_type).duplicate()
	var fitted_chip = fit_chips and unit_type == "Tank"
	if fitted_chip:
		if (
			not _unit.player.basic_programs_unlocked()
			or not _unit.player.has_completed_structure("CommandLab")
		):
			return null
		production_cost.resource_b += Factions.chip_cost(_unit.player.faction)
	if not _unit.player.has_resources(production_cost):
		MatchSignals.not_enough_resources_for_production.emit(_unit.player)
		return null
	_unit.player.subtract_resources(production_cost)
	var queue_element = ProductionQueueElement.new()
	queue_element.unit_prototype = unit_prototype
	queue_element.fitted_chip = fitted_chip
	queue_element.paid_cost = production_cost.duplicate()
	if _unit.player.get_meta("skirmish", false):
		queue_element.program_snapshot = FactoryProgram.snapshot(
			program_pin, unit_type, program_library_path
		)
	queue_element.time_total = (
		Factions.duration(_unit.player, unit_type)
		+ (Factions.chip_seconds(_unit.player.faction) if fitted_chip else 0.0)
	)
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
	var production_cost = element.paid_cost
	_unit.player.add_resources(production_cost)
	_remove_element(element)


func _enqueue_element(element):
	_queue.push_back(element)
	set_process(true)
	element_enqueued.emit(element)


func _remove_element(element):
	if is_instance_valid(departure) and departure.job == element:
		departure.queue_free()
		departure = null
		exit_blocked = false
	_queue.erase(element)
	set_process(not _queue.is_empty())
	element_removed.emit(element)


func _finalize_production(former_queue_element, launch):
	var produced_unit = former_queue_element.unit_prototype.instantiate()
	if former_queue_element.fitted_chip:
		produced_unit.set_meta("chip_installed", true)
	var placement = launch.global_transform
	MatchSignals.setup_and_spawn_unit.emit(produced_unit, placement, _unit.player)
	launch.handoff(produced_unit)
	FactoryProgram.apply_to(produced_unit, former_queue_element.program_snapshot)
	MatchSignals.unit_production_finished.emit(produced_unit, _unit)

	var rally_point = _unit.find_child("RallyPoint")
	if rally_point != null:
		MatchSignals.navigate_unit_to_rally_point.emit(produced_unit, rally_point)
