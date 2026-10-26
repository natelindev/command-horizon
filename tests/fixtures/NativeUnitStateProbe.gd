extends "res://source/match/units/Unit.gd"

var interactive := true
var invulnerable := false
var allow_damage := true
var forced_only := false
var domain_override := 1


class ProbeObstacle:
	extends NavigationObstacle3D
	var domain := 1


func _init():
	hp = 100.0
	hp_max = 100.0
	attack_damage = 5.0
	attack_interval = 1.0
	attack_range = 8.0
	attack_domains = [1, 2]
	sight_range = 16.0
	var obstacle := ProbeObstacle.new()
	obstacle.name = "MovementObstacle"
	add_child(obstacle)
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	process_mode = Node.PROCESS_MODE_DISABLED


func _ready():
	_native_state = load("res://source/match/NativeUnitState.gd").bind(
		self, _match.unit_state_store
	)


func combat_domain():
	return domain_override


func can_take_damage():
	return allow_damage


func force_attack_only():
	return forced_only
