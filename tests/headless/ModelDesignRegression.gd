extends "res://tests/headless/InfantryMotionRegression.gd"

## Reproduce design/model mismatches using actual spawned battle units.
## Equipment, firing origins and grips must agree after batching and posing.
const EXPECTED = {
	"helix":
	{
		"Infantry": ["PlasmaCarbine"],
		"AssaultInfantry": ["PulseRepeaterLeft", "PulseRepeaterRight"],
		"RocketInfantry": ["IonLauncher"],
		"SniperInfantry": ["ThermalLance"],
		"Hero": ["PhaseLance"],
		"MercenaryWarden": ["BreachShotgun"],
	},
	"frontier": {"AssaultInfantry": ["TrenchShotgun"], "MercenaryWarden": ["BreachShotgun"]},
	"bastion": {"MercenaryWarden": ["BreachShotgun"]},
}


func _run():
	Factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in EXPECTED:
		await _fixture(faction)
		for role in EXPECTED[faction]:
			var unit = _soldier(role, human, Vector3(40, 0, 10))
			_check_equipment(unit, EXPECTED[faction][role])
			_test_articulation(unit)
			if faction == "helix" and role == "AssaultInfantry":
				_check_paired_emitters(unit)
			unit.queue_free()
			await _frames(2)
		if faction == "helix":
			_check_defense()
		await _close()
	for message in errors:
		push_error(message)
	print("Model design alignment: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check_equipment(unit, expected):
	var label = unit.player.faction + "/" + unit.type
	var geometry = unit.get_node("Geometry")
	var carry = geometry.get_node("InfantryRig/Chest/WeaponCarry")
	var weapon = carry.get_node_or_null("ServiceWeapon")
	_check(weapon != null, label + ": missing faction weapon assembly")
	if weapon == null:
		return
	_check(not carry.get_node("RifleReceiver").visible, label + ": old rifle overlaps new weapon")
	_check(weapon.get_child_count() == expected.size(), label + ": incorrect weapon count")
	var muzzles = geometry.find_children("*Muzzle", "Node3D", true, false)
	_check(muzzles.size() == expected.size(), label + ": obsolete or missing firing origin")
	for name in expected:
		var gun = weapon.get_node_or_null(name)
		_check(gun != null, label + ": wrong weapon silhouette " + name)
		if gun == null:
			continue
		_check(
			gun.find_children("*", "MeshInstance3D", true, false).size() >= 4,
			label + ": empty weapon"
		)
		_check(
			gun.find_children("*Muzzle", "Node3D", true, false).size() == 1,
			label + ": detached emitter"
		)
	if unit.type == "AssaultInfantry":
		_check(
			geometry.find_child("BreachingShield", true, false) == null,
			label + ": generic shield returned"
		)
	if unit.type == "MercenaryWarden":
		_check(geometry.find_child("TowerShield", true, false) != null, "Warden lost its shield")
	if unit.type in ["SniperInfantry", "Hero"]:
		_check(
			geometry.find_child("Suppressor", true, false) == null,
			label + ": ballistic suppressor on beam weapon"
		)
	var visual = unit.get_node("BastionVisuals")
	var motion = visual._infantry_motion
	var attachments = {}
	for muzzle in muzzles:
		attachments[muzzle] = weapon.global_transform.affine_inverse() * muzzle.global_transform
	var before = weapon.global_transform
	for frame in 60:
		motion.advance(1.0 / 60, .025, frame / 60.0, 0, .5, 1)
	_check(not weapon.global_transform.is_equal_approx(before), label + ": weapon does not animate")
	for muzzle in muzzles:
		var attached = weapon.global_transform.affine_inverse() * muzzle.global_transform
		_check(
			attached.is_equal_approx(attachments[muzzle]),
			label + ": emitter left weapon during animation"
		)
	for arm in motion.arms:
		_check(
			arm.wrist.global_position.distance_to(arm.grip.global_position) < .025,
			label + ": hand missed weapon grip"
		)
	visual.fire_recoil()
	_check(weapon.is_ancestor_of(visual._muzzle), label + ": shot uses obsolete muzzle")
	_check(
		visual._projectile_origin.global_position.is_equal_approx(visual._muzzle.global_position),
		label + ": projectile starts outside weapon"
	)


func _check_paired_emitters(unit):
	var visual = unit.get_node("BastionVisuals")
	_check(visual._paired_muzzles.size() == 2, unit.type + ": missing paired emitters")
	visual.fire_recoil()
	var first = visual._muzzle
	visual.fire_recoil()
	var second = visual._muzzle
	_check(first != second, unit.type + ": both weapons use the same muzzle")
	_check(
		first.global_position.distance_to(second.global_position) > .15,
		unit.type + ": paired emitters overlap"
	)
	_check(
		visual._projectile_origin.global_position.is_equal_approx(second.global_position),
		unit.type + ": second emitter is cosmetic only"
	)


func _check_defense():
	var tower = _soldier("AntiGroundTurret", human, Vector3(40, 0, 20))
	var crystal = tower.find_child("*PrismCrystal", true, false)
	var focus = tower.find_child("*PrismFocus", true, false)
	_check(crystal != null and focus != null, "Prism pylon still uses old cannon model")
	_check(
		tower.find_child("*BarrelPivot", true, false) == null, "Prism pylon retains cannon barrel"
	)
	var visual = tower.get_node("BastionVisuals")
	if focus != null:
		_check(focus.is_ancestor_of(visual._muzzle), "Prism beam starts outside optical focus")
	visual.fire_recoil()
	_check(
		visual._projectile_origin.global_position.is_equal_approx(visual._muzzle.global_position),
		"Prism beam muzzle did not synchronize"
	)
	_check(
		"cannon" not in Factions.description("helix", "AntiGroundTurret"),
		"Prism pylon inherits cannon description"
	)
	var needle = _soldier("Tank", human, Vector3(45, 0, 20))
	_check_paired_emitters(needle)
	for unit in [tower, needle]:
		for mesh in unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				_check(
					not mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR].is_empty(),
					unit.type + ": lost baked weathering"
				)
