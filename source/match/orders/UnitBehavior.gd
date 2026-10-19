extends RefCounted

# Five fixed choices. Stances persist independently of queued move/follow orders.
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const CHOICES = ["attack", "defensive", "follow", "guard", "hold_fire"]
const TITLES = ["Auto-engage", "Defensive", "Follow", "Guard", "Hold Fire"]


static func set_stance(unit, behavior):
	if (
		not is_instance_valid(unit)
		or unit.is_queued_for_deletion()
		or behavior not in ["attack", "defensive", "hold_fire"]
	):
		return false
	# Clearing the old firing action makes Hold Fire immediate, including a
	# prepared weapon. Submitted manual orders remain explicit player authority.
	unit.issue_manual_order(null)
	unit.stance = {
		"attack": unit.Stance.AGGRESSIVE,
		"defensive": unit.Stance.DEFENSIVE,
		"hold_fire": unit.Stance.HOLD_FIRE,
	}[behavior]
	return true


static func guard(unit, point, append = false):
	if not point is Vector3 or not point.is_finite() or unit.manual_orders == null:
		return false
	var accepted = unit.manual_orders.submit(
		Orders.point_order("move", point), append, true, "guard"
	)
	if accepted:
		unit.stance = unit.Stance.HOLD_POSITION
	return accepted


static func follow(unit, target, append = false):
	if (
		not is_instance_valid(target)
		or target.is_queued_for_deletion()
		or not target.is_in_group("units")
		or target == unit
		or target.player != unit.player
		or target.hp <= 0
	):
		return false
	var accepted = unit.manual_orders.submit(Orders.target_order("follow", target), append)
	if accepted:
		unit.stance = unit.Stance.DEFENSIVE
	return accepted


static func current(unit):
	if unit.manual_orders != null and unit.manual_orders.current.get("kind") == "follow":
		return "follow"
	return ["attack", "defensive", "guard", "hold_fire"][int(unit.stance)]
