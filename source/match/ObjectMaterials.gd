extends RefCounted

## Shared object finishes for imported, generated and batched geometry.
## Source meshes/materials are immutable; ownership, previews and save reloads
## may instantiate the same resources. Value keys bound the shared cache across
## reloads, while retaining materials until deferred renderer frees have drained.
const SURFACE = preload("res://source/shaders/3d/object_surface.gdshader")
const FOLIAGE_CARDS = preload("res://source/shaders/3d/foliage_cards.gdshader")
const TWO_SIDED = preload("res://source/shaders/3d/object_surface_twosided.gdshader")
const ROOT = "res://assets/textures/objects/"
const MAPS = {
	"bark":
	[
		ROOT + "polyhaven/bark_color.jpg",
		ROOT + "polyhaven/bark_normal.jpg",
		ROOT + "polyhaven/bark_roughness.jpg"
	],
	"stone":
	[
		ROOT + "polyhaven/stone_color.jpg",
		ROOT + "polyhaven/stone_normal.jpg",
		ROOT + "polyhaven/stone_roughness.jpg"
	],
	"foliage": [ROOT + "generated/foliage_v1.png", "", ""],
	"needles": [ROOT + "generated/needles_v1.png", "", ""],
	"fabric": [ROOT + "generated/canvas_v1.png", "", ""],
	"concrete":
	[
		"res://assets/textures/surfaces/polyhaven/granular_concrete_diff_1k.jpg",
		"res://assets/textures/surfaces/polyhaven/granular_concrete_nor_gl_1k.jpg",
		"res://assets/textures/surfaces/polyhaven/granular_concrete_rough_1k.jpg"
	],
	"metal": ["res://assets/textures/surfaces/generated/armor_panels_v1.png", "", ""],
	"asphalt":
	[
		"res://assets/textures/surfaces/polyhaven/asphalt_03_diff_1k.jpg",
		"res://assets/textures/surfaces/polyhaven/asphalt_03_nor_gl_1k.jpg",
		"res://assets/textures/surfaces/polyhaven/asphalt_03_rough_1k.jpg"
	],
}
# source, metres per tile, contrast, normal strength, back-light transmission
const PROFILES = {
	"bark": ["bark", Vector3(1.2, 2.5, 1.2), .8, .65, 0.0],
	"wood": ["bark", Vector3(.5, 3.0, .5), .35, .25, 0.0],
	"stone": ["stone", Vector3(3.5, 3.5, 3.5), .8, .7, 0.0],
	"concrete": ["concrete", Vector3(2, 2, 2), .65, .45, 0.0],
	"foliage": ["foliage", Vector3(2.5, 2.5, 2.5), .8, 0.0, .12],
	"needles": ["needles", Vector3(1.8, 1.8, 1.8), .65, 0.0, .1],
	"grass": ["needles", Vector3(.45, 1.2, .45), .55, 0.0, .08],
	"fabric": ["fabric", Vector3(.65, .65, .65), .5, 0.0, 0.0],
	"rubber": ["fabric", Vector3(.18, .18, .18), .18, 0.0, 0.0],
	"skin": ["concrete", Vector3(.12, .12, .12), .055, .06, 0.0],
	"metal": ["metal", Vector3(2, 2, 2), .32, 0.0, 0.0],
	"asphalt": ["asphalt", Vector3(3, 3, 3), .5, .4, 0.0],
	"snow": ["concrete", Vector3(3, 3, 3), .12, .18, 0.0],
}
const WORDS = {
	"bark": ["bark", "trunk", "shag"],
	"wood": ["timber", "plank", "sleepers", "log end", "branches", "stems", "stalk"],
	"grass": ["grass", "sedge", "tussock", "ruderal", "yucca", "thatch", "hay"],
	"needles": ["needles", "sprays", "juniper scale"],
	"foliage":
	[
		"leaves",
		"foliage",
		"needles",
		"canopy",
		"scrub",
		"tips",
		"frond",
		"sprays",
		"fern",
		"hedge",
		"bramble",
		"salal",
		"heather",
		"juniper",
		"creosote",
		"greasewood",
		"saltbush",
		"sagebrush",
		"oleander",
		"moss",
		"lichen",
		"bloom",
		"blossom",
		"wildflower",
		"tumbleweed",
		"birch autumn"
	],
	"fabric":
	[
		"cloth",
		"canvas",
		"coat",
		"trouser",
		"jacket",
		"sleeve",
		"forearm",
		"pouch",
		"pack",
		"scarf",
		"collar",
		"satchel",
		"fur",
		"hair"
	],
	"rubber": ["rubber", "tyre", "tire", "boot", "glove", "belt", "strap", "webbing"],
	"snow": ["snow", "salt", "gypsum"],
	"stone":
	[
		"stone",
		"rock",
		"basalt",
		"granite",
		"gneiss",
		"shale",
		"scoria",
		"scree",
		"ballast",
		"slag",
		"ore",
		"obsidian",
		"sinter",
		"coke",
		"strata"
	],
	"concrete":
	[
		"concrete",
		"precast",
		"foundation",
		"plaster",
		"brick",
		"masonry",
		"refractory",
		"paving",
		"pavement",
		"courtyard",
		"parapet",
		"kerb",
		"landscape"
	],
	"asphalt": ["asphalt", "street", "road"],
}
const Cache = preload("res://source/utils/RuntimeCache.gd")
const HIT_SHADER = preload("res://source/shaders/3d/material_hit.gdshader")


