extends "res://source/match/Map.gd"

const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")


func _ready():
	for anchor in [Vector2(9, 28), Vector2(26, 13), Vector2(27, 47)]:
		for offset in [-2.0, 0.0, 2.0]:
			var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			deposit.position = Vector3(anchor.x + offset, 0, anchor.y)
			$Resources.add_child(deposit)
		var electronics = load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
		electronics.position = Vector3(anchor.x + 5, 0, anchor.y + 1)
		$Resources.add_child(electronics)
	# Two broad approaches around the sandstone ridge; the relay is beyond base defenses.
	for point in [
		Vector3(31, 0, 30),
		Vector3(34, 0, 33),
		Vector3(53, 0, 39),
		Vector3(55, 0, 42),
		Vector3(11, 0, 47),
		Vector3(66, 0, 17)
	]:
		var rock = Node3D.new()
		rock.position = point
		rock.add_child(load("res://assets/models/bastion/demo/CliffCluster.glb").instantiate())
		var obstacle = Obstacle.instantiate()
		obstacle.radius = 3.0
		obstacle.affect_navigation_mesh = true
		obstacle.path_height_offset = 0.6
		rock.add_child(obstacle)
		$Decorations.add_child(rock)
	for row in range(7):
		var paver = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(4.5, 0.05, 3.0)
		paver.mesh = mesh
		paver.position = Vector3(38 + row * 4.0, 0.025, 40)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("817c68")
		material.roughness = 1
		paver.material_override = material
		$Decorations.add_child(paver)
	var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
	relay.name = "Relay"
	relay.position = Vector3(42, 0, 40)
	add_child(relay)
