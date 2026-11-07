extends Node

## Presentation only: the unit's visibility/observation still owns concealment.
## Per-surface copies keep team finishes intact and restore their exact overrides.
const SHADER = preload("res://source/shaders/3d/optical_cloak.gdshader")
var blend = 0.0
var _phase = 0.0
var _surfaces = []
var _meshes = []
var _unit
var _initialized = false


func _ready():
	_unit = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(DisplayServer.get_name() != "headless")


func _process(delta):
	refresh(delta)


func refresh(delta: float):
	if _unit._match == null or _unit._match.restoring:
		return
	var cloak = _unit.optical_cloak
	var wanted = cloak != null and cloak.concealed and _unit.hp > 0
	# A paused restored match must display its saved concealment immediately.
	# Subsequent activation/reveal transitions use the paused simulation clock.
	if not _initialized:
		blend = 1.0 if wanted else 0.0
		_initialized = true
	elif not get_tree().paused:
		blend = move_toward(blend, 1.0 if wanted else 0.0, delta / .35)
	if blend == 0.0:
		_restore()
		return
	if _surfaces.is_empty():
		_attach()
	if not get_tree().paused:
		_phase += delta
	for entry in _surfaces:
		entry.material.set_shader_parameter("concealment", blend)
		entry.material.set_shader_parameter("phase", _phase)
		entry.material.set_shader_parameter("steady", Globals.options.reduced_flashes)


func _attach():
	var geometry = _unit.get_node_or_null("Geometry")
	if geometry == null:
		return
	var converted = {}
	for mesh in geometry.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		_meshes.append([mesh, mesh.material_override, mesh.cast_shadow])
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			if not converted.has(original):
				var material = ShaderMaterial.new()
				material.shader = SHADER
				material.next_pass = original.next_pass if original != null else null
				load("res://source/match/effects/ConstructionVisual.gd")._copy_surface(
					original, material
				)
				converted[original] = material
			_surfaces.append(
				{
					"mesh": mesh,
					"surface": surface,
					"override": mesh.get_surface_override_material(surface),
					"material": converted[original]
				}
			)
			mesh.set_surface_override_material(surface, converted[original])
		mesh.material_override = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _restore():
	for entry in _surfaces:
		if is_instance_valid(entry.mesh):
			entry.mesh.set_surface_override_material(entry.surface, entry.override)
	for entry in _meshes:
		if is_instance_valid(entry[0]):
			entry[0].material_override = entry[1]
			entry[0].cast_shadow = entry[2]
	_surfaces.clear()
	_meshes.clear()


func _exit_tree():
	_restore()