# One transient overlay per damaged model; imported and cached materials remain
# immutable. Weak references allow a dying unit to disappear during the pulse.
static func hit_flash(geometry, color: Color, recycled = {}) -> Dictionary:
	var entry = recycled
	if entry.is_empty():
		var fresh = ShaderMaterial.new()
		fresh.shader = HIT_SHADER
		entry = {"material": fresh, "surfaces": [], "color": Color.TRANSPARENT}
	var material = entry.material
	if entry.color != color:
		material.set_shader_parameter("hit_color", color)
		entry.color = color
	material.set_shader_parameter("hit_strength", .7)
	entry.age = 0.0
	entry.surfaces.clear()
	var batch_reference = (
		geometry.get_meta("gpu_batch_renderer") if geometry.has_meta("gpu_batch_renderer") else null
	)
	var renderer = batch_reference.get_ref() if batch_reference != null else null
	if renderer != null:
		renderer.set_hit_pulse(geometry, material)
		entry.batch_geometry = weakref(geometry)
	var surfaces = geometry.get_meta("hit_flash_surfaces", [])
	# Unit geometry is assembled before entering combat. Replaced/freed meshes
	# invalidate its weak cache; no source mesh or shared material is retained.
	if surfaces.is_empty() or surfaces.any(func(reference): return reference.get_ref() == null):
		surfaces = []
		_collect_hit_surfaces(geometry, surfaces)
		geometry.set_meta("hit_flash_surfaces", surfaces)
	for reference in surfaces:
		var surface = reference.get_ref()
		if surface != null and surface.material_overlay == null:
			surface.material_overlay = material
			entry.surfaces.append(reference)
	return entry


static func _collect_hit_surfaces(node, surfaces):
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		surfaces.append(weakref(node))
	for child in node.get_children():
		_collect_hit_surfaces(child, surfaces)


static func clear_hit_flash(entry):
	var geometry = entry.get("batch_geometry")
	geometry = geometry.get_ref() if geometry != null else null
	if geometry != null:
		var batch_reference = (
			geometry.get_meta("gpu_batch_renderer")
			if geometry.has_meta("gpu_batch_renderer")
			else null
		)
		var renderer = batch_reference.get_ref() if batch_reference != null else null
		if renderer != null:
			renderer.clear_hit_pulse(geometry, entry.material)
	entry.erase("batch_geometry")
	for reference in entry.surfaces:
		var surface = reference.get_ref()
		if surface != null and surface.material_overlay == entry.material:
			surface.material_overlay = null
	entry.surfaces.clear()
	entry.unit = null


static func materials() -> Dictionary:
	return Cache.bucket("object_materials")


static func configure_rock(material, kind = "stone", strength = .65):
	material.set_shader_parameter("rock_color", load(MAPS[kind][0]))
	material.set_shader_parameter("rock_normal", load(MAPS[kind][1]))
	material.set_shader_parameter("rock_texture_strength", strength)


static func family(original, mesh_name = "") -> String:
	# Material names are authoritative; generated primitives supply semantic names.
	var label = original.resource_name.to_lower()
	if label.is_empty():
		label = str(mesh_name).to_lower()
	if label in ["skin", "face", "neck", "nose", "ear", "chin"]:
		return "skin"
	for kind in WORDS:
		for word in WORDS[kind]:
			if word in label:
				return kind
	return "metal"


static func eligible(original) -> bool:
	if not original is StandardMaterial3D:
		return false
	# Optical/emissive surfaces and gameplay markings deliberately keep their finish.
	if (
		original.albedo_texture != null
		or original.normal_enabled
		or original.emission_enabled
		or original.next_pass != null
		or original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		or original.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL
		or original.cull_mode == BaseMaterial3D.CULL_FRONT
		or original.resource_name.begins_with("TeamColor")
	):
		return false
	var label = original.resource_name.to_lower()
	for word in [
		"glass",
		"glazing",
		"optics",
		"window",
		"water",
		"ice",
		"solar",
		"marking",
		"stencil",
		"warning",
		"ownership",
		"signal",
		"lamp",
		"flame"
	]:
		if word in label:
			return false
	return true


