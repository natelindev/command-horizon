extends "res://source/match/units/actions/Action.gd"

const Shooting = preload("res://source/match/units/actions/AttackingWhileInRange.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const Phase = preload("res://source/match/utils/UpdatePhase.gd")
const REFRESH_INTERVAL = .15
var force_attack = false
var _defense_origin = Vector3.ZERO
var _defense_radius = 0.0
var _target_unit = null
var _shot = null
var _elapsed = 0.0
var _last_known_position = Vector3.INF
var _lost_contact = false
var _blocked_elapsed = 0.0
var _progress_position = Vector3.INF
@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


static func is_applicable(source_unit, target_unit):
	return Rules.can_target(source_unit, target_unit)


func _init(target_unit, forced = false):
	_target_unit = target_unit
	force_attack = forced


func _ready():
	if restoring:
		return
	# Group orders still respond immediately. Spread their later perception
	# checks within the existing interval instead of revisiting the whole army
	# on one physics tick. Restored actions retain their saved phase.
	_elapsed = REFRESH_INTERVAL - Phase.first_delay(_unit, REFRESH_INTERVAL)
	_refresh()


func _physics_process(delta):
	_elapsed += delta
	if _elapsed >= REFRESH_INTERVAL:
		_elapsed = 0.0
		_refresh()


func _refresh():
	var field = _unit._match.battlefield
	if _defense_radius > 0:
		var outside = _unit.global_position_yless.distance_to(_defense_origin) > _defense_radius
		if is_instance_valid(_target_unit) and field.is_observed(_unit.player, _target_unit):
			outside = (
				outside
				or _target_unit.global_position_yless.distance_to(_defense_origin) > _defense_radius
			)
		# Defensive assistance never pursues an attacker into unexplored terrain.
		if (
			outside
			or not is_instance_valid(_target_unit)
			or not field.is_observed(_unit.player, _target_unit)
		):
			queue_free()
			return
	if _lost_contact:
		_follow_last_known_position()
		return
	if not is_instance_valid(_target_unit) or not Rules.can_target(_unit, _target_unit):
		queue_free()
		return
	if not field.is_observed(_unit.player, _target_unit):
		_lost_contact = true
		_target_unit = null
		if is_instance_valid(_shot):
			_shot.queue_free()
		_follow_last_known_position()
		return
	_last_known_position = _target_unit.global_position
	if is_instance_valid(_shot) and not _shot.is_queued_for_deletion():
		return
	if field.can_fire(_unit, _target_unit):
		if _movement != null:
			_movement.stop()
		_shot = Shooting.new(_target_unit)
		add_child(_shot)
		_unit.action_updated.emit()
	elif _movement != null:
		# An allied spotter can reveal a target behind a wall, but cannot grant a shot
		# through it. Navigate around it until a firing lane is available.
		if (
			_unit.global_position_yless.distance_to(_target_unit.global_position_yless)
			> _unit.radius + _target_unit.radius + 0.3
		):
			_movement.move(_target_unit.global_position)
		else:
			_movement.stop()


func _exit_tree():
	if is_instance_valid(_movement):
		_movement.stop()


func _follow_last_known_position():
	if _movement == null or not _last_known_position.is_finite():
		queue_free()
		return
	if _unit.global_position_yless.distance_to(_last_known_position * Vector3(1, 0, 1)) < 0.6:
		queue_free()
		return
	if (
		_progress_position.is_finite()
		and _unit.global_position.distance_to(_progress_position) < 0.15
	):
		_blocked_elapsed += 0.15
	else:
		_progress_position = _unit.global_position
		_blocked_elapsed = 0.0
	if _blocked_elapsed >= 5.0:
		queue_free()
		return
	_movement.move(_last_known_position)
