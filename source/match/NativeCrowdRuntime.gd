extends Node

## Experimental match-owned ground movement. Routing and avoidance remain in
## NavigationServer; native arrays own steering, contacts and pose publication.
var active := false
var native: RefCounted
var _configured_iteration := -1
var _projection_valid := false
var surface_active := false
var _nearest_surface := "--native-nearest-surface" in OS.get_cmdline_user_args()
@onready var _game = get_parent()


func _ready():
	var loader = load("res://source/match/rendering/NativePosePacker.gd").create()
	if loader == null or not ClassDB.class_exists("CopperfinCrowdRuntime"):
		return
	native = ClassDB.instantiate("CopperfinCrowdRuntime")
	# Older optional libraries retain the numerical solver, but cannot share
	# one ground-travel budget between scripted contacts and native steering.
	active = native != null and native.has_method("motion_budget")
	if active:
		_nearest_surface = _nearest_surface and native.has_method("configure_surface")
		if "--profile-runtime" in OS.get_cmdline_user_args():
			native.profile(true)
		get_tree().physics_frame.connect(_begin_frame)


func bind_agent(agent) -> bool:
	if not active or agent.domain != Constants.Match.Navigation.Domain.TERRAIN:
		return false
	_sync_projection()
	var handle: int = native.bind_agent(
		agent, agent.get_parent(), agent._unit.type in agent.VEHICLE_ROLES
	)
	if handle < 0:
		return false
	agent._native_runtime = native
	agent._native_handle = handle
	agent._native_velocity_callback = Callable(native, "receive_velocity").bind(handle)
	agent.velocity_computed.connect(agent._native_velocity_callback)
	var unit = agent.get_parent()
	if (
		unit.abilities != null
		and not unit.abilities.ability_changed.is_connected(agent._native_refresh_facts)
	):
		unit.abilities.ability_changed.connect(agent._native_refresh_facts)
	# Production spawns can bind the child agent before Unit._ready adds abilities.
	agent._native_connect_facts.call_deferred()
	_begin_frame()
	return true


func _sync_projection():
	var terrain = _game.navigation.terrain
	var iteration := NavigationServer3D.map_get_iteration_id(terrain.navigation_map_rid)
	_projection_valid = (
		not terrain._is_baking
		and terrain._earliest_frame_to_perform_next_rebake == null
		and terrain.is_synchronized()
	)
	if not _projection_valid or _configured_iteration == iteration:
		return
	if terrain._projection_iteration != iteration:
		terrain._index_projection_surface(iteration)
	var model = _game.map.terrain if terrain._elevated else null
	var ok: bool = native.configure_projection(
		terrain._projection_cells,
		model.heights if model != null else PackedFloat32Array(),
		model.columns if model != null else 0,
		model.rows if model != null else 0,
		terrain._elevated,
		iteration
	)
	if ok:
		_configured_iteration = iteration
		surface_active = false
		var region: NavigationRegion3D = terrain._navigation_region
		var regions := NavigationServer3D.map_get_regions(terrain.navigation_map_rid)
		if _nearest_surface and regions.size() == 1 and regions[0] == region.get_rid():
			var mesh := region.navigation_mesh
			var polygons := []
			for index in mesh.get_polygon_count():
				polygons.append(mesh.get_polygon(index))
			surface_active = native.configure_surface(
				mesh.get_vertices(), polygons, region.global_transform, iteration
			)
	else:
		surface_active = false
		_projection_valid = false


func _begin_frame():
	if not active or get_tree().paused or not can_process():
		return
	_sync_projection()
	native.begin_frame(
		_game.get_units(), get_tree().get_nodes_in_group("repair_platforms"), _projection_valid
	)


func step(delta: float):
	if active:
		native.step(delta, _game.simulation_time, _projection_valid)


func statistics() -> Array:
	return native.statistics() if active else []


func _exit_tree():
	if active and get_tree().physics_frame.is_connected(_begin_frame):
		get_tree().physics_frame.disconnect(_begin_frame)
