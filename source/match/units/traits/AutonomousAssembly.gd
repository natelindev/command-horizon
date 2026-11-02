extends Node

# Any paid construction progress is the beacon's durable activation marker.
# Existing partially assembled Helix saves therefore resume without a schema change.
const BEACON_PROGRESS = 0.000000001
var _harvest_returns = {}
@onready var structure = get_parent()


func _ready():
	structure.constructed.connect(queue_free)


func active() -> bool:
	return structure.is_under_construction() and structure.construction_progress() > 0.0


func remember_harvest(worker):
	if is_instance_valid(worker.action) and worker.action.has_method("get_resource_unit"):
		var deposit = worker.action.get_resource_unit()
		if is_instance_valid(deposit):
			_harvest_returns[worker] = weakref(deposit)


func deploy(worker) -> bool:
	if (
		not is_instance_valid(worker)
		or worker.type != "Worker"
		or worker.is_queued_for_deletion()
		or not worker.can_process()
		or not structure.can_process()
		or worker.player != structure.player
		or worker.hp <= 0
		or structure.hp <= 0
		or structure.is_queued_for_deletion()
		or not structure.is_under_construction()
		or not Utils.Match.Unit.Movement.units_adhere(worker, structure)
	):
		return false
	if not active():
		structure.construct(BEACON_PROGRESS)
	return true


func _process(delta):
	if (
		not active()
		or not structure.can_process()
		or structure.hp <= 0
		or structure.is_queued_for_deletion()
		or not is_finite(delta)
		or delta <= 0.0
	):
		return
	var speed = Constants.Match.Units.STRUCTURE_CONSTRUCTING_SPEED
	if structure.player.get_meta("skirmish", false):
		speed = 1.0 / load("res://source/match/FactionCatalog.gd").BUILD_TIMES[structure.type]
	structure.construct(delta * speed)


func release_worker(worker, construction_action):
	# Deferred out of action _ready: Unit protects its action swap with a lock.
	# A new explicit order issued in the meantime always takes precedence.
	if (
		not is_instance_valid(worker)
		or worker.is_queued_for_deletion()
		or worker.hp <= 0
		or worker.action != construction_action
	):
		return
	var target = null
	if _harvest_returns.has(worker):
		target = _harvest_returns[worker].get_ref()
		_harvest_returns.erase(worker)
	if worker.manual_orders != null and not worker.manual_orders.pending.is_empty():
		worker.action = null
		return
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	if not _valid_deposit(worker, target):
		target = _nearest_deposit(worker)
	if target == null and worker.resource_a + worker.resource_b > 0:
		target = harvest._find_cc_closest_to_unit(worker)
	worker.action = harvest.new(target) if target != null else null


func _valid_deposit(worker, deposit) -> bool:
	return (
		is_instance_valid(deposit)
		and not deposit.is_queued_for_deletion()
		and deposit.has_method("can_harvest")
		and deposit.can_harvest(worker)
		and (
			("resource_a" in deposit and deposit.resource_a > 0)
			or ("resource_b" in deposit and deposit.resource_b > 0)
		)
	)


func _nearest_deposit(worker):
	var best = null
	var distance = INF
	for deposit in get_tree().get_nodes_in_group("resource_units"):
		if not _valid_deposit(worker, deposit):
			continue
		var contact = (
			worker.radius
			+ deposit.radius
			+ Utils.Match.Unit.Movement.adherence_margin(worker, deposit)
		)
		var route = Utils.Match.Unit.Movement.path_distance_to(
			worker, deposit.global_position_yless, contact
		)
		if route < distance:
			best = deposit
			distance = route
	return best
