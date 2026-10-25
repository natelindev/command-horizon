extends RefCounted

## Two deforming belt meshes per tracked vehicle; rigid hulls remain GPU batched.
## Moving the authored raised shoes in the vertex shader avoids dozens of bones.
const SHADER = preload("res://source/shaders/3d/track_motion.gdshader")
const Wheel = preload("res://source/match/units/traits/WheelMotion.gd")
const Cache = preload("res://source/utils/RuntimeCache.gd")
var belts := []
var _unit
var _previous := Transform3D.IDENTITY


func setup(unit):
	_unit = unit
	var materials = Cache.bucket("animated_tracks")
	_previous = unit.global_transform
	for pivot in unit.find_children("*TrackPivot*", "Node3D", true, false):
		for mesh in pivot.find_children("*", "MeshInstance3D", true, false):
			var local: Transform3D = Wheel._transform_to(mesh, unit)
			var bounds: AABB = mesh.get_aabb()
			var center: Vector3 = local * bounds.get_center()
			# Skinned capsule deformation is intentionally outside rigid batching.
			mesh.set_meta("animated_track", true)
			for surface in mesh.mesh.get_surface_count():
				var original = mesh.get_active_material(surface)
				var color = Color("20262a")
				var metalness = .45
				var roughness = .8
				if original is BaseMaterial3D:
					color = original.albedo_color
					metalness = original.metallic
					roughness = original.roughness
				elif original is ShaderMaterial:
					color = original.get_shader_parameter("base_color")
					var metallic_value = original.get_shader_parameter("metalness")
					var roughness_value = original.get_shader_parameter("base_roughness")
					metalness = metallic_value if metallic_value != null else metalness
					roughness = roughness_value if roughness_value != null else roughness
				var key = [color, metalness, roughness]
				if not materials.has(key):
					var material = ShaderMaterial.new()
					material.shader = SHADER
					material.set_shader_parameter("base_color", color)
					material.set_shader_parameter("metalness", metalness)
					material.set_shader_parameter("base_roughness", roughness)
					materials[key] = material
				mesh.set_surface_override_material(surface, materials[key])
			mesh.material_override = null
			var arrays = mesh.mesh.surface_get_arrays(0)
			var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][0]
			var uv2: Vector2 = arrays[Mesh.ARRAY_TEX_UV2][0]
			belts.append(
				{
					"mesh": mesh,
					"offset": center.x,
					"scale": maxf(.001, local.basis.z.length()),
					"travel": 0.0,
					"perimeter": 4.0 * (1.0 - uv.y) + TAU * uv2.x
				}
			)


func advance(delta: float):
	var current: Transform3D = _unit.global_transform
	var previous := _previous
	_previous = current
	if (
		delta <= 0.0
		or (
			current.origin.distance_to(previous.origin)
			> maxf(1.0, _unit.movement_speed * delta * 4.0)
		)
	):
		return
	var old_facing := previous.basis.z.normalized()
	var facing := current.basis.z.normalized()
	var forward := -(old_facing + facing).normalized()
	var translation := (current.origin - previous.origin).dot(forward)
	var turn := atan2(old_facing.cross(facing).y, old_facing.dot(facing))
	if absf(translation) < .000001 and absf(turn) < .000001:
		return
	for belt in belts:
		# Bottom shoes move backwards relative to the hull, cancelling ground speed.
		belt.travel += (translation + turn * belt.offset) / belt.scale
		# Keep precision for long games without a visually discontinuous reset.
		belt.travel = fposmod(belt.travel, belt.perimeter)
		belt.mesh.set_instance_shader_parameter("track_travel", belt.travel)


func copy_from(other):
	for index in mini(belts.size(), other.belts.size()):
		belts[index].travel = other.belts[index].travel
		belts[index].mesh.set_instance_shader_parameter("track_travel", belts[index].travel)
