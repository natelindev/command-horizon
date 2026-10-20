# gdlint: disable=max-file-lines,max-returns
extends RefCounted

const Campaigns = preload("res://source/match/campaign/CampaignCatalog.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
# Saves from any other version are rejected; there is no migration.
const VERSION = 15
const ACTION_FIELDS = {
	"Garrisoning": ["_elapsed"],
	"Moving": ["_target_position", "_arrival_elapsed", "_arrival_progress"],
	"MovingToUnit": ["_target_position"],
	"AttackMoving": ["destination", "_elapsed", "_arrival_elapsed", "_arrival_progress"],
	"AutoAttacking":
	[
		"_elapsed",
		"_last_known_position",
		"_lost_contact",
		"_blocked_elapsed",
		"_progress_position",
		"_defense_origin",
		"_defense_radius"
	],
	"AttackingWhileInRange":
	["_shot_limit", "_shots", "_charge_left", "_charge_total", "_charge_origin"],
	"WaitingForTargets": [],
	"Following": ["_last_known_target_unit_position"],
	"FollowingToReachDistance": ["_distance_to_reach", "_last_known_target_unit_position"],
	"CollectingResourcesSequentially":
	["_state", "_kind", "_field_origin", "_waiting_reason", "_retry_left"],
	"CollectingResourcesWhileInRange": [],
	"Constructing": [],
	"ConstructingWhileInRange": [],
	"Repairing": ["_elapsed", "_finish_when_repaired"],
	"RecoveringAtService":
	["_elapsed", "_stalled", "_blocked", "_last_progress", "_retry_left", "_full_recovery"],
}
const ACTION_REFERENCES = ["_target_unit", "_resource_unit", "_cc_unit", "_target"]
const ACTION_CHILDREN = ["_shot", "_sub_action"]
const ACTION_TIMERS = ["_timer", "_one_shot_timer", "_range_check_timer"]
var error = ""
var _ids = {}
var _game


func capture(game):
	error = ""
	_ids.clear()
	_game = game
	if not game.get_tree().paused or not game.is_node_ready():
		return _fail("Pause at a simulation boundary before capturing the match.")
	if not game.settings.skirmish or game.settings.players.size() not in [2, 4] or game.finished:
		return _fail("Only active skirmishes and supported operations can be saved.")
	var maps = game.get_node("/root/Constants").Match.MAPS.keys()
	for operation in Campaigns.OPERATIONS.values():
		maps.append(operation.map)
	if (
		game.settings.map_path not in maps
		or game.settings.mission_id not in [""] + Campaigns.OPERATIONS.keys()
	):
		return _fail("This map or mission does not have a save contract yet.")
	game.wreck_salvage.flush()
	var players = game.get_node("Players").get_children().filter(func(p): return "faction" in p)
	var units = game.get_tree().get_nodes_in_group("units").filter(_live)
	var deposits = game.get_tree().get_nodes_in_group("resource_units").filter(_live)
	if units.size() > 140 * players.size() or deposits.size() > 512:
		return _fail("Match exceeds the supported save population or resource limit.")
	for index in range(players.size()):
		_ids[players[index]] = "player-%d" % index
	for index in range(units.size()):
		_ids[units[index]] = "unit-%d" % index
	for index in range(deposits.size()):
		_ids[deposits[index]] = "resource-%d" % index
	for target in game.get_tree().get_nodes_in_group("neutral_targets"):
		_ids[target] = target.neutral_id
	for site in load("res://source/match/world/PointOfInterestCatalog.gd").sites(game):
		_ids[site] = site.site_id
	var settings = _properties(
		game.settings,
		[
			"visibility",
			"visible_player",
			"skirmish",
			"advanced_start",
			"map_path",
			"match_seed",
			"mission_id"
		]
	)
	settings.players = []
	for player in game.settings.players:
		settings.players.append(
			_properties(
				player, ["color", "controller", "spawn_index_offset", "faction", "difficulty"]
			)
		)
	var camera = game.get_node("IsometricCamera3D")
	var result = {
		"snapshot_version": VERSION,
		"map_revision": 1,
		"settings": settings,
		"simulation_time": game.simulation_time,
		"visual_serial": game._visual_serial,
		"units_produced": game.units_produced,
		"battle_record": game.battle_record.capture(),
		"repair_elapsed": game.repair_service._elapsed,
		"camera": {"position": camera.position, "rotation": camera.rotation, "size": camera.size},
		"players": [],
		"units": [],
		"resources": [],
		"mission": {},
		"ambient":
		game.map.get_node("AmbientLife").capture() if game.map.has_node("AmbientLife") else [],
		"neutral_buildings": game.get_node("NeutralWorld").capture(_reference),
		"fog": _fog(),
		"structure_memory": _structure_memory(),
	}
	for player in players:
		result.players.append(_player(player))
	for unit in units:
		result.units.append(_unit(unit))
	for deposit in deposits:
		var kind = "resource_a" if "resource_a" in deposit else "resource_b"
		result.resources.append(
			{
				"id": _reference(deposit),
				"kind": kind,
				"amount": deposit.get(kind),
				"position": deposit.position,
				"field_origin":
				deposit.harvest_origin if deposit.harvest_origin.is_finite() else null,
				"wreck":
				(
					_properties(deposit, ["wreck_role", "wreck_faction", "salvage_left"])
					if deposit.is_in_group("salvage_wrecks")
					else {}
				)
			}
		)
	if settings.mission_id == "command_horizon":
		result.mission = _properties(
			game,
			[
				"alternate_route",
				"deployed",
				"hold_seconds",
				"command_left",
				"command_destroyed",
				"defence_started",
				"defence_time",
				"waves_sent",
				"waves_warned"
			]
		)
		result.mission.challenge = game.settings.campaign_challenge
		result.mission.target_command = (
			_reference(game.target_command) if is_instance_valid(game.target_command) else ""
		)
		result.mission.relay = _properties(game.map.relay, ["progress", "contested"])
		result.mission.relay.owner = _reference(game.map.relay.captured_by)
		result.mission.relay.candidate = _reference(game.map.relay.candidate)
	elif settings.mission_id == "broken_foundry":
		result.mission = _properties(
			game, ["alarm", "hold_seconds", "command_left", "response_left", "response_done"]
		)
		result.mission.nodes = []
		for entry in game.nodes:
			var saved = _properties(entry, ["disabled", "batches", "left"])
			saved.unit = _reference(entry.unit) if is_instance_valid(entry.unit) else ""
			result.mission.nodes.append(saved)
		result.mission.relay = _properties(game.map.relay, ["progress", "contested"])
		result.mission.relay.owner = _reference(game.map.relay.captured_by)
		result.mission.relay.candidate = _reference(game.map.relay.candidate)
	elif settings.mission_id == "supply_line":
		result.mission = {
			"convoy": [],
			"responses": game.responses.duplicate(),
			"resolved": game.resolved.duplicate()
		}
		for entry in game.convoy:
			result.mission.convoy.append(
				{
					"unit": _reference(entry.unit) if is_instance_valid(entry.unit) else "",
					"leg": entry.leg,
					"clearance": entry.clearance,
					"delivered": entry.delivered
				}
			)
	elif settings.mission_id == "first_orders":
		result.mission = _properties(
			game,
			[
				"phase",
				"hold_seconds",
				"command_left",
				"defence_started",
				"defence_time",
				"waves_sent",
				"waves_warned",
				"reuse_badge"
			]
		)
		result.mission.relay = _properties(game.relay, ["progress", "contested"])
		result.mission.relay.owner = _reference(game.relay.captured_by)
		result.mission.relay.candidate = _reference(game.relay.candidate)
	elif settings.mission_id == "split_signal":
		result.mission = _properties(
			game,
			[
				"control_seconds",
				"network_seconds",
				"command_left",
				"defence_started",
				"defence_time",
				"waves_sent",
				"waves_warned",
				"network_badge"
			]
		)
		result.mission.relays = game.map.capture_state(_reference).relays
	elif game.map.has_method("capture_state"):
		result.mission = game.map.capture_state(_reference)
	if Campaigns.is_story(settings.mission_id):
		result.mission = game.capture_operation(_reference)
	if "points_of_interest" in game.map:
		result.mission.points_of_interest = game.map.points_of_interest.map(
			func(site): return site.capture_state(_reference)
		)
	if settings.mission_id != "":
		if game.campaign_hero != null:
			result.mission.hero = game.campaign_hero.capture(_reference)
		game._attach_campaign_story()
		if is_instance_valid(game.campaign_story):
			result.mission.story = game.campaign_story.snapshot()
		if "opposition" in game and is_instance_valid(game.opposition):
			result.mission.opposition = game.opposition.capture_state(_reference)
	if not error.is_empty():
		return null
	# Detach every nested container, reject engine objects, NaN and unsupported types.
	var values = Values.new()
	var encoded = values.encode(result)
	if not values.error.is_empty():
		return _fail(values.error)
	return values.decode(encoded)


func _player(player):
	var result = _properties(
		player,
		["resource_a", "resource_b", "coordination_unlocked", "coordination_left", "_lab_research"]
	)
	result.technology = player.technology.capture()
	result.id = _reference(player)
	result.signatures = player.signatures.capture(_reference)
	result.command_left = _game._defeat_timers.get(player, 60.0)
	result.ai = {}
	if "structures_built" in player:
		result.ai = _properties(
			player, ["structures_built", "attacks_launched", "_elapsed", "_production_index"]
		)
		result.ai.wave_age = _game.simulation_time - player._last_wave
		result.ai.enabled = player.is_processing()
		result.ai.cursor = player._army_cursor
		result.ai.groups = _army_groups(player)
	return result


func _unit(unit):
	var result = {
		"id": _reference(unit),
		"player": _reference(unit.player),
		"role": unit.type,
		"position": unit.position,
		"rotation": unit.rotation,
		"stance": int(unit.stance),
		"hp": unit.hp,
		"visual_seed": unit.get_meta("visual_seed", 0),
		"signature": unit.signature.capture() if unit.signature != null else {},
		"deployment":
		(
			_properties(unit, ["deployment_left", "deployment_position"])
			if unit.type == "AdvancedTank" and unit.player.faction == "helix"
			else {}
		),
		"weapon_mode":
		(
			_properties(unit, ["weapon_mode", "pending_weapon_mode", "weapon_switch_left"])
			if unit.type == "CombatRobot" and unit.can_switch_weapon()
			else {}
		),
		"weapon_left":
		maxf(
			0.0, unit.get_meta("next_attack_availability_time", 0) / 1000.0 - _game.simulation_time
		),
		"damage_age":
		(
			_game.simulation_time - unit.last_enemy_damage_time
			if is_finite(unit.last_enemy_damage_time)
			else null
		),
		"construction": unit._construction_progress if unit.has_method("is_constructed") else null,
		"cargo": _properties(unit, ["resource_a", "resource_b"]) if unit.type == "Worker" else {},
		"action": _action(unit.action),
		"orders": {},
		"production": {},
		"rally": {},
		"movement": {},
		"groups": [],
		"selected": unit.is_in_group("selected_units"),
	}
	for index in range(1, 10):
		if unit.is_in_group("unit_group_%d" % index):
			result.groups.append(index)
	if unit.manual_orders != null:
		var orders = unit.manual_orders
		result.orders = _properties(orders, ["status", "_engaged", "_still"])
		result.orders.progress = orders._progress if orders._progress.is_finite() else null
		result.orders.current = _order(orders.current)
		result.orders.pending = orders.pending.map(_order)
	var movement = unit.get_node_or_null("Movement")
	if movement != null:
		result.movement = _properties(
			movement,
			[
				"_has_destination",
				"target_position",
				"velocity",
				"_progress_elapsed",
				"_progress_position",
				"_recovery_left",
				"_recovery_direction"
			]
		)
	if "production_queue" in unit and unit.production_queue != null:
		var queue = unit.production_queue
		result.production = {"jobs": []}
		for job in queue.get_elements():
			var item = _properties(
				job, ["time_total", "time_left", "paid_cost", "departure_endpoint"]
			)
			item.role = job.unit_prototype.resource_path.get_file().get_basename()
			result.production.jobs.append(item)
	var rally = unit.get_node_or_null("RallyPoint")
	if rally != null:
		result.rally = {"position": rally.position, "target": _reference(rally.target_unit)}
	result.projectiles = []
	for child in unit.get_children():
		if child.get_script() == null:
			continue
		var kind = child.get_script().resource_path.get_file().get_basename()
		if (
			kind in ["CannonShell", "Rocket"]
			and not child.is_queued_for_deletion()
			and not child._resolved
		):
			result.projectiles.append(
				{
					"kind": kind,
					"target": _reference(child.target_unit),
					"left": maxf(0, child._flight_left)
				}
			)
	return result


func _order(order):
	if order.is_empty():
		return {}
	var result = {"kind": order.kind}
	if order.has("point"):
		result.point = order.point
	if order.has("target"):
		result.target = _reference(order.target.get_ref())
	return result


func _action(action, depth = 0):
	if not _live(action):
		return {}
	if depth > 12:
		_fail("Action nesting exceeds the save contract.")
		return {}
	var path = action.get_script().resource_path
	var kind = path.get_file().get_basename()
	if kind not in ACTION_FIELDS or path != "res://source/match/units/actions/%s.gd" % kind:
		_fail("Unsupported active action: " + kind)
		return {}
	var state = _properties(action, ACTION_FIELDS[kind])
	for key in state:
		if state[key] is Vector3 and not state[key].is_finite():
			state[key] = null  # Explicit not-yet-known position sentinel.
	var result = {"kind": kind, "state": state, "references": {}, "children": {}, "timers": {}}
	for field in ACTION_REFERENCES:
		if field in action:
			result.references[field] = _reference(action.get(field))
	for field in ACTION_CHILDREN:
		if field in action:
			result.children[field] = _action(action.get(field), depth + 1)
	for field in ACTION_TIMERS:
		if field in action and is_instance_valid(action.get(field)):
			var timer = action.get(field)
			result.timers[field] = {
				"left": timer.time_left,
				"wait": timer.wait_time,
				"stopped": timer.is_stopped(),
				"paused": timer.paused
			}
	return result


func _fog():
	if DisplayServer.get_name() == "headless":
		return {"available": false}  # Headless verification fixtures have no render history.
	var image = _game.fog_of_war._fog_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Exploration image is not ready; retry after the next rendered frame.")
		return {}
	return {
		"available": true,
		"width": image.get_width(),
		"height": image.get_height(),
		"png": Marshalls.raw_to_base64(image.save_png_to_buffer())
	}


func _structure_memory():
	var handler = _game.get_node("Handlers/UnitVisibilityHandler")
	var result = []
	var memories = handler._orphaned_dummies.duplicate()
	memories.append_array(handler._structure_to_dummy_mapping.values())
	for dummy in memories:
		if not _live(dummy):
			continue
		if not dummy.has_meta("memory_role"):
			_fail("A remembered structure has no save identity.")
			continue
		var live_unit = handler._structure_to_dummy_mapping.find_key(dummy)
		(
			result
			. append(
				{
					"entity": _reference(live_unit),
					"role": dummy.get_meta("memory_role"),
					"faction": dummy.get_meta("memory_faction"),
					"color": dummy.get_meta("memory_color"),
					"position": dummy.position,
					"rotation": dummy.rotation,
					"scale": dummy.scale,
				}
			)
		)
	return result


func _properties(object, names):
	var result = {}
	for key in names:
		result[key] = object.get(key)
	return result


func _army_groups(player):
	var result = []
	for group in player._army_groups:
		var members = group.members.map(_reference).filter(func(id): return id != "")
		if members.is_empty():
			continue
		result.append(
			{
				"kind": group.kind,
				"point": group.point,
				"members": members,
				"age": maxf(0, _game.simulation_time - group.started),
				"retiring": group.retiring,
				"workers": group.workers.map(_reference).filter(func(id): return id != "")
			}
		)
	return result


func _reference(object):
	return _ids.get(object, "") if _live(object) else ""


func _live(object):
	return (
		is_instance_valid(object)
		and not object.is_queued_for_deletion()
		and _game.is_ancestor_of(object)
	)


func _fail(message):
	error = message
	return null
