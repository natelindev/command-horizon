# gdlint: disable=max-returns,max-file-lines
extends RefCounted

## A replica has one map and persistent live entities. Incoming records patch
## those entities; no simulation, save loading or snapshot scene replacement runs.
const Frame = preload("res://source/match/network/AuthoritativeFrame.gd")
const Benchmark = preload("res://source/match/saves/BenchmarkState.gd")
var game
var entities = {}
var state = {}
var error = ""
var local_slot = -1
var initialization_stage = "idle"
var _frame = Frame.new()
var _factions
var _last_units = {}


func initialize(
	tree: SceneTree, snapshot: Dictionary, slot: int, session, validated = false
) -> bool:
	if (not validated and not _frame.validate(snapshot)) or snapshot.settings.mission_id != "":
		error = (
			_frame.error
			if not _frame.error.is_empty()
			else "Only skirmish recordings are supported."
		)
		return false
	local_slot = slot
	initialization_stage = "settings"
	_factions = load("res://source/match/FactionCatalog.gd")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	for key in snapshot.settings:
		if key != "players":
			settings.set(key, snapshot.settings[key])
	for side in snapshot.settings.players:
		var player_settings = load("res://source/data-model/PlayerSettings.gd").new()
		_copy(player_settings, side, side.keys())
		settings.players.append(player_settings)
	print("REPLICA PHASE game = load('res://source/match/Skirmish.tscn').instantiate() ", Time.get_ticks_msec())
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.restoring = true
	game.settings = settings
	game.set_meta("network_local_slot", maxi(0, slot))
	game.set_meta("network_session", session)
	game.set_meta("network_replica", true)
	print("REPLICA PHASE var map = load(settings.map_path).instantiate() ", Time.get_ticks_msec())
	var map = load(settings.map_path).instantiate()
	if not settings.scenario.is_empty():
		map.scenario = settings.scenario.duplicate(true)
	game.map = map
	var previous = tree.current_scene
	tree.paused = true
	if is_instance_valid(previous):
		initialization_stage = "previous_scene_exit"
		previous.queue_free()
		await previous.tree_exited
	initialization_stage = "scene_ready"
	print("REPLICA PHASE tree.root.add_child(game) ", Time.get_ticks_msec())
	tree.root.add_child(game)
	tree.current_scene = game
	# Disable authority before a single physics frame can run on this peer.
	initialization_stage = "freeze_simulation"
	print("REPLICA PHASE _freeze_simulation() ", Time.get_ticks_msec())
	_freeze_simulation()
	for deposit in tree.get_nodes_in_group("resource_units"):
		deposit.free()
	for obstacle in tree.get_nodes_in_group("destructible_obstacles"):
		obstacle.free()
	var players = game.get_cached_group("players")
	for index in players.size():
		entities["player-%d" % index] = players[index]
	for target in tree.get_nodes_in_group("neutral_targets"):
		entities[target.neutral_id] = target
	for site in load("res://source/match/world/PointOfInterestCatalog.gd").sites(game):
		entities[site.site_id] = site
	initialization_stage = "initial_state"
	print("REPLICA PHASE if not apply(snapshot, validated): ", Time.get_ticks_msec())
	if not apply(snapshot, validated):
		return false
	if slot < 0:
		game.hud.ability_tray.hide()
	game.visible_player = players[maxi(0, slot)]
	game.settings.visibility = settings.visibility
	if settings.visibility == settings.Visibility.FULL:
		game.fog_of_war.reveal()
	game._move_camera_to_player_units_crowd_pivot(players[maxi(0, slot)])
	game.restoring = false
	print("REPLICA PHASE initialization_stage = 'ready' ", Time.get_ticks_msec())
	initialization_stage = "ready"
	tree.paused = false
	return true


func _freeze_simulation():
	game.set_physics_process(false)
	for node in [
		game.projectile_system,
		game.grenade_system,
		game.engineering,
		game.commander_support,
		game.battlefield_events,
		game.wreck_salvage,
		game.repair_service,
		game.helix_support,
		game.crowd_runtime
	]:
		if is_instance_valid(node):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	for player in game.get_cached_group("players"):
		player.set_process(false)
		player.set_physics_process(false)
		for child in player.get_children():
			if child.name in ["TechnologyResearch", "FactionSignatures", "AirContracts"]:
				child.process_mode = Node.PROCESS_MODE_DISABLED
	# Sites, ambient creatures and ruins cannot progress independently either.
	_disable_physics(game.map)
	_disable_physics(game.get_node("NeutralWorld"))


