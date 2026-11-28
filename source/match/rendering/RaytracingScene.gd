# gdlint: disable=max-file-lines,max-returns
extends RefCounted

## Extracts static map geometry, transparent water surfaces, and observed dynamic units
## into Vulkan Hardware Ray Tracing acceleration structures (BLAS + TLAS) and a unified
## GPU geometry/material megabuffer on the main RenderingDevice.

const MAX_TLAS_INSTANCES := 16384
const MAX_DYNAMIC_UNITS := 512
const WATER_SHADERS := ["authored_water.gdshader", "authored_water_fast.gdshader"]
const SKIP_NODE_NAMES := [
	"Fog",
	"FogOfWar",
	"WeatherVeil",
	"Rain",
	"LavaEmbers",
	"Selection",
	"Highlight",
	"TeamFootprint",
	"AirToTerrainMarker",
	"GroundDecals",
	"WindowSill",
	"WindowMullion",
	"WindowLintel",
	"RoofPlantLouver",
	"BalconyRailing",
	"BalconyRail",
	"CanopyBracket",
	"RainwaterPipe",
	"StoneCourse",
	"BenchLeg",
]

# CPU-side mesh registry: mesh_key -> { "mesh_id": int, "verts": PackedFloat32Array,
# "normals": PackedFloat32Array, "indices": PackedInt32Array }
var _mesh_registry := {}
var _mesh_order := []
var _pending_meshes := []
var _unit_templates := {}

# Static map instances: array of dicts { "mesh_id", "transform", "mask", "albedo",
# "roughness", "metallic", "emission", "flags" }
var _static_instances := []
var _static_dirty := false
var _map_bounds := Rect2(-20, -20, 320, 320)
var _has_water := false
var _static_built := false
var _last_living_visible := true
var _dynamic_clock := 0.0
var _last_dynamic_sig := 0
var _closed := false

# Render-thread GPU resources (ONLY touched on render thread)
var _rd: RenderingDevice
var _blas_list: Array[RID] = []
var _blas_vbs: Array[RID] = []
var _blas_ibs: Array[RID] = []
var _tlas: RID
var _tlas_capacity := 0
var _hit_sbt_range := -1
var _instance_buf: RID
var _instance_cap := 0
var _mesh_desc_buf: RID
var _geo_index_buf: RID
var _geo_normal_buf: RID
var _geo_indices_cpu := PackedInt32Array()
var _geo_normals_cpu := PackedFloat32Array()
var _mesh_descs_cpu := PackedInt32Array()
var _geo_dirty := false
var _tlas_ready := false
var _active_instance_count := 0
var _revision := 0
var _static_rd_instances: Array[RDAccelerationStructureInstance] = []
var _static_packed_bytes := PackedByteArray()


func has_water() -> bool:
	return _has_water


func is_ready() -> bool:
	return _tlas_ready and _tlas.is_valid() and _active_instance_count > 0


func get_tlas() -> RID:
	return _tlas


func get_revision() -> int:
	return _revision


func get_closest_hit_buffers() -> Array[RID]:
	return [_instance_buf, _mesh_desc_buf, _geo_index_buf, _geo_normal_buf]


func set_hit_sbt_range(sbt_range: int):
	_hit_sbt_range = sbt_range


func build_static(game):
	if _closed or game == null or game.map == null:
		return
	var map_sz: Vector2 = game.map.size if "size" in game.map else Vector2(224, 224)
	_map_bounds = Rect2(Vector2(-16.0, -76.0), map_sz + Vector2(32.0, 96.0))
	_static_instances.clear()
	_has_water = false
	_last_living_visible = Globals.options.living_world
	_collect_node(game.map, false)
	if _static_instances.size() > MAX_TLAS_INSTANCES - MAX_DYNAMIC_UNITS:
		_static_instances.resize(MAX_TLAS_INSTANCES - MAX_DYNAMIC_UNITS)
	_static_built = true
	_static_dirty = true
	_last_dynamic_sig = -1
	sync_frame(game, true)


