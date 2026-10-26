extends SceneTree

# Production wrecks must stay above the floor through every fall direction.
var failures = []
var scenarios = 0


func _initialize():
	_run.call_deferred()


func _run():
	var factions = load("res://source/match/FactionCatalog.gd")
	var roster = load("res://source/match/BastionCatalog.gd")
	var mercenaries = load("res://source/match/world/MercenaryCatalog.gd")
	var motion_type = load("res://source/match/units/traits/InfantryMotion.gd")
	var effects = load("res://source/match/effects/CombatEffects.gd").new()
	for faction in factions.IDS:
		for role in roster.INFANTRY_ROLES + mercenaries.ROLES:
			var source = load(roster.scene_path(role)).instantiate()
			factions.prepare_model(source, faction)
			var geometry = source.get_node("Geometry")
			source.remove_child(geometry)
			source.free()
			var unit = Node3D.new()
			unit.add_child(geometry)
			root.add_child(unit)
			var motion = motion_type.new()
			motion.setup(unit, .3, role)
			for style in range(3):
				var label = "%s/%s/style%d" % [faction, role, style]
				# Diagonal fall axes expose Euler pitch/roll composition errors.
				var tilt = [Vector3(-1.1, .08, .65), Vector3(1.2, -.06, -.6), Vector3(.4, .05, 1.4)][style]
				var entry = _entry(geometry, true, false, true, style, tilt)
				for frame in range(21):
					entry.age = frame / 20.0
					effects._update_wreck(entry)
					_check(_lowest_vertex(geometry) >= .019, label + ": mesh penetrated ground")
				_check(entry.has("ground_clearance"), label + ": final ground offset not cached")
				_check(_lowest_vertex(geometry) < .021, label + ": corpse floats above floor")
				_check(
					absf(geometry.basis.y.normalized().y) < .001, label + ": body rests diagonally"
				)
				var direction = (
					Basis(Vector3.UP, entry.rotation.y + tilt.y)
					* Vector3(-tilt.z, 0, tilt.x).normalized()
				)
				_check(
					geometry.basis.y.normalized().dot(direction) > .999,
					label + ": fall heading changed"
				)
				var rested = geometry.position
				var clearance = entry.ground_clearance
				entry.age = 10.0
				effects._update_wreck(entry)
				_check(
					geometry.position.is_equal_approx(rested),
					label + ": corpse moved before sink delay"
				)
				_check(entry.ground_clearance == clearance, label + ": changed cached clearance")
				entry.age = 17.0
				effects._update_wreck(entry)
				_check(
					is_equal_approx(geometry.position.y, rested.y - .25),
					label + ": deferred sinking changed"
				)
				scenarios += 1
			if faction == "helix" and role == "RocketInfantry":
				_check_rocket_support(geometry, effects)
			unit.free()
	# Vehicles, aircraft and structures retain the original positional settle.
	for kind in ["vehicle", "aircraft", "structure"]:
		var parent = Node3D.new()
		root.add_child(parent)
		var geometry = Node3D.new()
		parent.add_child(geometry)
		var mobile = kind != "structure"
		var airborne = kind == "aircraft"
		var entry = _entry(geometry, false, airborne, mobile, 0, Vector3(.2, 0, .1))
		entry.origin = Vector3(0, 2.0, 0)
		entry.age = .5
		effects._update_wreck(entry)
		var settle = .25 if airborne else .5
		var ground = .02 if mobile else 1.82
		_check(
			is_equal_approx(geometry.position.y, lerpf(2.0, ground, settle)),
			kind + ": fall height changed"
		)
		_check(not entry.has("ground_bounds"), kind + ": infantry bounds scan applied")
		parent.free()
	effects.free()
	for failure in failures:
		push_error(failure)
	print(
		(
			"Infantry death ground: %d faction/role/fall scenarios, %d failures"
			% [scenarios, failures.size()]
		)
	)
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _entry(geometry, infantry, airborne, mobile, style, tilt):
	return {
		"node": geometry,
		"origin": Vector3.ZERO,
		"rotation": Vector3(0, .4, 0),
		"age": 0.0,
		"motion":
		{
			"duration": 1.0,
			"infantry": infantry,
			"airborne": airborne,
			"mobile": mobile,
			"style": style,
			"tilt": tilt,
			"slide": Vector3(.1, 0, .05),
			"sink_start": 6.0,
		},
	}


func _lowest_vertex(geometry):
	var lowest = INF
	for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and mesh.is_visible_in_tree():
			lowest = minf(lowest, _mesh_lowest(mesh))
	return lowest


func _mesh_lowest(mesh):
	var lowest = INF
	var transform = mesh.global_transform
	for surface in mesh.mesh.get_surface_count():
		for point in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			lowest = minf(lowest, (transform * point).y)
	return lowest


func _check_rocket_support(geometry, effects):
	# Reproduce the rendered failure: a dangling launcher optic used to be the
	# sole ground contact while the body hovered more than .13 above the floor.
	var profile = load("res://source/match/units/traits/UnitMotionProfile.gd").new(124)
	var entry = _entry(geometry, true, false, true, 0, Vector3.ZERO)
	entry.rotation = Vector3.ZERO
	entry.motion = profile.death_motion(true, false, true, Vector3(0, 0, -1))
	entry.age = entry.motion.duration
	effects._update_wreck(entry)
	var chest = geometry.get_node("InfantryRig/Chest")
	var torso_lowest = INF
	for child in chest.get_children():
		if child is MeshInstance3D and child.is_visible_in_tree():
			torso_lowest = minf(torso_lowest, _mesh_lowest(child))
	var optic_lowest = _mesh_lowest(chest.get_node("WeaponCarry/Optic"))
	_check(torso_lowest < .1, "Rocket corpse torso floats above supporting arm")
	_check(optic_lowest >= torso_lowest, "Rocket corpse is propped up by optic")
	print("Rocket corpse support: torso=%.3f optic=%.3f" % [torso_lowest, optic_lowest])


func _check(condition, message):
	if not condition and not failures.has(message):
		failures.append(message)
