extends Node3D

## Render articulated models through shared meshes and a GPU pose palette.
## The opt-in decoupled path keeps articulated transforms in worker memory;
## weapon sockets publish on demand. Enable after measuring on target hardware.
## Decorative leaves are parked under a stationary hidden root, avoiding unit
## transform propagation while retaining Godot's visibility-change notifications;
## duplicate_geometry restores them temporarily for wrecks and fog memories.
const Builder = preload("res://source/match/rendering/RigidBatchMesh.gd")
const POSE_CAPACITY := 8192
const CELL_SIZE := 24.0
const GROUP_CAPACITY := 128

var _builder: RefCounted
var _compute: RefCounted
var _native: RefCounted
var _texture: ImageTexture
var _previous_texture: ImageTexture
var _last_pixels := PackedByteArray()
var _world_jobs := []
var _chassis_jobs := []
var _infantry_jobs := []
var _models := {}
var _mesh_hashes := {}
var _groups := {}
var _units := {}
var _pending := {}
var _entries := []
var _free_poses := {}
var _pose_count := 1  # Row zero is the identity pose for static spatial batches.
var _static_batches := []
var _flush_queued := false
var _orphans: Node3D
var _pose_workers = preload("res://source/match/rendering/ParallelPoseBatch.gd").new()
var _parallel_poses := not "--serial-pose-jobs" in OS.get_cmdline_user_args()
var _infantry_jobs_enabled := not "--no-infantry-workers" in OS.get_cmdline_user_args()
var _decoupled_poses := "--enable-decoupled-poses" in OS.get_cmdline_user_args()
var _render_pose_updates := not "--physics-pose-updates" in OS.get_cmdline_user_args()
var _pending_pose_delta := 0.0
var _native_infantry_poses := "--native-infantry-poses" in OS.get_cmdline_user_args()
var _native_infantry_solved := 0
var _native_infantry_fallbacks := 0
var _native_pose_rigs := (
	"--native-pose-rigs" in OS.get_cmdline_user_args()
	or "--native-presentation" in OS.get_cmdline_user_args()
)
var _presentation: RefCounted
var _presentation_entries := {}
var _resident_rigs := 0
var _profile_runtime := "--profile-runtime" in OS.get_cmdline_user_args()
# roots, prepare, chassis solve, finish, infantry solve, publish, upload;
# each stage has total elapsed microseconds followed by its call count.
var _profile_us := PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])


func _ready():
	if DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() != null:
		_native = load("res://source/match/rendering/NativePosePacker.gd").create()
	if _native == null or "--disable-unit-batching" in OS.get_cmdline_user_args():
		set_process(false)
		set_physics_process(false)
		return
	_render_pose_updates = _render_pose_updates and _native.has_method("rebase_poses")
	_native_infantry_poses = (_native_infantry_poses and _native.has_method("solve_infantry_batch"))
	_native_pose_rigs = _native_pose_rigs and ClassDB.class_exists("CopperfinPoseRig")
	if (
		"--native-presentation" in OS.get_cmdline_user_args()
		and _render_pose_updates
		and _native_pose_rigs
		and ClassDB.class_exists("CopperfinPresentationBatch")
	):
		_presentation = ClassDB.instantiate("CopperfinPresentationBatch")
		if not _presentation.has_method("set_track") or not _presentation.configure(POSE_CAPACITY):
			_presentation = null
	if _render_pose_updates:
		get_tree().physics_frame.connect(_capture_physics_roots)
	_orphans = Node3D.new()
	_orphans.name = "ParkedMeshSources"
	_orphans.hide()
	add_child(_orphans)
	process_priority = 10000
	process_physics_priority = 10000
	process_mode = Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY
	var image := Image.create(4, POSE_CAPACITY, false, Image.FORMAT_RGBAF)
	_texture = ImageTexture.create_from_image(image)
	_previous_texture = ImageTexture.create_from_image(image)
	_last_pixels.resize(POSE_CAPACITY * 64)
	for diagonal in [0, 5, 10]:
		_last_pixels.encode_float(diagonal * 4, 1.0)
	_builder = Builder.new()
	_compute = load("res://source/match/rendering/ComputePosePalette.gd").new()
	_compute.setup(_previous_texture, _texture, POSE_CAPACITY)
	_builder.setup(_compute.texture)
	MatchSignals.unit_spawned.connect(_queue_unit)
	MatchSignals.unit_construction_finished.connect(_queue_unit)
	for unit in get_tree().get_nodes_in_group("units"):
		_queue_unit(unit)
	_batch_static_map.call_deferred()