static func textured(original, mesh_name = ""):
	if not eligible(original):
		return original
	var kind = family(original, mesh_name)
	var shared = materials()
	var key = [
		kind,
		original.resource_name,
		original.albedo_color,
		original.metallic,
		original.roughness,
		original.metallic_specular,
		original.cull_mode,
		original.vertex_color_use_as_albedo
	]
	if shared.has(key):
		return shared[key]
	var profile = PROFILES[kind]
	var material = ShaderMaterial.new()
	material.resource_name = original.resource_name
	material.shader = (
		TWO_SIDED
		if (
			original.cull_mode == BaseMaterial3D.CULL_DISABLED
			or kind in ["foliage", "needles", "grass"]
		)
		else SURFACE
	)
	material.set_meta("object_surface_family", kind)
	material.set_shader_parameter("base_color", original.albedo_color)
	material.set_shader_parameter("metalness", original.metallic)
	material.set_shader_parameter("base_roughness", original.roughness)
	material.set_shader_parameter("base_specular", original.metallic_specular)
	material.set_shader_parameter("vertex_tint", original.vertex_color_use_as_albedo)
	material.set_shader_parameter("texture_scale", Vector3.ONE / profile[1])
	material.set_shader_parameter("detail_strength", profile[2])
	material.set_shader_parameter("normal_strength", profile[3])
	material.set_shader_parameter("leaf_transmission", profile[4])
	if kind == "metal":
		# Only the faction authoring pipeline reserves UV2 for mechanical trims.
		# Other scenery may use its second UV set for lightmaps or custom effects.
		var trims = ["Bastion_", "Helix_", "Frontier_", "Armor /", "Mechanisms /", "Hardware /"].any(
			func(prefix): return original.resource_name.begins_with(prefix)
		)
		load("res://source/match/SurfaceTextures.gd").configure_metal(material, trims)
		material.set_shader_parameter("metal_finish_enabled", true)
	if "[cards:" in original.resource_name:
		material.shader = FOLIAGE_CARDS
		material.set_shader_parameter("base_color", original.albedo_color)
		var leaf_kind = "needles" if "[cards:needles]" in original.resource_name else "leaves"
		material.set_shader_parameter(
			"leaf_texture", load(ROOT + "generated/" + leaf_kind + "_cutout.png")
		)
		shared[key] = material
		return material
	var maps = MAPS[profile[0]]
	material.set_shader_parameter("surface_color", load(maps[0]))
	if not maps[1].is_empty():
		material.set_shader_parameter("surface_normal", load(maps[1]))
		material.set_shader_parameter("has_normal", true)
	if not maps[2].is_empty():
		material.set_shader_parameter("surface_roughness", load(maps[2]))
		material.set_shader_parameter("has_roughness", true)
	shared[key] = material
	return material


static func apply(node):
	if node is MeshInstance3D and node.mesh != null:
		if node.material_override != null:
			node.material_override = textured(node.material_override, node.name)
		else:
			for index in node.mesh.get_surface_count():
				var original = node.get_active_material(index)
				var replacement = textured(original, node.name)
				if replacement != original:
					node.set_surface_override_material(index, replacement)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		if node.material_override != null:
			node.material_override = textured(node.material_override, node.name)
		# MeshBatch binds the shared finishes before merging. Other MultiMeshes
		# get a private mesh copy only if they still have untextured surfaces.
		elif node.multimesh.mesh != null:
			var mesh = node.multimesh.mesh
			var copy = null
			for index in mesh.get_surface_count():
				var original = mesh.surface_get_material(index)
				var replacement = textured(original, node.name)
				if replacement != original:
					if copy == null:
						copy = mesh.duplicate()
					if copy is PrimitiveMesh:
						copy.material = replacement
					else:
						copy.surface_set_material(index, replacement)
			if copy != null:
				# Resource.duplicate can assign the buffer before its format/count.
				# Initialize explicitly to retain every instance and custom channel.
				var original = node.multimesh
				var batch = MultiMesh.new()
				batch.transform_format = original.transform_format
				batch.use_colors = original.use_colors
				batch.use_custom_data = original.use_custom_data
				batch.mesh = copy
				batch.instance_count = original.instance_count
				# The headless dummy renderer does not retain GPU buffers.
				if not original.buffer.is_empty():
					batch.buffer = original.buffer
				batch.visible_instance_count = original.visible_instance_count
				batch.custom_aabb = original.custom_aabb
				node.multimesh = batch
	for child in node.get_children():
		apply(child)
