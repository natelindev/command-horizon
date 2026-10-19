# gdlint: disable=max-returns,max-file-lines
extends RefCounted

const Campaigns = preload("res://source/match/campaign/CampaignCatalog.gd")

const FactionRules = preload("res://source/match/FactionRules.gd")

const Schema = preload("res://source/match/saves/SnapshotSchema.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
const Actions = preload("res://source/match/saves/ActionRestore.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const NAVIGATION_SYNC_TIMEOUT_MS = 10000
var error = ""
var warnings = []
var entities = {}
var _schema
var _data


func prepare(snapshot):
	error = ""
	warnings.clear()
	entities.clear()
	_data = null
	var values = Values.new()
	var encoded = values.encode(snapshot)
	if not values.error.is_empty():
		return _fail(values.error)
	var data = values.decode(encoded)
	_schema = Schema.new()
	if not _schema.validate(data):
		return _fail(
			_schema.error if not _schema.error.is_empty() else "Invalid saved match state."
		)
	for unit in data.units:
		if (
			data.snapshot_version == 1
			and unit.role == "CombatRobot"
			and _schema.sides[unit.player].faction == "helix"
			and not warnings.has(
				"Legacy Lancers start in Precision; select Interception for air defense."
			)
		):
			warnings.append(
				"Legacy Lancers start in Precision; select Interception for air defense."
			)
		if unit.program.is_empty() or unit.program.lua_source.is_empty():
			continue
		if not warnings.has("Legacy scripted orders were replaced with Defensive behavior."):
			warnings.append("Legacy scripted orders were replaced with Defensive behavior.")

	_data = data
	return true


func restore(tree, snapshot):
	# Preflight is synchronous and has no battle side effects; errors retain the live match.
	if not prepare(snapshot):
		return {"ok": false, "error": error}
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	for key in _data.settings:
		if key != "players":
			settings.set(key, _data.settings[key])
	if settings.mission_id == "command_horizon":
		settings.campaign_challenge = _data.mission.challenge
	for side in _data.settings.players:
		var player_settings = load("res://source/data-model/PlayerSettings.gd").new()
		_copy(player_settings, side, side.keys())
		settings.players.append(player_settings)
	var scene_path = (
		"res://source/match/Skirmish.tscn"
		if settings.mission_id == ""
		else (Campaigns.OPERATIONS[settings.mission_id].scene)
	)
	var game = load(scene_path).instantiate()
	game.restoring = true
	game.settings = settings
	if settings.mission_id == "command_horizon":
		game.alternate_route = _data.mission.alternate_route
	game.map = load(settings.map_path).instantiate()
	# There may only be one match's global groups and signal subscribers at a time.
	tree.paused = true
	var previous = tree.current_scene
	if is_instance_valid(previous):
		previous.queue_free()
		await previous.tree_exited
		await tree.process_frame
	tree.root.add_child(game)
	tree.current_scene = game
	game.simulation_time = _data.simulation_time
	game.units_produced = _data.units_produced
	var players = game.get_node("Players").get_children().filter(func(p): return "faction" in p)
	for index in _data.players.size():
		var side = _data.players[index]
		var player = players[index]
		entities[side.id] = player
		_copy(
			player,
			side,
			[
				"resource_a",
				"resource_b",
				"coordination_unlocked",
				"coordination_left",
				"_basic_programs"
			]
		)
		if _data.snapshot_version >= 7:
			player.technology.restore(side.technology)
		game._defeat_timers[player] = side.command_left
		if side.command_left <= 0:
			player.set_physics_process(false)
		if not side.ai.is_empty():
			_copy(
				player,
				side.ai,
				["structures_built", "attacks_launched", "_elapsed", "_production_index"]
			)
			player._last_wave = game.simulation_time - side.ai.wave_age
			player.set_process(side.ai.enabled)
	for deposit in tree.get_nodes_in_group("resource_units"):
		deposit.free()
	for saved in _data.resources:
		var path = (
			"res://source/match/units/non-player/%s.tscn"
			% ("ResourceA" if saved.kind == "resource_a" else "ResourceB")
		)
		var salvage = saved.get("wreck", {})
		if not salvage.is_empty():
			path = "res://source/match/units/non-player/Wreck.tscn"
		var deposit = load(path).instantiate()
		for key in salvage:
			deposit.set(key, salvage[key])
		deposit.position = saved.position
		deposit.harvest_origin = (
			saved.field_origin if saved.get("field_origin") != null else Vector3.INF
		)
		deposit.set(saved.kind, saved.amount)
		game.map.get_node("Resources").add_child(deposit)
		entities[saved.id] = deposit
	for saved in _data.units:
		var unit = load(Catalog.scene_path(saved.role)).instantiate()
		unit.set_meta("visual_seed", saved.visual_seed)
		if not saved.program.is_empty():
			unit.set_meta("chip_installed", saved.program.installed)
		game._setup_and_spawn_unit(
			unit,
			Transform3D(Basis.from_euler(saved.rotation), saved.position),
			entities[saved.player],
			saved.construction != null and saved.construction < 1
		)
		entities[saved.id] = unit
		unit.hp = saved.hp
		unit.stance = saved.get("stance", unit.Stance.AGGRESSIVE)
		if not saved.get("signature", {}).is_empty():
			unit.signature.restore(saved.signature)
		var deployment = saved.get("deployment", {})
		if not deployment.is_empty():
			_copy(unit, deployment, deployment.keys())
			unit.get_node("WeaponPreparationVisual").refresh()
		var mode = saved.get("weapon_mode", {})
		if not mode.is_empty():
			_copy(unit, mode, mode.keys())
			unit.configure_weapon()
		if saved.construction != null:
			unit._construction_progress = saved.construction
			var construction_visual = unit.get_node_or_null("ConstructionVisual")
			if construction_visual != null:
				construction_visual.refresh()
			if _data.snapshot_version < 10 and unit.is_under_construction():
				# Upgrade the old 1-HP foundation curve once, retaining actual damage.
				var old_earned = 1.0 + floorf(saved.construction * (unit.hp_max - 1.0))
				var foundation_hp = unit._foundation_hp()
				var new_earned = (
					foundation_hp + floorf(saved.construction * (unit.hp_max - foundation_hp))
				)
				unit.hp = minf(unit.hp_max, saved.hp + new_earned - old_earned)
		_copy(unit, saved.cargo, saved.cargo.keys())
		unit.last_enemy_damage_time = (
			game.simulation_time - saved.damage_age if saved.damage_age != null else -INF
		)
		unit.set_meta(
			"next_attack_availability_time",
			roundi((game.simulation_time + saved.weapon_left) * 1000.0)
		)
		_program(unit, saved)
		_production(unit, saved.production)
	game._visual_serial = _data.visual_serial
	if not await _synchronize(tree, game):
		return {
			"ok": false,
			"error": "Navigation could not synchronize. Loaded battle remains paused.",
			"game": game
		}
	for target in tree.get_nodes_in_group("neutral_targets"):
		entities[target.neutral_id] = target
	for site in load("res://source/match/world/PointOfInterestCatalog.gd").sites(game):
		entities[site.site_id] = site
	for saved in _data.mission.get("points_of_interest", []):
		entities[saved.id].restore_state(saved, entities)
	if _data.snapshot_version >= 11:
		for saved in _data.neutral_buildings:
			entities[saved.id].restore(saved, entities)
	var actions = Actions.new()
	for side in _data.players:
		if side.has("signatures"):
			entities[side.id].signatures.restore(side.signatures, entities)
	actions.entities = entities
	for saved in _data.units:
		var unit = entities[saved.id]
		# Navigation initialization aligns agents; the authoritative save position wins.
		unit.position = saved.position
		unit.rotation = saved.rotation
		if unit.program != null:
			unit.program._changing = true
		var legacy_behavior = (
			saved.action.get("kind") in ["LuaAction", "PresetAction", "SpecialistAction"]
		)
		if legacy_behavior:
			unit.stance = unit.Stance.DEFENSIVE
		var action = actions.restore({} if legacy_behavior else saved.action, unit, unit)
		if action == null:
			unit.action = null
			if saved.action.get("kind") == "ChipInstalling":
				unit.program.install_left = 0
				if saved.action.state._paid:
					unit.player.add_resources(
						{"resource_b": FactionRules.chip_cost(unit.player.faction)}
					)
				unit.program.set_status("Manual", "Service unavailable; chip fee refunded.")
		if unit.program != null:
			unit.program._changing = false
			if saved.action.get("kind") in ["PresetAction", "SpecialistAction", "LuaAction"]:
				unit.program._owned_action = action

		_orders(unit, saved.orders)
		if not saved.movement.is_empty():
			_copy(unit.get_node("Movement"), saved.movement, saved.movement.keys())
		if action == null and not saved.action.is_empty():
			var movement = unit.get_node_or_null("Movement")
			if movement != null:
				movement.stop()
		if not saved.rally.is_empty():
			var rally = unit.get_node_or_null("RallyPoint")
			if rally != null:
				rally.position = saved.rally.position
				rally.target_unit = entities.get(saved.rally.target)
		for group in saved.groups:
			unit.add_to_group("unit_group_%d" % group)
		if saved.selected:
			unit.get_node("Selection").select()
		unit.reset_physics_interpolation()
		for shot in saved.projectiles:
			var target = entities.get(shot.target)
			if target == null:
				continue
			var projectile = (
				load("res://source/match/units/projectiles/%s.tscn" % shot.kind).instantiate()
			)
			projectile.restoring = true
			projectile.target_unit = target
			projectile._flight_left = shot.left
			unit.add_child(projectile)
	# Recreate the visible final production stage while the restored battle is
	# still paused, after every unit has recovered its authoritative position.
	for saved in _data.units:
		var unit = entities[saved.id]
		if not saved.production.is_empty():
			unit.production_queue.restore_departure()
		var activity = unit.get_node_or_null("StructureActivity")
		if activity != null:
			activity.refresh(0.0)
	warnings.append_array(actions.warnings)
	_army_groups(game)
	_squads()
	if Campaigns.is_story(game.settings.mission_id):
		game.restore_operation(_data.mission, entities)
	elif game.settings.mission_id == "" and game.map.has_method("restore_state"):
		game.map.restore_state(_data.mission, entities)
	elif game.settings.mission_id == "command_horizon":
		for key in [
			"deployed",
			"hold_seconds",
			"command_left",
			"command_destroyed",
			"defence_started",
			"defence_time",
			"waves_sent",
			"waves_warned"
		]:
			game.set(key, _data.mission[key])
		game.target_command = entities.get(_data.mission.target_command)
		var saved_relay = _data.mission.relay
		game.map.relay.captured_by = entities.get(saved_relay.owner)
		game.map.relay.candidate = entities.get(saved_relay.candidate)
		game.map.relay.progress = saved_relay.progress
		game.map.relay.contested = saved_relay.contested
		game.map.relay._update_presentation()
	elif game.settings.mission_id == "broken_foundry":
		for key in ["alarm", "hold_seconds", "command_left", "response_left", "response_done"]:
			game.set(key, _data.mission[key])
		game.nodes.clear()
		for saved in _data.mission.nodes:
			var entry = saved.duplicate()
			entry.unit = entities.get(saved.unit)
			game.nodes.append(entry)
		var saved_relay = _data.mission.relay
		game.map.relay.captured_by = entities.get(saved_relay.owner)
		game.map.relay.candidate = entities.get(saved_relay.candidate)
		game.map.relay.progress = saved_relay.progress
		game.map.relay.contested = saved_relay.contested
		game.map.relay._update_presentation()
	elif game.settings.mission_id == "air_corridor":
		game.command_left = _data.mission.command_left
		game.sites.clear()
		game.flights.clear()
		for kind in ["sites", "flights"]:
			for saved in _data.mission[kind]:
				var entry = saved.duplicate()
				entry.unit = entities.get(saved.unit)
				game.get(kind).append(entry)
	elif game.settings.mission_id == "supply_line":
		game.responses = _data.mission.responses.duplicate()
		game.resolved = _data.mission.resolved.duplicate()
		game.convoy.clear()
		for saved in _data.mission.convoy:
			var entry = saved.duplicate()
			entry.unit = entities.get(saved.unit)
			game.convoy.append(entry)
	elif game.settings.mission_id == "split_signal":
		for key in _data.mission:
			if key not in ["relays", "story", "opposition", "hero"]:
				game.set(key, _data.mission[key])
		game.map.restore_state(_data.mission, entities)
	elif game.settings.mission_id != "" and not _data.mission.is_empty():
		var mission = _data.mission
		for key in mission:
			if key not in ["relay", "story", "opposition", "hero"]:
				game.set(key, mission[key])
		game.relay.captured_by = entities.get(mission.relay.owner)
		game.relay.candidate = entities.get(mission.relay.candidate)
		game.relay.progress = mission.relay.progress
		game.relay.contested = mission.relay.contested
		game.relay._update_presentation()
	game.repair_service._elapsed = _data.repair_elapsed
	if game.settings.mission_id != "":
		game.campaign_hero.restore(_data.mission.get("hero", {}), entities)
		game._attach_campaign_story()
		if is_instance_valid(game.campaign_story):
			game.campaign_story.restore(_data.mission.get("story", {}))
		if "opposition" in game and is_instance_valid(game.opposition):
			var state = _data.mission.get("opposition", {})
			if not state.is_empty():
				game.opposition.restore_state(state, entities)
			elif game.settings.mission_id == "command_horizon":
				game.opposition.boss_defeated = true
	game.battlefield.invalidate()
	# Wrecks entered the tree before their observers; refresh while the load stays paused.
	for saved in _data.resources:
		if not saved.get("wreck", {}).is_empty():
			entities[saved.id]._refresh()
	if game.map.has_node("AmbientLife"):
		if _data.snapshot_version >= 6:
			game.map.get_node("AmbientLife").restore(_data.ambient)
		else:
			game.map.get_node("AmbientLife").refresh_visibility()
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	for saved in _data.units:
		visibility._recalculate_unit_visibility(entities[saved.id])
	_structure_memory(game, visibility)
	game.fog_of_war._physics_process(0.0)
	await _fog(tree, game)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(_data.camera.size)
	camera.position = _data.camera.position
	camera.rotation = _data.camera.rotation
	game.battle_record.restore(_data.get("battle_record", {}))
	game.restoring = false
	for player in players:
		player.emit_changed()
	game.hud.pause_after_load()
	game.hud.show_notice("Battle loaded." + (" " + warnings[0] if not warnings.is_empty() else ""))
	return {"ok": true, "game": game, "warnings": warnings.duplicate()}


func _program(unit, saved):
	if saved.program.is_empty():
		return
	var program = unit.program
	_copy(
		program,
		saved.program,
		[
			"installed",
			"config",
			"program_title",
			"anchor",
			"safe_point",
			"route",
			"mode",
			"reason",
			"install_left",
			"saved_record",
			"lua_source",
			"_pending"
		]
	)
	program.installed = true
	program.lua_runtime = null
	program.lua_source = ""
	program.saved_record = {}
	program._pending = false
	program.set_physics_process(false)
	program.set_status("Manual", "Choose a unit behavior.")
	# Escort references are linked after all units exist in _orders.


func _production(unit, saved):
	if saved.is_empty():
		return
	var queue = unit.production_queue
	queue.fit_chips = false
	queue.program_pin = {}
	for item in saved.jobs:
		var job = (
			load("res://source/match/units/traits/ProductionQueue.gd").ProductionQueueElement.new()
		)
		_copy(
			job, item, ["time_total", "time_left", "paid_cost", "fitted_chip", "program_snapshot"]
		)
		job.departure_endpoint = item.get("departure_endpoint")
		job.unit_prototype = load(Catalog.scene_path(item.role))
		queue._enqueue_element(job)


func _orders(unit, saved):
	if saved.is_empty():
		return
	var orders = unit.manual_orders
	_copy(orders, saved, ["auto_resume", "status", "_engaged", "_still"])
	orders._progress = saved.progress if saved.progress != null else Vector3.INF
	orders.current = _order(saved.current)
	orders.pending = saved.pending.map(_order)
	# A queue saved before its first tick still has the unit's idle defense.
	# Only a persisted current order owns that action; otherwise start pending work.
	orders._active = unit.action if orders._engaged and not orders.current.is_empty() else null
	orders.set_physics_process(orders._engaged)

	unit.manual_orders.auto_resume = false


func _order(saved):
	var result = saved.duplicate(true)
	if result.has("target"):
		var target = entities.get(result.target)
		result.target = weakref(target) if target != null else WeakRef.new()
	return result


func _army_groups(game):
	for index in range(1, _data.players.size()):
		var saved = _data.players[index].ai
		var player = entities["player-%d" % index]
		player._army_cursor = saved.get("cursor", 0)
		player._army_groups = []
		for group in saved.get("groups", []):
			player._army_groups.append(
				{
					"kind": group.kind,
					"point": group.point,
					"members": group.members.map(func(id): return entities[id]),
					"started": game.simulation_time - group.age,
					"retiring": group.retiring,
					"workers": group.workers.map(func(id): return entities[id])
				}
			)


func _squads():
	for side in _data.players:
		var roster = entities[side.id].squad_roster
		roster._next_id = side.next_squad_id
		for saved in side.squads:
			var squad = load("res://source/match/programs/ProgramSquad.gd").new()
			_copy(squad, saved, ["id", "title", "policy", "_state"])
			if not _valid_squad_state(squad, squad._state):
				squad._state = {}
				warnings.append("Invalid squad memory was reset.")
			roster.add_child(squad)
			for id in saved.members:
				var unit = entities[id]
				squad.members.append(unit)
				unit.program_squad = squad
				unit.tree_exiting.connect(roster._on_member_exit.bind(unit))
			for claim in saved.claims:
				var owner = entities.get(claim.owner)
				var target = entities.get(claim.target)
				if owner != null and target != null:
					squad._claims[owner.get_instance_id()] = {
						"unit": weakref(owner),
						"target": weakref(target),
						"channel": claim.channel,
						"expires": owner._match.simulation_time + claim.left,
						"damage": claim.damage
					}
	for saved in _data.units:
		if not saved.program.is_empty():
			entities[saved.id].program.escort = entities.get(saved.program.escort)


func _synchronize(tree, game):
	# Baking and server publication run asynchronously in wall time. A fixed
	# frame budget can expire in milliseconds during accelerated/headless play.
	var deadline = Time.get_ticks_msec() + NAVIGATION_SYNC_TIMEOUT_MS
	var frame = 0
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
		await tree.physics_frame
		frame += 1
		game.navigation.terrain._process(0.0)
		# A finished bake is still queued for NavigationServer publication.
		# Do not restore active movement against the previous mesh's footprints.
		var ready = game.navigation.terrain.is_synchronized()
		if not ready:
			continue
		for saved in _data.units + _data.resources:
			var obstacle = entities[saved.id].get_node_or_null("MovementObstacle")
			if obstacle != null and not obstacle._synchronized:
				ready = false
			var movement = entities[saved.id].get_node_or_null("Movement")
			if movement != null and not movement._synchronized:
				ready = false
		if ready and frame >= 5:
			return true
	return false


func _structure_memory(_game, handler):
	for saved in _data.structure_memory:
		var proxy = load("res://source/match/players/Player.gd").new()
		proxy.color = saved.color
		var prototype = load(Catalog.scene_path(saved.role)).instantiate()
		load("res://source/match/FactionCatalog.gd").prepare_model(prototype, saved.faction)
		proxy.add_child(prototype)
		prototype._setup_color()
		var geometry = prototype.get_node("Geometry")
		prototype.remove_child(geometry)
		proxy.free()
		geometry.position = saved.position
		geometry.rotation = saved.rotation
		geometry.scale = saved.scale
		geometry.set_meta("memory_role", saved.role)
		geometry.set_meta("memory_faction", saved.faction)
		geometry.set_meta("memory_color", saved.color)
		handler.add_child(geometry)
		var real = entities.get(saved.entity)
		if real != null:
			handler._structure_to_dummy_mapping[real] = geometry
		else:
			handler._orphaned_dummies.append(geometry)


func _fog(tree, game):
	if _schema.fog_image == null or DisplayServer.get_name() == "headless":
		return
	var history = TextureRect.new()
	history.texture = ImageTexture.create_from_image(_schema.fog_image)
	history.size = _schema.fog_image.get_size()
	game.fog_of_war._fog_viewport.add_child(history)
	await RenderingServer.frame_post_draw
	history.queue_free()
	await tree.process_frame


func _copy(object, data, keys):
	for key in keys:
		var value = data[key]
		object.set(key, value.duplicate(true) if value is Dictionary or value is Array else value)


func _fail(message):
	error = message
	return false


func _valid_squad_state(squad, state):
	if state.size() > 64 or JSON.stringify(state).to_utf8_buffer().size() > squad.STATE_BYTES:
		return false
	for key in state:
		if not key is String or key.is_empty() or key.length() > 48:
			return false
		if not squad._valid_value(state[key], 0, [squad.STATE_BYTES]):
			return false
	return true