func _batch_static_map():
	var map = get_parent().map
	for name in ["Decorations", "WorldDressing", "LivingWorld"]:
		var branch: Node3D = map.get_node_or_null(name)
		if branch == null:
			continue
		var chunks := {}
		for source: MeshInstance3D in branch.find_children("*", "MeshInstance3D", true, false):
			if not _eligible(source) or source.get_child_count() > 0:
				continue
			# Interactive buildings, wildlife and traffic own scripted ancestors.
			# Leave their damage, animation and replacement geometry fully dynamic.
			var ancestor := source.get_parent()
			var dynamic := false
			while ancestor != branch:
				if ancestor.get_script() != null:
					dynamic = true
					break
				ancestor = ancestor.get_parent()
			if name == "LivingWorld":
				dynamic = dynamic or source in branch._cloths
				for surface in source.mesh.get_surface_count():
					dynamic = dynamic or source.get_active_material(surface) == branch.windows
			if dynamic:
				continue
			var world := source.global_transform
			var cell := Vector2i(floori(world.origin.x / 16.0), floori(world.origin.z / 16.0))
			chunks.get_or_add(cell, []).append([source, world, 0])
		for pieces in chunks.values():
			if pieces.size() < 2 or not _builder.can_merge(pieces):
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = _builder.merge(pieces)
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D.IDENTITY)
			mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = mm
			batch.top_level = true
			branch.add_child(batch)
			batch.global_transform = Transform3D.IDENTITY
			var group := {"node": batch, "sources": [], "restored": false}
			for piece in pieces:
				var source: MeshInstance3D = piece[0]
				group.sources.append(source)
				RenderingServer.instance_set_base(source.get_instance(), RID())
				source.visibility_changed.connect(_static_visibility_changed.bind(source, group))
			_static_batches.append(group)


func _static_visibility_changed(source, group):
	if not source.visible:
		_restore_static(group)


func _restore_static(group):
	if group.restored:
		return
	group.restored = true
	if is_instance_valid(group.node):
		group.node.hide()
	for source in group.sources:
		if is_instance_valid(source) and source.mesh != null:
			_restore_mesh(source)


func _restore_mesh(source: MeshInstance3D):
	var instance = source.get_instance()
	RenderingServer.instance_set_base(instance, source.mesh.get_rid())
	# Clearing a rendering instance's base also clears its surface overrides in
	# the server. MeshInstance3D still retains those resources, so rebind them
	# when leaving a batch (fog, construction, hidden parts and damage effects).
	for surface in source.mesh.get_surface_count():
		var material = source.get_surface_override_material(surface)
		if material != null:
			RenderingServer.instance_set_surface_override_material(
				instance, surface, material.get_rid()
			)
	if source.material_override != null:
		RenderingServer.instance_geometry_set_material_override(
			instance, source.material_override.get_rid()
		)
	if source.material_overlay != null:
		RenderingServer.instance_geometry_set_material_overlay(
			instance, source.material_overlay.get_rid()
		)


func _queue_unit(unit):
	_pending[unit] = true
	if not _flush_queued:
		_flush_queued = true
		_flush_units.call_deferred()


func _flush_units():
	_flush_queued = false
	var pending := _pending.keys()
	_pending.clear()
	for unit in pending:
		if is_instance_valid(unit) and unit.is_inside_tree() and not _units.has(unit):
			_add_unit(unit)
	_upload_poses()


