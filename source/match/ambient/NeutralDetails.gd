extends RefCounted


static func material(color, metal = 0.0, glow = false):
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .65
	result.metallic = metal
	result.emission_enabled = glow
	result.emission = color
	result.emission_energy_multiplier = .65
	return result


static func box(parent, label, point, size, surface):
	var node = MeshInstance3D.new()
	node.name = label
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = surface
	node.mesh = mesh
	node.position = point
	parent.add_child(node)
	return node


static func dress_actor(model, entry):
	var seed_value = absi(entry.id.hash())
	var paint = material(
		[Color("557e7a"), Color("a27653"), Color("6c7994"), Color("b5ad8c")][seed_value % 4], .25
	)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if (
			("Lower body" in mesh.name or "Lower_body" in mesh.name)
			or "Coat" in mesh.name
			or "Sleeve" in mesh.name
			or "Cuff" in mesh.name
		):
			mesh.material_override = paint
	var dark = material(Color("26363b"), .3)
	var trim = material(Color("b5b9ae"), .7)
	if entry.kind == "car":
		for x in [-.49, .49]:
			box(
				model,
				"HeadlampLens",
				Vector3(x, .54, 1.34),
				Vector3(.22, .12, .035),
				material(Color("ffe0a2"), 0, true)
			)
			box(
				model,
				"RearLampLens",
				Vector3(x, .53, -1.34),
				Vector3(.2, .10, .035),
				material(Color("ae4431"), 0, true)
			)
		for z in [-.42, .6]:
			box(model, "RoofRack", Vector3(0, 1.17, z), Vector3(1.22, .045, .06), trim)
		box(
			model,
			"LicensePlate",
			Vector3(0, .3, -1.39),
			Vector3(.35, .1, .025),
			material(Color("dbd4b3"))
		)
		for x in [-.3, .3]:
			var wiper = box(model, "Wiper", Vector3(x, .92, .69), Vector3(.025, .02, .28), dark)
			wiper.rotation.x = -.7
	elif entry.kind == "resident":
		box(model, "Collar", Vector3(0, 1.15, .02), Vector3(.22, .06, .23), trim)
		box(model, "SatchelStrap", Vector3(.15, .94, -.15), Vector3(.045, .4, .025), dark)
		if seed_value % 2 == 0:
			box(model, "CapBrim", Vector3(0, 1.46, .08), Vector3(.32, .035, .3), paint)


static func dress_building(model, radius, asset):
	# Follow the authored facades. Do not stack new windows over existing glazing.
	var concrete = material(Color("b2ac96"))
	var metal = material(Color("46565a"), .45)
	var dark = material(Color("243337"), .2)
	var glass = material(Color("648689"), .45)
	var lamp = material(Color("f3cf86"), 0, true)
	var root = Node3D.new()
	root.name = "CivicDetails"
	model.add_child(root)
	if asset == "ServiceOffice":
		for side in [-1, 1]:
			box(
				root,
				"EntranceDoor",
				Vector3(side * .34, 1.10, 4.67),
				Vector3(.65, 1.67, .055),
				metal
			)
			box(root, "DoorGlass", Vector3(side * .34, 1.35, 4.71), Vector3(.49, .91, .018), glass)
			box(
				root,
				"DoorHandle",
				Vector3(side * .12, .98, 4.75),
				Vector3(.035, .26, .055),
				concrete
			)
			box(root, "PorchLamp", Vector3(side * 1.12, 2.23, 4.7), Vector3(.14, .25, .09), lamp)
			box(root, "DrainPipe", Vector3(side * 5.32, 2.65, 4.47), Vector3(.09, 5.0, .11), metal)
			box(
				root,
				"AirConditioner",
				Vector3(side * 5.37, 3.0, .5),
				Vector3(.38, .6, 1.0),
				concrete
			)
			for slat in 5:
				box(
					root,
					"CondenserVent",
					Vector3(side * 5.58, 2.79 + slat * .1, .5),
					Vector3(.018, .025, .8),
					dark
				)
		# A real parapet adds depth and contact shadows to the broad roof.
		for x in [-5.25, 5.25]:
			box(root, "RoofParapet", Vector3(x, 5.67, -.1), Vector3(.16, .35, 9.1), concrete)
		for z in [-4.65, 4.48]:
			box(root, "RoofParapet", Vector3(0, 5.67, z), Vector3(10.5, .35, .16), concrete)
	elif asset in ["SawtoothWorkshop", "CoolingHall"]:
		for x in [-3, 3]:
			box(root, "LoadingLampHousing", Vector3(x, 3.22, 4.85), Vector3(.8, .13, .23), metal)
			box(root, "LoadingLamp", Vector3(x, 3.15, 4.88), Vector3(.65, .035, .15), lamp)
		box(root, "ElectricalBox", Vector3(4.85, 1.1, 4.82), Vector3(.6, 1.25, .24), metal)
		for slat in 6:
			box(
				root,
				"CabinetVent",
				Vector3(4.85, .72 + slat * .11, 4.95),
				Vector3(.46, .025, .018),
				dark
			)
	elif asset == "DamagedWarehouse":
		for index in 6:
			var timber = box(
				root,
				"TimberStack",
				Vector3(3.1, .35 + index * .11, -2),
				Vector3(1.5, .09, .4),
				concrete
			)
			timber.rotation.y = .2 * (index % 2)
	elif asset in ["ServiceRuin", "PumpStation", "RelaySubstation"]:
		var edge = radius * .65
		for side in [-1, 1]:
			box(
				root,
				"ServiceLamp",
				Vector3(side * edge * .6, 2.4, edge),
				Vector3(.25, .16, .17),
				lamp
			)
			box(
				root,
				"UtilityConduit",
				Vector3(side * edge, 1.35, edge * .7),
				Vector3(.09, 2.6, .09),
				metal
			)
	return root