func sync_frame(game, force := false):
	if _closed or not _static_built or game == null or not is_instance_valid(game):
		return
	var living = game.map.get_node_or_null("LivingWorld") if is_instance_valid(game.map) else null
	var living_vis: bool = living.visible if living != null else false
	if living_vis != _last_living_visible:
		_last_living_visible = living_vis
		_static_instances.clear()
		_has_water = false
		_collect_node(game.map, false)
		if _static_instances.size() > MAX_TLAS_INSTANCES - MAX_DYNAMIC_UNITS:
			_static_instances.resize(MAX_TLAS_INSTANCES - MAX_DYNAMIC_UNITS)
		_static_dirty = true
		force = true
	if not force:
		_dynamic_clock += 1.0
		if _dynamic_clock < 3.0:
			return
		_dynamic_clock = 0.0

	var dyn_instances := []
	_append_dynamic_units(game, dyn_instances)
	var sig := _compute_dynamic_signature(dyn_instances)
	if not force and not _static_dirty and sig == _last_dynamic_sig and _pending_meshes.is_empty():
		return
	_last_dynamic_sig = sig

	var new_meshes := _pending_meshes.duplicate()
	_pending_meshes.clear()

	var static_entries := []
	var static_bytes := PackedByteArray()
	var send_static := _static_dirty
	if send_static:
		_static_dirty = false
		static_bytes = _pack_instance_buffer(_static_instances)
		static_entries.resize(_static_instances.size())
		for i in _static_instances.size():
			var item: Dictionary = _static_instances[i]
			static_entries[i] = [item.mesh_id, item.transform, item.mask]

	var dyn_bytes := (
		_pack_instance_buffer(dyn_instances) if not dyn_instances.is_empty() else PackedByteArray()
	)
	var dyn_entries := []
	dyn_entries.resize(dyn_instances.size())
	for i in dyn_instances.size():
		var item: Dictionary = dyn_instances[i]
		dyn_entries[i] = [item.mesh_id, item.transform, item.mask]

	RenderingServer.call_on_render_thread(
		_upload_render.bind(
			new_meshes, send_static, static_entries, static_bytes, dyn_entries, dyn_bytes
		)
	)


static func _compute_dynamic_signature(dyn_instances: Array) -> int:
	var h := dyn_instances.size() * 2654435761
	for item in dyn_instances:
		var xf: Transform3D = item.transform
		var o := xf.origin
		var fx := xf.basis.z
		h = (
			((h * 31) ^ int(round(o.x * 20.0)))
			^ (int(round(o.y * 20.0)) << 7)
			^ (int(round(o.z * 20.0)) << 14)
			^ (int(round(fx.x * 32.0)) << 21)
		)
	return h


func close():
	if _closed:
		return
	_closed = true
	_tlas_ready = false
	RenderingServer.call_on_render_thread(_release_render.bind(self))


func _collect_node(node: Node, skip_living: bool):
	if node == null or not is_instance_valid(node):
		return
	if node.name in SKIP_NODE_NAMES:
		return
	if node is GPUParticles3D:
		return
	if node is Node3D and not node.visible:
		return
	if node is MeshInstance3D and node.mesh != null:
		# Skip ground decals on render layer 11
		if (node.layers & (1 << 10)) != 0 and (node.layers & 1) == 0:
			return
		var is_lamp := node.name == "Lantern"
		var aabb: AABB = node.mesh.get_aabb()
		if not is_lamp and aabb.size.length() < 0.95:
			return
		_add_mesh_instance(node, node.global_transform, _static_instances)
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		if (node.layers & (1 << 10)) != 0 and (node.layers & 1) == 0:
			return
		_add_multimesh_instance(node, _static_instances)
	for child in node.get_children():
		_collect_node(child, skip_living)


