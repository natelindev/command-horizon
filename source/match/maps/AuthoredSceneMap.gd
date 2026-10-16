extends "res://source/match/Map.gd"

# Shared overview for the authored arena maps whose deposits live in the scene.
const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
var points_of_interest = []


func overview():
	var deposits = get_node("Resources").find_children("*", "", true, false).filter(
		func(node): return "resource_a" in node or "resource_b" in node
	)
	return {
		"ridges": [],
		"radius": 0,
		"fields": deposits.map(func(node): return Vector2(node.position.x, node.position.z)),
		"relays": [],
		"roads": [],
		"points_of_interest": Sites.definitions(scene_file_path)
	}
