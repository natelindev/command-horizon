extends RefCounted

const Cache = preload("res://source/utils/RuntimeCache.gd")

# Production model, authored against art/infantry/redesign/target-v1.png.
# Contoured cross sections model tailoring, anatomy and helmet shells rather
# than scaling capsules. Shared mesh resources keep squad construction cheap.
const Kit = preload("res://source/match/units/traits/InfantryEquipment.gd")


static func build(faction, role):
	var Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")
	var is_mercenary = role in Mercenaries.ROLES
	if is_mercenary:
		role = Mercenaries.UNITS[role].base
	var model = _pivot(null, "InfantryRig", Vector3.ZERO)
	var palette = (
		["333739", "544d42", "7a6e5b", "c49a45"]
		if is_mercenary
		else {
			"bastion": ["555a43", "807c5e", "93886b", "b7a066"],
			"helix": ["35414b", "68717a", "778186", "72a4af"],
			"frontier": ["80775e", "535f47", "8b8065", "8d9e79"]
		}[faction]
	)
	var cloth = _material(palette[0], "Infantry cloth", .96)
	var armor = _material(palette[1], "Infantry armor", .82)
	var canvas = _material(palette[2], "Infantry canvas", .98)
	var trim = _material(palette[3], "Infantry insignia", .85)
	var dark = _material("282d2b", "Infantry rubber", .93)
	var steel = _material("41484a", "Infantry metal", .62, .45)
	var skin = _material("a98065", "skin", .9)
	var hips = _pivot(model, "Hips", Vector3(0, .55, 0))
	_profile(
		hips,
		"Trousers",
		Vector3.ZERO,
		[
			Vector4(-.055, .105, .073, 0),
			Vector4(.0, .128, .086, 0),
			Vector4(.055, .12, .083, 0),
			Vector4(.09, .12, .083, 0)
		],
		cloth
	)
	_box(hips, "Belt", Vector3(0, .066, 0), Vector3(.243, .026, .172), dark)
	_box(hips, "BeltBuckle", Vector3(0, .066, -.092), Vector3(.038, .029, .012), steel)
	for side in [-1, 1]:
		var suffix = "Left" if side == -1 else "Right"
		var leg = _pivot(hips, "Hip" + suffix, Vector3(side * .082, 0, 0))
		_profile(
			leg,
			"TrouserThigh",
			Vector3.ZERO,
			[
				Vector4(-.275, .043, .044, -.006),
				Vector4(-.245, .05, .048, -.006),
				Vector4(-.218, .055, .057, -.002),
				Vector4(-.20, .048, .052, 0),
				Vector4(-.17, .059, .058, 0),
				Vector4(-.11, .066, .069, .004),
				Vector4(-.035, .068, .074, 0),
				Vector4(.025, .054, .066, 0)
			],
			cloth,
			.035
		)
		_box(leg, "CargoPocket", Vector3(side * .058, -.105, .006), Vector3(.032, .106, .10), cloth)
		_box(
			leg, "PocketFlap", Vector3(side * .073, -.068, .004), Vector3(.012, .029, .104), canvas
		)
		var knee = _pivot(leg, "Knee" + suffix, Vector3(0, -.26, 0))
		_profile(
			knee,
			"TrouserCalf",
			Vector3.ZERO,
			[
				Vector4(-.205, .045, .046, .008),
				Vector4(-.195, .047, .048, .007),
				Vector4(-.18, .044, .043, .009),
				Vector4(-.16, .051, .048, .012),
				Vector4(-.12, .054, .057, .016),
				Vector4(-.065, .05, .052, .011),
				Vector4(-.025, .043, .044, 0),
				Vector4(.02, .045, .046, 0)
			],
			cloth,
			.055
		)
		_box(knee, "KneeStrap", Vector3(0, -.025, .004), Vector3(.098, .025, .10), dark)
		_profile(
			knee,
			"KneePad",
			Vector3(0, 0, -.047),
			[
				Vector4(-.068, .027, .012, 0),
				Vector4(-.047, .038, .02, 0),
				Vector4(.015, .038, .024, 0),
				Vector4(.033, .025, .012, 0)
			],
			armor
		)
		var ankle = _pivot(knee, "Ankle" + suffix, Vector3(0, -.26, 0))
		_profile(
			ankle,
			"Boot",
			Vector3.ZERO,
			[
				Vector4(-.038, .05, .085, -.027),
				Vector4(-.022, .051, .086, -.027),
				Vector4(.004, .046, .076, -.029),
				Vector4(.032, .041, .049, -.004),
				Vector4(.065, .034, .035, .008),
				Vector4(.083, .032, .033, .009)
			],
			dark
		)
		_box(ankle, "BootSole", Vector3(0, -.034, -.026), Vector3(.103, .021, .177), dark)
		for lace in [Vector2(.02, -.082), Vector2(.04, -.049), Vector2(.06, -.034)]:
			_box(ankle, "BootLace", Vector3(0, lace.x, lace.y), Vector3(.049, .005, .006), dark)

	var chest = _pivot(model, "Chest", Vector3(0, .62, 0))
	_profile(
		chest,
		"Jacket",
		Vector3.ZERO,
		[
			Vector4(-.035, .12, .079, .002),
			Vector4(.03, .127, .085, 0),
			Vector4(.065, .118, .077, .003),
			Vector4(.12, .13, .087, .002),
			Vector4(.21, .151, .095, 0),
			Vector4(.267, .148, .08, .008),
			Vector4(.30, .086, .058, .005)
		],
		cloth,
		.025
	)
	_profile(
		chest,
		"PlateCarrier",
		Vector3(0, 0, -.021),
		[
			Vector4(.065, .122, .083, 0),
			Vector4(.09, .133, .088, 0),
			Vector4(.215, .135, .091, 0),
			Vector4(.255, .103, .079, 0)
		],
		armor
	)
	_box(chest, "CeramicPlate", Vector3(0, .18, -.112), Vector3(.183, .135, .019), armor)
	for side in [-1, 1]:
		var webbing = _box(
			chest, "Webbing", Vector3(side * .097, .224, -.088), Vector3(.024, .13, .027), canvas
		)
		webbing.rotation.z = side * -.12
		_box(chest, "StrapBuckle", Vector3(side * .10, .24, -.106), Vector3(.028, .026, .012), dark)
		_box(
			chest, "UtilityPouch", Vector3(side * .13, .071, -.013), Vector3(.055, .10, .105), cloth
		)
	for x in [-.079, -.026, .027, .08]:
		_profile(
			chest,
			"AmmoPouch",
			Vector3(x, .091, -.128),
			[
				Vector4(-.046, .018, .012, 0),
				Vector4(-.034, .023, .021, -.002),
				Vector4(.024, .024, .024, -.002),
				Vector4(.044, .02, .018, 0)
			],
			canvas,
			.02,
			.32
		)
		_box(chest, "PouchFlap", Vector3(x, .12, -.151), Vector3(.041, .025, .008), cloth)
	for y in [.17, .20, .23]:
		_box(chest, "CarrierWebbing", Vector3(0, y, -.125), Vector3(.155, .008, .007), canvas)
	_profile(
		chest,
		"FieldPack",
		Vector3(0, .15, .122),
		[
			Vector4(-.123, .065, .032, 0),
			Vector4(-.105, .091, .05, 0),
			Vector4(-.05, .103, .055, .004),
			Vector4(.07, .098, .052, .002),
			Vector4(.111, .088, .045, 0),
			Vector4(.125, .063, .03, 0)
		],
		cloth,
		.025,
		.38
	)
	_profile(
		chest,
		"PackPocket",
		Vector3(0, .12, .177),
		[
			Vector4(-.065, .058, .012, 0),
			Vector4(-.05, .072, .026, 0),
			Vector4(.045, .073, .027, 0),
			Vector4(.065, .062, .015, 0)
		],
		canvas,
		.025,
		.4
	)
	_box(chest, "PackFlap", Vector3(0, .257, .142), Vector3(.20, .034, .10), canvas)
	for x in [-.065, .065]:
		_box(chest, "PackWebbing", Vector3(x, .16, .203), Vector3(.013, .16, .007), dark)
	_team_box(chest, "PackMark", Vector3(0, .266, .145), Vector3(.055, .009, .045), trim)
	_team_box(chest, "UnitMark", Vector3(-.06, .239, -.125), Vector3(.037, .022, .007), trim)
	_profile(
		chest,
		"Collar",
		Vector3(0, .30, 0),
		[Vector4(-.014, .067, .055, 0), Vector4(.028, .062, .052, 0)],
		cloth
	)
	var head = _pivot(chest, "Head", Vector3(0, .32, 0))
	head.scale = Vector3.ONE * .9
	_profile(
		head,
		"Neck",
		Vector3.ZERO,
		[Vector4(-.035, .033, .033, .008), Vector4(.035, .035, .036, .004)],
		skin
	)
	_profile(
		head,
		"Face",
		Vector3.ZERO,
		[
			Vector4(.015, .029, .031, -.017),
			Vector4(.028, .043, .037, -.012),
			Vector4(.053, .051, .044, -.008),
			Vector4(.082, .056, .047, -.004),
			Vector4(.118, .054, .046, .002),
			Vector4(.145, .042, .035, .004)
		],
		skin
	)
	_profile(
		head,
		"Helmet",
		Vector3.ZERO,
		[
			Vector4(.092, .073, .073, .009),
			Vector4(.109, .078, .078, .009),
			Vector4(.15, .073, .072, .012),
			Vector4(.183, .053, .052, .014),
			Vector4(.195, .02, .023, .013),
			Vector4(.197, .002, .002, .013)
		],
		cloth if faction == "frontier" else armor
	)
	_box(head, "HelmetBrow", Vector3(0, .109, -.062), Vector3(.13, .015, .034), dark)
	for side in [-1, 1]:
		var goggle = _box(
			head, "GoggleFrame", Vector3(side * .028, .084, -.052), Vector3(.054, .028, .016), dark
		)
		goggle.rotation.y = side * -.14
		var lens = _box(
			head,
			"BallisticLens",
			Vector3(side * .027, .084, -.062),
			Vector3(.044, .018, .004),
			_material("394440", "Ballistic glass", .24, .25)
		)
		lens.rotation.y = side * -.14
		_box(head, "Headset", Vector3(side * .066, .07, .006), Vector3(.025, .061, .046), dark)
		_box(head, "HelmetRail", Vector3(side * .075, .123, .007), Vector3(.012, .021, .066), steel)
		_segment(
			head,
			"ChinStrap",
			Vector3(side * .055, .073, -.002),
			Vector3(side * .025, .017, -.035),
			.012,
			dark
		)
	_profile(
		head,
		"Nose",
		Vector3(0, .044, -.052),
		[
			Vector4(0, .013, .012, 0),
			Vector4(.012, .011, .017, -.001),
			Vector4(.034, .005, .006, .003)
		],
		skin
	)
	_box(
		head,
		"Mouth",
		Vector3(0, .033, -.049),
		Vector3(.027, .003, .004),
		_material("775c4e", "skin", .96)
	)
	_team_box(head, "HelmetStripe", Vector3(0, .193, .015), Vector3(.027, .007, .043), trim)
	_box(head, "HelmetMount", Vector3(0, .143, -.068), Vector3(.03, .029, .018), steel)
	if faction == "helix":
		var visor = _material("2ad4e0", "Helix visor", .2, .3)
		_box(head, "CyberVisor", Vector3(0, .072, -.058), Vector3(.105, .046, .028), visor)
		_box(head, "ChinGuard", Vector3(0, .032, -.046), Vector3(.098, .036, .038), armor)
		for side in [-1, 1]:
			var fin = _box(chest, "PackFin" + str(side), Vector3(side * .09, .24, .18), Vector3(.02, .12, .06), armor)
			fin.rotation.z = side * -.28
	elif faction == "frontier":
		_profile(
			head,
			"BoonieBrim",
			Vector3(0, .105, 0),
			[Vector4(-.01, .112, .112, .006), Vector4(.008, .108, .108, .006)],
			canvas,
			.06
		)
		_profile(
			chest,
			"Bedroll",
			Vector3(0, .29, .15),
			[Vector4(-.02, .038, .038, 0), Vector4(.02, .038, .038, 0)],
			canvas
		)
	var left_hand = Vector3(.08, .08, -.34)
	var right_hand = Vector3(.10, .06, -.16)
	if role == "RocketInfantry":
		left_hand = Vector3(.17, .10, -.27)
		right_hand = Vector3(.22, .11, -.12)
	elif role == "SniperInfantry":
		left_hand = Vector3(.12, .055, -.32)
		right_hand = Vector3(.12, .035, -.17)
	elif role == "AssaultInfantry" or (role == "Hero" and faction == "bastion"):
		left_hand = Vector3(-.25, .025, -.11)
	elif role == "Hero" and faction == "helix":
		left_hand = Vector3(.10, .08, -.45)
		right_hand = Vector3(.10, .05, -.18)
	_arm(
		chest,
		"Left",
		Vector3(-.145, .25, 0),
		Vector3(-.20, .08, -.10),
		left_hand,
		cloth,
		dark,
		armor,
		trim
	)
	_arm(
		chest,
		"Right",
		Vector3(.145, .25, 0),
		Vector3(.22, .07, .015),
		right_hand,
		cloth,
		dark,
		armor,
		trim
	)
	if faction == "frontier":
		_profile(
			chest,
			"Scarf",
			Vector3(0, .30, 0),
			[
				Vector4(-.025, .085, .068, 0),
				Vector4(0, .081, .07, 0),
				Vector4(.018, .065, .056, 0),
				Vector4(.03, .062, .053, 0)
			],
			canvas,
			.08
		)
	elif faction == "helix":
		_box(head, "TempleSensor", Vector3(.085, .119, -.02), Vector3(.018, .022, .038), trim)
	# Rifle attachments share one parent so the complete weapon follows its grips.
	var rifle = _pivot(chest, "RifleReceiver", Vector3(.10, .10, -.26))
	_box(rifle, "Receiver", Vector3.ZERO, Vector3(.047, .062, .18), steel)
	_box(rifle, "EjectionPort", Vector3(.025, .009, .014), Vector3(.004, .014, .052), dark)
	_box(rifle, "RifleStock", Vector3(0, .003, .175), Vector3(.039, .064, .17), dark)
	_box(rifle, "ButtPad", Vector3(0, .003, .252), Vector3(.047, .075, .015), dark)
	var grip = _box(rifle, "PistolGrip", Vector3(0, -.05, .069), Vector3(.035, .068, .037), dark)
	grip.rotation.x = -.22
	var magazine = _box(
		rifle, "RifleMagazine", Vector3(0, -.06, -.015), Vector3(.035, .095, .056), dark
	)
	magazine.rotation.x = .10
	_box(rifle, "Handguard", Vector3(0, .004, -.135), Vector3(.052, .055, .12), armor)
	for index in range(5):
		_box(
			rifle,
			"HandguardVent",
			Vector3(.028, .006, -.09 - index * .023),
			Vector3(.004, .018, .012),
			dark
		)
		_box(rifle, "Rail", Vector3(0, .037, .05 - index * .04), Vector3(.047, .008, .016), dark)
	Kit._tube(rifle, "RifleBarrel", Vector3(0, .01, -.25), .012, .14, steel)
	Kit._tube(rifle, "FlashHider", Vector3(0, .01, -.329), .018, .025, dark)
	_box(rifle, "ReflexSight", Vector3(0, .055, .005), Vector3(.032, .037, .046), dark)
	_pivot(chest, "RifleMuzzle", Vector3(.10, .11, -.61))
	return model


