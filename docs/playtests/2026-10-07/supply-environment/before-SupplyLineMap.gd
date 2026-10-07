extends "res://source/match/Map.gd"

const POINTS = [Vector3(64, 0, 100), Vector3(100, 0, 40), Vector3(170, 0, 40)]
const NAMES = ["South crossing", "Ridge depot", "Extraction"]
const ENTRIES = [Vector3(64, 0, 120), Vector3(100, 0, 12), Vector3(182, 0, 66)]


func _ready():
	var route = [Vector3(18, 0, 100)] + POINTS
	for index in range(route.size() - 1):
		var a = route[index]
		var b = route[index + 1]
		var road = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(10, 0.04, a.distance_to(b))
		road.mesh = mesh
		road.position = (a + b) * 0.5 + Vector3.UP * 0.025
		road.rotation.y = atan2(b.x - a.x, b.z - a.z)
		road.material_override = _material(Color("575855"))
		$Geometry.add_child(road)
	for point in POINTS:
		var pad = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 7
		mesh.bottom_radius = 7
		mesh.height = 0.08
		pad.mesh = mesh
		pad.position = point
		pad.material_override = _material(Color("998b64"))
		$Geometry.add_child(pad)
	for point in [Vector3(49, 0, 68), Vector3(79, 0, 51), Vector3(121, 0, 60), Vector3(145, 0, 22)]:
		var rock = Node3D.new()
		rock.position = point
		var mesh = load("res://assets/models/bastion/demo/CliffCluster.glb").instantiate()
		mesh.scale = Vector3(2, 2, 2)
		rock.add_child(mesh)
		var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
		obstacle.radius = 5.0
		obstacle.affect_navigation_mesh = true
		rock.add_child(obstacle)
		$Decorations.add_child(rock)


func _material(color):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1
	return material
