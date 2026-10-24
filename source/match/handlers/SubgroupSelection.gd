extends RefCounted

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Bindings = preload("res://source/input/KeyBindings.gd")

var _pool = []
var _role = ""
var _cycling = false


func changed(_unit = null):
	if not _cycling:
		_pool.clear()
		_role = ""


func cycle(tree):
	var members = _live_pool()
	if members.is_empty():
		members = tree.get_nodes_in_group("selected_units").filter(_eligible)
		_pool = members.map(func(unit): return weakref(unit))
	var roles = []
	for unit in members:
		if unit.type not in roles:
			roles.append(unit.type)
	var order = Catalog.NAMES.keys() + Catalog.MISSION_NAMES.keys()
	roles.sort_custom(func(a, b): return order.find(a) < order.find(b))
	if roles.size() < 2 and _role.is_empty():
		return ""
	var index = roles.find(_role) + 1
	_role = roles[index] if index < roles.size() else ""
	var chosen = members.filter(func(unit): return _role.is_empty() or unit.type == _role)
	if chosen.is_empty():
		changed()
		return ""
	_cycling = true
	# Retain the complete pool while issuing commands only to the visible subgroup.
	# Ordinary click/box/roster/group selection resets this temporary cycle.
	for unit in tree.get_nodes_in_group("selected_units"):
		if unit not in chosen:
			unit.get_node("Selection").deselect()
	for unit in chosen:
		unit.get_node("Selection").select()
	_cycling = false
	var title = (
		tr("All selected units")
		if _role.is_empty()
		else Factions.title(chosen[0].player.faction, _role)
	)
	return (
		tr("%s · %d / %d units · %s cycles classes")
		% [title, chosen.size(), members.size(), Bindings.label("cycle_subgroup")]
	)


func _live_pool():
	return _pool.map(func(reference): return reference.get_ref()).filter(_eligible)


func _eligible(unit):
	return (
		is_instance_valid(unit)
		and not unit.is_queued_for_deletion()
		and unit.is_in_group("controlled_units")
		and unit.hp > 0
	)
