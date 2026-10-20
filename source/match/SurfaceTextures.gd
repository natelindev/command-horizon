extends RefCounted

# One shared set of imported maps. Keep source material resources immutable so
# team tinting, construction restoration and fog-memory copies remain independent.
const ARMOR = preload("res://assets/textures/surfaces/generated/armor_panels_v1.png")
const CONCRETE_COLOR = preload(
	"res://assets/textures/surfaces/polyhaven/granular_concrete_diff_1k.jpg"
)
const CONCRETE_NORMAL = preload(
	"res://assets/textures/surfaces/polyhaven/granular_concrete_nor_gl_1k.jpg"
)
const CONCRETE_ROUGHNESS = preload(
	"res://assets/textures/surfaces/polyhaven/granular_concrete_rough_1k.jpg"
)
const ASPHALT_COLOR = preload("res://assets/textures/surfaces/polyhaven/asphalt_03_diff_1k.jpg")
const ASPHALT_NORMAL = preload("res://assets/textures/surfaces/polyhaven/asphalt_03_nor_gl_1k.jpg")
const ASPHALT_ROUGHNESS = preload(
	"res://assets/textures/surfaces/polyhaven/asphalt_03_rough_1k.jpg"
)
const ARMOR_SHADER = preload("res://source/shaders/3d/armor_surface.gdshader")
const ARMOR_NAMES = [
	"Bastion_Armor",
	"Bastion_Panels",
	"Bastion_FortressOlive",
	"Bastion_CastArmor",
	"Armor / olive graphite",
	"Armor / raised panels",
	"Helix_Ceramic",
	"Helix_Secondary",
]
const Cache = preload("res://source/utils/RuntimeCache.gd")


static func armor_materials() -> Dictionary:
	return Cache.bucket("armor_materials")


static func configure_ground(material):
	material.set_shader_parameter("concrete_color", CONCRETE_COLOR)
	material.set_shader_parameter("concrete_normal", CONCRETE_NORMAL)
	material.set_shader_parameter("concrete_roughness", CONCRETE_ROUGHNESS)
	material.set_shader_parameter("asphalt_color", ASPHALT_COLOR)
	material.set_shader_parameter("asphalt_normal", ASPHALT_NORMAL)
	material.set_shader_parameter("asphalt_roughness", ASPHALT_ROUGHNESS)


static func configure_industrial(material, panels):
	material.set_shader_parameter("concrete_color", CONCRETE_COLOR)
	material.set_shader_parameter("concrete_roughness", CONCRETE_ROUGHNESS)
	configure_armor(material, panels)


static func configure_armor(material, enabled = true):
	material.set_shader_parameter("armor_texture", ARMOR)
	material.set_shader_parameter("armor_panels", enabled)


static func apply_armor(model):
	var materials = armor_materials()
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			if not original is StandardMaterial3D:
				continue
			# Blender adds numeric suffixes to duplicate materials in related models.
			if original.resource_name.get_slice(".", 0) not in ARMOR_NAMES:
				continue
			# Value keys keep the cache bounded when a save reload creates new
			# instances of an imported material, without retaining the source resource.
			var key = [
				original.resource_name, original.albedo_color, original.metallic, original.roughness
			]
			if not materials.has(key):
				var material = ShaderMaterial.new()
				material.resource_name = original.resource_name
				material.shader = ARMOR_SHADER
				material.set_shader_parameter("base_color", original.albedo_color)
				material.set_shader_parameter("metalness", original.metallic)
				material.set_shader_parameter("base_roughness", original.roughness)
				configure_armor(material)
				materials[key] = material
			mesh.set_surface_override_material(surface, materials[key])
