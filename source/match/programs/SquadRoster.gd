extends Node

const Squad = preload("res://source/match/programs/ProgramSquad.gd")
var revision = 0
var error = ""
var _next_id = 1
@onready var player = get_parent()


func squads():
	return get_children().filter(func(squad): return not squad.is_queued_for_deletion())


func create(title, units):
	if not _validate(units, []):
		return null
	var squad = Squad.new()
	squad.id = _next_id
	_next_id += 1
	squad.title = _title(title, squad.id)
	add_child(squad)
	assign(squad, units)
	return squad


func assign(squad, units):
	if not _owns(squad) or not _validate(units, squad.active_members()):
		return false
	for unit in units:
		if unit.program_squad == squad:
			continue
		remove(unit)
		squad.members.append(unit)
		unit.program_squad = squad
		if not unit.tree_exiting.is_connected(_on_member_exit.bind(unit)):
			unit.tree_exiting.connect(_on_member_exit.bind(unit))
	revision += 1
	return true


func remove(unit):
	var squad = unit.program_squad
	if not _owns(squad):
		return
	squad.release(unit)
	squad.members.erase(unit)
	unit.program_squad = null
	if unit.tree_exiting.is_connected(_on_member_exit.bind(unit)):
		unit.tree_exiting.disconnect(_on_member_exit.bind(unit))
	if squad.members.is_empty():
		squad.queue_free()
	revision += 1


func disband(squad):
	if not _owns(squad):
		return
	for unit in squad.active_members():
		remove(unit)
	squad.queue_free()
	revision += 1


func rename(squad, title):
	if not _owns(squad):
		return false
	squad.title = _title(title, squad.id)
	revision += 1
	return true


func _title(value, id):
	var cleaned = value.strip_edges().replace("\n", " ").replace("\t", " ").left(32)
	return "Squad %d" % id if cleaned.is_empty() else cleaned


func _owns(squad):
	return (
		is_instance_valid(squad)
		and not squad.is_queued_for_deletion()
		and squad.get_parent() == self
	)


func _validate(units, existing):
	error = ""
	if not player.coordination_unlocked:
		error = "Research Coordination at your lab to create program squads."
		return false
	if units.is_empty():
		error = "Select at least one mobile unit."
		return false
	var combined = existing.duplicate()
	for unit in units:
		if (
			not is_instance_valid(unit)
			or unit.is_queued_for_deletion()
			or unit.player != player
			or unit.movement_speed <= 0
		):
			error = "Squads can contain only your mobile units."
			return false
		if unit not in combined:
			combined.append(unit)
	if combined.size() > Squad.MEMBER_LIMIT:
		error = "Squad limit: 24 members. Choose fewer units."
		return false
	return true


func _on_member_exit(unit):
	remove(unit)