func _add_mesh_instance(node: MeshInstance3D, xform: Transform3D, out_list: Array):
	var mesh: Mesh = node.mesh
	var count := mesh.get_surface_count()
	for s in count:
		var mat := node.get_active_material(s)
		var info := _classify_material(mat, node.name)
		if info.skip:
			continue
		var mesh_id := _register_surface(mesh, s)
		if mesh_id < 0:
			continue
		if info.mask == 2:
			_has_water = true
		(
			out_list
			. append(
				{
					"mesh_id": mesh_id,
					"transform": xform,
					"mask": info.mask,
					"albedo": info.albedo,
					"roughness": info.roughness,
					"metallic": info.metallic,
					"emission": info.emission,
					"flags": info.flags,
				}
			)
		)


func _add_multimesh_instance(node: MultiMeshInstance3D, out_list: Array):
	var mm: MultiMesh = node.multimesh
	var mesh: Mesh = mm.mesh
	var aabb: AABB = mesh.get_aabb()
	if aabb.size.length() < 1.25:
		return
	var total := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	if total <= 0:
		return
	var parent_xf: Transform3D = node.global_transform
	var count := mesh.get_surface_count()
	for s in count:
		var mat: Material = (
			node.material_override
			if node.material_override != null
			else mesh.surface_get_material(s)
		)
		var info := _classify_material(mat, node.name)
		if info.skip:
			continue
		var mesh_id := _register_surface(mesh, s)
		if mesh_id < 0:
			continue
		var cap := mini(total, 900)
		var added := 0
		for idx in total:
			if added >= cap:
				break
			var inst_xf: Transform3D = parent_xf * mm.get_instance_transform(idx)
			# Skip zero-scaled / hidden or distant off-map background clutter
			if inst_xf.basis.get_scale().length_squared() < 0.0001:
				continue
			if not _map_bounds.has_point(Vector2(inst_xf.origin.x, inst_xf.origin.z)):
				continue
			added += 1
			(
				out_list
				. append(
					{
						"mesh_id": mesh_id,
						"transform": inst_xf,
						"mask": info.mask,
						"albedo": info.albedo,
						"roughness": info.roughness,
						"metallic": info.metallic,
						"emission": info.emission,
						"flags": info.flags,
					}
				)
			)


func _append_dynamic_units(game, out_list: Array):
	var camera = game.get_node_or_null("IsometricCamera3D")
	var cam_focus := Vector3.ZERO
	if camera != null:
		var focus_dist: float = camera.global_position.y / maxf(0.1, camera.global_basis.z.y)
		cam_focus = camera.global_position - camera.global_basis.z * focus_dist
	var candidates := []
	for unit in game.get_units():
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or not unit.visible:
			continue
		if game.combat_audio != null and not game.combat_audio._observed(unit):
			continue
		var d2: float = (unit.global_position - cam_focus).length_squared()
		if d2 > 110.0 * 110.0:
			continue
		candidates.append([d2, unit])
	if candidates.size() > MAX_DYNAMIC_UNITS:
		candidates.sort_custom(func(a, b): return a[0] < b[0])
		candidates.resize(MAX_DYNAMIC_UNITS)
	for entry in candidates:
		var unit = entry[1]
		var parts := _unit_template(unit)
		var unit_xf: Transform3D = unit.global_transform
		for part in parts:
			(
				out_list
				. append(
					{
						"mesh_id": part.mesh_id,
						"transform": unit_xf * part.local_xf,
						"mask": 1,
						"albedo": part.albedo,
						"roughness": part.roughness,
						"metallic": part.metallic,
						"emission": part.emission,
						"flags": 0,
					}
				)
			)