func _disable_physics(node):
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_physics(child)


func apply(snapshot: Dictionary, validated = false) -> bool:
	if not validated and not _frame.validate(snapshot):
		error = _frame.error
		return false
	game.simulation_time = snapshot.simulation_time
	game.units_produced = snapshot.units_produced
	game._visual_serial = snapshot.visual_serial
	_remove_missing(snapshot)
	for saved in snapshot.resources:
		_resource(saved)
	for saved in snapshot.get("obstacles", []):
		_obstacle(saved)
	for saved in snapshot.units:
		if not entities.has(saved.id):
			var unit = (
				load(_factions.scene_path(entities[saved.player].faction, saved.role)).instantiate()
			)
			unit.set_meta("visual_seed", saved.visual_seed)
			unit.set_meta("network_id", saved.id)
			game._setup_and_spawn_unit(
				unit,
				Transform3D(Basis.from_euler(saved.rotation), saved.position),
				entities[saved.player],
				saved.construction != null and saved.construction < 1
			)
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			entities[saved.id] = unit
	_engineering(snapshot.engineering)
	for side in snapshot.players:
		var player = entities[side.id]
		_copy(
			player,
			side,
			[
				"resource_a",
				"resource_b",
				"coordination_unlocked",
				"coordination_left",
				"_lab_research"
			]
		)
		player.technology.restore(side.technology)
		player.technology.process_mode = Node.PROCESS_MODE_DISABLED
		Benchmark.restore_player(player, side.economy, entities)
		player.signatures.restore(side.signatures, entities)
		player.signatures.process_mode = Node.PROCESS_MODE_DISABLED
		player.set_process(false)
		player.set_physics_process(false)
		if player.has_node("AirContracts"):
			player.get_node("AirContracts").process_mode = Node.PROCESS_MODE_DISABLED
		game._defeat_timers[player] = side.command_left
		player.emit_changed()
	for saved in snapshot.units:
		_unit(saved)
	for saved in snapshot.units:
		if saved.has("garrison_mount"):
			_mount(entities[saved.id].garrison_mount, saved.garrison_mount)
	for saved in snapshot.engineering.entities:
		if saved.kind == "bunker":
			_mount(entities[saved.id].garrison_mount, saved.garrison)
	for saved in snapshot.mission.get("points_of_interest", []):
		entities[saved.id].restore_state(saved, entities)
	for saved in snapshot.neutral_buildings:
		_neutral(saved)
	game.commander_support.restore_state(snapshot.commander, entities)
	game.battlefield_events.restore_state(snapshot.events, entities)
	game.battlefield_wear.restore(snapshot.battlefield_wear)
	game.projectile_system.restore(snapshot.rounds, entities)
	game.grenade_system.restore(snapshot.grenades, entities)
	game.battle_record.restore(snapshot.battle_record)
	game.battlefield.invalidate()
	state = snapshot
	return true


func _remove_missing(snapshot):
	var present = {}
	for table in ["units", "resources", "obstacles"]:
		for row in snapshot.get(table, []):
			present[row.id] = true
	for row in snapshot.engineering.entities:
		present[row.id] = true
	for id in entities.keys():
		if id.begins_with("player-") or id.begins_with("poi-") or id.begins_with("neutral-"):
			continue
		if not present.has(id):
			var node = entities[id]
			if is_instance_valid(node):
				# Replica deaths never run salvage, damage or ejection gameplay.
				if node.has_meta("garrison_host"):
					node.remove_meta("garrison_host")
				node.free()
			entities.erase(id)
			_last_units.erase(id)


