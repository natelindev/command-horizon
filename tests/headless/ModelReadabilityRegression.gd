extends "res://tests/headless/UnitAnimationRegression.gd"

const ROLES = [
	"Worker",
	"Tank",
	"RepairRobot",
	"CombatRobot",
	"AdvancedTank",
	"AntiAirVehicle",
	"Drone",
	"Helicopter",
	"Fighter",
	"Bomber"
]
const BUILDINGS = {
	"temperate":
	[
		"Farmhouse",
		"Barn",
		"Sawmill",
		"WaterMill",
		"CottageA",
		"CottageB",
		"VillageChurch",
		"GrainElevator",
		"MetalSilos"
	],
	"cold": ["FjordHouseRed", "FjordHouseOchre", "MountainHut", "Boathouse", "FjordChapel"]
}
var _lod_surfaces = 0
var _batch_mesh_script
var _mesh_lods_script


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_batch_mesh_script = load("res://source/match/rendering/RigidBatchMesh.gd")
	_mesh_lods_script = load("res://source/match/rendering/RigidMeshLods.gd")
	_check_lod_transforms()
	var catalog = load("res://source/match/FactionCatalog.gd")
	for faction in ["bastion", "helix", "frontier"]:
		for role in ROLES:
			var unit = load(Catalog.scene_path(role)).instantiate()
			var original_path = unit.get_node("Geometry").get_child(0).scene_file_path
			var collision = unit.get_node("CollisionShape3D").shape
			var radius = unit.radius
			var nav_radius = unit.get_node("Movement").radius
			catalog.prepare_model(unit, faction)
			var geometry = unit.get_node("Geometry")
			var bounds = catalog._bounds(geometry, Transform3D.IDENTITY)
			var maximum = radius * 1.85
			if Catalog.is_aircraft(role):
				maximum *= 1.35
			if faction == "frontier" and role == "AdvancedTank":
				maximum *= 1.1
			var label = faction + "/" + role
			if (
				faction == "bastion"
				and role not in ["AdvancedTank", "CombatRobot", "AntiAirVehicle"]
			):
				_check(
					geometry.get_child(0).scene_file_path == original_path,
					label + ": normalization replaced the current asset with a legacy model"
				)
			_check(
				absf(maxf(bounds.size.x, bounds.size.z) - maximum) < .002,
				label + ": model bypasses the shared sizing policy"
			)
			_check(absf(bounds.position.y) < .002, label + ": model is not grounded")
			_check(
				Vector2(bounds.get_center().x, bounds.get_center().z).length() < .002,
				label + ": model is offset from its footprint"
			)
			_check(
				(
					unit.radius == radius
					and unit.get_node("Movement").radius == nav_radius
					and unit.get_node("CollisionShape3D").shape == collision
				),
				label + ": model normalization changed gameplay collision"
			)
			if role == "Tank" and faction == "bastion":
				_check(
					_triangles(geometry) <= 3200,
					"Bastion tank exceeds battle-scale triangle budget"
				)
			if (
				faction == "frontier"
				and role in ["Tank", "AdvancedTank", "Worker", "RepairRobot", "CombatRobot"]
			):
				_check(_triangles(geometry) <= 4000, label + ": excessive wheel geometry")
			if role in ["Tank", "AdvancedTank"]:
				_check_lods(geometry, label)
			unit.free()
	_check(_lod_surfaces >= 6, "Imported vehicle LODs were lost during batching")
	for kit in BUILDINGS:
		for name in BUILDINGS[kit]:
			var model = (
				load("res://assets/models/environment/%s/%s.glb" % [kit, name]).instantiate()
			)
			var bounds = catalog._bounds(model, Transform3D.IDENTITY)
			_check(
				bounds.end.y >= 3.1 and bounds.end.y <= 4.501,
				kit + "/" + name + ": oversized civilian roofline"
			)
			model.free()
	await _fixture("bastion")
	var tank = _spawn("Tank", 0, Vector3(30, 0, 20))
	for mesh in tank.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("animated_track"):
			continue
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			_check(
				material.next_pass != null and material.next_pass.has_meta("unit_occlusion"),
				"Mobile geometry is missing its visibility-owned occlusion pass"
			)
			_check(
				mesh.mesh.surface_get_material(surface).next_pass == null,
				"Occlusion pass mutated shared imported materials"
			)
	tank.queue_free()
	await _close()
	for message in _errors:
		push_error(message)
	print(
		(
			"Model readability regression: %d failures, %d batched LOD surfaces"
			% [_errors.size(), _lod_surfaces]
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _triangles(geometry):
	var result = 0
	for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface)
			result += arrays[Mesh.ARRAY_INDEX].size() / 3
	return result


func _check_lod_transforms():
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[Vector3.ZERO, Vector3.RIGHT, Vector3(1, 0, 1), Vector3.BACK]
	)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES, arrays, [], {1.0: PackedInt32Array([0, 1, 2])}
	)
	mesh.surface_set_material(0, StandardMaterial3D.new())
	var reflected = MeshInstance3D.new()
	reflected.mesh = mesh
	reflected.scale = Vector3(-2, 2, 2)
	var small = MeshInstance3D.new()
	small.mesh = mesh
	small.scale = Vector3.ONE * .5
	var builder = _batch_mesh_script.new()
	builder.setup(ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBAF)))
	var merged = builder.merge([[reflected, reflected.transform, 0], [small, small.transform, 1]])
	var levels = _mesh_lods_script.read(merged, 0)
	_check(levels.has(.5) and levels.has(2.0), "LOD switch errors ignore model scale")
	_check(
		levels.get(2.0) == PackedInt32Array([0, 2, 1, 4, 5, 6]),
		"LOD lost reflected winding or crossed articulated vertex offsets"
	)
	_check(
		levels.get(.5) == PackedInt32Array([0, 2, 1, 0, 3, 2, 4, 5, 6]),
		"Smaller part's LOD simplified the larger part too early"
	)
	reflected.free()
	small.free()


func _check_lods(geometry, label):
	var builder = _batch_mesh_script.new()
	builder.setup(ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBAF)))
	var pieces = []
	for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
		var supported = true
		for surface in mesh.mesh.get_surface_count():
			supported = supported and builder.supports(mesh.get_active_material(surface))
		if supported:
			pieces.append([mesh, Transform3D.IDENTITY, pieces.size()])
	var merged = builder.merge(pieces)
	for surface in merged.get_surface_count():
		var previous = merged.surface_get_array_index_len(surface)
		var count = merged.surface_get_array_len(surface)
		var levels = _mesh_lods_script.read(merged, surface)
		if not levels.is_empty():
			_lod_surfaces += 1
		var distances = levels.keys()
		distances.sort()
		for distance in distances:
			var indices: PackedInt32Array = levels[distance]
			_check(
				indices.size() < previous and indices.size() % 3 == 0,
				label + ": LOD did not reduce intact triangles"
			)
			_check(
				Array(indices).all(func(index): return index >= 0 and index < count),
				label + ": LOD indexes another mesh's vertices"
			)
			previous = indices.size()
