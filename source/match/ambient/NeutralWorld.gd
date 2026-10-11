extends Node

const Building = preload("res://source/match/ambient/NeutralBuilding.gd")
# Only authored structures in playable space are interactive; rocks and scenic
# out-of-bounds districts never become military targets.
const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
var buildings = []


func _ready():
	var game = get_parent()
	var obstacles = get_tree().get_nodes_in_group("sight_blockers").filter(
		func(obstacle): return game.map.is_ancestor_of(obstacle.get_parent())
	)
	for asset in Catalog.structures(game.settings.map_path):
		for obstacle in obstacles:
			var body = obstacle.get_parent()
			if body.get_meta("neutral_asset", "") != asset or body.has_node("NeutralBuilding"):
				continue
			if not body.has_node("MovementObstacle"):
				obstacle.name = "MovementObstacle"
			var target = Building.new()
			target.setup(body, "neutral-building-%d" % buildings.size())
			body.add_child(target)
			buildings.append(target)
			break


func capture(reference):
	return buildings.map(func(building): return building.capture(reference))
