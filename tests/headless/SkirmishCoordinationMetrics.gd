extends RefCounted

const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")

var samples = 0
var peak_groups = 0
var violations = {}


func sample(game, player):
	samples += 1
	peak_groups = maxi(peak_groups, player._army_groups.size())
	var issues = inspect(player, game.get_tree().get_nodes_in_group("units"))
	for issue in issues:
		violations[issue] = violations.get(issue, 0) + 1


static func inspect(player, units):
	var issues = []
	var membership = {}
	if player._army_groups.size() > player.difficulty + 1:
		issues.append("group_budget")
	for group in player._army_groups:
		for unit in group.members:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
				continue
			var id = unit.get_instance_id()
			if membership.has(id):
				issues.append("duplicate_member")
			membership[id] = group
			if unit.player != player:
				issues.append("foreign_member")
	for unit in units:
		if unit.player != player or unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		if not unit.action is AttackMove:
			continue
		var group = membership.get(unit.get_instance_id(), {})
		if group.is_empty():
			issues.append("unassigned_attack_order")
			continue
		# A field team covers deposits within 12 m and stands 5 m toward home.
		# Other teams have at most 2 m of formation offset / retained-order slack.
		var tolerance = 19.0 if group.kind == "guard" else 5.0
		if unit.action.destination.distance_to(group.point) > tolerance:
			issues.append("detached_attack_order")
	return issues


func summary():
	return {"samples": samples, "peak_groups": peak_groups, "violations": violations}


static func tasks(game, player):
	var result = []
	for group in player._army_groups:
		var roles = {}
		for unit in group.members:
			if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0:
				roles[unit.type] = roles.get(unit.type, 0) + 1
		result.append(
			{
				"kind": group.kind,
				"point": [group.point.x, group.point.z],
				"roles": roles,
				"age": snappedf(game.simulation_time - group.started, 0.1),
				"retiring": group.retiring
			}
		)
	return result
