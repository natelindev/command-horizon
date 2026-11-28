extends Node3D

## Helix Phase Condenser spire: sleek white-slate pylons framing a central
## levitating cyan capacitor column.


func _ready():
	if get_child_count() > 0:
		return
	var shell = _material(Color("cbd5d8"), 0.35, 0.35)
	var dark = _material(Color("1e2c34"), 0.6, 0.4)
	var cyan = _material(Color("4cd4f0"), 0.2, 0.2, true)
	_cyl("BasePad", Vector3(0.0, 0.14, 0.0), 1.45, 1.6, 0.28, dark)
	_cyl("InnerDeck", Vector3(0.0, 0.32, 0.0), 1.15, 1.25, 0.16, shell)
	_cyl("CoreColumn", Vector3(0.0, 1.35, 0.0), 0.34, 0.44, 2.0, cyan)
	for index in 3:
		var angle = index * TAU / 3.0
		var pos = Vector3(cos(angle) * 0.92, 1.15, sin(angle) * 0.92)
		var fin = MeshInstance3D.new()
		fin.name = "PylonFin%d" % index
		var box = BoxMesh.new()
		box.size = Vector3(0.28, 1.85, 0.48)
		fin.mesh = box
		fin.material_override = shell
		fin.position = pos
		fin.rotation.y = -angle
		add_child(fin)
	_cyl("CrownRing", Vector3(0.0, 2.18, 0.0), 0.72, 0.72, 0.18, dark)


func _material(color: Color, metallic: float, roughness: float, glowing: bool = false):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if glowing:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.2
	return mat


func _cyl(label: String, point: Vector3, top_r: float, bot_r: float, height: float, mat):
	var mesh = MeshInstance3D.new()
	mesh.name = label
	var cyl = CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.height = height
	mesh.mesh = cyl
	mesh.material_override = mat
	mesh.position = point
	add_child(mesh)
