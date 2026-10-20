extends "res://tests/headless/StructureActivityRegression.gd"

const Textures = preload("res://source/match/SurfaceTextures.gd")
const INDUSTRIAL = "res://source/match/maps/IndustrialCrossroads.tscn"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	_check_imports()
	_check_shaders()
	for faction in factions.IDS:
		var failures_before = errors.size()
		await _skirmish(faction, INDUSTRIAL)
		human = game._get_human_player()
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		_check_ground()
		_check_units()
		await _check_construction()
		var materials_before_restore = Textures.armor_materials().size()
		# Rebuild the real match from a save: presentation must be recreated through
		# the same spawn paths, not depend on material mutations in the old instance.
		paused = true
		var snapshot = Snapshot.new()
		var data = snapshot.capture(game)
		_check(data != null, "Textured match capture failed: " + snapshot.error)
		if data != null:
			var restore = Restore.new()
			var restored = await restore.restore(self, data)
			_check(restored.ok, "Textured match restore failed: " + restored.get("error", ""))
			if restored.ok:
				game = restored.game
				human = game._get_human_player()
				_check_ground()
				_check_units()
				_check(
					Textures.armor_materials().size() == materials_before_restore,
					"Save reload grew the armor material cache"
				)
		paused = false
		game.queue_free()
		await _frames(5)
		if errors.size() == failures_before:
			print("PASS texture lifecycle: ", faction)
	for message in errors:
		push_error(message)
	print("Surface textures: %d failures" % errors.size())
	# Release this coroutine's snapshot/restore locals before engine shutdown.
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check_shaders():
	for shader_name in [
		"armor_surface",
		"district_ground",
		"district_surface",
		"frontier_surface",
		"construction_bastion",
		"construction_helix",
		"construction_frontier",
	]:
		var shader = load("res://source/shaders/3d/%s.gdshader" % shader_name)
		var names = shader.get_shader_uniform_list().map(func(uniform): return uniform.name)
		var expected = "asphalt_color" if shader_name == "district_ground" else "armor_texture"
		_check(expected in names, "Shader parser did not expose texture inputs: " + shader_name)


func _check_imports():
	for texture in [
		Textures.ARMOR,
		Textures.CONCRETE_COLOR,
		Textures.CONCRETE_NORMAL,
		Textures.CONCRETE_ROUGHNESS,
		Textures.ASPHALT_COLOR,
		Textures.ASPHALT_NORMAL,
		Textures.ASPHALT_ROUGHNESS,
	]:
		_check(texture.get_width() == 1024, "Runtime texture size: " + texture.resource_path)
		var config = ConfigFile.new()
		_check(config.load(texture.resource_path + ".import") == OK, "Missing texture import")
		_check(config.get_value("params", "mipmaps/generate", false), "Texture lacks mipmaps")
		_check(config.get_value("params", "compress/mode") == 2, "Texture lacks VRAM compression")
		if "nor_gl" in texture.resource_path:
			_check(
				config.get_value("params", "compress/normal_map") == 1, "Normal imported as color"
			)


func _check_ground():
	var terrain = game.map.get_node("Geometry/Terrain").get_active_material(0)
	_check(
		terrain.get_shader_parameter("asphalt_color") == Textures.ASPHALT_COLOR,
		"Road color missing"
	)
	_check(
		terrain.get_shader_parameter("concrete_normal") == Textures.CONCRETE_NORMAL,
		"Paving normal missing"
	)
	var exterior = game.map.exterior.ground.get_active_material(0)
	_check(
		exterior.get_shader_parameter("asphalt_normal") == Textures.ASPHALT_NORMAL,
		"Exterior road seam: different material maps"
	)
	var buildings = 0
	for body in game.map.flight_obstacles:
		for material in _materials(body):
			if (
				material is ShaderMaterial
				and material.shader.resource_path.ends_with("district_surface.gdshader")
			):
				buildings += 1
				_check(
					material.get_shader_parameter("concrete_color") == Textures.CONCRETE_COLOR,
					"Industrial wall color missing"
				)
	_check(buildings > 0, "No textured industrial buildings")


func _check_units():
	for role in ["Tank", "CommandCenter", "PowerPlant"]:
		var units = _units(human, role)
		_check(not units.is_empty(), "Missing texture fixture: " + role)
		if units.is_empty():
			continue
		var armored = 0
		var team_parts = 0
		for mesh in units[0].get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original = mesh.mesh.surface_get_material(surface)
				var active = mesh.get_active_material(surface)
				if original.resource_name.begins_with("TeamColor"):
					team_parts += 1
					_check(active == human.get_color_material(), "Texture replaced player color")
				if _has_armor(active):
					armored += 1
					_check(
						active.get_shader_parameter("armor_texture") == Textures.ARMOR,
						"Armor texture missing"
					)
					_check(
						original is StandardMaterial3D and original.albedo_texture == null,
						"Shared source material mutated"
					)
		_check(
			armored > 0 and team_parts > 0, human.faction + " missing armor/team surfaces: " + role
		)


func _check_construction():
	var building = _spawn("PowerPlant", Vector3(25, 0, 22), true)
	await _frames(2)
	var visual = building.get_node("ConstructionVisual")
	var originals = []
	for entry in visual._surfaces:
		if _has_armor(entry[2]):
			originals.append(entry)
			var assembling = entry[0].get_active_material(entry[1])
			_check(_has_armor(assembling), "Construction dropped armor artwork")
			_check(
				assembling.get_shader_parameter("armor_texture") == Textures.ARMOR,
				"Construction map differs"
			)
	_check(not originals.is_empty(), "Construction fixture has no textured armor")
	building.construct(1.0)
	await _frames(2)
	for entry in originals:
		_check(
			entry[0].get_active_material(entry[1]) == entry[2],
			"Completion did not restore original textured material"
		)
	var memory = game.get_node("Handlers/UnitVisibilityHandler")
	memory._create_dummy_structure(building)
	var dummy = memory._structure_to_dummy_mapping.get(building)
	_check(dummy != null and _materials(dummy).any(_has_armor), "Fog memory lost surface artwork")
	building.queue_free()
	await _frames(3)


func _materials(node):
	var result = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			result.append(mesh.get_active_material(surface))
	return result


func _has_armor(material):
	return material is ShaderMaterial and material.get_shader_parameter("armor_panels") == true
