# gdlint: disable=max-returns
extends RefCounted

## Every local entry point passes this boundary before it changes live gameplay.
## Offline matches and authoritative command application follow their usual path.
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")


static func session_for(subject):
	var node = subject
	while is_instance_valid(node):
		if node.has_meta("network_session"):
			var session = node.get_meta("network_session")
			return session if is_instance_valid(session) else null
		node = node.get_parent() if node is Node else null
	return null


static func id_for(subject) -> String:
	var session = session_for(subject)
	return session.id_for(subject) if session != null else ""


static func intercept(subject, intent: Dictionary) -> bool:
	var session = session_for(subject)
	if (
		session == null
		or session.applying
		or (
			session.authority
			and (not is_instance_valid(session.game) or not session.game.is_node_ready())
		)
	):
		return false
	session.submit_group_member(intent)
	return true


static func intercept_order(unit, order: Dictionary, append: bool) -> bool:
	var session = session_for(unit)
	if (
		session == null
		or session.applying
		or (
			session.authority
			and (not is_instance_valid(session.game) or not session.game.is_node_ready())
		)
	):
		return false
	var intent = {
		"kind": "order",
		"units": [session.id_for(unit)],
		"order": order.kind,
		"point": Protocol.quantize(order.get("point", unit.global_position)),
		"append": append
	}
	if order.has("target"):
		var target = order.target.get_ref()
		var target_id = session.id_for(target)
		if target_id.is_empty():
			session.notice("This target is not available to the server.")
			return true
		intent.target = target_id
	if order.has("engineering_kind"):
		intent.id = order.engineering_kind
		intent.angle = roundi(rad_to_deg(order.get("angle", 0.0)) * 1000.0)
	if order.has("token"):
		intent.token = order.token
	if order.has("cohort") and order.cohort != null:
		intent.members = order.cohort.references(session.id_for)
	if order.has("waypoints"):
		intent.waypoints = Array(order.waypoints).map(Protocol.quantize)
	session.submit_group_member(intent)
	return true


static func intercept_action(unit, action) -> bool:
	var session = session_for(unit)
	if (
		session == null
		or session.applying
		or (
			session.authority
			and (not is_instance_valid(session.game) or not session.game.is_node_ready())
		)
	):
		return false
	var name = action.get_script().resource_path.get_file().get_basename() if action != null else ""
	var mapping = {
		"Moving": "move",
		"AttackMoving": "attack_move",
		"Patrolling": "patrol",
		"AutoAttacking": "attack",
		"Following": "follow",
		"MovingToUnit": "approach",
		"Garrisoning": "garrison",
		"Repairing": "repair",
		"Constructing": "construct",
		"Scavenging": "scavenge",
		"CollectingResourcesSequentially": "gather",
		"RecoveringAtService": "recover",
		"WaitingForTargets": "hold",
		"AirIdle": "hold"
	}
	var kind = mapping.get(name, "stop")
	var point = unit.global_position
	var target = null
	if action != null:
		for field in ["_target_unit", "_resource_unit", "_target", "_escort"]:
			if field in action and is_instance_valid(action.get(field)):
				target = action.get(field)
				break
		for field in ["_target_position", "destination", "_point"]:
			if field in action and action.get(field) is Vector3:
				point = action.get(field)
	if target != null:
		point = target.global_position
	var order = {"kind": kind, "point": point}
	if target != null:
		order.target = weakref(target)
	intercept_order(unit, order, false)
	if action != null and action.get_parent() == null:
		action.free()
	return true
