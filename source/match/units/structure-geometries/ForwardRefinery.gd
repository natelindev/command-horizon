extends Node3D

## A compact industrial receiver: open drive-up intake, ore hoppers, conveyor
## and orange heat exchangers. Composed natively so its readable silhouette
## does not depend on editing an exported faction model.


func _ready():
	if get_child_count() > 0:
		return
	var steel = _material(Color("414d50"), 0.65)
	var concrete = _material(Color("777b72"), 0.05)
	var yellow = _material(Color("b99845"), 0.45)
	var dark = _material(Color("20292c"), 0.4)
	_box("Foundation", Vector3(0, .12, 0), Vector3(3.1, .24, 2.5), concrete)
	_box("ReceivingBelt", Vector3(-.2, .42, .65), Vector3(2.6, .3, .75), dark)
	_box("MainFurnace", Vector3(.55, 1.0, -.3), Vector3(1.4, 1.5, 1.45), steel)
	_box("OreHopper", Vector3(-.9, .93, -.35), Vector3(1.0, 1.15, 1.3), yellow)
	_box("HopperOpening", Vector3(-.9, 1.52, -.35), Vector3(.75, .04, 1.0), dark)
	for offset in [-.42, 0.0, .42]:
		_box("HeatExchanger", Vector3(.6 + offset, 1.85, -.3), Vector3(.19, .28, 1.1), yellow)
	for index in 5:
		_box("BeltSlat", Vector3(-1.22 + index * .5, .59, .65), Vector3(.12, .03, .68), steel)
	_box("ReceiverArm", Vector3(1.23, 1.05, .67), Vector3(.13, 1.25, .14), yellow)
	_box("ReceiverArm", Vector3(-1.35, 1.05, .67), Vector3(.13, 1.25, .14), yellow)
	_box("ReceiverHeader", Vector3(-.06, 1.65, .67), Vector3(2.72, .16, .16), yellow)


func _material(color, metallic):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = .7
	return material


func _box(label, point, size, material):
	var mesh = MeshInstance3D.new()
	mesh.name = label
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = point
	add_child(mesh)
