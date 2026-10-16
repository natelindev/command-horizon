extends "res://source/match/Map.gd"

const ResourceA = preload("res://source/match/units/non-player/ResourceA.tscn")
const ResourceB = preload("res://source/match/units/non-player/ResourceB.tscn")
const Cliff = preload("res://assets/models/bastion/demo/CliffCluster.glb")
const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")

# The opposition half is the bastion half turned half a circle around the
# center, so both starts see the same fields, outcrops and routes.
const CENTER = Vector2(32, 32)
# Bastion main and the contested central expansion beside it.
const FIELDS = [Vector2(9, 26), Vector2(30, 17)]
const OUTCROPS = [Vector2(27, 30), Vector2(6, 43), Vector2(32, 5)]
const OUTCROP_RADIUS = 3.3
var points_of_interest = []


func _ready():
	for anchor in FIELDS:
		for side in [1, -1]:
			_field(_rotated(anchor, side), side)
	for point in OUTCROPS:
		for side in [1, -1]:
			_outcrop(_rotated(point, side), side)


func _rotated(point, side):
	return point if side == 1 else CENTER * 2 - point


func _field(anchor, side):
	for offset in [
		Vector2(-1.7, 0), Vector2(0, 1.5), Vector2(1.7, 0), Vector2(-1.5, -2.5), Vector2(1.5, -2.5)
	]:
		var deposit = ResourceA.instantiate()
		deposit.position = Vector3(anchor.x + offset.x * side, 0, anchor.y + offset.y * side)
		$Resources.add_child(deposit)
	for extra in 2:
		var electronics = ResourceB.instantiate()
		electronics.position = Vector3(anchor.x + 4.0 * side, 0, anchor.y + 3 * extra * side)
		$Resources.add_child(electronics)


func _outcrop(point, side):
	var rock = Node3D.new()
	rock.name = "SandstoneOutcrop"
	rock.position = Vector3(point.x, 0, point.y)
	rock.rotation.y = 0.0 if side == 1 else PI
	var geometry = Cliff.instantiate()
	rock.add_child(geometry)
	var obstacle = Obstacle.instantiate()
	obstacle.radius = OUTCROP_RADIUS
	obstacle.vertices = PackedVector3Array(
		[Vector3(-2.5, 0, -2), Vector3(2.5, 0, -2), Vector3(2.5, 0, 2), Vector3(-2.5, 0, 2)]
	)
	obstacle.affect_navigation_mesh = true
	obstacle.path_height_offset = 0.6
	rock.add_child(obstacle)
	$Decorations.add_child(rock)