func _unit_template(unit) -> Array:
	var faction := ""
	if "player" in unit and unit.player != null and "faction" in unit.player:
		faction = String(unit.player.faction)
	var team_col := Color(0.55, 0.58, 0.62)
	if "player" in unit and unit.player != null and "color" in unit.player:
		team_col = unit.player.color
	var key := "%s:%s:%s" % [faction, String(unit.type), team_col.to_html(false)]
	if _unit_templates.has(key):
		return _unit_templates[key]
	var parts := []
	var geom = unit.get_node_or_null("Geometry")
	var inv_root: Transform3D = unit.global_transform.affine_inverse()
	if geom != null:
		for child in geom.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var local_xf: Transform3D = inv_root * mi.global_transform
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				var info := _classify_material(mat, mi.name, team_col)
				if info.skip:
					continue
				var mesh_id := _register_surface(mi.mesh, s)
				if mesh_id >= 0:
					(
						parts
						. append(
							{
								"mesh_id": mesh_id,
								"local_xf": local_xf,
								"albedo": info.albedo,
								"roughness": info.roughness,
								"metallic": info.metallic,
								"emission": info.emission,
							}
						)
					)
	if parts.is_empty():
		# Fallback clean proxy box if UnitBatchRenderer already parked leaf meshes
		var r: float = maxf(0.45, float(unit.radius) if "radius" in unit else 0.9)
		var h: float = maxf(0.8, r * 1.15)
		var box := BoxMesh.new()
		box.size = Vector3(r * 1.5, h, r * 1.5)
		var mesh_id := _register_surface(box, 0)
		if mesh_id >= 0:
			(
				parts
				. append(
					{
						"mesh_id": mesh_id,
						"local_xf": Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)),
						"albedo": team_col.lerp(Color(0.35, 0.37, 0.39), 0.55).srgb_to_linear(),
						"roughness": 0.45,
						"metallic": 0.45,
						"emission": Color(0.0, 0.0, 0.0),
					}
				)
			)
	_unit_templates[key] = parts
	return parts


func _register_surface(mesh: Mesh, surface: int) -> int:
	var key := "%d:%d" % [mesh.get_instance_id(), surface]
	if _mesh_registry.has(key):
		return _mesh_registry[key]
	if surface >= mesh.get_surface_count():
		return -1
	var arrays: Array = mesh.surface_get_arrays(surface)
	if arrays.is_empty():
		return -1
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.size() < 3:
		return -1
	var normals: PackedVector3Array = (
		arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	)
	var indices: PackedInt32Array = (
		arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	)
	if indices.is_empty():
		var tri_count := verts.size() / 3
		if tri_count <= 0:
			return -1
		indices.resize(tri_count * 3)
		for i in indices.size():
			indices[i] = i
	if indices.size() < 3 or (indices.size() % 3) != 0:
		var usable := (indices.size() / 3) * 3
		if usable < 3:
			return -1
		indices.resize(usable)
	var packed_verts := PackedFloat32Array()
	packed_verts.resize(verts.size() * 3)
	var packed_normals := PackedFloat32Array()
	packed_normals.resize(verts.size() * 4)
	var has_normals := normals.size() == verts.size()
	for i in verts.size():
		var v := verts[i]
		packed_verts[i * 3] = v.x
		packed_verts[i * 3 + 1] = v.y
		packed_verts[i * 3 + 2] = v.z
		var n := normals[i] if has_normals else Vector3.UP
		packed_normals[i * 4] = n.x
		packed_normals[i * 4 + 1] = n.y
		packed_normals[i * 4 + 2] = n.z
		packed_normals[i * 4 + 3] = 1.0
	if not has_normals:
		# Compute flat face normals for meshes lacking vertex normals
		for t in range(0, indices.size(), 3):
			var i0 := indices[t]
			var i1 := indices[t + 1]
			var i2 := indices[t + 2]
			var fn := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).normalized()
			if fn.length_squared() < 0.001:
				fn = Vector3.UP
			for idx in [i0, i1, i2]:
				packed_normals[idx * 4] = fn.x
				packed_normals[idx * 4 + 1] = fn.y
				packed_normals[idx * 4 + 2] = fn.z

	var mesh_id := _mesh_order.size()
	_mesh_registry[key] = mesh_id
	_mesh_order.append(key)
	(
		_pending_meshes
		. append(
			{
				"mesh_id": mesh_id,
				"verts": packed_verts,
				"normals": packed_normals,
				"indices": indices,
				"vert_count": verts.size(),
			}
		)
	)
	return mesh_id


