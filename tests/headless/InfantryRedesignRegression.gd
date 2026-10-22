extends SceneTree

# Exercise production geometry and shoulder/elbow/wrist tracking without a
# battlefield. Gameplay integration and foot planting are covered by the
# InfantryMotionRegression and UnitAnimationRegression suites.
var failures = []
var models = 0
var largest_triangle_count = 0


func _initialize():
	_run.call_deferred()


func _run():
	var factions = load("res://source/match/FactionCatalog.gd")
	var roster = load("res://source/match/BastionCatalog.gd")
	var motion_type = load("res://source/match/units/traits/InfantryMotion.gd")
	var mercenaries = load("res://source/match/world/MercenaryCatalog.gd")
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
			var label = faction + "/" + role
			var rig = geometry.get_node("InfantryRig")
			_check(
				rig.has_node("Chest/Head/BallisticLens"), label + ": missing modeled eye protection"
			)
			_check(rig.has_node("Chest/WeaponCarry/GripLeft"), label + ": missing left grip")
			var faces = rig.find_children("Face", "MeshInstance3D", true, false)
			_check(
				faces.size() == 1 and faces[0].mesh is ArrayMesh,
				label + ": primitive head returned"
			)
			var triangles = 0
			for mesh in rig.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					var arrays = mesh.mesh.surface_get_arrays(surface)
					var indices = arrays[Mesh.ARRAY_INDEX]
					triangles += (
						(
							indices.size()
							if indices != null and indices.size() > 0
							else arrays[Mesh.ARRAY_VERTEX].size()
						)
						/ 3
					)
			largest_triangle_count = maxi(largest_triangle_count, triangles)
			_check(triangles < 18000, label + ": exceeded infantry geometry budget")
			var authority = unit.transform
			for state in [
				Vector2(0, 0), Vector2(1.7, 0), Vector2(0, 1), Vector2(2.5, 1), Vector2(0, 0)
			]:
				for frame in range(90):
					var recoil = maxf(0, 1.0 - frame / 8.0) if state.y == 1 else 0.0
					motion.advance(1.0 / 60, state.x / 60, frame / 60.0, .1, recoil, state.y)
					for arm in motion.arms:
						_check(
							arm.upper.position.is_equal_approx(arm.grip.get_meta("shoulder")),
							label + ": shoulder detached from torso"
						)
						var grip_distance = arm.wrist.global_position.distance_to(
							arm.grip.global_position
						)
						_check(
							grip_distance < .025, label + ": hand left grip (%0.3f)" % grip_distance
						)
						_check(arm.lower.basis.is_finite(), label + ": invalid elbow solve")
					_check(unit.transform == authority, label + ": animation moved gameplay root")
			motion.raise_for_shot()
			for arm in motion.arms:
				_check(
					arm.wrist.global_position.distance_to(arm.grip.global_position) < .025,
					label + ": first shot detached grip"
				)
			for style in range(3):
				for progress in [0.0, .25, .5, .75, 1.0]:
					motion_type.pose_death(geometry, progress, style)
					for arm in motion.arms:
						_check(
							arm.wrist.global_position.distance_to(arm.grip.global_position) < .025,
							label + ": death detached grip"
						)
			unit.free()
			models += 1
	for failure in failures:
		push_error(failure)
	print(
		(
			"Infantry redesign: %d models, %d maximum triangles, %d failures"
			% [models, largest_triangle_count, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)


func _check(condition, message):
	if not condition and not failures.has(message):
		failures.append(message)