func _resource(saved):
	if not entities.has(saved.id):
		var filename = (
			"Wreck"
			if not saved.wreck.is_empty()
			else ("ResourceA" if saved.kind == "resource_a" else "ResourceB")
		)
		var deposit = load("res://source/match/units/non-player/%s.tscn" % filename).instantiate()
		_copy(deposit, saved.wreck, saved.wreck.keys())
		deposit.position = saved.position
		deposit.set(saved.kind, saved.amount)
		deposit.set_meta("network_id", saved.id)
		game.map.get_node("Resources").add_child(deposit)
		deposit.process_mode = Node.PROCESS_MODE_DISABLED
		entities[saved.id] = deposit
	var deposit = entities[saved.id]
	deposit.position = saved.position
	deposit.harvest_origin = saved.field_origin if saved.field_origin != null else Vector3.INF
	deposit.set(saved.kind, saved.amount)


func _obstacle(saved):
	if not entities.has(saved.id):
		var obstacle = (
			load(
				(
					"res://source/match/world/StructureRuin.gd"
					if saved.role == "StructureRuin"
					else "res://source/match/environment/DestructibleObstacle.gd"
				)
			)
			. new()
		)
		if saved.role == "StructureRuin":
			obstacle.restore_state(saved.ruin)
		_copy(
			obstacle,
			saved,
			["position", "rotation", "hp", "hp_max", "radius", "obstacle_height", "light_barricade"]
		)
		obstacle.set_meta("network_id", saved.id)
		game.map.add_child(obstacle)
		obstacle.process_mode = Node.PROCESS_MODE_DISABLED
		entities[saved.id] = obstacle
	entities[saved.id].hp = saved.hp
	if saved.role == "StructureRuin":
		entities[saved.id].restore_state(saved.ruin)


func _engineering(saved):
	game.engineering._next_id = saved.next_id
	for record in saved.entities:
		if not entities.has(record.id):
			var owner = entities[record.owner]
			var entity = (
				game.engineering._spawn_mine(owner, record.point, record.id)
				if record.kind == "mine"
				else game.engineering._spawn_emplacement(
					owner, record.kind, record.point, record.angle, record.id
				)
			)
			entity.process_mode = Node.PROCESS_MODE_DISABLED
			entities[record.id] = entity
		var entity = entities[record.id]
		entity.hp = record.hp
		if record.kind == "mine":
			_copy(entity, record, ["deploy_left", "arm_left", "fuse_left"])


func _unit(saved):
	var unit = entities[saved.id]
	var previous = _last_units.get(saved.id, {})
	unit.position = saved.position
	unit.rotation = saved.rotation
	unit.hp = saved.hp
	unit.experience = saved.experience
	unit.stance = saved.stance
	unit.regarrison_lock_left = saved.regarrison_lock_left
	unit.damage_visual_band = saved.damage_visual_band
	unit.permanent_scrap_rank = saved.permanent_scrap_rank
	if saved.has("plasma_shield"):
		unit.shields = saved.plasma_shield.charge
		unit.shields_changed.emit()
	if saved.has("scrap_hardened"):
		unit.scrap_hardened_tiers = saved.scrap_hardened.tiers
		unit.scrap_hardened_left = saved.scrap_hardened.left
	if unit.suppression != null:
		unit.suppression.restore(saved.suppression)
	if unit.abilities != null:
		unit.abilities.restore(saved.abilities)
	if unit.signature != null and not saved.signature.is_empty():
		unit.signature.restore(saved.signature)
	_copy(unit, saved.deployment, saved.deployment.keys())
	if saved.weapon_mode != previous.get("weapon_mode", {}):
		_copy(unit, saved.weapon_mode, saved.weapon_mode.keys())
		if not saved.weapon_mode.is_empty():
			unit.configure_weapon()
	if saved.construction != null:
		unit._construction_progress = saved.construction
		var visual = unit.get_node_or_null("ConstructionVisual")
		if visual != null:
			visual.refresh()
	_copy(unit, saved.cargo, saved.cargo.keys())
	unit.set_meta(
		"next_attack_availability_time", roundi((game.simulation_time + saved.weapon_left) * 1000.0)
	)
	_production(unit, saved.production)
	if unit.manual_orders != null:
		unit.manual_orders.status = saved.orders.get("status", "")
		unit.manual_orders.restore_tactics(
			saved.benchmark.tactics, func(id): return entities.get(id)
		)
	var movement = unit.get_node_or_null("Movement")
	if movement != null:
		_copy(movement, saved.movement, saved.movement.keys())
		movement.ion_stall_left = saved.benchmark.ion_stall_left
	if not saved.get("air", {}).is_empty():
		unit.restore_air(saved.air, entities)
	if unit.type == "CommandCenter":
		unit.energy = saved.benchmark.hq_energy
	if unit.type == "ForwardRefinery":
		unit.smelting_remainder = saved.benchmark.refinery_remainder
	if unit.optical_cloak != null:
		unit.optical_cloak.idle_left = saved.benchmark.cloak_left
		unit.optical_cloak.concealed = saved.benchmark.cloak_left <= 0
	if not saved.benchmark.mercenary.is_empty():
		load("res://source/match/units/traits/MercenarySortie.gd").attach(
			unit, saved.benchmark.mercenary
		)
	if not saved.rally.is_empty():
		var rally = unit.get_node_or_null("RallyPoint")
		if rally != null:
			rally.position = saved.rally.position
			rally.target_unit = entities.get(saved.rally.target)
	unit.aim_target = _aim_target(saved.action)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.reset_physics_interpolation()
	var visuals = unit.get_node_or_null("BastionVisuals")
	if visuals != null:
		visuals.process_mode = Node.PROCESS_MODE_PAUSABLE
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	visibility._recalculate_unit_visibility(unit)
	_last_units[saved.id] = saved


