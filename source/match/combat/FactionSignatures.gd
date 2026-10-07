# gdlint: disable=max-returns
extends Node

const Factions = preload("res://source/match/FactionCatalog.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
var groups = []
var next_id = 1
var error = ""
@onready var player = get_parent()
@onready var game = player.find_parent("Match")


func _physics_process(delta):
	for group in groups:
		group.left = maxf(0, group.left - delta)
		group.members = group.members.filter(func(unit): return is_instance_valid(unit))
	groups = groups.filter(
		func(group):
			return (
				group.left > 0
				or group.members.any(func(unit): return unit.signature.group_id == group.id)
			)
	)


func eligible(unit):
	if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.player != player:
		return false
	if unit.signature == null or unit.hp <= 0 or unit.program == null:
		return false
	if not unit.program.ready_to_run() or not player.coordination_unlocked:
		return false
	var state = unit.signature
	state.damage_factor()
	if state.cooldown > 0 or state.kind != "":
		return false
	if groups.any(func(group): return group.left > 0 and unit in group.members):
		return false
	if player.faction in ["bastion", "frontier"]:
		return true
	if (
		Rules.preparation_for(unit) <= 0
		or unit.weapon_delay() > 0
		or unit.get_node("Movement")._has_destination
	):
		return false
	if unit.get_meta("next_attack_availability_time", 0) > int(game.simulation_time * 1000):
		return false
	return game.battlefield.observed_enemies_near(unit, unit.sight_range).any(
		func(target): return game.battlefield.can_fire(unit, target)
	)


func activate(selection, point = Vector3.ZERO):
	error = ""
	if not player.coordination_unlocked:
		error = "Research Coordination first."
		return 0
	if (
		not point.is_finite()
		or point.x < 0
		or point.z < 0
		or point.x > game.map.size.x
		or point.z > game.map.size.y
	):
		error = "Choose a sector inside the battlefield."
		return 0
	var participants = []
	for unit in selection:
		if unit not in participants and eligible(unit):
			participants.append(unit)
	if player.faction == "bastion":
		participants.sort_custom(
			func(a, b):
				return (
					a.global_position_yless.distance_squared_to(point)
					< b.global_position_yless.distance_squared_to(point)
				)
		)
	participants = participants.slice(0, 6)
	if participants.is_empty():
		error = (
			"No ready chipped ground combatants."
			if player.faction in ["bastion", "frontier"]
			else "No ready precision shot with a visible target."
		)
		return 0
	var group = {
		"id": next_id, "left": Factions.signature_cooldown(player.faction), "members": participants
	}
	next_id += 1
	groups.append(group)
	for unit in participants:
		unit.signature.activate(group.id, point)
	return participants.size()


func capture(reference):
	var saved = []
	for group in groups:
		var members = []
		for unit in group.members:
			var id = reference.call(unit)
			if id != "":
				members.append(id)
		saved.append({"id": group.id, "left": group.left, "members": members})
	return {"next_id": next_id, "groups": saved}


func restore(state, entities):
	next_id = state.next_id
	groups.clear()
	for saved in state.groups:
		var members = saved.members.map(func(id): return entities[id])
		groups.append({"id": saved.id, "left": saved.left, "members": members})
