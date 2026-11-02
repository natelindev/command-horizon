extends Node

const Rules = preload("res://source/match/economy/SalvageRules.gd")
const ROLES = Rules.ROLES
const LIFETIME = Rules.LIFETIME
const LIMIT = Rules.LIMIT
var pending = []
@onready var game = get_parent()


func _ready():
	MatchSignals.unit_destroying.connect(_destroyed)


func _destroyed(unit):
	if game.restoring or not game.settings.skirmish or unit.type not in ROLES:
		return
	if not game.settings.players.any(func(side): return side.faction == "frontier"):
		return
	if unit.find_parent("Match") != game:
		return
	var amount = Rules.amount(unit.player.faction, unit.type)
	if amount <= 0:
		return
	pending.append(
		{
			"role": unit.type,
			"faction": unit.player.faction,
			"amount": amount,
			"position":
			game.map.ground_point(Vector2(unit.global_position.x, unit.global_position.z))
		}
	)
	flush.call_deferred()


func flush():
	# A paused snapshot calls this too: death and its finite wreck are one save boundary.
	if pending.is_empty() or not is_instance_valid(game):
		return
	var deposits = game.map.get_node("Resources")
	for entry in pending:
		var existing = get_tree().get_nodes_in_group("salvage_wrecks").filter(
			func(node): return not node.is_queued_for_deletion()
		)
		if existing.size() >= LIMIT:
			existing.sort_custom(func(a, b): return a.salvage_left < b.salvage_left)
			existing[0].queue_free()
		var wreck = load("res://source/match/units/non-player/Wreck.tscn").instantiate()
		wreck.wreck_role = entry.role
		wreck.wreck_faction = entry.faction
		wreck.salvage_left = LIFETIME
		wreck.resource_a = entry.amount
		wreck.position = entry.position
		deposits.add_child(wreck)
	pending.clear()
