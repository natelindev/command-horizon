extends MeshInstance3D

const Cache = preload("res://source/utils/RuntimeCache.gd")

## One static terrain-conforming surface per structure. No collision, navigation,
## scripts per frame, team markers or simulation state. Visibility follows the unit.
const Profiles = preload("res://source/match/environment/AtmosphereProfiles.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const SHADER = preload("res://source/shaders/3d/base_apron.gdshader")
const SOIL = {
	"desert": Color("8d7857"),
	"alpine": Color("a1aeb6"),
	"coastal": Color("657365"),
	"urban": Color("565955"),
	"temperate": Color("6b7052"),
}
var footprint = Vector2.ZERO


func _ready():
	var materials = Cache.bucket("base_apron_materials")
	name = "BaseApron"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var unit = get_parent()
	var bounds = Factions._bounds(unit.get_node("Geometry"), Transform3D.IDENTITY)
	footprint = Vector2(bounds.size.x, bounds.size.z) * .55 + Vector2(.25, .25)
	footprint = footprint.max(Vector2(.7, .7))
	# Long structures (the runway) keep a proportionate worn margin, not 3.5x.
	var span = (footprint * 3.5).min(footprint * 2.0 + Vector2(10, 10))
	var faction = unit.player.faction
	var biome = Profiles.biome(unit._match.map)
	var key = [faction, biome, footprint]
	if not materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("span", span)
		material.set_shader_parameter("pad_half", footprint)
		material.set_shader_parameter("faction", ["bastion", "helix", "frontier"].find(faction))
		material.set_shader_parameter("soil", SOIL[biome])
		(
			material
			. set_shader_parameter(
				"concrete",
				{"bastion": Color("72756c"), "helix": Color("839397"), "frontier": Color("81775e")}[faction]
			)
		)
		materials[key] = material
	material_override = materials[key]
	# The rendered terrain is authoritative for this cosmetic surface; navmesh
	# heights intentionally include clearance and must not lift the apron.
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points = []
	var space = get_world_3d().direct_space_state
	for z in 9:
		for x in 9:
			var uv = Vector2(x, z) / 8.0
			var local = Vector3((uv.x - .5) * span.x, 0, (uv.y - .5) * span.y)
			var world = to_global(local)
			var ray = PhysicsRayQueryParameters3D.create(
				world + Vector3.UP * 100, world - Vector3.UP * 100, 1
			)
			var hit = space.intersect_ray(ray)
			if not hit.is_empty():
				local = to_local(hit.position + Vector3.UP * .025)
			else:
				local.y = .025
			points.append(local)
	for z in 8:
		for x in 8:
			for index in [
				z * 9 + x,
				z * 9 + x + 1,
				(z + 1) * 9 + x,
				z * 9 + x + 1,
				(z + 1) * 9 + x + 1,
				(z + 1) * 9 + x
			]:
				surface.set_uv(Vector2(index % 9, index / 9) / 8.0)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(points[index])
	mesh = surface.commit()