func _production(unit, saved):
	if saved.is_empty():
		return
	var queue = unit.production_queue
	var jobs = saved.jobs
	while queue._queue.size() > jobs.size():
		queue._remove_element(queue._queue.back())
	for index in jobs.size():
		var item = jobs[index]
		var job
		if index < queue._queue.size():
			job = queue._queue[index]
		else:
			job = (
				load("res://source/match/units/traits/ProductionQueue.gd")
				. ProductionQueueElement
				. new()
			)
			queue._enqueue_element(job)
		job.unit_prototype = load(_factions.scene_path(unit.player.faction, item.role))
		_copy(
			job,
			item,
			[
				"time_total",
				"time_left",
				"paid_cost",
				"departure_endpoint",
				"assembly_started",
				"assembly_bonus",
				"batch_count"
			]
		)
		job.emit_changed()
	queue.restore_assembly_state(saved.assembly_state)


func _mount(mount, saved, host_override = null):
	var host = mount.get_parent() if host_override == null else host_override
	for passenger in mount.occupants:
		if is_instance_valid(passenger):
			passenger.remove_meta("garrison_host")
			passenger.remove_meta("garrison_slot")
			passenger.collision_layer = passenger.get_meta("network_body_layer", 2)
			passenger.get_node("Movement").ghosted = false
			game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(passenger)
	mount.occupants.clear()
	mount.pending_evacuations.clear()
	for index in saved.occupants.size():
		var passenger = entities[saved.occupants[index]]
		if not passenger.has_meta("network_body_layer"):
			passenger.set_meta("network_body_layer", passenger.collision_layer)
		passenger.collision_layer = 0
		passenger.get_node("Movement").ghosted = true
		passenger.set_meta("garrison_host", host)
		passenger.set_meta("garrison_slot", saved.slots[index])
		mount.occupants.append(passenger)
		passenger.hide()
	for id in saved.evacuating:
		mount.pending_evacuations.append(entities[id])
	# Normalize only selected mobile cargo, after the complete list is restored.
	# Selection handles ownership and host deduplication without issuing orders.
	if host.is_in_group("units"):
		for passenger in mount.occupants:
			if passenger.is_in_group("selected_units"):
				passenger.get_node("Selection").select()


func _copy(object, data, keys):
	for key in keys:
		object.set(
			key,
			(
				data[key].duplicate(true)
				if data[key] is Array or data[key] is Dictionary
				else data[key]
			)
		)


func _aim_target(action: Dictionary):
	if action.is_empty():
		return null
	if action.kind in ["AttackingWhileInRange", "AutoAttacking", "AirStrike"]:
		return entities.get(action.references.get("_target_unit", ""))
	for child in action.children.values():
		var target = _aim_target(child)
		if target != null:
			return target
	return null


func _neutral(saved):
	var building = entities[saved.id]
	building.restore_combat(saved.combat)
	building.player = entities.get(saved.owner)
	_mount(building, saved, building)
	building._update_debris()
	building.update_label()
