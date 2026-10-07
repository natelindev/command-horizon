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
		speed = 1.0 / load("res://source/match/FactionCatalog.gd").BUILD_TIMES[_target_unit.type]
	_target_unit.construct(delta * speed)
