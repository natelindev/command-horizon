extends RefCounted


static func equip(unit, faction):
	if unit.type == "Infantry":
		return
	var geometry = unit.get_node("Geometry")
	var gear = Node3D.new()
	gear.name = "ClassEquipment"
	var chest = geometry.get_node("InfantryRig/Chest")
	chest.add_child(gear)
	gear.position = -chest.position
	var dark = _material(Color("243139"), .5)
	var metal = _material(Color("9da9ad"), .65)
	var accent = _material(
		{"bastion": Color("f1ba58"), "helix": Color("65e5e9"), "frontier": Color("a9d486")}[faction],
		.25
	)
	var cloth = _material(
		{"bastion": Color("4c555f"), "helix": Color("2e4357"), "frontier": Color("79744d")}[faction],
		0
	)
	if unit.type in ["RocketInfantry", "SniperInfantry"]:
		for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
			if (
				"Rifle" in str(mesh.name)
				or "Carbine" in str(mesh.name)
				or "Barrel" in str(mesh.name)
				or "WoodStock" in str(mesh.name)
			):
				mesh.hide()
	if unit.type in ["RocketInfantry", "SniperInfantry"]:
		for old_muzzle in geometry.find_children("*Muzzle", "Node3D", true, false):
			old_muzzle.name = "StockEmitter"
		var muzzle = Marker3D.new()
		muzzle.name = "ClassMuzzle"
		muzzle.position = (
			Vector3(.22, .75, -.68) if unit.type == "RocketInfantry" else Vector3(.12, .66, -1.02)
		)
		gear.add_child(muzzle)
	match unit.type:
		"RocketInfantry":
			_tube(gear, "Launcher", Vector3(.22, .75, -.15), .11, .86, dark)
			_tube(gear, "LaunchMouth", Vector3(.22, .75, -.60), .125, .09, metal)
			_tube(gear, "RocketTip", Vector3(.22, .75, -.65), .075, .05, accent)
			_box(gear, "Optic", Vector3(.22, .89, -.15), Vector3(.09, .08, .15), accent)
			_box(gear, "AmmoPack", Vector3(0, .6, .21), Vector3(.32, .4, .17), cloth)
			for x in [-.1, .1]:
				_tube(gear, "SpareRocket", Vector3(x, .65, .32), .06, .48, metal).rotation.x = 0
		"SniperInfantry":
			_box(gear, "PrecisionStock", Vector3(.12, .65, -.26), Vector3(.11, .12, .52), dark)
			_tube(gear, "LongBarrel", Vector3(.12, .66, -.68), .026, .42, metal)
			_tube(gear, "Suppressor", Vector3(.12, .66, -.94), .042, .14, dark)
			_tube(gear, "Scope", Vector3(.12, .76, -.32), .045, .23, accent)
			_box(gear, "Mantle", Vector3(0, .75, .06), Vector3(.47, .16, .24), cloth)
			_box(gear, "FieldPack", Vector3(0, .52, .23), Vector3(.29, .4, .10), cloth)
		"AssaultInfantry":
			_armor(gear, dark, accent)
			_box(gear, "BreachingShield", Vector3(-.28, .53, -.14), Vector3(.20, .55, .09), metal)
			_box(gear, "ShieldMark", Vector3(-.28, .58, -.19), Vector3(.09, .2, .018), accent)
			_tube(gear, "DrumMagazine", Vector3(.12, .52, -.26), .09, .15, dark)
		"Hero":
			geometry.get_child(0).scale *= 1.12
			_armor(gear, metal, accent)
			_box(gear, "CommandPack", Vector3(0, .64, .23), Vector3(.3, .44, .14), dark)
			_box(gear, "CommandAntenna", Vector3(.17, .99, .25), Vector3(.018, .48, .018), accent)
			if faction == "helix":
				_tube(gear, "Lance", Vector3(.10, .73, -.7), .04, .7, accent)
				chest.get_node("RifleMuzzle").position = Vector3(.10, .11, -1.06)
			elif faction == "frontier":
				_box(gear, "ScoutMantle", Vector3(0, .8, .12), Vector3(.57, .15, .35), cloth)
			else:
				_box(gear, "MarshalShield", Vector3(-.29, .57, -.13), Vector3(.22, .59, .13), dark)
			var aura = load("res://source/match/units/traits/HeroAura.gd").new()
			aura.name = "HeroAura"
			unit.add_child(aura)


static func _armor(parent, metal, accent):
	for x in [-.18, .18]:
		_box(parent, "Pauldrons", Vector3(x, .82, 0), Vector3(.13, .12, .18), metal)
		_box(parent, "RankMark", Vector3(x, .88, -.01), Vector3(.07, .018, .12), accent)
	_box(parent, "ChestPlate", Vector3(0, .64, -.12), Vector3(.25, .23, .045), metal)


static func _material(color, metallic):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = .65
	return material


static func _box(parent, label, point, size, material):
	return _mesh(parent, label, point, _beveled_box(size), material)


static func _tube(parent, label, point, radius, length, material):
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	var node = _mesh(parent, label, point, mesh, material)
	node.rotation.x = PI / 2
	return node


static func _mesh(parent, label, point, mesh, material):
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = point
	node.material_override = material
	parent.add_child(node)
	return node


static func _beveled_box(size):
	# Chamfered hard-surface kit pieces, with explicit face normals for crisp lighting.
	var half = size * .5
	var bevel = minf(.025, minf(size.x, minf(size.y, size.z)) * .18)
	var inner = half - Vector3.ONE * bevel
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u = (axis + 1) % 3
		var v = (axis + 2) % 3
		for sign_value in [-1, 1]:
			var normal = Vector3.ZERO
			normal[axis] = sign_value
			var face = []
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point = normal * half[axis]
				point[u] = corner.x * inner[u]
				point[v] = corner.y * inner[v]
				face.append(point)
			_face(surface, face, normal)
	for axis in 3:
		var u = (axis + 1) % 3
		var v = (axis + 2) % 3
		for su in [-1, 1]:
			for sv in [-1, 1]:
				var normal = Vector3.ZERO
				normal[u] = su
				normal[v] = sv
				var face = []
				for corner in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
					var point = Vector3.ZERO
					point[axis] = corner.x * inner[axis]
					point[u] = su * (half[u] if corner.y == 0 else inner[u])
					point[v] = sv * (inner[v] if corner.y == 0 else half[v])
					face.append(point)
				_face(surface, face, normal.normalized())
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var sign_vector = Vector3(sx, sy, sz)
				var face = []
				for axis in 3:
					var point = inner * sign_vector
					point[axis] = half[axis] * sign_vector[axis]
					face.append(point)
				_face(surface, face, sign_vector.normalized())
	return surface.commit()


static func _face(surface, vertices, normal):
	for index in range(1, vertices.size() - 1):
		var triangle = [vertices[0], vertices[index], vertices[index + 1]]
		if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).dot(normal) > 0:
			triangle.reverse()
		for vertex in triangle:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
