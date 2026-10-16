extends Node3D


func _ready():
	_box(Vector3(1.22, 0.22, 2.25), Vector3(0, 0.4, 0), Color("303b42"))
	_box(Vector3(1.2, 0.7, 0.7), Vector3(0, 0.85, -0.78), Color("8d916d"))
	_box(Vector3(1.03, 0.27, 0.04), Vector3(0, 0.98, -1.145), Color("5fa8b5"))
	_box(Vector3(1.28, 0.85, 1.35), Vector3(0, 0.94, 0.32), Color("bd975a"))
	for z in [-0.24, 0.32, 0.88]:
		_box(Vector3(1.31, 0.9, 0.045), Vector3(0, 0.94, z), Color("394650"))
	for x in [-0.42, 0.42]:
		_box(Vector3(0.18, 0.14, 0.05), Vector3(x, 0.63, -1.16), Color("ffdea0"))
		for z in [-0.74, 0.5, 0.95]:
			# Each wheel sits in its own pivot so it can roll with the truck.
			var pivot = Node3D.new()
			pivot.name = "WheelPivot"
			pivot.position = Vector3(sign(x) * 0.68, 0.3, z)
			add_child(pivot, true)
			var wheel = MeshInstance3D.new()
			var mesh = CylinderMesh.new()
			mesh.top_radius = 0.28
			mesh.bottom_radius = 0.28
			mesh.height = 0.2
			wheel.mesh = mesh
			wheel.rotation.z = PI / 2
			wheel.material_override = _material(Color("18212a"))
			pivot.add_child(wheel)


func _box(dimensions, point, color):
	var part = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = point
	part.material_override = _material(color)
	add_child(part)


func _material(color):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
