extends Node3D

var restoring = false
var target_unit = null
var _flight_left = 0.0
var _resolved = false
@onready var _unit = get_parent()


func _ready():
	if restoring:
		return
	if not is_instance_valid(target_unit):
		queue_free()
		return
	var visuals = _unit.get_node_or_null("BastionVisuals")
	if visuals != null:
		visuals.fire_recoil()
	var marker = _unit.get_node_or_null("ProjectileOrigin")
	var origin = marker.global_position if marker != null else _unit.global_position + Vector3.UP
	var point = target_unit.global_position + Vector3.UP * 0.5
	if _unit.has_meta("garrison_host"):
		origin = _unit.get_meta("garrison_host").firing_origin(point)
	var rail = _unit.type == "AdvancedTank"
	_flight_left = 0.0 if rail else clampf(origin.distance_to(point) / 38.0, 0.06, 0.28)
	_unit._match.combat_effects.shot(
		_unit, origin, point, 0.16 if rail else _flight_left, false, target_unit
	)
	if rail:
		_hit()


func _physics_process(delta):
	_flight_left -= delta
	if _flight_left <= 0:
		_hit()


func _hit():
	if _resolved:
		return
	_resolved = true
	if is_instance_valid(target_unit) and not target_unit.is_queued_for_deletion():
		if _unit._match.battlefield.has_line_of_fire(_unit, target_unit):
			target_unit.receive_weapon_hit(_unit)
	queue_free()
