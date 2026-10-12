extends RefCounted

# Shared, articulated human proportions. Cloth and exposed faces separate soldiers
# from the mechanical walkers; faction armor and class equipment remain distinct.
const Kit = preload("res://source/match/units/traits/InfantryEquipment.gd")
static var _meshes = {}
static var _materials = {}


static func build(faction, role):
	var model = Node3D.new()
	model.name = "InfantryRig"
	var palette = {
		"bastion": ["626451", "71796c", "e0af57"],
		"helix": ["354a5d", "b2c2ca", "62d6da"],
		"frontier": ["797653", "59664c", "bdce8c"]
	}[faction]
	var cloth = _material(palette[0])
	var armor = _material(palette[1])
	var trim = _material(palette[2])
	var dark = _material("293038")
	var skin = _material("bc9274")
	var hips = _pivot(model, "Hips", Vector3(0, .55, 0))
	_ellipsoid(hips, "Trousers", Vector3(0, .015, 0), Vector3(.27, .16, .18), cloth)
	_box(hips, "Belt", Vector3(0, .075, 0), Vector3(.27, .045, .18), dark)
	for side in [-1, 1]:
		var suffix = "Left" if side == -1 else "Right"
		var leg = _pivot(hips, "Hip" + suffix, Vector3(side * .082, 0, 0))
		_capsule(leg, "TrouserThigh", Vector3(0, -.125, 0), Vector3(.125, .29, .145), cloth)
		var knee = _pivot(leg, "Knee" + suffix, Vector3(0, -.26, 0))
		_capsule(knee, "TrouserCalf", Vector3(0, -.12, 0), Vector3(.095, .28, .11), cloth)
		_box(knee, "KneePad", Vector3(0, -.005, -.058), Vector3(.085, .07, .025), dark)
		var ankle = _pivot(knee, "Ankle" + suffix, Vector3(0, -.26, 0))
		_box(ankle, "Boot", Vector3(0, 0, -.038), Vector3(.11, .09, .205), dark)
	var chest = _pivot(model, "Chest", Vector3(0, .62, 0))
	_ellipsoid(chest, "Jacket", Vector3(0, .13, 0), Vector3(.32, .35, .20), cloth)
	_box(chest, "Vest", Vector3(0, .15, -.047), Vector3(.27, .25, .15), armor)
	for side in [-1, 1]:
		_box(chest, "Webbing", Vector3(side * .102, .18, -.105), Vector3(.03, .23, .028), dark)
		_box(
			chest, "AmmoPouch", Vector3(side * .069, .075, -.122), Vector3(.075, .085, .035), cloth
		)
	_box(chest, "FieldPack", Vector3(0, .15, .13), Vector3(.21, .24, .11), cloth)
	_team_box(chest, "UnitMark", Vector3(-.075, .24, -.113), Vector3(.052, .032, .013), trim)
	var head = _pivot(chest, "Head", Vector3(0, .33, 0))
	_ellipsoid(head, "Neck", Vector3(0, -.015, 0), Vector3(.075, .10, .078), skin)
	_ellipsoid(head, "Face", Vector3(0, .085, -.012), Vector3(.145, .195, .155), skin)
	_ellipsoid(head, "Helmet", Vector3(0, .145, .008), Vector3(.185, .14, .19), armor)
	_box(head, "HelmetRim", Vector3(0, .108, -.013), Vector3(.19, .025, .20), armor)
	for side in [-1, 1]:
		_box(head, "Eye", Vector3(side * .028, .073, -.088), Vector3(.014, .012, .012), dark)
		_ellipsoid(head, "Ear", Vector3(side * .072, .075, 0), Vector3(.032, .052, .036), skin)
	_ellipsoid(head, "Nose", Vector3(0, .054, -.093), Vector3(.034, .044, .029), skin)
	_box(head, "ChinStrap", Vector3(0, .004, -.062), Vector3(.10, .018, .025), dark)
	_team_box(head, "HelmetStripe", Vector3(0, .208, .006), Vector3(.03, .014, .10), trim)
	for side in [-1, 1]:
		_team_box(
			chest, "ShoulderMark", Vector3(side * .18, .24, -.05), Vector3(.085, .065, .025), trim
		)
	# Bent elbows and role-specific grips keep hands on the carried weapon.
	var left_hand = Vector3(.08, .08, -.34)
	var right_hand = Vector3(.10, .06, -.16)
	if role == "RocketInfantry":
		left_hand = Vector3(.22, .16, -.43)
		right_hand = Vector3(.22, .11, -.12)
	elif role == "SniperInfantry":
		left_hand = Vector3(.12, .055, -.44)
		right_hand = Vector3(.12, .035, -.17)
	elif role == "AssaultInfantry" or (role == "Hero" and faction == "bastion"):
		left_hand = Vector3(-.25, .025, -.11)
	_arm(chest, "Left", Vector3(-.18, .25, 0), Vector3(-.22, .08, -.10), left_hand, cloth, dark)
	_arm(chest, "Right", Vector3(.18, .25, 0), Vector3(.24, .07, .015), right_hand, cloth, dark)
	if faction == "frontier":
		_ellipsoid(chest, "Scarf", Vector3(0, .315, 0), Vector3(.21, .055, .18), trim)
	elif faction == "helix":
		_box(head, "TempleSensor", Vector3(.10, .10, 0), Vector3(.023, .045, .08), trim)
	_box(chest, "RifleStock", Vector3(.10, .10, -.07), Vector3(.075, .085, .20), dark)
	_box(chest, "RifleReceiver", Vector3(.10, .10, -.26), Vector3(.07, .09, .23), dark)
	_box(chest, "RifleMagazine", Vector3(.10, .025, -.23), Vector3(.05, .10, .075), armor)
	Kit._tube(chest, "RifleBarrel", Vector3(.10, .11, -.48), .018, .24, dark)
	_pivot(chest, "RifleMuzzle", Vector3(.10, .11, -.61))
	return model


