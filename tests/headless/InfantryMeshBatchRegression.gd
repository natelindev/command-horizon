extends SceneTree

var failures = []


func _initialize():
	_run.call_deferred()


func _run():
	var batching = load("res://source/match/units/traits/InfantryMeshBatch.gd")
	var first = _unbatched_model("bastion", "Infantry")
	var before = _geometry(first)
	var original_count = first.find_children("*", "MeshInstance3D", true, false).size()
	batching.apply(first)
	var after = _geometry(first)
	var final_count = first.find_children("*", "MeshInstance3D", true, false).size()
	_check(before == after, "Batching changed material families or triangle counts")
	_check(final_count <= original_count * .65, "Batching did not remove enough draw instances")
	for path in [
		"Chest/Jacket",
		"Chest/RifleReceiver",
		"Chest/RifleReceiver/RifleStock",
		"Chest/Head/Face",
		"Chest/Head/BallisticLens",
		"Chest/UnitMark",
		"Chest/GripLeft",
		"Chest/RifleMuzzle",
		"Hips/HipLeft/KneeLeft/AnkleLeft",
		"Chest/ArmRight/ElbowRight/WristRight"
	]:
		_check(first.has_node(path), "Batching removed semantic node: " + path)
	var second = _unbatched_model("bastion", "Infantry")
	batching.apply(second)
	_check(
		(
			first.get_node("Chest/InfantryDetailBatch").mesh
			== second.get_node("Chest/InfantryDetailBatch").mesh
		),
		"Identical soldiers did not share generated batch mesh"
	)
	var count = final_count
	batching.apply(first)
	_check(
		first.find_children("*", "MeshInstance3D", true, false).size() == count,
		"Batching was not idempotent"
	)
	first.free()
	second.free()
	_check_roster(batching)
	_check_transforms(batching)
	for failure in failures:
		push_error(failure)
	print(
		(
			"Infantry batching: %d -> %d mesh instances, %d failures"
			% [original_count, final_count, failures.size()]
		)
	)
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _unbatched_model(faction, role):
	# Construct before the production FactionCatalog batching integration, so
	# this regression exercises the first merge, including role equipment.
	var roster = load("res://source/match/BastionCatalog.gd")
	var unit = load(roster.scene_path(role)).instantiate()
	var geometry = unit.get_node("Geometry")
	for child in geometry.get_children():
		child.free()
	var rig = load("res://source/match/units/traits/InfantryModel.gd").build(faction, role)
	geometry.add_child(rig)
	load("res://source/match/units/traits/InfantryEquipment.gd").equip(unit, faction)
	load("res://source/match/ObjectMaterials.gd").apply(rig)
	geometry.remove_child(rig)
	unit.free()
	return rig


func _check_roster(batching):
	var roster = load("res://source/match/BastionCatalog.gd")
	var mercenaries = load("res://source/match/world/MercenaryCatalog.gd")
	var carried = load("res://source/match/units/traits/InfantryMotion.gd").CARRIED
	for faction in ["bastion", "helix", "frontier"]:
		for role in roster.INFANTRY_ROLES + mercenaries.ROLES:
			var rig = _unbatched_model(faction, role)
			_check_weapon_materials(faction, role, rig)
			var before = _geometry(rig)
			var protected = {}
			for node in rig.find_children("*", "Node3D", true, false):
				if (
					str(node.name) in carried
					or str(node.name) in ["Jacket", "Face", "BallisticLens"]
				):
					protected[rig.get_path_to(node)] = node
			batching.apply(rig)
			var label = faction + "/" + role
			_check(_geometry(rig) == before, label + ": changed material triangle totals")
			for path in protected:
				_check(
					rig.get_node_or_null(path) == protected[path], label + ": removed " + str(path)
				)
			rig.free()


func _check_weapon_materials(faction, role, rig):
	var optics := []
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_active_material(0).resource_name == "Energy optic":
			optics.append(mesh)
	if optics.is_empty():
		return
	var other = _unbatched_model(faction, role)
	var matching: Material
	for mesh in other.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_active_material(0).resource_name == "Energy optic":
			matching = mesh.get_active_material(0)
			break
	for mesh in optics:
		var material = mesh.get_active_material(0)
		_check(material == matching, "Identical energy optics split model batches: " + role)
		_check(
			(
				material is StandardMaterial3D
				and material.albedo_color.is_equal_approx(Color("42dce4"))
				and material.emission_enabled
				and material.emission.is_equal_approx(Color("25bccb"))
				and is_equal_approx(material.emission_energy_multiplier, .65)
			),
			"Shared optic changed its finish: " + role
		)
	other.free()


func _geometry(parent):
	var families = {}
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var material = node.get_active_material(0)
		var family = material.get_meta("object_surface_family", material.resource_name)
		var arrays = node.mesh.surface_get_arrays(0)
		var indices = arrays[Mesh.ARRAY_INDEX]
		var count = (
			indices.size()
			if indices != null and not indices.is_empty()
			else arrays[Mesh.ARRAY_VERTEX].size()
		)
		families[family] = families.get(family, 0) + count
	return families


func _check_transforms(batching):
	var parent = Node3D.new()
	var material = StandardMaterial3D.new()
	material.resource_name = "Infantry cloth"
	var source = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1])
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var poses = [
		Transform3D(
			Basis.from_euler(Vector3(.2, .4, .1)).scaled(Vector3(2, 1, .5)), Vector3(1, 2, 3)
		),
		Transform3D(Basis.from_scale(Vector3(-1, 2, 1)), Vector3(-2, 1, 0))
	]
	for pose in poses:
		var node = MeshInstance3D.new()
		node.mesh = source
		node.material_override = material
		node.transform = pose
		parent.add_child(node)
	batching.apply(parent)
	_check(parent.get_child_count() == 1, "Synthetic geometry did not merge")
	var merged = parent.get_child(0).mesh.surface_get_arrays(0)
	for piece in range(2):
		for vertex in range(3):
			var index = piece * 3 + vertex
			_check(
				merged[Mesh.ARRAY_VERTEX][index].is_equal_approx(
					poses[piece] * arrays[Mesh.ARRAY_VERTEX][vertex]
				),
				"Vertex transform changed"
			)
			var normal = (
				(poses[piece].basis.inverse().transposed() * arrays[Mesh.ARRAY_NORMAL][vertex])
				. normalized()
			)
			# ArrayMesh stores normals with octahedral quantization.
			_check(
				merged[Mesh.ARRAY_NORMAL][index].dot(normal) > .99999, "Normal transform changed"
			)
			_check(
				merged[Mesh.ARRAY_COLOR][index] == arrays[Mesh.ARRAY_COLOR][vertex],
				"Vertex tint changed"
			)
			_check(
				merged[Mesh.ARRAY_TEX_UV][index] == arrays[Mesh.ARRAY_TEX_UV][vertex], "UV changed"
			)
	_check(
		merged[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 2, 1, 3, 4, 5]),
		"Reflected winding was not corrected"
	)
	_check(
		is_equal_approx(merged[Mesh.ARRAY_TANGENT][15], -1.0),
		"Reflected tangent handedness changed"
	)
	parent.free()


func _check(condition, message):
	if not condition:
		failures.append(message)