func _classify_material(
	mat: Material, node_name: String, team_col := Color(0.5, 0.52, 0.55)
) -> Dictionary:
	var result := {
		"skip": false,
		"mask": 1,
		"albedo": Color(0.32, 0.34, 0.32),
		"roughness": 0.78,
		"metallic": 0.0,
		"emission": Color(0.0, 0.0, 0.0),
		"flags": 0,
	}
	if mat == null:
		return result
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.emission_enabled:
			result.skip = true
			return result
		var col := sm.albedo_color
		if sm.resource_name.begins_with("TeamColor"):
			col = team_col
		result.albedo = col.srgb_to_linear()
		result.roughness = clampf(sm.roughness, 0.05, 1.0)
		result.metallic = clampf(sm.metallic, 0.0, 1.0)
		if sm.emission_enabled:
			var emit_col := sm.emission.srgb_to_linear() * sm.emission_energy_multiplier
			result.emission = emit_col
			if node_name == "Lantern":
				result.flags = 3
		return result
	if mat is ShaderMaterial and mat.shader != null:
		var sh_file: String = mat.shader.resource_path.get_file()
		if sh_file in WATER_SHADERS:
			result.mask = 2
			result.albedo = Color(0.06, 0.14, 0.16)
			result.roughness = 0.08
			result.flags = 1
			return result
		if (
			sh_file
			in [
				"battlefield_atmosphere.gdshader",
				"fog.gdshader",
				"simple_fog_of_war.gdshader",
				"team_footprint.gdshader",
				"faction_selection.gdshader",
				"circle.gdshader",
				"faded_circle.gdshader",
				"ability_aura.gdshader",
				"battlefield_wear.gdshader",
				"battle_scar.gdshader",
				"blueprint.gdshader",
			]
		):
			result.skip = true
			return result
		if sh_file == "authored_lava.gdshader":
			result.albedo = Color(0.25, 0.06, 0.02)
			result.emission = Color(2.4, 0.65, 0.12)
			result.roughness = 0.45
			return result
		if sh_file == "living_facade.gdshader":
			var masonry = mat.get_shader_parameter("masonry")
			if masonry is Color:
				result.albedo = masonry.srgb_to_linear()
			result.roughness = 0.85
			result.flags = 2
			return result
		if sh_file == "coastal_water.gdshader" or sh_file == "living_river.gdshader":
			result.albedo = Color(0.05, 0.14, 0.18)
			result.roughness = 0.08
			return result
		if sh_file == "authored_terrain.gdshader":
			var low = mat.get_shader_parameter("ground_low")
			var high = mat.get_shader_parameter("ground_high")
			if low is Color and high is Color:
				result.albedo = low.lerp(high, 0.5).srgb_to_linear()
			result.roughness = 0.90
			return result
		if sh_file == "district_ground.gdshader" or sh_file == "foundry_ground.gdshader":
			result.albedo = Color(0.18, 0.19, 0.18)
			result.roughness = 0.82
			return result
		# Armor / object_surface / foliage / rock shaders
		var base_c = mat.get_shader_parameter("base_color")
		if base_c is Color:
			result.albedo = base_c.srgb_to_linear()
		else:
			var rock_c = mat.get_shader_parameter("rock")
			if rock_c is Color:
				result.albedo = rock_c.srgb_to_linear()
			elif "tree" in node_name.to_lower() or "foliage" in sh_file:
				result.albedo = Color(0.10, 0.18, 0.08)
		var r_val = mat.get_shader_parameter("base_roughness")
		if r_val is float:
			result.roughness = clampf(r_val, 0.08, 1.0)
		var m_val = mat.get_shader_parameter("metalness")
		if m_val is float:
			result.metallic = clampf(m_val, 0.0, 1.0)
		return result
	return result


