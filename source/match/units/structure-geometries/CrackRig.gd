extends Node3D

## Frontier Crack-Rig: rugged 6-wheeled wasteland distiller truck with a
## pressurized chemical tank, welded cab and vertical exhaust flare stack.


func _ready():
	if get_child_count() > 0:
		return
	var rust = _material(Color("926845"), 0.35, 0.78)
	var steel = _material(Color("4b5250"), 0.6, 0.65)
	var tire = _material(Color("1e2122"), 0.05, 0.92)
	var hazard = _material(Color("d19a3a"), 0.25, 0.6)
	_box("Chassis", Vector3(0.0, 0.32, 0.0), Vector3(0.95, 0.22, 1.65), steel)
	_box("Cab", Vector3(0.0, 0.62, -0.48), Vector3(0.86, 0.48, 0.56), rust)
	_box("Bumper", Vector3(0.0, 0.34, -0.84), Vector3(0.98, 0.16, 0.12), hazard)
	var tank = MeshInstance3D.new()
	tank.name = "DistillerTank"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.38
	cyl.height = 1.02
	tank.mesh = cyl
	tank.material_override = hazard
	tank.position = Vector3(0.0, 0.74, 0.24)
	tank.rotation.x = PI * 0.5
	add_child(tank)
	_box("ExhaustStack", Vector3(0.32, 0.98, -0.15), Vector3(0.12, 0.76, 0.12), steel)
	for side in [-1, 1]:
		for z_pos in [-0.52, 0.08, 0.54]:
			var wheel = MeshInstance3D.new()
			wheel.name = "Wheel"
			var w_cyl = CylinderMesh.new()
			w_cyl.top_radius = 0.22
			w_cyl.bottom_radius = 0.22
			w_cyl.height = 0.16
			wheel.mesh = w_cyl
			wheel.material_override = tire
			wheel.position = Vector3(side * 0.50, 0.22, z_pos)
			wheel.rotation.z = PI * 0.5
			add_child(wheel)


func _material(color: Color, metallic: float, roughness: float):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _box(label: String, point: Vector3, size: Vector3, mat):
	var mesh = MeshInstance3D.new()
	mesh.name = label
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = point
	add_child(mesh)
