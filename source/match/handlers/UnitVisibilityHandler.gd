extends Node3D

const Structure = preload("res://source/match/units/Structure.gd")

var _units_processed_at_least_once = {}
var _structure_to_dummy_mapping = {}
var _orphaned_dummies = []
var _refresh_cursor = 0
var _orphan_elapsed = 0.0
@onready var _match = find_parent("Match")


func _ready():
	MatchSignals.unit_spawned.connect(_recalculate_unit_visibility)
	MatchSignals.unit_died.connect(_on_unit_died)


func _physics_process(delta):
	_orphan_elapsed += delta
	var all_units = _match.get_units()
	if all_units.is_empty():
		return
	var observers = _match.visible_players
	# Spread presentation updates over six frames. Weapon legality always queries
	# current positions independently, so this never grants stale firing authority.
	for _index in range(ceili(all_units.size() / 6.0)):
		_refresh_cursor %= all_units.size()
		_recalculate_unit_visibility(all_units[_refresh_cursor], null, observers)
		_refresh_cursor += 1
	if _orphan_elapsed >= 0.1:
		_orphan_elapsed = 0.0
		for orphaned_dummy in _orphaned_dummies.duplicate():
			_recalcuate_orphaned_dummy_existence(orphaned_dummy)


func _is_disabled():
	return not visible


func _recalculate_unit_visibility(unit, _revealed_units = null, observers = null):
	if unit.is_in_group("revealed_units") or _is_disabled():
		_update_unit_visibility(unit, true)
		return
	if observers == null:
		observers = _match.visible_players
	# An owner always observes its own units. In shared/full viewing modes,
	# searching earlier players' sight grids cannot change this result.
	if unit.player in observers:
		_update_unit_visibility(unit, true)
		return

	var should_be_visible = false
	for player in observers:
		if _match.battlefield.is_observed(player, unit):
			should_be_visible = true
			break
	_update_unit_visibility(unit, should_be_visible)


func _update_unit_visibility(unit, should_be_visible):
	# Mobile passengers keep simulation vision and weapons, without rendering
	# their model, health bars, selection circles or other child presentation.
	if unit.has_meta("garrison_host"):
		var host = unit.get_meta("garrison_host")
		if is_instance_valid(host) and "garrison_mount" in host and host.garrison_mount != null:
			should_be_visible = false
	if (
		unit in _units_processed_at_least_once
		and unit is Structure
		and unit.visible != should_be_visible
	):
		if unit.visible:
			_create_dummy_structure(unit)
		else:
			_try_removing_dummy_structure(unit)
	if unit.visible != should_be_visible:
		unit.visible = should_be_visible
	if "optical_cloak" in unit and unit.optical_cloak != null:
		unit.input_ray_pickable = should_be_visible
	_units_processed_at_least_once[unit] = true


func _create_dummy_structure(unit):
	if unit in _structure_to_dummy_mapping:
		return
	var dummy = load("res://source/match/rendering/UnitBatchRenderer.gd").duplicate_geometry(
		unit.get_node("Geometry")
	)
	# Keep inert visual identity after the real structure dies outside observation.
	dummy.set_meta("memory_role", unit.type)
	dummy.set_meta("memory_faction", unit.player.faction)
	dummy.set_meta("memory_color", unit.player.color)
	dummy.global_transform = unit.find_child("Geometry").global_transform
	if unit.is_under_construction():
		_freeze_construction(dummy)
	prepare_memory_geometry(dummy)
	add_child(dummy)
	_structure_to_dummy_mapping[unit] = dummy


func _freeze_construction(dummy):
	# Remember the site as last seen instead of sharing its live assembly materials.
	var meshes = dummy.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		for surface in mesh.get_surface_override_material_count():
			var material = mesh.get_surface_override_material(surface)
			if material is ShaderMaterial:
				mesh.set_surface_override_material(surface, material.duplicate(true))


func prepare_memory_geometry(geometry):
	# Restored memories own fresh team-color materials as well as construction
	# copies. Detach overrides while their meshes still exist so the renderer
	# cannot inspect a freed material during the same visibility refresh.
	var meshes = geometry.find_children("*", "MeshInstance3D", true, false)
	geometry.tree_exiting.connect(_release_memory_materials.bind(meshes), CONNECT_ONE_SHOT)


func _release_memory_materials(meshes):
	for mesh in meshes:
		if is_instance_valid(mesh):
			for surface in mesh.get_surface_override_material_count():
				mesh.set_surface_override_material(surface, null)


func _try_removing_dummy_structure(unit):
	if unit in _structure_to_dummy_mapping:
		_structure_to_dummy_mapping[unit].queue_free()
		_structure_to_dummy_mapping.erase(unit)


func _recalcuate_orphaned_dummy_existence(orphaned_dummy, revealed_units = null):
	var should_exist = true
	if revealed_units == null:
		var candidates = _match.get_observers()
		revealed_units = candidates.filter(func(unit): return unit.is_in_group("revealed_units"))
	for revealed_unit in revealed_units:
		if (
			revealed_unit.is_revealing()
			and _match.battlefield.can_observe_point(
				revealed_unit, orphaned_dummy.global_position + Vector3.UP * 0.8
			)
		):
			should_exist = false
			break
	if not should_exist:
		_orphaned_dummies.erase(orphaned_dummy)
		orphaned_dummy.queue_free()


func _on_unit_died(unit):
	_units_processed_at_least_once.erase(unit)
	if unit in _structure_to_dummy_mapping:
		var orphaned_dummy = _structure_to_dummy_mapping[unit]
		_structure_to_dummy_mapping.erase(unit)
		_orphaned_dummies.append(orphaned_dummy)
		_recalcuate_orphaned_dummy_existence(orphaned_dummy)
