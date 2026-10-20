extends Node

const Attack = preload("res://source/match/units/actions/AutoAttacking.gd")
const Waiting = preload("res://source/match/units/actions/WaitingForTargets.gd")
const RESPONSE_RADIUS = 10.0
const PURSUIT_RADIUS = 16.0
@onready var game = get_parent()


func _ready():
	MatchSignals.unit_weapon_hit.connect(_on_hit)


func _on_hit(victim, attacker):
	if game.restoring or ("finished" in game and game.finished):
		return
	if not is_instance_valid(victim) or not is_instance_valid(attacker):
		return
	# A round whose shooter was destroyed reports its frozen Shot record.
	if not attacker is Node3D:
		return
	if (
		victim.player == attacker.player
		or not game.battlefield.is_observed(victim.player, attacker)
	):
		return
	var origin = victim.global_position_yless
	var radius = RESPONSE_RADIUS + victim.radius
	for unit in game.battlefield.nearby_units(origin, radius, victim.player):
		if not _available(unit, attacker):
			continue
		var response = Attack.new(attacker)
		response._defense_origin = origin
		response._defense_radius = PURSUIT_RADIUS + victim.radius
		unit.action = response


func _available(unit, attacker):
	if not Attack.is_applicable(unit, attacker) or unit.movement_speed <= 0:
		return false
	if "stance" in unit and unit.stance in [unit.Stance.HOLD_FIRE, unit.Stance.HOLD_POSITION]:
		return false
	if unit.has_meta("garrison_host"):
		return false
	if unit.manual_orders != null and unit.manual_orders._engaged:
		return false
	if unit.program != null and unit.program.mode in ["Ready", "Running", "Waiting", "Blocked"]:
		return false
	return unit.action == null or (unit.action is Waiting and unit.action.is_idle())