func _add_unit(unit):
	if _units.has(unit):
		return
	if unit.has_method("is_under_construction") and unit.is_under_construction():
		return
	var geometry: Node3D = unit.get_node("Geometry")
	var visuals = unit.get_node_or_null("BastionVisuals")
	if visuals == null:
		return
	var anchors: Array[Node3D] = []
	if visuals._track_motion != null:
		# Reserve row zero for the unit hit pulse. Each belt owns a separate
		# articulated row whose fourth column carries its signed travel.
		anchors.append(geometry)
	var pieces := []
	var signature := []
	for source: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
		if not _eligible(source):
			continue
		var anchor: Node3D = source if source in visuals._rotors else source.get_parent()
		if anchor not in anchors:
			anchors.append(anchor)
		var local := Transform3D.IDENTITY if anchor == source else source.transform
		var part := anchors.find(anchor)
		pieces.append([source, local, part])
		var materials := []
		for surface in source.mesh.get_surface_count():
			materials.append(source.get_active_material(surface))
		if not _mesh_hashes.has(source.mesh):
			var arrays := []
			for surface in source.mesh.get_surface_count():
				arrays.append(source.mesh.surface_get_arrays(surface))
			_mesh_hashes[source.mesh] = hash(arrays)
		signature.append([_mesh_hashes[source.mesh], local, part, materials])
	if pieces.is_empty() or not _builder.can_merge(pieces):
		return
	var offset := _allocate_poses(anchors.size())
	if offset < 0:
		return
	if not _models.has(signature):
		_models[signature] = _builder.merge(pieces)
	var extent := 0.0
	var inverse_root: Transform3D = unit.global_transform.affine_inverse()
	for piece in pieces:
		var source: MeshInstance3D = piece[0]
		var bounds := source.mesh.get_aabb()
		var relative: Transform3D = inverse_root * source.global_transform
		for corner in 8:
			extent = maxf(extent, (relative * bounds.get_endpoint(corner)).length())
	var entry := {
		"unit": unit,
		"owner": unit.player,
		"geometry": geometry,
		"anchors": anchors,
		"offset": offset,
		"mesh": _models[signature],
		# Twice the rest reach covers articulation around offset pivots; leave
		# additional room for recoil, suspension and the previous motion sample.
		"bounds_radius": extent * 2.0 + 2.0,
		"sources": [],
		"group": null,
		"slot": -1,
		"previous_position": Vector3.INF,
		"tracks": [],
		"detached": [],
		"pulse_material": null,
		"visuals": visuals,
		"reset": true,
		"shown": false,
		"pulse": Color(0, 0, 0, 0),
		"step_delta": 0.0,
		"physics_root": unit.global_transform,
		"sampled_root": unit.global_transform,
		"rebase": Transform3D.IDENTITY,
	}
	for piece in pieces:
		var source: MeshInstance3D = piece[0]
		if source.has_meta("animated_track"):
			for belt in visuals._track_motion.belts:
				if belt.mesh == source:
					entry.tracks.append([belt, piece[2]])
		entry.sources.append(source)
		RenderingServer.instance_set_base(source.get_instance(), RID())
		# A selectively hidden/replaced part must immediately regain native rendering.
		source.visibility_changed.connect(_source_visibility_changed.bind(source, unit))
		if (
			source not in anchors
			and source != visuals._muzzle
			and source != visuals._projectile_origin
			and source.get_child_count() == 0
			and not (
				"Muzzle" in source.name
				or "Emitter" in source.name
				or "Barrel" in source.name
				or "Tip" in source.name
			)
		):
			entry.detached.append([source, source.get_parent(), source.transform, source.owner])
		else:
			source.tree_exiting.connect(_invalidate.bind(unit), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_entries.append(entry)
	_units[unit] = entry
	unit.tree_exiting.connect(_unit_exiting.bind(unit), CONNECT_ONE_SHOT)
	geometry.set_meta("gpu_batch_renderer", weakref(self))
	_detach_sources(entry)
	var decoupled := (
		_decoupled_poses
		or _native_pose_rigs
		or (_native_infantry_poses and visuals._infantry_motion != null)
	)
	visuals.set_gpu_interpolation(true, anchors if decoupled else [], _native)
	if decoupled:
		entry.poses = visuals._pose_hierarchy.job.palette
		if visuals._pose_hierarchy.job.native_rig != null:
			entry.native_rig = visuals._pose_hierarchy.job.native_rig
			visuals._pose_hierarchy.job.direct_palette = true
			_resident_rigs += 1
		_world_jobs.append(visuals._pose_hierarchy.job)
	_join_group(entry)
	if _presentation != null:
		var handle: int = _presentation.bind_unit(
			unit, geometry, anchors, entry.get("native_rig"), offset, entry.bounds_radius
		)
		if handle < 0:
			_disable_native_presentation()
		else:
			entry.presentation_handle = handle
			_presentation_entries[handle] = entry
			visuals.set_native_presentation(_presentation, handle)
			_update_native_pulse(entry)
	_bind_tracks(entry)


func _bind_tracks(entry):
	for track in entry.tracks:
		entry.visuals._track_motion.bind_palette(
			track[0].mesh, _presentation, entry.get("presentation_handle", -1), track[1]
		)
	# Track bindings can remove the last native scene-geometry dependency.
	if entry.has("presentation_handle"):
		entry.visuals.set_native_presentation(_presentation, entry.presentation_handle)


func _disable_native_presentation():
	for entry in _presentation_entries.values():
		entry.visuals.set_native_presentation(null, -1)
		entry.erase("presentation_handle")
		for track in entry.tracks:
			entry.visuals._track_motion.bind_palette(track[0].mesh, null, -1, track[1])
	_presentation_entries.clear()
	_presentation = null


func _update_native_pulse(entry):
	if _presentation == null or not entry.has("presentation_handle"):
		return
	var overlay = entry.pulse_material
	var material = null
	if (
		overlay is ShaderMaterial
		and overlay.shader != null
		and overlay.shader.resource_path.ends_with("material_hit.gdshader")
	):
		material = overlay
	_presentation.set_pulse(entry.presentation_handle, material)


func _detach_sources(entry):
	for part in entry.detached:
		var source: Node3D = part[0]
		if source.get_parent() != _orphans:
			source.get_parent().remove_child(source)
			_orphans.add_child(source)


func _restore_sources(entry):
	if entry.visuals._track_motion != null:
		entry.visuals._track_motion.sync_originals()
	for part in entry.detached:
		var source: Node3D = part[0]
		if is_instance_valid(source) and is_instance_valid(part[1]):
			source.get_parent().remove_child(source)
			part[1].add_child(source)
			source.transform = part[2]
			if is_instance_valid(part[3]):
				source.owner = part[3]


static func duplicate_geometry(geometry: Node3D, flags: int = 15) -> Node3D:
	var reference = (
		geometry.get_meta("gpu_batch_renderer") if geometry.has_meta("gpu_batch_renderer") else null
	)
	var renderer = reference.get_ref() if reference != null else null
	if renderer == null or not renderer._units.has(geometry.get_parent()):
		return geometry.duplicate(flags)
	var entry = renderer._units[geometry.get_parent()]
	renderer._restore_sources(entry)
	if entry.visuals._pose_hierarchy != null:
		entry.visuals._pose_hierarchy.publish()
	# Reparented leaves cannot be reconstructed from the imported scene's owner
	# table. Copy the current posed tree, including runtime-generated meshes.
	var copy = geometry.duplicate(flags & ~Node.DUPLICATE_USE_INSTANTIATION)
	# Freeze each belt at its current travel in wrecks and fog memories.
	# Generated mesh names may change on duplication; belt indices stay stable.
	if entry.visuals._track_motion != null:
		for cloned_belt in copy.find_children("*", "MeshInstance3D", true, false):
			if cloned_belt.has_meta("track_belt_index"):
				var belt = entry.visuals._track_motion.belts[cloned_belt.get_meta(
					"track_belt_index"
				)]
				cloned_belt.set_instance_shader_parameter("track_travel", belt.travel)
	copy.remove_meta("gpu_batch_renderer")
	if copy.has_meta("hit_flash_surfaces"):
		copy.remove_meta("hit_flash_surfaces")
	renderer._detach_sources(entry)
	return copy


func set_hit_pulse(geometry, material):
	var unit = geometry.get_parent()
	if _units.has(unit):
		_units[unit].pulse_material = material
		_update_native_pulse(_units[unit])


func clear_hit_pulse(geometry, material):
	var unit = geometry.get_parent()
	if _units.has(unit) and _units[unit].pulse_material == material:
		_units[unit].pulse_material = null
		_update_native_pulse(_units[unit])


func _unit_exiting(unit):
	_invalidate(unit, true)


func _source_visibility_changed(source, unit):
	# Ancestor fog visibility also emits this signal; it is represented by the
	# palette and must not discard the batch. A part's own visibility is different.
	if not source.visible:
		_invalidate(unit)


func _eligible(source: MeshInstance3D) -> bool:
	if (
		source.has_meta("dynamic_presentation")
		or source.mesh == null
		or source.skin != null
		or not source.visible
	):
		return false
	if source.get_script() != null or source.material_overlay != null or source.transparency != 0.0:
		return false
	if source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or source.layers != 1:
		return false
	if source.visibility_range_begin != 0.0 or source.visibility_range_end != 0.0:
		return false
	if source.mesh is ArrayMesh and source.mesh.get_blend_shape_count() > 0:
		return false
	for surface in source.mesh.get_surface_count():
		if (
			source.mesh is ArrayMesh
			and source.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES
		):
			return false
		if not _builder.supports(source.get_active_material(surface)):
			return false
	return true


func _allocate_poses(count: int) -> int:
	var free: Array = _free_poses.get(count, [])
	if not free.is_empty():
		return free.pop_back()
	if _pose_count + count > POSE_CAPACITY:
		return -1
	var offset := _pose_count
	_pose_count += count
	return offset


func _join_group(entry):
	var position: Vector3 = entry.unit.global_position
	var cell := Vector2i(floori(position.x / CELL_SIZE), floori(position.z / CELL_SIZE))
	if entry.group != null and entry.group.cell == cell:
		_grow_group_bounds(entry.group, position.y, entry.bounds_radius)
		return
	var key := [entry.mesh, cell]
	_leave_group(entry)
	if not _groups.has(key):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = entry.mesh
		mm.instance_count = GROUP_CAPACITY
		mm.visible_instance_count = 0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		add_child(node)
		_groups[key] = {
			"cell": cell, "mm": mm, "entries": [], "padding": 0.0, "low": INF, "high": -INF
		}
	var group: Dictionary = _groups[key]
	_grow_group_bounds(group, position.y, entry.bounds_radius)
	if group.entries.size() >= GROUP_CAPACITY:
		_invalidate(entry.unit)
		return
	entry.group = group
	entry.slot = group.entries.size()
	group.entries.append(entry)
	group.mm.set_instance_transform(entry.slot, Transform3D.IDENTITY)
	group.mm.set_instance_custom_data(entry.slot, Color(entry.offset, 0, 0, 0))
	group.mm.visible_instance_count = group.entries.size()


func _grow_group_bounds(group: Dictionary, height: float, radius: float):
	if radius <= group.padding and height - radius >= group.low and height + radius <= group.high:
		return
	group.padding = maxf(group.padding, radius)
	group.low = minf(group.low, height - radius - 1.0)
	group.high = maxf(group.high, height + radius + 1.0)
	var padding: float = group.padding
	group.mm.custom_aabb = AABB(
		Vector3(group.cell.x * CELL_SIZE - padding, group.low, group.cell.y * CELL_SIZE - padding),
		Vector3(CELL_SIZE + padding * 2.0, group.high - group.low, CELL_SIZE + padding * 2.0)
	)


func _leave_group(entry):
	if entry.group == null:
		return
	var group: Dictionary = entry.group
	var last = group.entries.pop_back()
	if last != entry:
		group.entries[entry.slot] = last
		last.slot = entry.slot
		group.mm.set_instance_custom_data(last.slot, Color(last.offset, 0, 0, 0))
	group.mm.visible_instance_count = group.entries.size()
	entry.group = null


func _invalidate(unit, exiting := false):
	if not _units.has(unit):
		return
	var entry: Dictionary = _units[unit]
	if entry.visuals._track_motion != null:
		entry.visuals._track_motion.unbind_palette()
	if entry.has("presentation_handle"):
		entry.visuals.set_native_presentation(null, -1)
		_presentation.unbind(entry.presentation_handle)
		_presentation_entries.erase(entry.presentation_handle)
	if entry.has("native_rig"):
		_resident_rigs -= 1
	_entries.erase(entry)
	if entry.visuals._pose_hierarchy != null:
		_world_jobs.erase(entry.visuals._pose_hierarchy.job)
	_units.erase(unit)
	for source in entry.sources:
		if is_instance_valid(source):
			var visibility_callback = _source_visibility_changed.bind(source, unit)
			if source.visibility_changed.is_connected(visibility_callback):
				source.visibility_changed.disconnect(visibility_callback)
			var exit_callback = _invalidate.bind(unit)
			if source.tree_exiting.is_connected(exit_callback):
				source.tree_exiting.disconnect(exit_callback)
	if is_instance_valid(unit) and unit.tree_exiting.is_connected(_unit_exiting.bind(unit)):
		unit.tree_exiting.disconnect(_unit_exiting.bind(unit))
	if is_instance_valid(entry.geometry):
		entry.geometry.remove_meta("gpu_batch_renderer")
	if not exiting:
		_restore_sources(entry)
	else:
		for part in entry.detached:
			if is_instance_valid(part[0]):
				part[0].free()
	if not exiting and is_instance_valid(unit):
		var visual = unit.get_node_or_null("BastionVisuals")
		if visual != null:
			visual.set_gpu_interpolation(false)
	_leave_group(entry)
	for source in entry.sources:
		if is_instance_valid(source) and source.mesh != null:
			_restore_mesh(source)
	_free_poses.get_or_add(entry.anchors.size(), []).append(entry.offset)


func _process(_delta: float):
	if _render_pose_updates and not get_tree().paused and _pending_pose_delta > 0.0:
		_advance_poses(_pending_pose_delta)
		_pending_pose_delta = 0.0
	_compute.dispatch(
		1.0 if get_tree().paused else Engine.get_physics_interpolation_fraction(), _pose_count
	)
	if get_tree().paused:
		_upload_poses()


func _physics_process(delta: float):
	if _render_pose_updates:
		return
	_advance_poses(delta)


func _capture_physics_roots():
	if get_tree().paused:
		return
	var profile_start := Time.get_ticks_usec() if _profile_runtime else 0
	var delta = get_physics_process_delta_time()
	_pending_pose_delta += delta
	# This signal runs before movement, including NavigationServer callbacks.
	# Retain the penultimate simulation root even when several ticks catch up.
	if _presentation != null:
		_presentation.capture(delta)
	else:
		for entry in _entries:
			entry.physics_root = entry.unit.global_transform
			entry.visuals._pose_elapsed += delta
	_profile_stage(0, profile_start)


func _profile_stage(index: int, began: int) -> int:
	if not _profile_runtime:
		return 0
	var now := Time.get_ticks_usec()
	_profile_us[index] += now - began
	_profile_us[index + 7] += 1
	return now


func _advance_poses(delta: float):
	if not get_tree().paused:
		var profile_start := Time.get_ticks_usec() if _profile_runtime else 0
		_chassis_jobs.clear()
		for entry in _entries:
			entry.step_delta = entry.visuals._pose_elapsed if _render_pose_updates else delta
			if _render_pose_updates:
				entry.visuals._pose_elapsed = 0.0
			_chassis_jobs.append(entry.visuals.prepare_gpu_pose(entry.step_delta))
		profile_start = _profile_stage(1, profile_start)
		_pose_workers.solve(_chassis_jobs, _parallel_poses)
		profile_start = _profile_stage(2, profile_start)
		_infantry_jobs.clear()
		for entry in _entries:
			var worker = entry.visuals._pose_worker
			if worker != null and _infantry_jobs_enabled:
				worker.begin()
			entry.visuals.finish_gpu_pose(entry.step_delta, false)
			if worker != null and _infantry_jobs_enabled and worker.job.pending:
				_infantry_jobs.append(worker.job)
		profile_start = _profile_stage(3, profile_start)
		if _native_infantry_poses and _native.has_method("solve_infantry_batch"):
			_native_infantry_solved = _native.solve_infantry_batch(_infantry_jobs)
			_native_infantry_fallbacks = _infantry_jobs.size() - _native_infantry_solved
			for job in _infantry_jobs:
				if not job.native_solved:
					job.solve()
		else:
			_pose_workers.solve(_infantry_jobs, _parallel_poses, 16)
		profile_start = _profile_stage(4, profile_start)
		for entry in _entries:
			var worker = entry.visuals._pose_worker
			if worker != null:
				worker.end()
			entry.visuals.publish_gpu_pose(entry.step_delta)
		_profile_stage(5, profile_start)
		_upload_poses()


func _upload_poses():
	var profile_start := Time.get_ticks_usec() if _profile_runtime else 0
	if _presentation != null:
		for handle in _presentation.changes():
			var entry: Dictionary = _presentation_entries[handle]
			if (
				not is_instance_valid(entry.unit)
				or not is_instance_valid(entry.geometry)
				or entry.unit.player != entry.owner
			):
				_invalidate(entry.unit)
				continue
			_join_group(entry)
		var palettes: Array = _presentation.pack(get_tree().paused)
		_previous_texture.update(
			Image.create_from_data(4, POSE_CAPACITY, false, Image.FORMAT_RGBAF, palettes[1])
		)
		_last_pixels = palettes[0]
		_texture.update(
			Image.create_from_data(4, POSE_CAPACITY, false, Image.FORMAT_RGBAF, palettes[0])
		)
		_profile_stage(6, profile_start)
		return
	var cursor := 0
	while cursor < _entries.size():
		var entry = _entries[cursor]
		if not is_instance_valid(entry.unit) or not is_instance_valid(entry.geometry):
			_invalidate(entry.unit)
			continue
		if entry.unit.player != entry.owner:
			_invalidate(entry.unit)
			continue
		_join_group(entry)
		if not _units.has(entry.unit):
			continue
		cursor += 1
		var position: Vector3 = entry.unit.global_position
		var reset: bool = position.distance_to(entry.previous_position) > 4.0
		entry.previous_position = position
		var shown: bool = entry.geometry.is_visible_in_tree()
		var pulse := Color(0, 0, 0, 0)
		var overlay = entry.pulse_material
		if (
			overlay is ShaderMaterial
			and overlay.shader.resource_path.ends_with("material_hit.gdshader")
		):
			pulse = overlay.get_shader_parameter("hit_color").srgb_to_linear()
			pulse.a = overlay.get_shader_parameter("hit_strength")
		entry.shown = shown
		entry.pulse = pulse
		entry.reset = reset
		if _render_pose_updates and not get_tree().paused:
			entry.rebase = entry.physics_root * entry.sampled_root.affine_inverse()
		else:
			entry.rebase = Transform3D.IDENTITY
		entry.visuals._publish_simulation_pose()
	_pose_workers.solve(_world_jobs, _parallel_poses, 16)
	# Activation requires the native uploader; otherwise the ordinary renderer
	# stays active. Avoid allocating a second, unused CPU packing buffer here.
	var pixels: PackedByteArray = _native.pack_poses(_entries, POSE_CAPACITY)
	for entry in _entries:
		for track in entry.tracks:
			pixels.encode_float((entry.offset + track[1]) * 64 + 48, track[0].travel)
	for diagonal in [0, 5, 10]:
		pixels.encode_float(diagonal * 4, 1.0)
	var previous = (
		_native.rebase_poses(_last_pixels, _entries) if _render_pose_updates else _last_pixels
	)
	for entry in _entries:
		if entry.reset:
			for index in range(entry.offset * 64, (entry.offset + entry.anchors.size()) * 64, 4):
				previous.encode_float(index, pixels.decode_float(index))
		entry.sampled_root = entry.unit.global_transform
	_previous_texture.update(
		Image.create_from_data(4, POSE_CAPACITY, false, Image.FORMAT_RGBAF, previous)
	)
	_last_pixels = pixels
	_texture.update(Image.create_from_data(4, POSE_CAPACITY, false, Image.FORMAT_RGBAF, pixels))
	_profile_stage(6, profile_start)


func _exit_tree():
	for group in _static_batches:
		_restore_static(group)
	if _compute != null:
		_compute.release()
	for unit in _units.keys():
		_invalidate(unit)
