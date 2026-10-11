extends Node

@onready var _voice = get_parent().get_node("BattleVoice")


func _ready():
	MatchSignals.unit_selected.connect(_on_unit_selected)
	MatchSignals.unit_order_issued.connect(_on_order_issued)


func _on_unit_selected(unit):
	_voice.say_unit(unit, "select")


func _on_order_issued(unit, kind):
	var response = "move"
	if kind in ["attack", "attack_move"]:
		response = "attack"
	elif kind in ["gather", "construct", "repair", "stop"]:
		response = kind
	_voice.say_unit(unit, response)