static func _arm(parent, label, shoulder, elbow, hand, cloth, glove, armor, trim):
	# Separate upper and lower arm pivots. The motion solver keeps shoulders on
	# the torso and the hands on weapon-local Grip markers through aim/recoil.
	var arm = _pivot(parent, "Arm" + label, shoulder)
	var direction = (hand - shoulder).normalized()
	var distance = shoulder.distance_to(hand)
	var along = (distance * distance + .24 * .24 - .25 * .25) / (2.0 * distance)
	var pole = Vector3(-1 if label == "Left" else 1, -.8, .25)
	var outward = (pole - direction * pole.dot(direction)).normalized()
	elbow = shoulder + direction * along + outward * sqrt(maxf(0, .24 * .24 - along * along))
	var upper = elbow - shoulder
	var lower = hand - elbow
	_segment(arm, "Sleeve", Vector3.ZERO, upper, .087, cloth)
	var forearm = _pivot(arm, "Elbow" + label, upper)
	_segment(forearm, "Forearm", Vector3.ZERO, lower, .071, cloth)
	_profile(
		arm,
		"ShoulderArmor",
		Vector3(0, -.025, 0),
		[Vector4(-.049, .051, .052, 0), Vector4(.015, .055, .055, 0), Vector4(.04, .031, .034, 0)],
		armor
	)
	_team_box(
		arm,
		"ShoulderMark",
		Vector3(-.045 if label == "Left" else .045, -.03, -.014),
		Vector3(.007, .032, .04),
		trim
	)
	_box(forearm, "ElbowPad", Vector3(0, .005, .015), Vector3(.061, .042, .024), armor)
	var wrist = _pivot(forearm, "Wrist" + label, lower)
	_box(wrist, "Glove", Vector3.ZERO, Vector3(.055, .053, .068), glove)
	for index in range(3):
		_box(
			wrist,
			"Knuckle",
			Vector3(-.017 + index * .017, .025, -.012),
			Vector3(.012, .012, .024),
			glove
		)
	var grip = _pivot(parent, "Grip" + label, hand)
	grip.set_meta("shoulder", shoulder)


