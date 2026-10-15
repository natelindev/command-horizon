extends "res://source/match/Map.gd"

const ResourceA = preload("res://source/match/units/non-player/ResourceA.tscn")
const ResourceB = preload("res://source/match/units/non-player/ResourceB.tscn")
const Cliff = preload("res://assets/models/bastion/demo/CliffCluster.glb")
const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")


func _ready():
	# Deterministic paired resource fields and a contested central expansion.
	for anchor in [Vector2(9, 26), Vector2(54, 38), Vector2(30, 17), Vector2(34, 48)]:
		for offset in [
			Vector2(-1.7, 0),
			Vector2(0, 1.5),
			Vector2(1.7, 0),
			Vector2(-1.5, -2.5),
			Vector2(1.5, -2.5)
		]:
			var deposit = ResourceA.instantiate()
			deposit.position = Vector3(anchor.x + offset.x, 0, anchor.y + offset.y)
			$Resources.add_child(deposit)
		for extra in 2:
			var electronics = ResourceB.instantiate()
			electronics.position = Vector3(anchor.x + 4.0, 0, anchor.y)
			electronics.position += Vector3(0, 0, 3) * extra
			$Resources.add_child(electronics)
	for position_2d in [
		Vector2(27, 30),
		Vector2(37, 35),
		Vector2(6, 43),
		Vector2(55, 20),
		Vector2(32, 5),
		Vector2(31, 60)
	]:
		var rock = Node3D.new()
		rock.name = "SandstoneOutcrop"
		rock.position = Vector3(position_2d.x, 0, position_2d.y)
		var geometry = Cliff.instantiate()
		rock.add_child(geometry)
		var obstacle = Obstacle.instantiate()
		obstacle.radius = 3.3
		obstacle.vertices = PackedVector3Array(
			[Vector3(-2.5, 0, -2), Vector3(2.5, 0, -2), Vector3(2.5, 0, 2), Vector3(-2.5, 0, 2)]
		)
		obstacle.affect_navigation_mesh = true
		obstacle.path_height_offset = 0.6
		rock.add_child(obstacle)
		$Decorations.add_child(rock)
