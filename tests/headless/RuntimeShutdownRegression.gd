extends SceneTree

const BATTLE_CACHE_BUCKETS = [
	"ownership_symbols",
	"terrain_meshes",
	"infantry_meshes",
	"infantry_materials",
	"infantry_batch_meshes",
	"veteran_badge_textures",
	"base_apron_materials",
	"construction_meshes",
	"construction_finishes",
	"team_footprint_meshes"
]
var errors = []
var _materials_script


class CacheSide:
	extends RefCounted
	var faction = "bastion"

	func get_footprint_material():
		return StandardMaterial3D.new()


class CacheSubject:
	extends Node3D
	var player = CacheSide.new()
	var radius = 1.0
	var veterancy_rank = 1
	var _match = {"map": null}


func _initialize():
	_run.call_deferred()


func _run():
	_materials_script = load("res://source/match/ObjectMaterials.gd")
	var globals = root.get_node("Globals")
	_set_factories()
	var material = _cached_material()
	_check(material.get_ref() != null, "Runtime cache did not retain its shared material")
	globals.cache.erase("object_materials")
	_check(material.get_ref() == null, "Cleared runtime cache retained its material")
	await _interface_cache_lifetime()
	await _faction_cache_lifetime()
	await _battle_cache_lifetime()
	var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
	var count = catalog.operations().size()
	_check(count > 5 and not catalog.stories().is_empty(), "Campaign catalog did not load")
	globals.cache.erase("campaign_catalog")
	_check(catalog.operations().size() == count, "Campaign cache did not rebuild")
	var director = root.get_node("MusicDirector")
	director.play_track("bastion")
	var deadline = Time.get_ticks_msec() + 10000
	while director.current_track != "bastion" and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(director.current_track == "bastion", "Music did not start before shutdown")
	# Quit during playback with another threaded load outstanding. Include the
	# positional players used by scene effects, and quit while already paused.
	director.play_track("frontier")
	var playbacks: Array[WeakRef] = []
	for player in director.players:
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	for player in [AudioStreamPlayer.new(), AudioStreamPlayer2D.new(), AudioStreamPlayer3D.new()]:
		root.add_child(player)
		player.stream = load("res://assets/audio/ui/click.wav")
		player.play()
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	_check(not playbacks.is_empty(), "Shutdown fixture did not start audio playback")
	# Positional voices start on the next physics step. Exercise actual audio
	# playback, rather than prepared objects still owned by their player nodes.
	await physics_frame
	await process_frame
	paused = true
	Engine.time_scale = 0.0
	if errors.is_empty() and "--window-close" in OS.get_cmdline_user_args():
		print("Runtime shutdown: native close requested with 0 failures")
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		# Repeated close requests must share the existing shutdown operation.
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return
	await globals.quit_game(0 if errors.is_empty() else 1)
	for playback in playbacks:
		_check(playback.get_ref() == null, "Shutdown returned before audio playback was released")
	for message in errors:
		push_error(message)
	print("Runtime shutdown: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _set_factories():
	var sets = root.get_node("Utils").Set
	var original = sets.from_array([1, 2, 2, 3])
	var excluded = sets.from_array([2, 4])
	var difference = sets.subtracted(original, excluded)
	_check(original.size() == 3 and excluded.size() == 2, "Set subtraction mutated its inputs")
	_check(difference.to_array() == [1, 3], "Set subtraction lost membership or insertion order")
	var fresh = sets.new()
	fresh.merge(difference)
	fresh.merge([3, 5])
	_check(fresh.to_array() == [1, 3, 5], "Set merge did not deduplicate arrays and sets")
	fresh.erase(3)
	_check(fresh.pop() == 1 and fresh.peek() == 5, "Set extraction changed insertion order")
	_check(difference.has(3), "Set factory returned shared mutable storage")
	fresh.clear()
	_check(fresh.empty() and fresh.is_empty() and fresh.pop() == null, "Empty set behavior changed")
	print("CHECKED set constructors, factories, subtraction and independent mutation")


func _cached_material():
	var original = StandardMaterial3D.new()
	return weakref(_materials_script.textured(original))


func _interface_cache_lifetime():
	var globals = root.get_node("Globals")
	for cycle in 2:
		var resources = _cached_interface_resources()
		var preview = _cached_preview_texture()
		await process_frame
		await process_frame
		globals.cache.erase("battle_theme")
		globals.cache.erase("map_previews")
		for label in resources:
			_check(resources[label].get_ref() == null, "Released interface cache retained " + label)
		_check(preview.get_ref() == null, "Released preview cache retained its texture")
		print("CHECKED interface cache release/rebuild cycle ", cycle + 1)


func _cached_interface_resources():
	var console = load("res://source/match/hud/BattleTheme.gd")
	var resources = {}
	for faction in ["bastion", "helix", "frontier"]:
		console.use_faction(faction)
		var theme = console.create()
		_check(theme == console.create(), "Repeated theme lookup missed its shared cache")
		_check(console.accent() == console.PALETTES[faction].accent, "Cached faction was lost")
		resources[faction + " theme"] = weakref(theme)
	for method in ["display_font", "heading_font", "numeral_font"]:
		resources[method] = weakref(console.call(method))
	console.use_faction("bastion")
	return resources


func _cached_preview_texture():
	var preview_script = load("res://source/main-menu/SkirmishMapPreview.gd")
	var first = preview_script.new()
	var second = preview_script.new()
	root.add_child(first)
	root.add_child(second)
	first.set_map("res://source/match/maps/battlefields/PinebreakValleyMap.tscn")
	second.set_map("res://source/match/maps/battlefields/PinebreakValleyMap.tscn")
	_check(first._terrain != null, "Baked map preview did not load")
	_check(first._terrain == second._terrain, "Baked previews did not share their texture")
	var texture = weakref(first._terrain)
	first.queue_free()
	second.queue_free()
	return texture


func _faction_cache_lifetime():
	var globals = root.get_node("Globals")
	for cycle in 2:
		var resources = _cached_faction_resources()
		await process_frame
		globals.cache.erase("selection_portraits")
		globals.cache.erase("frontier_materials")
		for label in resources:
			_check(resources[label].get_ref() == null, "Released faction cache retained " + label)
		print("CHECKED faction cache release/rebuild cycle ", cycle + 1)


func _cached_faction_resources():
	var catalog = load("res://source/match/FactionCatalog.gd")
	var portrait = catalog.selection_portrait("bastion", "Infantry")
	_check(portrait != null, "Selection portrait did not load")
	_check(
		portrait == catalog.selection_portrait("bastion", "Infantry"),
		"Selection portrait missed its shared cache"
	)
	var model = Node3D.new()
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var original = StandardMaterial3D.new()
	original.resource_name = "Frontier_Ceramic"
	mesh.mesh.material = original
	model.add_child(mesh)
	var surfaces = load("res://source/match/FrontierMaterials.gd")
	surfaces.apply(model)
	var material = mesh.get_surface_override_material(0)
	_check(material is ShaderMaterial, "Frontier surface was not configured")
	var resources = {"portrait": weakref(portrait), "frontier material": weakref(material)}
	model.free()
	return resources


func _battle_cache_lifetime():
	var globals = root.get_node("Globals")
	for cycle in 2:
		_populate_battle_caches()
		await process_frame
		await process_frame
		var resources = {}
		for key in BATTLE_CACHE_BUCKETS:
			var bucket = globals.cache.get(key, {})
			_check(not bucket.is_empty(), "Battle cache fixture did not populate " + key)
			_weak_resources(bucket, resources)
			globals.cache.erase(key)
			bucket = {}
		globals.cache.erase("object_materials")
		for id in resources:
			_check(
				resources[id].get_ref() == null, "Released battle cache retained resource %d" % id
			)
		print("CHECKED battle cache release/rebuild cycle ", cycle + 1)


func _populate_battle_caches():
	var ownership = load("res://source/match/hud/Ownership.gd")
	for shape in ["own", "opponent", "resource"]:
		ownership._symbol(shape)
	var terrain = load("res://source/match/maps/terrain/MeshBatch.gd")
	terrain.merged_mesh("CutBerm2", 2.0)
	var construction = load("res://source/match/effects/construction/ConstructionRig.gd")
	construction.mesh(construction.BOX)
	construction.mesh(construction.ROD)
	construction.finish("shutdown fixture")
	var infantry = load("res://source/match/units/traits/InfantryModel.gd").build(
		"bastion", "Infantry"
	)
	_materials_script.apply(infantry)
	load("res://source/match/units/traits/InfantryMeshBatch.gd").apply(infantry)
	infantry.free()
	var unit = CacheSubject.new()
	var geometry = Node3D.new()
	geometry.name = "Geometry"
	var hull = MeshInstance3D.new()
	hull.mesh = BoxMesh.new()
	geometry.add_child(hull)
	unit.add_child(geometry)
	root.add_child(unit)
	unit.add_child(load("res://source/match/units/traits/TeamFootprint.gd").new(unit))
	var badge = load("res://source/match/units/traits/VeteranBadge.gd").new(unit)
	unit.add_child(badge)
	for rank in range(2, 4):
		unit.veterancy_rank = rank
		badge.refresh()
	unit.add_child(load("res://source/match/effects/BaseApron.gd").new())
	unit.queue_free()


func _weak_resources(value, resources):
	if value is Resource:
		resources[value.get_instance_id()] = weakref(value)
	elif value is Dictionary:
		for key in value:
			_weak_resources(key, resources)
			_weak_resources(value[key], resources)
	elif value is Array:
		for item in value:
			_weak_resources(item, resources)


func _check(value, message):
	if not value:
		errors.append(message)