static func _arm(parent, label, shoulder, elbow, hand, cloth, glove):
	var arm = _pivot(parent, "Arm" + label, shoulder)
	_segment(arm, "Sleeve", Vector3.ZERO, elbow - shoulder, .095, cloth)
	_segment(arm, "Forearm", elbow - shoulder, hand - shoulder, .075, cloth)
	_ellipsoid(arm, "Glove", hand - shoulder, Vector3(.08, .07, .085), glove)


static func _segment(parent, label, start, end, width, material):
	var node = _capsule(
		parent,
		label,
		(start + end) * .5,
		Vector3(width, start.distance_to(end) + width * .4, width),
		material
	)
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())


static func _pivot(parent, label, point):
	var node = Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	return node


static func _material(color):
	if not _materials.has(color):
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = .88
		_materials[color] = material
	return _materials[color]


static func _ellipsoid(parent, label, point, size, material):
	var key = "round" + str(size)
	if not _meshes.has(key):
		var mesh = SphereMesh.new()
		mesh.radius = .5
		mesh.height = 1.0
		mesh.radial_segments = 12
		mesh.rings = 6
		_meshes[key] = mesh
	var node = Kit._mesh(parent, label, point, _meshes[key], material)
	node.scale = size
	return node


static func _capsule(parent, label, point, size, material):
	var key = "capsule" + str(size)
	if not _meshes.has(key):
		var mesh = CapsuleMesh.new()
		mesh.radius = size.x * .5
		mesh.height = size.y
		mesh.radial_segments = 12
		mesh.rings = 4
		_meshes[key] = mesh
	var node = Kit._mesh(parent, label, point, _meshes[key], material)
	node.scale.z = size.z / size.x
	return node


static func _box(parent, label, point, size, material):
	var key = "box" + str(size)
	if not _meshes.has(key):
		_meshes[key] = Kit._beveled_box(size)
	return Kit._mesh(parent, label, point, _meshes[key], material)


static func _team_box(parent, label, point, size, material):
	# Use a surface material so Unit._setup_color can replace it per owner.
	var key = "team" + str(size)
	if not _meshes.has(key):
		var team = material.duplicate()
		team.resource_name = "TeamColor_Infantry"
		var mesh = Kit._beveled_box(size)
		mesh.surface_set_material(0, team)
		_meshes[key] = mesh
	return Kit._mesh(parent, label, point, _meshes[key], null)
