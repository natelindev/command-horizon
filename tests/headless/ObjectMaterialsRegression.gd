extends "res://tests/headless/SaveRestoreEdges.gd"

const Materials = preload("res://source/match/ObjectMaterials.gd")
var _model_count = 0
var _surface_count = 0
var _families = {}


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_check_classification()
	_check_imports()
	_check_specialized()
	_check_multimesh()
	_check_library("res://assets/models")
	_check(_model_count > 0 and _surface_count > 0, "Object model library was not inspected")
	_check_generated_roster()
	await _check_maps()
	for message in errors:
		push_error(message)
	print(
		(
			"Object materials: %d failures, %d models, %d textured surfaces, families %s"
			% [errors.size(), _model_count, _surface_count, str(_families.keys())]
		)
	)
	# Exercise the same cache/audio lifetime as a normal game exit.
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check_classification():
	for pair in [
		["Oak bark", "bark"],
		["Fir needles 0", "needles"],
		["Oak leaves 2", "foliage"],
		["Sagebrush 0", "foliage"],
		["Dune grass", "grass"],
		["Winter sedge", "grass"],
		["Granite 1", "stone"],
		["Bastion_Precast", "concrete"],
		["Ochre work coat", "fabric"],
		["Skin", "skin"],
		["Tracks / rubber", "rubber"],
	]:
		var material = StandardMaterial3D.new()
		material.resource_name = pair[0]
		_check(Materials.family(material) == pair[1], "Wrong finish for " + pair[0])
	for label in ["TeamColor_Bastion", "Window glass", "Optics / ice cyan"]:
		var material = StandardMaterial3D.new()
		material.resource_name = label
		_check(Materials.textured(material) == material, "Replaced protected surface " + label)
	var lamp = StandardMaterial3D.new()
	lamp.emission_enabled = true
	_check(Materials.textured(lamp) == lamp, "Replaced live emissive material")


func _check_imports():
	for maps in Materials.MAPS.values():
		for path in maps:
			if path.is_empty():
				continue
			var texture = load(path)
			_check(texture is Texture2D, "Missing object texture " + path)
			var config = ConfigFile.new()
			_check(config.load(path + ".import") == OK, "Missing import " + path)
			# Exported imports keep remaps, but strip editor-only import parameters.
			# Inspect the actual texture in packages as well as source checkouts.
			if texture is Texture2D:
				_check(
					texture.get_width() > 0 and texture.get_height() > 0, "Empty texture " + path
				)
			if not config.has_section("params"):
				continue
			_check(config.get_value("params", "mipmaps/generate", false), "No mipmaps " + path)
			_check(config.get_value("params", "compress/mode") == 2, "Uncompressed " + path)
			if "_normal" in path:
				_check(
					config.get_value("params", "compress/normal_map") == 1,
					"Normal map imported as color: " + path
				)
	for shader in [Materials.SURFACE, Materials.TWO_SIDED]:
		var uniforms = shader.get_shader_uniform_list().map(func(item): return item.name)
		for name in ["surface_color", "surface_normal", "object_detail"]:
			_check(name in uniforms, "Object shader failed to parse: " + name)


func _check_specialized():
	for entry in [
		["desert/SandstoneShelfA", "DesertMaterials", "weather_stone"],
		["quarry/QuarryBenchA", "QuarryMaterials", "weather_stone"],
		["alpine/GlacialShelfA", "AlpineMaterials", "weather"],
		["coastal/CoastalHeadland", "CoastalMaterials", "weather"],
	]:
		var model = load("res://assets/models/environment/%s.glb" % entry[0]).instantiate()
		load("res://source/match/maps/%s.gd" % entry[1]).call(entry[2], model)
		var count = 0
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			for index in mesh.mesh.get_surface_count():
				var material = mesh.get_active_material(index)
				if not material is ShaderMaterial:
					continue
				count += 1
				_check(
					material.get_shader_parameter("rock_color") is Texture2D,
					entry[0] + " has no scanned rock color"
				)
				_check(
					material.get_shader_parameter("rock_normal") is Texture2D,
					entry[0] + " has no scanned rock normal"
				)
		_check(count > 0, entry[0] + " lost biome weathering")
		model.free()
	var coast = load("res://assets/models/environment/coastal/CoastalPineStand.glb").instantiate()
	load("res://source/match/maps/CoastalMaterials.gd").weather(coast)
	Materials.apply(coast)
	var bark = 0
	for mesh in coast.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(index)
			if "bark" in material.resource_name:
				bark += 1
				_check(
					material.get_meta("object_surface_family", "") == "bark",
					"Coastal bark was treated as stone"
				)
	_check(bark > 0, "Coastal bark fixture empty")
	coast.free()


func _check_library(directory):
	# ResourceLoader preserves original names after export remaps GLBs to scenes.
	for file in ResourceLoader.list_directory(directory):
		if file.ends_with("/"):
			_check_library(directory.path_join(file.trim_suffix("/")))
			continue
		if not file.ends_with(".glb"):
			continue
		var model = load(directory + "/" + file).instantiate()
		_check_model(model, file)
		model.free()
		_model_count += 1


