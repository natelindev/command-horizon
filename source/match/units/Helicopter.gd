extends "res://source/match/units/Unit.gd"

# Attack helicopter: hovers and holds position against ground targets with a
# rocket load that reloads on cooldown in the field.
# Rotors and airframe motion are animated by BastionVisuals.

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const Recovering = preload("res://source/match/units/actions/RecoveringAtService.gd")
const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")
const ROCKET_CAPACITY = 12
const REARM_INTERVAL = 0.5
const RELOAD_COOLDOWN = 5.0
const OUT_OF_COMBAT_RELOAD_DELAY = 4.0

var rockets = ROCKET_CAPACITY
# Scenario patrols without an airfield fly with unlimited rockets.
var unlimited_stores = false
var resume_point = Vector3.INF
var reload_cooldown_left = 0.0
var _rearm_left = REARM_INTERVAL
var _time_since_last_shot = 0.0


func _ready():
	await super()
	action_changed.connect(_on_action_changed)
	if action == null:
		action = WaitingForTargets.new()


func _on_action_changed(new_action):
	if new_action != null or not is_inside_tree() or is_queued_for_deletion():
		return
	if resume_point.is_finite() and armed():
		var point = resume_point
		resume_point = Vector3.INF
		action = AttackMoving.new(point)
		return
	action = WaitingForTargets.new()


func armed():
	return true


func weapon_delay():
	return reload_cooldown_left


func weapon_status():
	if reload_cooldown_left > 0.0:
		return "Reloading · %.1f s" % reload_cooldown_left
	return "Rockets · %d/%d" % [rockets, ROCKET_CAPACITY]


func expend_round():
	_time_since_last_shot = 0.0
	if not unlimited_stores:
		rockets = maxi(0, rockets - 1)
		if rockets == 0:
			reload_cooldown_left = RELOAD_COOLDOWN


func needs_rearm():
	return false


func _physics_process(delta):
	super(delta)
	if _match == null:
		return
	_time_since_last_shot += delta
	if reload_cooldown_left > 0.0:
		reload_cooldown_left = maxf(0.0, reload_cooldown_left - delta)
		if reload_cooldown_left == 0.0:
			rockets = ROCKET_CAPACITY
			_rearm_left = REARM_INTERVAL
	elif (
		not unlimited_stores
		and rockets < ROCKET_CAPACITY
		and _time_since_last_shot >= OUT_OF_COMBAT_RELOAD_DELAY
	):
		rockets = ROCKET_CAPACITY
		_rearm_left = REARM_INTERVAL
	if not unlimited_stores and rockets < ROCKET_CAPACITY:
		_rearm_on_pad(delta)


func _rearm_on_pad(delta):
	var field = _home_airfield()
	if field == null or not field.services(self) or not Repairs.stationary(self):
		return
	_rearm_left -= delta
	if _rearm_left <= 0.0:
		_rearm_left = REARM_INTERVAL
		rockets = mini(ROCKET_CAPACITY, rockets + 1)
		if rockets == ROCKET_CAPACITY:
			reload_cooldown_left = 0.0


func _home_airfield():
	var best = null
	var best_distance = INF
	for field in get_tree().get_nodes_in_group("airfields"):
		if field.player != player or field.is_queued_for_deletion() or not field.is_constructed():
			continue
		var distance = field.global_position.distance_to(global_position)
		if distance < best_distance:
			best = field
			best_distance = distance
	return best


func capture_air(_reference):
	return {
		"stores": {"rockets": rockets},
		"rearm_left": _rearm_left,
		"resume_station": resume_point if resume_point.is_finite() else null,
		"unlimited": unlimited_stores,
	}


func restore_air(saved, _entities):
	rockets = clampi(saved.stores.get("rockets", ROCKET_CAPACITY), 0, ROCKET_CAPACITY)
	_rearm_left = saved.rearm_left
	resume_point = saved.resume_station if saved.resume_station != null else Vector3.INF
	unlimited_stores = saved.unlimited
	if rockets == 0:
		reload_cooldown_left = RELOAD_COOLDOWN
