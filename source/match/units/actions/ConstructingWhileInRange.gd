extends "res://source/match/units/actions/Action.gd"

var _target_unit = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	if restoring:
		return
	_target_unit.tree_exited.connect(queue_free)
	_target_unit.constructed.connect(queue_free)
	_unit.get_node("Sparkling").enable()


func _exit_tree():
	_unit.get_node("Sparkling").disable()


func _process(delta):
	if (
		not Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit)
		or _target_unit.is_constructed()
	):
		queue_free()
		return
	var speed = Constants.Match.Units.STRUCTURE_CONSTRUCTING_SPEED
	if _unit.player.get_meta("skirmish", false):
		if not _has_construction_slot():
			return
		speed = 1.0 / load("res://source/match/FactionCatalog.gd").BUILD_TIMES[_target_unit.type]
	_target_unit.construct(delta * speed)


func _has_construction_slot():
	# Derive one working engineer from live orders. No saved claim can strand
	# a site after its builder leaves, dies, or a paused battle is restored.
	for worker in _unit.player.get_children():
		if (
			worker.is_in_group("units")
			and not worker.is_queued_for_deletion()
			and worker.hp > 0
			and worker.can_process()
			and is_instance_valid(worker.action)
			and worker.action.has_method("is_working_on")
			and worker.action.is_working_on(_target_unit)
			and Utils.Match.Unit.Movement.units_adhere(worker, _target_unit)
		):
			return worker == _unit
	return false