static func _segment(parent, label, start, end, width, material):
	var length = start.distance_to(end)
	var node = _profile(
		parent,
		label,
		start,
		[
			Vector4(-.025 if label == "Sleeve" else 0, width * .44, width * .44, 0),
			Vector4(
				.004 if label == "Sleeve" else length * .04,
				width * .6 if label == "Sleeve" else width * .46,
				width * .58 if label == "Sleeve" else width * .46,
				0
			),
			Vector4(length * .12, width * .54, width * .55, 0),
			Vector4(length * .40, width * .51, width * .51, 0),
			Vector4(length * .70, width * .44, width * .46, 0),
			Vector4(length * .82, width * .50, width * .49, 0),
			Vector4(length * .9, width * .40, width * .40, 0),
			Vector4(length, width * .36, width * .36, 0)
		],
		material,
		.035
	)
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return node


static func _pivot(parent, label, point):
	var node = Node3D.new()
	node.name = label
	node.position = point
	if parent != null:
		parent.add_child(node)
	return node


static func _material(color, label, roughness, metallic = 0.0):
	var materials = Cache.bucket("infantry_materials")
	var key = color + label
	if not materials.has(key):
		var material = StandardMaterial3D.new()
		material.resource_name = label
		material.albedo_color = Color(color)
		material.roughness = roughness
		material.metallic = metallic
		material.vertex_color_use_as_albedo = true
		if "cloth" in label or "canvas" in label:
			# Quiet, irregular fibers and broad fading remain attached to the
			# articulated mesh. Shared per finish, never rebuilt per soldier.
			material = ShaderMaterial.new()
			material.shader = load("res://source/shaders/3d/infantry_fabric.gdshader")
			material.resource_name = label
			material.set_meta("object_surface_family", "fabric")
			material.set_shader_parameter("base_color", Color(color))
			material.set_shader_parameter("base_roughness", roughness)
			material.set_shader_parameter("vertex_tint", true)
		materials[key] = material
	return materials[key]


