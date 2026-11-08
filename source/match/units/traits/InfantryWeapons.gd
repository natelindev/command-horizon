extends RefCounted

## Faction equipment on the production infantry rig. Coordinates are chest-local;
## one carried root keeps every lens, stock and muzzle attached through all poses.
const Kit = preload("res://source/match/units/traits/InfantryEquipment.gd")
const Cache = preload("res://source/utils/RuntimeCache.gd")


static func equip(chest: Node3D, role: String, faction: String):
	chest.get_node("RifleReceiver").hide()
	chest.get_node("RifleMuzzle").name = "StockEmitter"
	var weapon = _pivot(chest, "ServiceWeapon", Vector3.ZERO)
	var dark = _material("Weapon graphite", "293638", .6)
	var metal = _material("Weapon titanium", "717b79", .55)
	var ceramic = _material("Weapon ceramic", "a2b5b8", .2)
	var cyan = _material("Energy optic", "42dce4", .25, Color("25bccb"), .65)
	match role:
		"Infantry":
			_plasma_carbine(weapon, dark, ceramic, cyan)
			_grips(chest, Vector3(.08, .08, -.34), Vector3(.10, .06, -.16))
		"AssaultInfantry":
			if faction == "helix":
				for side in [-1, 1]:
					_pulse_repeater(weapon, side, dark, ceramic, cyan)
				_grips(chest, Vector3(-.19, .035, -.16), Vector3(.19, .035, -.16))
			else:
				_shotgun(weapon, false, dark, metal)
				_grips(chest, Vector3(.10, .075, -.38), Vector3(.10, .04, -.15))
		"MercenaryWarden":
			_shotgun(weapon, true, dark, metal)
			_grips(chest, Vector3(-.25, .025, -.11), Vector3(.10, .04, -.15))
		"RocketInfantry":
			_ion_launcher(weapon, dark, ceramic, cyan)
			_grips(chest, Vector3(.17, .10, -.27), Vector3(.22, .11, -.12))
		"SniperInfantry", "Hero":
			_beam_lance(weapon, role == "Hero", dark, metal, ceramic, cyan)
			_grips(chest, Vector3(.10, .075, -.38), Vector3(.10, .045, -.16))


static func _plasma_carbine(parent, dark, ceramic, cyan):
	var gun = _pivot(parent, "PlasmaCarbine", Vector3(.10, .10, -.26))
	Kit._box(gun, "CapacitorReceiver", Vector3.ZERO, Vector3(.065, .075, .24), dark)
	Kit._box(gun, "ShoulderStock", Vector3(0, .005, .18), Vector3(.045, .065, .15), ceramic)
	Kit._box(gun, "TriggerGrip", Vector3(0, -.045, .10), Vector3(.035, .07, .045), dark)
	Kit._box(gun, "PowerCell", Vector3(0, -.065, -.02), Vector3(.055, .08, .08), ceramic)
	for side in [-1, 1]:
		Kit._box(
			gun,
			"InductionShroud",
			Vector3(side * .039, .003, -.17),
			Vector3(.024, .055, .22),
			ceramic
		)
		Kit._box(
			gun, "CellIndicator", Vector3(side * .034, .015, .01), Vector3(.008, .018, .12), cyan
		)
	Kit._tube(gun, "PlasmaChamber", Vector3(0, .005, -.20), .024, .19, cyan)
	Kit._tube(gun, "EmitterCollar", Vector3(0, .005, -.315), .038, .05, dark)
	Kit._tube(gun, "PlasmaLens", Vector3(0, .005, -.344), .026, .009, cyan)
	_muzzle(gun, "Muzzle", Vector3(0, .005, -.352))


static func _pulse_repeater(parent, side, dark, ceramic, cyan):
	var gun = _pivot(
		parent,
		"PulseRepeaterLeft" if side < 0 else "PulseRepeaterRight",
		Vector3(side * .19, .075, -.24)
	)
	Kit._box(gun, "PulseReceiver", Vector3.ZERO, Vector3(.065, .072, .20), dark)
	Kit._box(gun, "TriggerGrip", Vector3(0, -.05, .08), Vector3(.04, .08, .05), dark)
	Kit._box(gun, "PowerCell", Vector3(0, -.053, -.03), Vector3(.053, .065, .075), ceramic)
	Kit._box(gun, "PulseShroud", Vector3(0, .018, -.135), Vector3(.082, .055, .16), ceramic)
	for x in [-.044, .044]:
		Kit._box(gun, "ChargeStrip", Vector3(x, .012, -.12), Vector3(.009, .023, .12), cyan)
	Kit._tube(gun, "EmitterCollar", Vector3(0, .008, -.23), .035, .048, dark)
	Kit._tube(gun, "PulseLens", Vector3(0, .008, -.257), .025, .009, cyan)
	_muzzle(gun, "LeftMuzzle" if side < 0 else "RightMuzzle", Vector3(0, .008, -.266))


