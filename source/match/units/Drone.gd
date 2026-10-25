extends "res://source/match/units/Unit.gd"

# Helix fields an unarmed EW scout. Other factions keep the loitering munition.
# The loitering munition scouts while hovering and holds fire by
# default; an attack order, or an engaging stance chosen by the player, sends it
# into a one-way dive (DroneDive). Autonomous dives pick machines and structures,
# never infantry.

const Catalog = preload("res://source/match/BastionCatalog.gd")
const DroneDive = preload("res://source/match/units/actions/DroneDive.gd")
const SCAN_INTERVAL = 0.5

var _scan_left = SCAN_INTERVAL


func _init():
	stance = Stance.HOLD_FIRE


func ability_definitions() -> Array:
	if player.faction != "helix":
		return []
	return [
		{
			"id": "drone_chaff",
			"name": "Guidance Chaff",
			"key": "E",
			"description":
			(
				"Interrupt hostile missile guidance around allied units within 10 m for 8 seconds. "
				+ "Requires a Signal lab. Missiles keep flying."
			),
			"target_type": "instant",
			"cooldown": 30.0,
			"duration": 8.0,
			"radius": 10.0,
		}
	]


func armed() -> bool:
	return player.faction != "helix"


func _adapt_action(action_node):
	if action_node == null:
		return null
	var kind = action_node.get_script().resource_path.get_file().get_basename()
	if player.faction == "helix" and kind == "AttackMoving":
		var point = action_node.destination
		action_node.free()
		return load("res://source/match/units/actions/Moving.gd").new(point)
	if (
		player.faction == "helix"
		and kind in ["DroneDive", "AutoAttacking", "AttackingWhileInRange", "AirStrike"]
	):
		action_node.free()
		return null
	if kind in ["AutoAttacking", "AttackingWhileInRange"]:
		var target = action_node._target_unit
		var forced = action_node.get("force_attack") == true
		action_node.free()
		return DroneDive.new(target, forced)
	return action_node


func _physics_process(delta):
	super(delta)
	if (
		_match == null
		or player.faction == "helix"
		or stance not in [Stance.AGGRESSIVE, Stance.DEFENSIVE]
	):
		return
	if action != null and not action.has_method("is_idle"):
		return
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = SCAN_INTERVAL
	var target = _dive_target()
	if target != null:
		action = DroneDive.new(target)


func _dive_target():
	var best = null
	var best_distance = INF
	var rules = _rules()
	for unit in _match.battlefield.nearby_units(global_position * Vector3(1, 0, 1), sight_range):
		if (
			unit.player == player
			or Catalog.is_infantry(unit.type)
			or not rules.can_target(self, unit)
			or not _match.battlefield.is_observed(player, unit)
		):
			continue
		var distance = global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return best
