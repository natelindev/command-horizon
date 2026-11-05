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
	var metal = _material(Color("6b736e"), .25)
	var Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")
	var is_mercenary = unit.type in Mercenaries.ROLES
	var accent = _material(
		(
			Color("c49a45")
			if is_mercenary
			else {"bastion": Color("b7a066"), "helix": Color("72a4af"), "frontier": Color("8d9e79")}[faction]
		),
		.25
	)
	var cloth = _material(
		(
			Color("333739")
			if is_mercenary
			else {"bastion": Color("4c555f"), "helix": Color("2e4357"), "frontier": Color("79744d")}[faction]
		),
		0
	)
	if unit.type in ["RocketInfantry", "SniperInfantry", "MercenaryRanger", "MercenaryLancer"]:
		chest.get_node("RifleReceiver").hide()
		for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
			if (
				"Rifle" in str(mesh.name)
				or "Carbine" in str(mesh.name)
				or "Barrel" in str(mesh.name)
				or "WoodStock" in str(mesh.name)
			):
				mesh.hide()
	if unit.type in ["RocketInfantry", "SniperInfantry", "MercenaryRanger", "MercenaryLancer"]:
		for old_muzzle in geometry.find_children("*Muzzle", "Node3D", true, false):
			old_muzzle.name = "StockEmitter"
		var muzzle = Marker3D.new()
		muzzle.name = "ClassMuzzle"
		muzzle.position = (
			Vector3(.22, .75, -.68)
			if unit.type in ["RocketInfantry", "MercenaryLancer"]
			else Vector3(.12, .66, -1.02)
		)
		gear.add_child(muzzle)
	var role = unit.type
	if role in Mercenaries.ROLES:
		role = Mercenaries.UNITS[role].base
		_box(gear, "ContractMantle", Vector3(0, .78, .17), Vector3(.34, .10, .23), dark)
		_box(gear, "ContractBadge", Vector3(0, .89, .17), Vector3(.18, .025, .14), metal)
		if unit.type == "MercenaryWarden":
			_box(gear, "TowerShield", Vector3(-.28, .5, -.2), Vector3(.34, .78, .12), dark)
		elif unit.type == "MercenaryRanger":
			_box(gear, "ReconAntenna", Vector3(-.16, 1.03, .22), Vector3(.025, .44, .025), metal)
		else:
			_tube(gear, "HeavyWarhead", Vector3(.22, .75, -.54), .085, .24, metal)
	match role:
		"RocketInfantry":
			_tube(gear, "Launcher", Vector3(.22, .75, -.15), .075, .86, dark)
			_tube(gear, "LaunchMouth", Vector3(.22, .75, -.60), .082, .065, metal)
			_tube(gear, "RocketTip", Vector3(.22, .75, -.64), .058, .025, dark)
			_box(gear, "Optic", Vector3(.22, .89, -.15), Vector3(.055, .045, .09), dark)
			_box(gear, "AmmoPack", Vector3(0, .72, .16), Vector3(.25, .32, .15), cloth)
			for x in [-.075, .075]:
				_tube(gear, "SpareRocket", Vector3(x, .74, .26), .045, .48, metal).rotation.x = 0
		"SniperInfantry":
			_box(gear, "PrecisionStock", Vector3(.12, .65, -.26), Vector3(.055, .065, .43), dark)
			_tube(gear, "LongBarrel", Vector3(.12, .66, -.68), .016, .42, metal)
			_tube(gear, "Suppressor", Vector3(.12, .66, -.94), .026, .14, dark)
			_tube(gear, "Scope", Vector3(.12, .76, -.32), .028, .19, dark)
			_box(gear, "Mantle", Vector3(0, .75, .06), Vector3(.32, .075, .22), cloth)
			_tube(gear, "ClothBedroll", Vector3(0, .89, .17), .039, .23, cloth).rotation = Vector3(
				0, 0, PI / 2
			)
		"AssaultInfantry":
			_armor(gear, dark, accent)
			_box(gear, "BreachingShield", Vector3(-.28, .53, -.14), Vector3(.28, .64, .09), metal)
			_box(gear, "ShieldMark", Vector3(-.28, .58, -.19), Vector3(.055, .09, .012), accent)
			_tube(gear, "DrumMagazine", Vector3(.12, .52, -.26), .09, .15, dark)
		"Hero":
			if faction == "helix":
				geometry.get_child(0).scale = Vector3(0.94, 0.98, 0.94)
				for side in ["Left", "Right"]:
					var shell = gear.get_parent().get_node("Arm" + side + "/ShoulderArmor")
					shell.material_override = dark
				_box(gear, "PhaseCuirass", Vector3(0, .77, -.11), Vector3(.19, .18, .022), dark)
				_box(gear, "PhaseCore", Vector3(0, .77, -.123), Vector3(.05, .07, .008), accent)
				_box(gear, "SpectreVisor", Vector3(0, .96, -.088), Vector3(.09, .016, .015), accent)
				_box(gear, "PhaseDrive", Vector3(0, .77, .12), Vector3(.16, .22, .07), dark)
				_tube(gear, "CapacitorLeft", Vector3(-.06, .77, .13), .02, .20, accent)
				_tube(gear, "CapacitorRight", Vector3(.06, .77, .13), .02, .20, accent)
				_box(gear, "PhaseCoil", Vector3(0, .85, .15), Vector3(.08, .03, .03), accent)
				_box(gear, "LanceReceiver", Vector3(.10, .68, -.32), Vector3(.045, .07, .26), dark)
				_tube(gear, "LanceCore", Vector3(.10, .68, -.70), .022, .62, accent)
				_box(gear, "LanceRailTop", Vector3(.10, .71, -.70), Vector3(.012, .015, .50), metal)
				_box(
					gear,
					"LanceRailBottom",
					Vector3(.10, .65, -.70),
					Vector3(.012, .015, .50),
					metal
				)
				_tube(gear, "LanceEmitter", Vector3(.10, .68, -1.02), .016, .06, accent)
				chest.get_node("RifleMuzzle").position = Vector3(.10, .06, -1.06)
			else:
				geometry.get_child(0).scale *= 1.12
				_armor(gear, metal, accent)
				_box(gear, "CommandPack", Vector3(0, .76, .16), Vector3(.22, .28, .12), dark)
				_box(
					gear, "CommandAntenna", Vector3(.17, .99, .25), Vector3(.018, .48, .018), accent
				)
				if faction == "frontier":
					_box(gear, "ScoutMantle", Vector3(0, .8, .12), Vector3(.32, .075, .23), cloth)
				else:
					_box(
						gear,
						"MarshalShield",
						Vector3(-.29, .57, -.13),
						Vector3(.22, .59, .13),
						dark
					)
			var aura = load("res://source/match/units/traits/HeroAura.gd").new()
			aura.name = "HeroAura"
			unit.add_child(aura)


static func _armor(parent, metal, _accent):
	# Heavy roles reinforce the fitted shoulder shell instead of adding a
	# second floating cuboid pauldron. Pads keep following their upper arms.
	for side in ["Left", "Right"]:
		var shell = parent.get_parent().get_node("Arm" + side + "/ShoulderArmor")
		shell.scale *= 1.2
		shell.material_override = metal
	_box(parent, "ChestPlate", Vector3(0, .78, -.128), Vector3(.24, .20, .035), metal)


static func _material(color, metallic):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = .86
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
