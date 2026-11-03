extends Node3D

const Factions = preload("res://source/match/FactionCatalog.gd")
const Players = preload("res://source/match/Players.gd")

const Unit = preload("res://source/match/units/Unit.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Player = preload("res://source/match/players/Player.gd")
const Human = preload("res://source/match/players/human/Human.gd")

const CommandCenter = preload("res://source/match/units/CommandCenter.tscn")
const Drone = preload("res://source/match/units/Drone.tscn")
const Worker = preload("res://source/match/units/Worker.tscn")

@export var settings: Resource = null

var restoring = false
var simulation_time = 0.0
var battlefield = null
var repair_service = null
var wreck_salvage = null
var combat_effects = null
var battlefield_wear = null
var base_area_lighting = null
var projectile_system = null
var combat_audio = null
var environment_audio = null
var subtitles = null
var helix_support = null
var commander_support = null
var battlefield_events = null
var engineering = null
var grenade_system = null
var crowd_runtime = null
var runtime_profiler = null
var unit_state_store: RefCounted

var map:
	set = _set_map,
	get = _get_map
var visible_player = null:
	set = _set_visible_player
var visible_players = null:
	set = _ignore,
	get = _get_visible_players

# Membership snapshots are shared, read-only arrays. Invalidate on lifecycle changes;
# replacing arrays rather than mutating them keeps callback-driven iteration safe.
var _group_registry := {}
var _observer_registry: Array[Node] = []
var _observers_dirty := true
var _visual_serial = 0
# Local scene resources must outlive their instances. In Compatibility, releasing
# the PackedScene first leaks two local texture allocations during scene teardown.
var _scene_template: PackedScene

@onready var navigation = $Navigation
@onready var fog_of_war = $FogOfWar

@onready var _camera = $IsometricCamera3D
@onready var _players = $Players
@onready var _terrain = $Terrain


func _notification(what):
	if what == NOTIFICATION_SCENE_INSTANTIATED and not scene_file_path.is_empty():
		_scene_template = load(scene_file_path)


func _enter_tree():
	assert(settings != null, "match cannot start without settings, see examples in tests/manual/")
	assert(map != null, "match cannot start without map, see examples in tests/manual/")
	# The battle console wears the human player's faction kit; HUD nodes read it as they
	# become ready, which happens after this.
	var sides = settings.players.filter(
		func(side): return side.controller == Constants.PlayerType.HUMAN
	)
	if sides.is_empty():
		sides = settings.players
	if not sides.is_empty():
		preload("res://source/match/hud/BattleTheme.gd").use_faction(sides[0].faction)


func _ready():
	load("res://source/match/orders/FormationPlanner.gd").warm_native_solver()
	battlefield = load("res://source/match/combat/Battlefield.gd").new()
	add_child(battlefield)
	add_child(load("res://source/match/combat/AlliedDefense.gd").new())
	combat_audio = load("res://source/match/audio/CombatAudio.gd").new()
	add_child(combat_audio)
	environment_audio = load("res://source/match/audio/EnvironmentAudio.gd").new()
	add_child(environment_audio)
	combat_effects = load("res://source/match/effects/CombatEffects.gd").new()
	add_child(combat_effects)
	helix_support = load("res://source/match/combat/HelixSupport.gd").new()
	helix_support.name = "HelixSupport"
	add_child(helix_support)
	grenade_system = load("res://source/match/combat/GrenadeSystem.gd").new()
	grenade_system.name = "GrenadeSystem"
	add_child(grenade_system)
	engineering = load("res://source/match/world/FieldEngineering.gd").new()
	engineering.name = "FieldEngineering"
	add_child(engineering)
	commander_support = load("res://source/match/combat/CommanderSupport.gd").new()
	commander_support.name = "CommanderSupport"
	add_child(commander_support)
	if "--native-unit-state" in OS.get_cmdline_user_args():
		var native = load("res://source/match/rendering/NativePosePacker.gd").create()
		if native != null and ClassDB.class_exists("CopperfinUnitStore"):
			unit_state_store = ClassDB.instantiate("CopperfinUnitStore")
			unit_state_store.configure(self, commander_support)
	projectile_system = load("res://source/match/combat/ProjectileSystem.gd").new()
	projectile_system.name = "ProjectileSystem"
	projectile_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(projectile_system)
	wreck_salvage = load("res://source/match/economy/WreckSalvage.gd").new()
	add_child(wreck_salvage)
	repair_service = load("res://source/match/combat/RepairService.gd").new()
	add_child(repair_service)
	MatchSignals.setup_and_spawn_unit.connect(_setup_and_spawn_unit)
	# Facilities, landmarks and caches use the map's final (expanded) layout.
	load("res://source/match/world/MapLandmarks.gd").populate(map)
	load("res://source/match/maps/CampaignInteriors.gd").populate(map, settings.mission_id)
	load("res://source/match/economy/LegacyHomeFields.gd").standardize(self)
	_setup_subsystems_dependent_on_map()
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		crowd_runtime = load("res://source/match/NativeCrowdRuntime.gd").new()
		crowd_runtime.name = "NativeCrowdRuntime"
		add_child(crowd_runtime)
	if "--profile-runtime" in OS.get_cmdline_user_args():
		runtime_profiler = load("res://source/match/rendering/RuntimePhaseProfiler.gd").new()
		runtime_profiler.name = "RuntimePhaseProfiler"
		add_child(runtime_profiler)
	_setup_players()
	_setup_player_units()
	visible_player = get_cached_group("players")[settings.visible_player]
	_move_camera_to_initial_position()
	if settings.visibility == settings.Visibility.FULL:
		fog_of_war.reveal()
	var human = _get_human_player()
	var voice = human.get_node_or_null("BattleVoice") if human != null else null
	if voice != null:
		subtitles = load("res://source/match/hud/BattleSubtitles.gd").new()
		subtitles.voice = voice
		add_child(subtitles)
	var ownership_layer = CanvasLayer.new()
	ownership_layer.name = "OwnershipLayer"
	ownership_layer.layer = 1
	add_child(ownership_layer)
	ownership_layer.add_child(load("res://source/match/hud/OwnershipOverlay.gd").new())
	var routes = load("res://source/match/hud/OrderRoutes.gd").new()
	routes.process_mode = Node.PROCESS_MODE_ALWAYS
	ownership_layer.add_child(routes)
	var living_world = load("res://source/match/environment/LivingWorld.gd").new()
	map.add_child(living_world)
	var neutral_world = load("res://source/match/ambient/NeutralWorld.gd").new()
	neutral_world.name = "NeutralWorld"
	add_child(neutral_world)
	battlefield_wear = load("res://source/match/effects/BattlefieldWear.gd").new()
	add_child(battlefield_wear)
	base_area_lighting = load("res://source/match/environment/BaseAreaLighting.gd").new()
	add_child(base_area_lighting)
	battlefield_events = load("res://source/match/world/BattlefieldEvents.gd").new()
	battlefield_events.name = "BattlefieldEvents"
	add_child(battlefield_events)
	battlefield_events.announced.connect(_event_announced)
	load("res://source/match/ObjectMaterials.gd").apply(map)
	var atmosphere = load("res://source/match/environment/WorldAtmosphere.gd").new()
	add_child(atmosphere)
	if DisplayServer.get_name() != "headless":
		var batches = load("res://source/match/rendering/UnitBatchRenderer.gd").new()
		batches.name = "UnitBatchRenderer"
		add_child(batches)
	if DisplayServer.get_name() != "headless":
		add_child(load("res://source/match/effects/ConstructionPrewarm.gd").new())
	MatchSignals.match_started.emit()


func invalidate_unit_registry():
	_group_registry.erase("units")
	_group_registry.erase("revealed_units")
	_observers_dirty = true


func _event_announced(text: String, _point: Vector3):
	if "hud" in self and is_instance_valid(get("hud")):
		get("hud").show_notice(text)


func field_position_reserved(point: Vector3, radius: float) -> bool:
	if battlefield_events != null and battlefield_events.position_reserved(point, radius):
		return true
	if commander_support != null:
		for record in commander_support.pending:
			if record.kind == "airdrop" and record.point.distance_to(point) < 2.0 + radius:
				return true
	return false


func invalidate_vision_registry():
	_group_registry.erase("vision_sources")
	_group_registry.erase("revealed_units")
	_observers_dirty = true


func invalidate_group_registry(group: StringName):
	_group_registry.erase(group)


func get_cached_group(group: StringName) -> Array[Node]:
	# Callers must not mutate the shared array. Replacement on invalidation
	# preserves existing iteration snapshots when callbacks spawn/remove units.
	assert(group in ["units", "players", "vision_sources", "revealed_units", "resource_units"])
	if not _group_registry.has(group):
		var members = get_tree().get_nodes_in_group(group)
		members.make_read_only()
		_group_registry[group] = members
	return _group_registry[group]


func get_units() -> Array[Node]:
	return get_cached_group("units")


func get_observers() -> Array[Node]:
	if _observers_dirty:
		_observer_registry = get_units() + get_cached_group("vision_sources")
		_observer_registry.make_read_only()
		_observers_dirty = false
	return _observer_registry


func allocate_visual_seed():
	_visual_serial += 1
	return _visual_serial


func _physics_process(delta):
	simulation_time += delta
	if crowd_runtime != null:
		crowd_runtime.step(delta)


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Globals.options.selection_modifier_pressed():
			return
		MatchSignals.deselect_all_units.emit()


func _set_map(a_map):
	assert(get_node_or_null("Map") == null, "map already set")
	a_map.name = "Map"
	add_child(a_map)
	a_map.owner = self


func _ignore(_value):
	pass


func _get_map():
	return get_node_or_null("Map")


func _set_visible_player(player):
	_conceal_player_units(visible_player)
	_reveal_player_units(player)
	visible_player = player


func _get_visible_players():
	if settings.visibility == settings.Visibility.PER_PLAYER:
		return get_cached_group("players").filter(
			func(side): return Players.allied(side, visible_player)
		)
	return get_cached_group("players")


func _setup_subsystems_dependent_on_map():
	if map.has_method("click_collision"):
		var click = map.click_collision()
		_terrain.use_shape(click[0], click[1])
	else:
		_terrain.update_shape(map.find_child("Terrain").mesh)
	map.add_child(load("res://source/match/maps/BattlefieldBoundary.gd").new())
	var decals = load("res://source/match/effects/GroundDecals.gd").new()
	decals.name = "GroundDecals"
	map.add_child(decals)
	fog_of_war.resize(map.size)
	_recalculate_camera_bounding_planes(map.size)
	navigation.setup(map)


func _recalculate_camera_bounding_planes(map_size: Vector2):
	_camera.bounding_planes[1] = Plane(-1, 0, 0, -map_size.x)
	_camera.bounding_planes[3] = Plane(0, 0, -1, -map_size.y)


func _setup_players():
	assert(
		_players.get_children().is_empty() or settings.players.is_empty(),
		"players can be defined either in settings or in scene tree, not in both"
	)
	if _players.get_children().is_empty():
		_create_players_from_settings()
	for node in _players.get_children():
		if node is Player:
			node._native_register_team()
			node.add_to_group("players")
			node.tree_exited.connect(invalidate_group_registry.bind("players"))
	invalidate_group_registry("players")


func _create_players_from_settings():
	for side_index in settings.players.size():
		var player_settings = settings.players[side_index]
		var player_scene = Constants.Match.Player.CONTROLLER_SCENES.get(
			player_settings.controller,
			Constants.Match.Player.CONTROLLER_SCENES[Constants.PlayerType.HUMAN]
		)
		if settings.skirmish and player_settings.controller != Constants.PlayerType.HUMAN:
			player_scene = load("res://source/match/players/skirmish-ai/SkirmishAI.tscn")
		if has_meta("network_local_slot"):
			var network_slot = get_meta("network_local_slot")
			player_scene = load(
				"res://source/match/players/human/Human.tscn"
				if (network_slot == side_index or (network_slot < 0 and side_index == 0))
				else "res://source/match/players/skirmish-ai/SkirmishAI.tscn"
			)
		var player = player_scene.instantiate()
		player.color = player_settings.color
		player.faction = player_settings.faction
		player.difficulty = player_settings.difficulty
		player.team = player_settings.team
		player.spawn_index = player_settings.spawn_index
		player.set_meta("skirmish", settings.skirmish)
		if player_settings.spawn_index_offset > 0:
			for _i in range(player_settings.spawn_index_offset):
				_players.add_child(Node.new())
		_players.add_child(player)


func _setup_player_units():
	if restoring:
		return
	for player in _players.get_children():
		if not player is Player:
			continue
		var player_index = player.start_index()
		var predefined_units = player.get_children().filter(func(child): return child is Unit)
		if not predefined_units.is_empty():
			predefined_units.map(func(unit): _setup_unit_groups(unit, unit.player))
		else:
			_spawn_player_units(
				player, map.find_child("SpawnPoints").get_child(player_index).global_transform
			)
		# All starting bases face the bottom of the default camera view. Rotate
		# the complete structure so its portal and production exit face it too.
		# Restored games return above and retain their saved orientations.
		# Runways keep the heading their layout chose for room and approach.
		for unit in player.get_children():
			if unit is Structure and not unit.is_in_group("footprinted_structures"):
				unit.global_rotation.y = PI


func _spawn_player_units(player, spawn_transform):
	_setup_and_spawn_unit(CommandCenter.instantiate(), spawn_transform, player, false)
	_setup_and_spawn_unit(
		Drone.instantiate(), spawn_transform.translated(Vector3(-2, 0, -2)), player
	)
	_setup_and_spawn_unit(
		Worker.instantiate(), spawn_transform.translated(Vector3(-3, 0, 3)), player
	)
	_setup_and_spawn_unit(
		Worker.instantiate(), spawn_transform.translated(Vector3(3, 0, 3)), player
	)


func _setup_and_spawn_unit(unit, a_transform, player, mark_structure_under_construction = true):
	Factions.prepare_model(unit, player.faction)
	unit.global_transform = a_transform
	if unit is Structure and mark_structure_under_construction:
		unit.mark_as_under_construction()
	_setup_unit_groups(unit, player)
	player.add_child(unit)
	unit.reset_physics_interpolation()
	battlefield.invalidate()
	MatchSignals.unit_spawned.emit(unit)


func _setup_unit_groups(unit, player):
	invalidate_unit_registry()
	unit.add_to_group("units")
	if player == _get_human_player():
		unit.add_to_group("controlled_units")
	elif not Players.allied(player, _get_human_player()):
		unit.add_to_group("adversary_units")
	if player in visible_players:
		unit.add_to_group("revealed_units")


func _get_human_player():
	var human_players = get_cached_group("players").filter(func(player): return player is Human)
	assert(human_players.size() <= 1, "more than one human player is not allowed")
	if not human_players.is_empty():
		return human_players[0]
	return null


func _move_camera_to_initial_position():
	if restoring:
		return
	var human_player = _get_human_player()
	if human_player != null:
		_move_camera_to_player_units_crowd_pivot(human_player)
	else:
		_move_camera_to_player_units_crowd_pivot(get_cached_group("players")[0])


func _move_camera_to_player_units_crowd_pivot(player):
	var player_units = get_units().filter(func(unit): return unit.player == player)
	assert(not player_units.is_empty(), "player must have at least one initial unit")
	var crowd_pivot = Utils.Match.Unit.Movement.calculate_aabb_crowd_pivot_yless(player_units)
	_camera.set_position_safely(crowd_pivot)


func _reveal_player_units(player):
	invalidate_group_registry("revealed_units")
	if player == null:
		return
	for unit in get_units().filter(func(a_unit): return Players.allied(a_unit.player, player)):
		unit.add_to_group("revealed_units")


func _conceal_player_units(player):
	invalidate_group_registry("revealed_units")
	if player == null:
		return
	for unit in get_units().filter(func(a_unit): return Players.allied(a_unit.player, player)):
		unit.remove_from_group("revealed_units")