func _pack_instance_buffer(instances: Array) -> PackedByteArray:
	var count := maxi(1, instances.size())
	var bytes := PackedByteArray()
	bytes.resize(count * 48)
	for i in instances.size():
		var item: Dictionary = instances[i]
		var off := i * 48
		var alb: Color = item.albedo
		var em: Color = item.emission
		bytes.encode_float(off + 0, alb.r)
		bytes.encode_float(off + 4, alb.g)
		bytes.encode_float(off + 8, alb.b)
		bytes.encode_float(off + 12, float(item.roughness))
		bytes.encode_float(off + 16, em.r)
		bytes.encode_float(off + 20, em.g)
		bytes.encode_float(off + 24, em.b)
		bytes.encode_float(off + 28, float(item.metallic))
		bytes.encode_u32(off + 32, int(item.mesh_id))
		bytes.encode_u32(off + 36, int(item.flags))
		bytes.encode_u32(off + 40, 0)
		bytes.encode_u32(off + 44, 0)
	return bytes


func _upload_render(
	new_meshes: Array,
	send_static: bool,
	static_entries: Array,
	static_bytes: PackedByteArray,
	dyn_entries: Array,
	dyn_bytes: PackedByteArray
):
	if _closed:
		return
	_rd = RenderingServer.get_rendering_device()
	if _rd == null or not _rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE):
		return
	if _hit_sbt_range < 0:
		return

	for m in new_meshes:
		var verts: PackedFloat32Array = m.verts
		var normals: PackedFloat32Array = m.normals
		var indices: PackedInt32Array = m.indices
		var vb_bytes := verts.to_byte_array()
		var ib_bytes := indices.to_byte_array()
		var vb := _rd.vertex_buffer_create(
			vb_bytes.size(),
			vb_bytes,
			RenderingDevice.BUFFER_CREATION_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT
		)
		var ib := _rd.index_buffer_create(
			indices.size(),
			RenderingDevice.INDEX_BUFFER_FORMAT_UINT32,
			ib_bytes,
			false,
			RenderingDevice.BUFFER_CREATION_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT
		)
		var geom := RDAccelerationStructureGeometry.new()
		geom.flags = RenderingDevice.ACCELERATION_STRUCTURE_GEOMETRY_OPAQUE_BIT
		geom.vertex_buffer = vb
		geom.vertex_offset = 0
		geom.vertex_stride = 12
		geom.vertex_count = int(m.vert_count)
		geom.vertex_format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
		geom.index_buffer = ib
		geom.index_offset = 0
		geom.index_count = indices.size()
		var blas := _rd.blas_create(
			[geom], RenderingDevice.ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT
		)
		if blas.is_valid():
			_rd.blas_build(blas)
		_blas_vbs.append(vb)
		_blas_ibs.append(ib)
		_blas_list.append(blas)

		var idx_off := _geo_indices_cpu.size()
		var vert_off := _geo_normals_cpu.size() / 4
		_geo_indices_cpu.append_array(indices)
		_geo_normals_cpu.append_array(normals)
		_mesh_descs_cpu.append_array(PackedInt32Array([idx_off, vert_off, indices.size(), 0]))
		_geo_dirty = true

	if _geo_dirty and not _geo_indices_cpu.is_empty():
		_geo_dirty = false
		if _mesh_desc_buf.is_valid():
			_rd.free_rid(_mesh_desc_buf)
		if _geo_index_buf.is_valid():
			_rd.free_rid(_geo_index_buf)
		if _geo_normal_buf.is_valid():
			_rd.free_rid(_geo_normal_buf)
		var md_bytes := _mesh_descs_cpu.to_byte_array()
		var gi_bytes := _geo_indices_cpu.to_byte_array()
		var gn_bytes := _geo_normals_cpu.to_byte_array()
		_mesh_desc_buf = _rd.storage_buffer_create(md_bytes.size(), md_bytes)
		_geo_index_buf = _rd.storage_buffer_create(gi_bytes.size(), gi_bytes)
		_geo_normal_buf = _rd.storage_buffer_create(gn_bytes.size(), gn_bytes)
		_revision += 1

	if send_static:
		_static_packed_bytes = static_bytes
		_static_rd_instances.clear()
		for i in static_entries.size():
			var e: Array = static_entries[i]
			var mesh_id: int = e[0]
			if mesh_id < 0 or mesh_id >= _blas_list.size():
				continue
			var blas: RID = _blas_list[mesh_id]
			if not blas.is_valid():
				continue
			var inst := RDAccelerationStructureInstance.new()
			inst.transform = e[1]
			inst.id = i
			inst.mask = int(e[2])
			inst.hit_sbt_range = _hit_sbt_range
			inst.flags = RenderingDevice.ACCELERATION_STRUCTURE_INSTANCE_FORCE_OPAQUE_BIT
			inst.blas = blas
			_static_rd_instances.append(inst)

	var static_count := _static_packed_bytes.size() / 48
	var total_bytes_size := maxi(48, _static_packed_bytes.size() + dyn_bytes.size())
	var reallocated := false
	if not _instance_buf.is_valid() or total_bytes_size > _instance_cap:
		if _instance_buf.is_valid():
			_rd.free_rid(_instance_buf)
		_instance_cap = nearest_po2(total_bytes_size)
		_instance_buf = _rd.storage_buffer_create(_instance_cap)
		_revision += 1
		reallocated = true
	if (send_static or reallocated) and not _static_packed_bytes.is_empty():
		_rd.buffer_update(_instance_buf, 0, _static_packed_bytes.size(), _static_packed_bytes)
	if not dyn_bytes.is_empty():
		_rd.buffer_update(_instance_buf, _static_packed_bytes.size(), dyn_bytes.size(), dyn_bytes)

	var rd_instances: Array[RDAccelerationStructureInstance] = _static_rd_instances.duplicate()
	for i in dyn_entries.size():
		var e: Array = dyn_entries[i]
		var mesh_id: int = e[0]
		if mesh_id < 0 or mesh_id >= _blas_list.size():
			continue
		var blas: RID = _blas_list[mesh_id]
		if not blas.is_valid():
			continue
		var inst := RDAccelerationStructureInstance.new()
		inst.transform = e[1]
		inst.id = static_count + i
		inst.mask = int(e[2])
		inst.hit_sbt_range = _hit_sbt_range
		inst.flags = RenderingDevice.ACCELERATION_STRUCTURE_INSTANCE_FORCE_OPAQUE_BIT
		inst.blas = blas
		rd_instances.append(inst)

	if rd_instances.is_empty():
		_active_instance_count = 0
		_tlas_ready = false
		return

	if not _tlas.is_valid() or rd_instances.size() > _tlas_capacity:
		if _tlas.is_valid():
			_rd.free_rid(_tlas)
		_tlas_capacity = maxi(256, nearest_po2(rd_instances.size()))
		_tlas = _rd.tlas_create(
			_tlas_capacity,
			(
				RenderingDevice.ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT
				| RenderingDevice.ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT
			)
		)
		_revision += 1

	var err := _rd.tlas_build(_tlas, rd_instances)
	_active_instance_count = rd_instances.size() if err == OK else 0
	_tlas_ready = (err == OK and _mesh_desc_buf.is_valid() and _geo_index_buf.is_valid())


func _release_render(_keep_alive: RefCounted = null):
	if _rd == null:
		return
	_static_rd_instances.clear()
	_static_packed_bytes.clear()
	if _tlas.is_valid():
		_rd.free_rid(_tlas)
	_tlas = RID()
	for blas in _blas_list:
		if blas.is_valid():
			_rd.free_rid(blas)
	_blas_list.clear()
	for vb in _blas_vbs:
		if vb.is_valid():
			_rd.free_rid(vb)
	_blas_vbs.clear()
	for ib in _blas_ibs:
		if ib.is_valid():
			_rd.free_rid(ib)
	_blas_ibs.clear()
	for buf in [_instance_buf, _mesh_desc_buf, _geo_index_buf, _geo_normal_buf]:
		if buf.is_valid():
			_rd.free_rid(buf)
	_instance_buf = RID()
	_mesh_desc_buf = RID()
	_geo_index_buf = RID()
	_geo_normal_buf = RID()
	_tlas_ready = false
	_active_instance_count = 0
