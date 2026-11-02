extends "res://source/match/units/actions/Action.gd"

const Worker = preload("res://source/match/units/Worker.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")

var _resource_unit = null
var _timer = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _unit_movement_trait = _unit.find_child("Movement")


static func is_applicable(source_unit, target_unit):
	if not is_instance_valid(source_unit) or not is_instance_valid(target_unit):
		return false
	return (
		source_unit is Worker
		and target_unit is ResourceUnit
		and target_unit.can_harvest(source_unit)
		and not source_unit.is_full()
		and Utils.Match.Unit.Movement.units_adhere(source_unit, target_unit)
	)


func _init(resource_unit):
	_resource_unit = resource_unit


func _ready():
	if restoring:
		return
	if not is_instance_valid(_resource_unit):
		queue_free()
		return
	_resource_unit.tree_exited.connect(queue_free)
	_unit_movement_trait.passive_movement_finished.connect(_on_passive_movement_finished)
	_setup_timer()
	_unit.get_node("Sparkling").enable()


func _exit_tree():
	_unit.get_node("Sparkling").disable()


func _setup_timer():
	_timer = Timer.new()
	_timer.timeout.connect(_transfer_single_resource_unit_from_resource_to_worker)
	add_child(_timer)
	_timer.start(_collection_interval())


func _collection_interval() -> float:
	var kind = 1 if "resource_a" in _resource_unit else 2
	var base = (
		Constants.Match.Resources.A.COLLECTING_TIME_S
		if kind == 1
		else Constants.Match.Resources.B.COLLECTING_TIME_S
	)
	if _resource_unit.is_in_group("salvage_wrecks"):
		base = .5
	var profile = _unit.harvesting_profile
	if profile == null:
		profile = load("res://source/match/economy/HarvestingProfile.gd").new(_unit.player.faction)
	var efficiency = (
		get_parent().gathering_efficiency(_resource_unit)
		if get_parent().has_method("gathering_efficiency")
		else 1.0
	)
	var boost = (
		_unit.player.harvesting_factor(_resource_unit)
		if _unit.player.has_method("harvesting_factor")
		else 1.0
	)
	return profile.collection_interval(kind, base) / maxf(.01, efficiency * boost)


func _transfer_single_resource_unit_from_resource_to_worker():
	# Crowd avoidance can keep a stationary worker gently moving indefinitely.
	# Collection depends on contact range, not on perfectly zero avoidance velocity.
	if (
		not _resource_unit.can_harvest(_unit)
		or _unit.is_full()
		or not Utils.Match.Unit.Movement.units_adhere(_unit, _resource_unit)
		or (get_parent().has_method("can_work") and not get_parent().can_work(_resource_unit))
	):
		queue_free()
		return
	if _resource_unit.is_in_group("salvage_wrecks"):
		_resource_unit.dismantle(_unit)
		queue_free()
		return
	if "resource_a" in _resource_unit:
		_resource_unit.resource_a -= 1
		_unit.resource_a += 1
		MatchSignals.resources_mined.emit(_unit, "materials", 1)
	if "resource_b" in _resource_unit:
		_resource_unit.resource_b -= 1
		_unit.resource_b += 1
		MatchSignals.resources_mined.emit(_unit, "electronics", 1)
	if _unit.is_full():
		queue_free()
	else:
		_timer.wait_time = _collection_interval()


func _rotate_unit_towards_resource_unit():
	_unit.global_transform = _unit.global_transform.looking_at(
		Vector3(
			_resource_unit.global_position.x,
			_unit.global_position.y,
			_resource_unit.global_position.z
		),
		Vector3(0, 1, 0)
	)


func _on_passive_movement_finished():
	_rotate_unit_towards_resource_unit()
