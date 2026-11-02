extends RefCounted

## One shared speed sample per physics frame, regardless of army size.
var members = []
var _frame = -1
var _limit = -1.0


func _init(units = []):
	for unit in units:
		members.append(weakref(unit))


func invalidate():
	_frame = -1


func speed_limit() -> float:
	var frame = Engine.get_physics_frames()
	if _frame == frame:
		return _limit
	_frame = frame
	_limit = INF
	for reference in members:
		var unit = reference.get_ref()
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		var movement = unit.get_node_or_null("Movement")
		if (
			movement == null
			or movement.cohesion_group != self
			or not unit.manual_orders.cohesion_enabled
		):
			continue
		_limit = minf(_limit, movement.unclamped_speed())
	if not is_finite(_limit):
		_limit = -1.0
	return _limit


func references(reference: Callable) -> Array:
	var result = []
	for member in members:
		var unit = member.get_ref()
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			result.append(reference.call(unit))
	return result