func _check_multimesh():
	var original_material = StandardMaterial3D.new()
	original_material.resource_name = "Courtyard concrete"
	var mesh = BoxMesh.new()
	mesh.material = original_material
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	batch.mesh = mesh
	batch.instance_count = 2
	batch.visible_instance_count = 1
	batch.set_instance_transform(0, Transform3D(Basis(), Vector3(4, 0, 7)))
	batch.set_instance_color(0, Color(.4, .5, .6))
	batch.set_instance_custom_data(0, Color(.2, .3, .4, .5))
	var node = MultiMeshInstance3D.new()
	node.multimesh = batch
	Materials.apply(node)
	_check(node.multimesh != batch, "Material conversion mutated the shared batch")
	_check(mesh.material == original_material, "Material conversion mutated the shared primitive")
	_check(node.multimesh.mesh.material is ShaderMaterial, "Primitive batch remained untextured")
	_check(
		node.multimesh.instance_count == 2 and node.multimesh.visible_instance_count == 1,
		"Batch conversion changed its instance counts"
	)
	_check(node.multimesh.use_colors and node.multimesh.use_custom_data, "Batch channels lost")
	_check(node.multimesh.buffer == batch.buffer, "Batch transforms or custom data changed")
	node.free()


func _check_model(model, label):
	var originals = []
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for index in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(index)
			originals.append([mesh, index, original, mesh.mesh])
	Materials.apply(model)
	var count = Materials.materials().size()
	Materials.apply(model)
	_check(Materials.materials().size() == count, label + " not idempotent")
	for entry in originals:
		var original = entry[2]
		var material = entry[0].get_active_material(entry[1])
		_check(entry[0].mesh == entry[3], label + " mutated source mesh")
		if not Materials.eligible(original):
			_check(material == original, label + " changed a protected material")
			continue
		_check(material is ShaderMaterial, label + " retained flat material")
		if not material is ShaderMaterial:
			continue
		_check(
			(
				material.get_shader_parameter(
					(
						"leaf_texture"
						if material.shader == Materials.FOLIAGE_CARDS
						else "surface_color"
					)
				)
				is Texture2D
			),
			label + " has an unbound texture"
		)
		_check(
			material.get_shader_parameter("base_color") == original.albedo_color,
			label + " lost authored palette"
		)
		_check(original.albedo_texture == null, label + " mutated imported material")
		_families[material.get_meta("object_surface_family")] = true
		_surface_count += 1


func _check_generated_roster():
	var factions = load("res://source/match/FactionCatalog.gd")
	var roster = load("res://source/match/BastionCatalog.gd")
	for faction in factions.IDS:
		for role in roster.NAMES:
			var unit = load(roster.scene_path(role)).instantiate()
			factions.prepare_model(unit, faction)
			_assert_covered(unit.get_node("Geometry"), faction + "/" + role)
			if role == "Infantry":
				var rig = unit.get_node("Geometry/InfantryRig")
				var jacket = rig.get_node("Chest/Jacket").get_active_material(0)
				var face = rig.get_node("Chest/Head/Face").get_active_material(0)
				_check(jacket.get_meta("object_surface_family", "") == "fabric", "Flat uniform")
				_check(face.get_meta("object_surface_family", "") == "skin", "Wrong skin finish")
			unit.free()


func _assert_covered(node, label):
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			_check(
				not Materials.eligible(node.get_active_material(index)),
				label + ": untextured " + str(node.name)
			)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		for index in node.multimesh.mesh.get_surface_count():
			var material = node.material_override
			if material == null:
				material = node.multimesh.mesh.surface_get_material(index)
			_check(not Materials.eligible(material), label + ": untextured batch " + str(node.name))
	for child in node.get_children():
		_assert_covered(child, label)


func _check_maps():
	for map_name in ["battlefields/PinebreakValleyMap", "IndustrialCrossroads"]:
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		_assert_covered(game.map, map_name)
		var dressing = game.map.get_node_or_null("Dressing")
		if dressing != null:
			var small = 0
			for batch in dressing.get_children():
				if batch.multimesh.mesh.get_aabb().size.y < 1.2:
					small += 1
					_check(
						batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
						"Small scenery lost shadows: " + str(batch.name)
					)
			_check(small > 0, "Shadow fixture has no small scenery")
		for batch in game.map.find_children("*Cover", "MultiMeshInstance3D", true, false):
			_check(
				batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"Landmark vegetation lost shadows: " + str(batch.name)
			)
		var human = game._get_human_player()
		var site = load("res://source/match/units/PowerPlant.tscn").instantiate()
		game._setup_and_spawn_unit(site, Transform3D(Basis(), Vector3(55, 0, 50)), human, true)
		site.construct(.65)
		site.construct(1.0)
		await _frames(3)
		_assert_covered(site.get_node("Geometry"), "Completed building")
		var deposit = get_nodes_in_group("resource_units")[0]
		if "resource_a" in deposit:
			deposit.resource_a = 30
		else:
			deposit.resource_b = 30
		_assert_covered(deposit, "Depleted resource")
		paused = true
		var snapshot = Snapshot.new().capture(game)
		var cache_size = Materials.materials().size()
		_check(snapshot != null, "Cannot save textured match")
		if snapshot != null:
			var restored = await Restore.new().restore(self, snapshot)
			_check(restored.ok, "Cannot restore textured match: " + restored.get("error", ""))
			if restored.ok:
				game = restored.game
				_assert_covered(game.map, "Restored map")
				for unit in get_nodes_in_group("units"):
					_assert_covered(unit.get_node("Geometry"), "Restored unit")
				_check(Materials.materials().size() == cache_size, "Reload grew material cache")
		paused = false
		game.queue_free()
		await _frames(5)