static func _profile(parent, label, point, rings, material, folds = 0.0, roundness = .8):
	var meshes = Cache.bucket("infantry_meshes")
	# Each ring is (height, half width, half depth, depth offset). Slightly
	# squared cross sections give cloth seams and anatomical planes. Geometry
	# folds and deterministic vertex shading survive every graphics preset.
	var key = "profile" + str(rings) + str(folds) + str(roundness)
	if not meshes.has(key):
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices = []
		const SIDES = 16
		for row in range(rings.size()):
			var ring = rings[row]
			for column in range(SIDES):
				var angle = TAU * column / SIDES
				var ripple = 1.0 + folds * sin(angle * 5.0 + row * 2.3)
				var x = signf(cos(angle)) * pow(absf(cos(angle)), roundness)
				var z = signf(sin(angle)) * pow(absf(sin(angle)), roundness)
				vertices.append(Vector3(x * ring.y * ripple, ring.x, z * ring.z * ripple + ring.w))
		for row in range(rings.size() - 1):
			for column in range(SIDES):
				var a = row * SIDES + column
				var b = row * SIDES + (column + 1) % SIDES
				for index in [a, b, a + SIDES, b, b + SIDES, a + SIDES]:
					var shade = (
						.93 + .055 * sin(float(index / SIDES) * 1.7) + .015 * cos(index * 2.3)
					)
					surface.set_color(Color(shade, shade, shade, 1))
					surface.set_uv(
						Vector2(
							float(index % SIDES) / SIDES, float(index / SIDES) / (rings.size() - 1)
						)
					)
					surface.add_vertex(vertices[index])
		for row in [0, rings.size() - 1]:
			for column in range(1, SIDES - 1):
				var indices = [0, column + 1, column] if row == 0 else [0, column, column + 1]
				for index in indices:
					surface.set_color(Color(.9, .9, .9))
					surface.set_uv(Vector2.ZERO)
					surface.add_vertex(vertices[row * SIDES + index])
		# Index before smoothing to share normals along authored contours.
		surface.index()
		surface.generate_normals()
		meshes[key] = surface.commit()
	return Kit._mesh(parent, label, point, meshes[key], material)


static func _box(parent, label, point, size, material):
	var meshes = Cache.bucket("infantry_meshes")
	var key = "box" + str(size)
	if not meshes.has(key):
		meshes[key] = Kit._beveled_box(size)
	return Kit._mesh(parent, label, point, meshes[key], material)


static func _team_box(parent, label, point, size, material):
	var meshes = Cache.bucket("infantry_meshes")
	var key = "team" + str(size) + str(material.albedo_color)
	if not meshes.has(key):
		var team = material.duplicate()
		team.resource_name = "TeamColor_Infantry"
		var mesh = Kit._beveled_box(size)
		mesh.surface_set_material(0, team)
		meshes[key] = mesh
	return Kit._mesh(parent, label, point, meshes[key], null)
