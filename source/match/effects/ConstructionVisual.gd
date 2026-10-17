extends Node3D

# Faction-specific assembly of a structure under construction. A faction shader
# builds the real model up from the ground, and a light prop rig plus pooled
# particles show how that faction works. Everything is removed on completion; the
# structure frees this node with itself when it is destroyed or cancelled.

const STYLES = {
	"bastion":
	{
		"shader": preload("res://source/shaders/3d/construction_bastion.gdshader"),
		"rig": preload("res://source/match/effects/construction/BastionConstruction.gd"),
	},
	"helix":
	{
		"shader": preload("res://source/shaders/3d/construction_helix.gdshader"),
		"rig": preload("res://source/match/effects/construction/HelixConstruction.gd"),
	},
	"frontier":
	{
		"shader": preload("res://source/shaders/3d/construction_frontier.gdshader"),
		"rig": preload("res://source/match/effects/construction/FrontierConstruction.gd"),
	},
}
const HOLOGRAM_SHADER = preload("res://source/shaders/3d/construction_hologram.gdshader")
const WORK_WINDOW = .6  # Seconds after the latest progress during which the site counts as worked.

var style = "bastion"
var rig
var bursts = 0  # Particle bursts shown; cosmetic diagnostics only.
var _surfaces = []
var _materials = []
var _phase = 0.0
var _unit
var _last_progress = 0.0
var _since_progress = INF
var _emit_clock = 0.0
var _random = RandomNumberGenerator.new()


func _ready():
	_unit = get_parent()
	var faction = _unit.player.faction if _unit.player != null else "bastion"
	style = faction if STYLES.has(faction) else "bastion"
	var meshes = _unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false)
	var bounds = AABB()
	# Do not merge with an origin AABB: the site may be far from the world origin.
	if not meshes.is_empty():
		bounds = meshes[0].global_transform * meshes[0].get_aabb()
		for mesh in meshes:
			bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
	var hologram = null
	if style == "helix":
		hologram = ShaderMaterial.new()
		hologram.shader = HOLOGRAM_SHADER
		_configure(hologram, bounds)
	# Model parts commonly share a finish. They also share the same site bounds
	# and progress, so one converted material per original is sufficient.
	var converted = {}
	for mesh in meshes:
		var original_override = mesh.material_override
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			if not converted.has(original):
				var material = ShaderMaterial.new()
				material.shader = STYLES[style].shader
				_copy_surface(original, material)
				_configure(material, bounds)
				material.next_pass = hologram
				converted[original] = material
			_surfaces.append(
				[mesh, surface, mesh.get_surface_override_material(surface), original_override]
			)
			mesh.set_surface_override_material(surface, converted[original])
		mesh.material_override = null
	rig = STYLES[style].rig.new()
	rig.name = style.capitalize() + "ConstructionRig"
	add_child(rig)
	var geometry = _unit.get_node("Geometry")
	rig.setup(load("res://source/match/FactionCatalog.gd")._bounds(geometry, Transform3D.IDENTITY))
	_random.seed = rig.site_seed()
	_emit_clock = _random.randf() * rig.emit_interval
	_last_progress = _unit._construction_progress
	refresh()


func _configure(material, bounds):
	material.set_shader_parameter("floor_height", bounds.position.y)
	material.set_shader_parameter("total_height", maxf(.1, bounds.size.y))
	_materials.append(material)


static func _copy_surface(original, material):
	if original is BaseMaterial3D:
		material.set_shader_parameter("base_color", original.albedo_color)
		material.set_shader_parameter("base_metallic", original.metallic)
		material.set_shader_parameter("base_roughness", original.roughness)
		if original.albedo_texture != null:
			material.set_shader_parameter("base_texture", original.albedo_texture)
			material.set_shader_parameter("has_texture", true)
		if original.emission_enabled:
			material.set_shader_parameter(
				"base_emission", original.emission * original.emission_energy_multiplier
			)
	elif original is ShaderMaterial:
		# Frontier surfaces keep their palette in a weathering shader.
		var color = original.get_shader_parameter("base_color")
		if color != null:
			material.set_shader_parameter("base_color", color)
		var metallic = original.get_shader_parameter("metalness")
		if metallic != null:
			material.set_shader_parameter("base_metallic", metallic)


func _process(delta):
	if rig == null:
		return
	_phase += delta
	var progress = _unit._construction_progress
	_since_progress = 0.0 if progress > _last_progress else _since_progress + delta
	_last_progress = progress
	refresh(delta)
	_emit(delta)


func is_worked():
	return _since_progress < WORK_WINDOW


func refresh(delta = 0.0):
	var steady = Globals.options.reduced_flashes
	for material in _materials:
		material.set_shader_parameter("progress", _unit._construction_progress)
		material.set_shader_parameter("phase", _phase)
		material.set_shader_parameter("steady", steady)
	if rig != null:
		rig.progress = _unit._construction_progress
		rig.phase = _phase
		rig.steady = steady
		rig.advance(delta, is_worked())


func _emit(delta):
	if rig.activity < .5:
		return
	_emit_clock -= delta
	if _emit_clock > 0:
		return
	_emit_clock += rig.emit_interval * _random.randf_range(.75, 1.25)
	var effects = _unit._match.combat_effects if _unit._match != null else null
	if effects != null and effects.can_show_construction(_unit):
		rig.emit_effects(effects, _random)
		bursts += 1


func finish():
	for entry in _surfaces:
		if is_instance_valid(entry[0]):
			entry[0].set_surface_override_material(entry[1], entry[2])
			entry[0].material_override = entry[3]
	_surfaces.clear()
	if rig != null:
		rig.queue_free()
		rig = null
	queue_free()