static func _ion_launcher(parent, dark, ceramic, cyan):
	var gun = _pivot(parent, "IonLauncher", Vector3(.22, .13, -.15))
	Kit._box(gun, "IonChamber", Vector3.ZERO, Vector3(.14, .135, .56), dark)
	for side in [-1, 1]:
		Kit._box(
			gun, "IonShroud", Vector3(side * .078, .018, -.05), Vector3(.035, .11, .50), ceramic
		)
		for z in [-.21, -.11, -.01]:
			Kit._box(
				gun, "InductionBand", Vector3(side * .10, .02, z), Vector3(.012, .07, .025), cyan
			)
	Kit._box(gun, "RearCell", Vector3(0, 0, .27), Vector3(.16, .14, .12), ceramic)
	Kit._box(gun, "TriggerGrip", Vector3(0, -.065, .03), Vector3(.04, .055, .065), dark)
	Kit._tube(gun, "IonFocus", Vector3(0, 0, -.32), .082, .12, dark)
	Kit._tube(gun, "IonLens", Vector3(0, 0, -.385), .062, .012, cyan)
	Kit._box(gun, "Optic", Vector3(0, .10, -.08), Vector3(.055, .045, .10), dark)
	Kit._box(gun, "TargetLens", Vector3(0, .10, -.135), Vector3(.036, .025, .008), cyan)
	_muzzle(gun, "Muzzle", Vector3(0, 0, -.397))


static func _beam_lance(parent, hero, dark, metal, ceramic, cyan):
	var gun = _pivot(parent, "PhaseLance" if hero else "ThermalLance", Vector3(.10, .095, -.26))
	Kit._box(gun, "LanceReceiver", Vector3.ZERO, Vector3(.07, .085, .23), dark)
	Kit._box(gun, "ShoulderStock", Vector3(0, 0, .18), Vector3(.05, .07, .16), dark)
	Kit._box(gun, "TriggerGrip", Vector3(0, -.05, .10), Vector3(.035, .07, .045), dark)
	Kit._box(gun, "Capacitor", Vector3(0, -.06, -.015), Vector3(.06, .055, .11), ceramic)
	var reach = .60 if hero else .49
	for side in [-1, 1]:
		Kit._box(
			gun,
			"FocusingRail",
			Vector3(side * .039, .005, -.12 - reach / 2),
			Vector3(.022, .045, reach),
			ceramic
		)
		Kit._box(
			gun,
			"LensSpine",
			Vector3(side * .024, .005, -.12 - reach / 2),
			Vector3(.009, .018, reach * .85),
			cyan
		)
	Kit._tube(gun, "CoherentCore", Vector3(0, .005, -.12 - reach / 2), .017, reach, cyan)
	for z in [-.18, -.31, -.44]:
		Kit._box(gun, "HeatSink", Vector3(0, -.028, z), Vector3(.11, .025, .025), metal)
	Kit._box(gun, "Rangefinder", Vector3(0, .075, -.04), Vector3(.065, .045, .15), dark)
	Kit._box(gun, "OpticalWindow", Vector3(0, .075, -.12), Vector3(.042, .026, .009), cyan)
	var tip = -.14 - reach
	Kit._tube(gun, "LensCollar", Vector3(0, .005, tip), .052, .04, dark)
	Kit._tube(gun, "FocusLens", Vector3(0, .005, tip - .025), .037, .009, cyan)
	_muzzle(gun, "Muzzle", Vector3(0, .005, tip - .035))


static func _shotgun(parent, warden, dark, metal):
	var gun = _pivot(
		parent, "BreachShotgun" if warden else "TrenchShotgun", Vector3(.10, .09, -.24)
	)
	var wood = _material("Weapon wood", "786044", .05)
	var furniture = dark if warden else wood
	Kit._box(gun, "Receiver", Vector3.ZERO, Vector3(.06, .07, .22), metal)
	Kit._box(gun, "Stock", Vector3(0, -.008, .19), Vector3(.045, .07, .19), furniture)
	Kit._box(gun, "TriggerGrip", Vector3(0, -.055, .09), Vector3(.035, .07, .04), furniture)
	Kit._tube(gun, "ShotgunBarrel", Vector3(0, .012, -.27), .024, .36, dark)
	Kit._tube(gun, "MagazineTube", Vector3(0, -.039, -.24), .022, .29, metal)
	Kit._box(gun, "PumpForeend", Vector3(0, -.033, -.15), Vector3(.069, .065, .15), furniture)
	for z in [-.20, -.17, -.14, -.11]:
		Kit._box(gun, "PumpRib", Vector3(0, -.035, z), Vector3(.074, .068, .009), dark)
	Kit._tube(gun, "BarrelBore", Vector3(0, .012, -.455), .019, .012, metal)
	Kit._box(gun, "FrontSight", Vector3(0, .043, -.41), Vector3(.015, .026, .022), metal)
	for z in [-.07, -.025, .02, .065]:
		Kit._tube(gun, "ShellCarrier", Vector3(-.04, -.002, z), .013, .055, wood).rotation.x = 0
	_muzzle(gun, "Muzzle", Vector3(0, .012, -.466))


static func _grips(chest, left, right):
	chest.get_node("GripLeft").position = left
	chest.get_node("GripRight").position = right


static func _pivot(parent, label, point):
	var node = Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	return node


static func _muzzle(parent, label, point):
	var node = Marker3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)


static func _material(label, color, metallic, emission := Color.BLACK, energy := 0.0):
	# These authored finishes are immutable. Sharing the emissive optics also
	# lets identical soldiers share their complete articulated model batch.
	var materials = Cache.bucket("infantry_weapon_materials")
	var key = [label, color, metallic, emission, energy]
	if materials.has(key):
		return materials[key]
	var material = StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_color = Color(color)
	material.metallic = metallic
	material.roughness = .55
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	materials[key] = material
	return material
