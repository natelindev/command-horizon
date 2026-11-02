# gdlint: disable=max-returns,max-file-lines
extends RefCounted

const Catalog = preload("res://source/match/BastionCatalog.gd")
const AmbientCatalog = preload("res://source/match/ambient/AmbientCatalog.gd")
const Benchmark = preload("res://source/match/saves/BenchmarkState.gd")
const Harvesting = preload("res://source/match/economy/HarvestingProfile.gd")
const Factions = preload("res://source/match/FactionRules.gd")
const Salvage = preload("res://source/match/economy/SalvageRules.gd")
const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const Technology = preload("res://source/match/research/TechnologyCatalog.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")

const Campaigns = preload("res://source/match/campaign/CampaignCatalog.gd")
const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const Rules = preload("res://source/match/MatchConstants.gd")
const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const LINKS = {
	"EngineeringAction": [["_target"], [], []],
	"CollectTacticalCargo": [["_target_unit"], ["_shot"], []],
	"Garrisoning": [["_target_unit"], ["_shot"], []],
	"Moving": [[], ["_shot"], []],
	"MovingToUnit": [["_target_unit"], ["_shot"], []],
	"Scavenging": [["_target_unit"], ["_shot"], []],
	"AttackMoving": [[], ["_shot"], []],
	"Patrolling": [[], ["_shot"], []],
	"AutoAttacking": [["_target_unit"], ["_shot"], []],
	"AttackingWhileInRange": [["_target_unit"], [], ["_one_shot_timer", "_range_check_timer"]],
	"WaitingForTargets": [[], ["_sub_action"], ["_timer"]],
	"Following": [["_target_unit"], ["_sub_action"], ["_timer"]],
	"FollowingToReachDistance": [["_target_unit"], [], ["_timer"]],
	"CollectingResourcesSequentially": [["_resource_unit", "_cc_unit"], ["_sub_action"], []],
	"CollectingResourcesWhileInRange": [["_resource_unit"], [], ["_timer"]],
	"Constructing": [["_target_unit"], ["_sub_action"], []],
	"ConstructingWhileInRange": [["_target_unit"], [], []],
	"Repairing": [["_target"], [], []],
	"RecoveringAtService": [["_target"], [], []],
	"AirStation": [["_escort"], [], []],
	"AirStrike": [["_target_unit"], [], []],
	"AirReturn": [[], [], []],
	"AirIdle": [[], [], []],
	"DroneDive": [["_target_unit"], [], []],
}
const AIR_ACTIONS = ["AirStation", "AirStrike", "AirReturn", "AirIdle"]
const AIR_MODES = ["idle", "station", "strike", "return"]
# Fixed-wing turns and runway approaches extend over the backdrop. Leave room
# for a bank-limited turn after the flight controller notices the airspace edge.
const AIRSPACE_SAVE_MARGIN = 32.0
const AIRSPACE_SAVE_HEIGHT = 60.0
const ScenarioDocument = preload("res://source/scenario/ScenarioDocument.gd")
var error = ""
var ability_definitions = {}
var entities = {}
var sides = {}
var map_size = Vector2.ZERO
var fog_image = null
var _scenario := {}
var _nodes_left = 20000
var _neutral_ids = {}
var _poi_ids = {}
var _tactical_ids = {}
var _depth = null
var _faction_catalog = null
var _scenario_document = ScenarioDocument.new()
var _validation_scripts = []


func prepare_validation(definitions: Dictionary = {}):
	ability_definitions = definitions
	if _validation_scripts.is_empty():
		# Keep runtime-loaded scripts alive before a worker starts. Their pure
		# constants may then be inspected without loading/unloading scripts there.
		for path in [
			"res://source/match/FactionCatalog.gd",
			"res://source/match/BattleRecord.gd",
			"res://source/match/combat/ProjectileSystem.gd",
			"res://source/match/combat/CombatRules.gd",
			"res://source/match/combat/WeaponCatalog.gd",
			"res://source/match/units/Helicopter.gd",
			"res://source/match/units/Fighter.gd",
			"res://source/match/units/Bomber.gd",
			"res://source/match/campaign/CampaignNarration.gd",
			"res://source/match/maps/CommandHorizonMap.gd"
		]:
			_validation_scripts.append(load(path))
	if _depth == null:
		_depth = load("res://source/match/saves/GameplayDepthSchema.gd").new(self)


func validate(data):
	error = ""
	_faction_catalog = load("res://source/match/FactionCatalog.gd")
	entities.clear()
	_tactical_ids.clear()
	if _depth == null:
		prepare_validation(ability_definitions)
	_neutral_ids.clear()
	_poi_ids.clear()
	sides.clear()
	fog_image = null
	_nodes_left = 20000
	if data is Dictionary and data.get("snapshot_version") != Snapshot.VERSION:
		return _fail("This save was made by a different game version.")
	if not _shape(
		data,
		(
			"snapshot_version:int map_revision:int settings:dict simulation_time:num "
			+ "visual_serial:int units_produced:int repair_elapsed:num camera:dict "
			+ "players:list units:list resources:list mission:dict fog:dict "
			+ "structure_memory:list neutral_buildings:list battle_record:dict ambient:list "
			+ "rounds:dict battlefield_wear:list grenades:dict engineering:dict commander:dict events:dict"
			+ (" obstacles:list" if data is Dictionary and data.has("obstacles") else "")
		)
	):
		return false
	if not load("res://source/match/BattleRecord.gd").valid(data.battle_record):
		return _fail("Invalid battle record.")
	if data.map_revision != _map_revision(data.settings.map_path) or not _settings(data.settings):
		return _fail("Unsupported snapshot, map or settings version.")
	if not _ambient(data.ambient, data.settings.map_path):
		return false
	if (
		data.players.size() != data.settings.players.size()
		or data.units.size() > 140 * data.players.size()
		or data.resources.size() > 512
	):
		return _fail("Save exceeds match population limits.")
	if (
		not _shape(data.camera, "position:vec rotation:vec size:num")
		or data.camera.size < 1
		or data.camera.size > Rules.SKIRMISH_CAMERA_MAX_SIZE
	):
		return _fail("Invalid saved camera.")
	for index in data.players.size():
		var side = data.players[index]
		if not _shape(
			side,
			(
				"id:text resource_a:int resource_b:int coordination_unlocked:bool "
				+ "coordination_left:signed _lab_research:bool command_left:num ai:dict "
				+ "signatures:dict technology:dict economy:dict"
			)
		):
			return false
		if not Benchmark.valid_player(self, side):
			return false
		if (
			side.id != "player-%d" % index
			or side.coordination_left < -1
			or side.coordination_left > 30
			or side.command_left > 60
		):
			return _fail("Invalid player progression.")
		if not Technology.valid_state(
			side.technology, side.coordination_unlocked, side.coordination_left > 0
		):
			return _fail("Invalid technology research.")
		if side.technology.active != "" and side.coordination_left > 0:
			return _fail("Multiple active research projects.")
		var projects = side.technology.completed + [side.technology.active]
		for entry in side.technology.queued:
			projects.append(entry.id)
		if not projects.all(
			func(id): return Technology.available(id, data.settings.players[index].faction)
		):
			return _fail("Technology is unavailable to this faction.")
		sides[side.id] = {
			"faction": data.settings.players[index].faction,
			"mobile": 0,
			"heroes": 0,
			"structures": 0,
			"technology": side.technology.completed,
			"coordination": side.coordination_unlocked
		}
		if index > 0:
			if not _shape(
				side.ai,
				(
					"structures_built:int attacks_launched:int _elapsed:num "
					+ "_production_index:int wave_age:num enabled:bool cursor:int groups:list"
				)
			):
				return false
		elif not side.ai.is_empty():
			return _fail("Human player cannot restore an AI controller.")
	if not _obstacles(data.get("obstacles", [])):
		return false
	var wreck_count = 0
	for entry in data.resources:
		if (
			not _shape(
				entry, "id:text kind:text amount:int position:vec wreck:dict field_origin:maybevec"
			)
			or not _identify(entry, "resource-")
		):
			return false
		if (
			entry.kind not in ["resource_a", "resource_b"]
			or entry.amount <= 0
			or not _position(entry.position)
		):
			return _fail("Invalid resource deposit.")
		if entry.field_origin != null and not _position(entry.field_origin):
			return _fail("Invalid resource field origin.")
		if not entry.wreck.is_empty():
			var wreck = entry.wreck
			wreck_count += 1
			if not _shape(wreck, "wreck_role:text wreck_faction:text salvage_left:num"):
				return false
			if (
				wreck.wreck_role not in Salvage.ROLES
				or wreck.wreck_faction not in Factions.IDS
				or wreck.salvage_left <= 0
				or wreck.salvage_left > Salvage.LIFETIME
				or entry.kind != "resource_a"
				or entry.amount > Salvage.amount(wreck.wreck_faction, wreck.wreck_role)
				or wreck_count > Salvage.LIMIT
				or not data.settings.players.any(func(side): return side.faction == "frontier")
			):
				return _fail("Invalid finite wreck salvage.")
	for unit in data.units:
		if (
			not _shape(
				unit,
				(
					"id:text player:text role:text position:vec rotation:vec hp:num experience:num "
					+ "visual_seed:int weapon_left:num damage_age:maybenum construction:maybenum "
					+ "cargo:dict action:dict orders:dict production:dict rally:dict "
					+ "movement:dict groups:list selected:bool air:dict "
					+ "weapon_mode:dict deployment:dict signature:dict stance:int "
					+ "permanent_scrap_rank:int damage_visual_band:int regarrison_lock_left:num "
					+ "suppression:dict abilities:dict benchmark:dict"
					+ (
						" plasma_shield:dict"
						if unit is Dictionary and unit.has("plasma_shield")
						else ""
					)
					+ (
						" scrap_hardened:dict"
						if unit is Dictionary and unit.has("scrap_hardened")
						else ""
					)
					+ (
						" garrison_mount:dict"
						if unit is Dictionary and unit.has("garrison_mount")
						else ""
					)
				)
			)
			or not _identify(unit, "unit-")
		):
			return false
		if (
			unit.player not in sides
			or (
				unit.role not in Catalog.NAMES
				and not (
					unit.player == "player-0"
					and unit.role == "SupplyTruck"
					and (
						data.settings.mission_id == "supply_line"
						or (
							data.settings.mission_id != ""
							and Campaigns.is_story(data.settings.mission_id)
						)
					)
				)
			)
			or not (
				_airspace_position(unit.position)
				if Catalog.is_fixed_wing(unit.role)
				else _position(unit.position)
			)
		):
			return _fail("Invalid unit owner, role or position.")
		if unit.role == "Hero":
			sides[unit.player].heroes += 1
			if sides[unit.player].heroes > 1:
				return _fail("Duplicate hero reservation.")
		var building = unit.role in Catalog.STRUCTURES
		if (
			unit.experience > 600.0
			or (
				unit.experience > 0
				and (
					building
					or (
						not Rules.Units.DEFAULT_PROPERTIES[Catalog.scene_path(unit.role)].has(
							"attack_damage"
						)
						and not (unit.role == "Worker" and sides[unit.player].faction == "frontier")
					)
				)
			)
		):
			return _fail("Invalid unit veterancy.")
		if unit.stance not in [0, 1, 2, 3]:
			return _fail("Invalid unit stance.")
		if unit.has("scrap_hardened"):
			var scrap = unit.scrap_hardened
			if (
				not _shape(scrap, "tiers:int left:num")
				or sides[unit.player].faction != "frontier"
				or unit.role not in ["Tank", "AntiAirVehicle", "AdvancedTank"]
				or scrap.tiers not in [1, 2]
				or scrap.left <= 0.0
				or scrap.left > 60.0
			):
				return _fail("Invalid Scrap Hardened buff.")
		if not _depth.unit_state(unit):
			return false
		var shield_max = Technology.shield_capacity(
			unit.role, sides[unit.player].faction, sides[unit.player].technology
		)
		if (shield_max > 0) != unit.has("plasma_shield"):
			return _fail("Plasma shield does not match unit research.")
		if unit.has("plasma_shield"):
			if not _shape(unit.plasma_shield, "charge:num damage_age:maybenum"):
				return false
			if unit.plasma_shield.charge > shield_max:
				return _fail("Invalid plasma shield charge.")
		if (
			not _air(unit)
			or not _weapon_mode(unit)
			or not _deployment(unit)
			or not _signature_unit(unit)
		):
			return false
		sides[unit.player]["structures" if building else "mobile"] += 1
		var maximum = _faction_catalog.base_health(sides[unit.player].faction, unit.role)
		maximum *= Technology.health_factor(unit.role, sides[unit.player].technology)
		if unit.hp <= 0 or unit.hp > maximum + 0.000001 or unit.weapon_left > 120:
			return _fail("Invalid unit health or cooldown.")
		if building != (unit.construction != null) or (building and unit.construction > 1):
			return _fail("Invalid construction state.")
	if not _neutral_buildings(data.neutral_buildings, data.settings.map_path):
		return false
	if not _site_records(data.mission.get("points_of_interest", []), data.settings.map_path):
		return false
	if not Benchmark.valid_links(self, data):
		return false
	if not _depth.manager_states(data):
		return false
	if not _mobile_garrisons(data.units, data.neutral_buildings, data.engineering.entities):
		return false
	for unit in data.units:
		if not _unit(unit):
			return false
	if not _army_groups(data):
		return false
	for side in data.players:
		if not _signature_groups(side, data.units):
			return false
		if sides[side.id].mobile > 100 or sides[side.id].structures > 40:
			return _fail("Invalid reserved population.")
	if (
		not _mission(data.mission, data.settings.mission_id, data.settings.map_path)
		or not _fog(data.fog)
		or not _rounds(data)
		or not _wear(data.battlefield_wear)
	):
		return false
	if data.structure_memory.size() > 2048:
		return _fail("Too many remembered structures.")
	for memory in data.structure_memory:
		if not _shape(
			memory,
			"entity:text role:text faction:text color:color position:vec rotation:vec scale:vec"
		):
			return false
		if (
			memory.role not in Catalog.STRUCTURES
			or memory.faction not in Factions.IDS
			or not _unit_reference(memory.entity)
			or (
				entities.has(memory.entity)
				and entities[memory.entity].role not in Catalog.STRUCTURES
			)
		):
			return _fail("Invalid remembered structure.")
	return true


func _wear(marks):
	if marks.size() > 2048:
		return _fail("Too many battlefield marks.")
	for mark in marks:
		if not _shape(
			mark,
			(
				"x:num z:num radius:num angle:signed kind:int"
				+ (" left:num" if mark is Dictionary and mark.get("kind") == 1 else "")
			)
		):
			return false
		if (
			mark.x >= map_size.x
			or mark.z >= map_size.y
			or mark.radius < .3
			or mark.radius > 6.0
			or mark.kind > 1
			or absf(mark.angle) > TAU
			or (mark.kind == 1 and (mark.left <= 0.0 or mark.left > 180.0))
		):
			return _fail("Invalid battlefield mark.")
	return true


func _rounds(data):
	# Runtime loads: combat scripts read autoloads, and this schema is preloaded
	# by scripts that compile before autoloads exist.
	var projectiles = load("res://source/match/combat/ProjectileSystem.gd")
	var profiles = load("res://source/match/combat/CombatRules.gd").PROFILES
	var weapons = load("res://source/match/combat/WeaponCatalog.gd")
	if not _shape(data.rounds, "serial:int flying:list"):
		return false
	if data.rounds.flying.size() > 600:
		return _fail("Too many rounds in flight.")
	for round in data.rounds.flying:
		if (
			not _shape(
				round,
				(
					"kind:text weapon:text player:text shooter:text type:text damage:num "
					+ "domains:list "
					+ "mode:text force_attack:bool origin:vec target:text target_base:maybevec "
					+ "position:vec velocity:vec age:num "
					+ "life:num burn:num serial:int suppression:list"
				)
			)
			or round.kind not in projectiles.KINDS
			or round.weapon not in weapons.ids()
			or weapons.by_id(round.weapon).kind != round.kind
			or not sides.has(round.player)
			or not profiles.has(round.type)
			or round.damage > 1000
			or round.life > projectiles.MAX_FLIGHT
			or round.age > round.life
			or round.burn > projectiles.MAX_FLIGHT
			or round.serial >= data.rounds.serial
			or round.velocity.length() > 500
			or round.mode not in ["", "precision", "interception"]
			or round.domains.size() > 2
			or round.domains.any(func(domain): return not domain is int or domain not in [0, 1])
			or not _airspace_position(round.origin)
			or not _airspace_position(round.position)
			or (round.target_base != null and not _airspace_position(round.target_base))
		):
			return _fail("Invalid round in flight.")
		if not _depth.round_state(round):
			return false
		if not _unit_reference(round.shooter) or not _unit_reference(round.target):
			return false
	return true


func _army_groups(data):
	for index in range(1, data.players.size()):
		if not _side_army_groups(data, index):
			return false
	return true


func _side_army_groups(data, index):
	var ai = data.players[index].ai
	var budget = Difficulty.of(data.settings.players[index].difficulty).task_groups
	if ai.cursor > 3 or ai.groups.size() > budget:
		return _fail("Invalid AI coordination budget or cursor.")
	var assigned = []
	var guards = 0
	for group in ai.groups:
		if not _shape(group, "kind:text point:vec members:list age:num retiring:bool workers:list"):
			return false
		if (
			group.kind not in ["defense", "assault", "guard", "capture", "scout"]
			or not _position(group.point)
			or group.age > data.simulation_time
			or group.members.is_empty()
			or group.members.size() > 100
			or group.workers.size() > 100
			or (group.kind != "guard" and (group.retiring or not group.workers.is_empty()))
			or (not group.retiring and not group.workers.is_empty())
		):
			return _fail("Invalid AI task state.")
		var maximum = {"defense": 6, "assault": 100, "guard": 2, "capture": 2, "scout": 1}[
			group.kind
		]
		if group.members.size() > maximum:
			return _fail("Too many AI task members.")
		for id in group.members:
			if not id is String or not entities.has(id) or id in assigned:
				return _fail("Missing or duplicate AI task member.")
			var unit = entities[id]
			if not unit.has("player") or unit.player != "player-%d" % index:
				return _fail("AI task member belongs to another side.")
			var ground = ["Tank", "AdvancedTank", "CombatRobot", "AntiAirVehicle"]
			var roles = ground + Catalog.AIRCRAFT_ROLES + Catalog.INFANTRY_ROLES
			if group.kind == "guard":
				roles = ground + Catalog.INFANTRY_ROLES
			elif group.kind == "capture":
				roles = Catalog.INFANTRY_ROLES
			elif group.kind == "scout":
				roles = ["Drone"]
			if unit.role not in roles:
				return _fail("Incompatible AI task member role.")
			assigned.append(id)
		if group.kind == "guard":
			guards += group.members.size()
		var workers = []
		for id in group.workers:
			if not id is String or not entities.has(id) or id in workers:
				return _fail("Missing or duplicate returning engineer.")
			var unit = entities[id]
			if unit.get("player") != "player-%d" % index or unit.get("role") != "Worker":
				return _fail("Invalid returning engineer owner or role.")
			workers.append(id)
	return guards <= 2 or _fail("AI guard roster exceeds two units.")


func _signature_unit(unit):
	var state = unit.signature
	if unit.role not in ["Tank", "AdvancedTank", "CombatRobot"]:
		return state.is_empty() or _fail("Unexpected faction ability state.")
	if not _shape(
		state,
		(
			"cooldown:num group_id:int kind:text sector:vec setup_left:num anchored:bool "
			+ "window_left:num precision_ready:bool last_position:vec"
		)
	):
		return false
	var side = sides[unit.player]
	if (
		state.cooldown > Factions.signature_cooldown(side.faction)
		or state.setup_left > 2
		or state.window_left > (6 if side.faction == "frontier" else 2)
		or not _position(state.sector)
		or not _position(state.last_position)
		or state.kind not in ["", "anchor", "precision", "maneuver"]
	):
		return _fail("Invalid faction ability duration or sector.")
	if (
		(state.kind == "anchor" and side.faction != "bastion")
		or (state.kind == "precision" and side.faction != "helix")
		or (state.kind == "maneuver" and side.faction != "frontier")
	):
		return _fail("Wrong faction ability.")
	if (
		state.anchored and (state.kind != "anchor" or state.setup_left != 0)
		or state.precision_ready and state.kind != "precision"
		or state.window_left > 0 and state.kind not in ["precision", "maneuver"]
	):
		return _fail("Inconsistent faction ability state.")
	if (state.cooldown > 0 or state.kind != "") and (state.group_id == 0 or not side.coordination):
		return _fail("Faction ability lacks its group or research.")
	return true


func _signature_groups(side, units):
	var state = side.signatures
	if (
		not _shape(state, "next_id:int groups:list")
		or state.next_id < 1
		or state.groups.size() > 200
	):
		return _fail("Invalid activation groups.")
	var ids = {}
	for group in state.groups:
		if not _shape(group, "id:int left:num members:list"):
			return false
		if (
			group.id <= 0
			or group.id >= state.next_id
			or ids.has(group.id)
			or group.members.size() > 6
		):
			return _fail("Invalid activation group identity or size.")
		if group.left > Factions.signature_cooldown(sides[side.id].faction):
			return _fail("Invalid activation group cooldown.")
		ids[group.id] = group
		var members = []
		for member in group.members:
			if not member is String or member in members or not entities.has(member):
				return _fail("Invalid activation member reference.")
			var unit = entities[member]
			if (
				unit.get("player") != side.id
				or unit.get("role") not in ["Tank", "AdvancedTank", "CombatRobot"]
			):
				return _fail("Invalid activation member owner or role.")
			members.append(member)
	for unit in units:
		if unit.player == side.id and not unit.signature.is_empty() and unit.signature.group_id > 0:
			var id = unit.signature.group_id
			if not ids.has(id) or unit.id not in ids[id].members:
				return _fail("Missing unit activation group.")
	return true


func _air(unit):
	if unit.role == "Helicopter":
		if not _shape(
			unit.air, "stores:dict rearm_left:num resume_station:maybevec unlimited:bool"
		):
			return false
		var helicopter = load("res://source/match/units/Helicopter.gd")
		var rockets = unit.air.stores.get("rockets")
		if (
			unit.air.stores.size() != 1
			or not rockets is int
			or rockets < 0
			or rockets > helicopter.ROCKET_CAPACITY
			or unit.air.rearm_left > helicopter.REARM_INTERVAL
		):
			return _fail("Invalid helicopter stores.")
		return true
	if not Catalog.is_fixed_wing(unit.role):
		return unit.air.is_empty() or _fail("Only fixed-wing aircraft carry flight state.")
	var fields = (
		"flight:dict stores:dict cooldowns:dict rearm_left:num "
		+ "resume_station:maybevec unlimited:bool"
	)
	if unit.role == "Bomber":
		fields += " stick_left:int"
	if not _shape(unit.air, fields):
		return false
	var flight = unit.air.flight
	if not _shape(
		flight,
		(
			"phase:int heading:signed airspeed:num bank:signed vertical_speed:signed mode:text "
			+ "station:maybevec strike_target:text airfield:text stand:signedint "
			+ "orbit_sign:signedint ordered:bool route:list route_after:text "
			+ "approach_entry:bool landing_end:signedint arrived:bool"
		)
	):
		return false
	if (
		flight.phase > 5
		or absf(flight.heading) > 4.0
		or flight.airspeed > 60.0
		or absf(flight.bank) > 1.6
		or absf(flight.vertical_speed) > 30.0
		or flight.mode not in AIR_MODES
		or flight.stand < -1
		or flight.stand > 3
		or flight.orbit_sign not in [-1, 1]
		or flight.route.size() > 6
		or flight.route.any(func(point): return not _type(point, "vec") or not _position(point))
		or flight.route_after not in ["", "takeoff", "park"]
		or flight.landing_end not in [-1, 0, 1]
		or (flight.station != null and not _position(flight.station))
		or not _unit_reference(flight.strike_target)
		or not _unit_reference(flight.airfield)
		or (
			entities.has(flight.airfield)
			and entities[flight.airfield].get("role") != "AircraftFactory"
		)
	):
		return _fail("Invalid flight state.")
	var aircraft = load("res://source/match/units/%s.gd" % unit.role)
	var loadout = aircraft.LOADOUT
	if (
		unit.air.stores.size() != loadout.size()
		or unit.air.cooldowns.size() != loadout.size()
		or unit.air.rearm_left > aircraft.REARM_INTERVAL
	):
		return _fail("Invalid aircraft stores.")
	for store in loadout:
		var count = unit.air.stores.get(store)
		var left = unit.air.cooldowns.get(store)
		if (
			not _type(count, "int")
			or count > loadout[store].capacity
			or not _type(left, "num")
			or left > loadout[store].interval
		):
			return _fail("Invalid aircraft stores or weapon cooldown.")
	if unit.role == "Bomber" and unit.air.stick_left > unit.air.stores.bomb:
		return _fail("Invalid remaining bomb stick.")
	return true


func _weapon_mode(unit):
	var state = unit.weapon_mode
	if unit.role != "CombatRobot" or sides[unit.player].faction != "helix":
		return state.is_empty() or _fail("Unexpected weapon mode.")
	if not _shape(state, "weapon_mode:text pending_weapon_mode:text weapon_switch_left:num"):
		return false
	if state.weapon_mode not in ["precision", "interception"] or state.weapon_switch_left > 2:
		return _fail("Invalid weapon mode or switch duration.")
	if state.weapon_switch_left == 0:
		return state.pending_weapon_mode == "" or _fail("Finished weapon switch has a destination.")
	return (
		(
			state.pending_weapon_mode in ["precision", "interception"]
			and state.pending_weapon_mode != state.weapon_mode
		)
		or _fail("Invalid pending weapon mode.")
	)


func _deployment(unit):
	var state = unit.deployment
	if unit.role != "AdvancedTank" or sides[unit.player].faction != "bastion":
		return state.is_empty() or _fail("Unexpected weapon deployment.")
	return (
		(
			_shape(state, "deployment_left:num deployment_position:vec")
			and state.deployment_left <= 2.0
			and _position(state.deployment_position)
		)
		or _fail("Invalid weapon deployment.")
	)


func _settings(settings):
	_scenario = {}
	if not _shape(
		settings,
		(
			"visibility:int visible_player:int skirmish:bool advanced_start:bool battlefield_events:bool "
			+ "starting_resources_multiplier:int "
			+ "map_path:text match_seed:signedint mission_id:text players:list"
			+ (" scenario:dict" if settings is Dictionary and settings.has("scenario") else "")
		)
	):
		return false
	if (
		not settings.skirmish
		or settings.visibility > 2
		or settings.starting_resources_multiplier not in [1, 2, 4]
		or settings.visible_player >= settings.players.size()
		or settings.players.size() not in [2, 4]
	):
		return false
	var document = _scenario_document
	if settings.has("scenario"):
		if settings.map_path != document.MAP or settings.mission_id != "":
			return _fail("Unexpected custom battlefield document.")
		if not document.validate(settings.scenario):
			return _fail(document.error)
		_scenario = settings.scenario
		map_size = Vector2(_scenario.size[0], _scenario.size[1])
	elif settings.mission_id != "" and settings.mission_id in Campaigns.operations():
		if settings.players.size() != 2:
			return false
		var operation = Campaigns.operations()[settings.mission_id]
		if settings.map_path != operation.map:
			return false
		map_size = operation.size
	elif settings.mission_id == "" and settings.map_path in Rules.MAPS:
		map_size = Vector2(Rules.MAPS[settings.map_path].size)
	else:
		return false
	var spawn_count = (
		_scenario.spawns.size()
		if not _scenario.is_empty()
		else (2 if settings.mission_id != "" else Rules.MAPS[settings.map_path].players)
	)
	if settings.players.size() > spawn_count:
		return false
	var spawn_index = 0
	var used_spawns = []
	for index in settings.players.size():
		var side = settings.players[index]
		if not _shape(
			side,
			(
				"color:color controller:int spawn_index_offset:int faction:text difficulty:int "
				+ "spawn_index:signedint team:signedint"
			)
		):
			return false
		spawn_index += side.spawn_index_offset + (1 if index > 0 else 0)
		if (
			side.controller != (1 if index == 0 else 2)
			or side.faction not in Factions.IDS
			or side.difficulty < Difficulty.EASY
			or side.difficulty > Difficulty.HARD
			or side.spawn_index < -1
			or side.spawn_index_offset >= spawn_count
			or (side.spawn_index >= 0 and side.spawn_index_offset != 0)
			or side.spawn_index >= spawn_count
			or side.team < -1
			or side.team > 3
			or (side.spawn_index if side.spawn_index >= 0 else spawn_index) >= spawn_count
		):
			return false
		var selected_spawn = side.spawn_index if side.spawn_index >= 0 else spawn_index
		if selected_spawn in used_spawns:
			return false
		used_spawns.append(selected_spawn)
		if (
			settings.mission_id != ""
			and (
				side.faction
				!= [
					Campaigns.operations()[settings.mission_id].faction,
					Campaigns.operations()[settings.mission_id].enemy
				][index]
			)
		):
			return false
	return true


func _unit(unit):
	if unit.role == "Worker":
		if (
			not _shape(unit.cargo, "resource_a:int resource_b:int")
			or (
				unit.cargo.resource_a + unit.cargo.resource_b
				> Harvesting.CAPACITY.get(sides[unit.player].faction, 4)
			)
		):
			return _fail("Invalid worker cargo.")
	elif not unit.cargo.is_empty():
		return _fail("Only engineers carry resources.")
	if (
		unit.groups.size() > 9
		or not unit.groups.all(func(id): return id is int and id >= 1 and id <= 9)
	):
		return _fail("Invalid control groups.")
	if unit.role not in Catalog.STRUCTURES:
		if not _shape(
			unit.movement,
			(
				"_has_destination:bool target_position:vec velocity:vec "
				+ "_progress_elapsed:num _progress_position:vec _recovery_left:signed "
				+ "_recovery_direction:vec"
			)
		):
			return false
		if (
			not _shape(
				unit.orders,
				(
					"status:text _engaged:bool _still:num progress:maybevec "
					+ "current:dict pending:list"
				)
			)
			or unit.orders.pending.size() > 16
		):
			return false
		if not _order(unit.orders.current, unit):
			return false
		for order in unit.orders.pending:
			if not _order(order, unit):
				return false
	elif not unit.movement.is_empty() or not unit.orders.is_empty():
		return _fail("Structures cannot have movement queues.")
	if not _action(unit.action, unit, 0):
		return false
	if not unit.production.is_empty():
		if (
			unit.role not in Catalog.PRODUCES
			or not _shape(unit.production, "jobs:list assembly_state:dict")
			or unit.production.jobs.size() > 100
		):
			return _fail("Invalid producer queue.")
		if not _depth.assembly_state(unit):
			return false
		for job in unit.production.jobs:
			if not _shape(
				job,
				(
					"time_total:num time_left:num paid_cost:dict role:text departure_endpoint:maybevec "
					+ "assembly_started:bool assembly_bonus:num batch_count:int"
				)
			):
				return false
			if (
				(
					job.role
					not in _faction_catalog.production_options(
						sides[unit.player].faction, unit.role
					)
				)
				or job.batch_count < 1
				or (
					job.batch_count
					> _faction_catalog.batch_size(sides[unit.player].faction, job.role)
				)
				or job.time_total <= 0
				or job.time_left > job.time_total
				or job.time_total > 3600
				or not _shape(job.paid_cost, "resource_a:int resource_b:int")
			):
				return _fail("Invalid paid production job.")
			if job.departure_endpoint != null:
				if (
					not _position(job.departure_endpoint)
					or job.departure_endpoint.distance_to(unit.position) > 12
				):
					return _fail("Invalid production exit.")
			sides[unit.player].mobile += job.batch_count
			if job.role == "Hero":
				sides[unit.player].heroes += 1
				if sides[unit.player].heroes > 1:
					return _fail("Duplicate hero reservation.")
	if not unit.rally.is_empty():
		if (
			not _shape(unit.rally, "position:vec target:text")
			or not _entity_reference(unit.rally.target)
		):
			return false
	return true


func _action(action, unit, depth):
	if action.is_empty():
		return true
	_nodes_left -= 1
	if depth > 12 or _nodes_left < 0 or action.get("kind") not in Snapshot.ACTION_FIELDS:
		return _fail("Unsupported saved action.")
	var kind = action.kind
	if not _shape(action, "kind:text state:dict references:dict children:dict timers:dict"):
		return false
	if (
		kind in ["AttackMoving", "AutoAttacking", "AttackingWhileInRange", "WaitingForTargets"]
		and not (
			Rules.Units.DEFAULT_PROPERTIES[Catalog.scene_path(unit.role)].has("attack_range")
			or (unit.role == "Worker" and sides[unit.player].faction == "frontier")
		)
	):
		return _fail("Unarmed unit has a weapon action.")
	if (
		(
			kind
			in [
				"CollectingResourcesSequentially",
				"CollectingResourcesWhileInRange",
				"Constructing",
				"ConstructingWhileInRange"
			]
		)
		and unit.role != "Worker"
	):
		return _fail("Only engineers can gather or construct.")
	if (kind in AIR_ACTIONS) != Catalog.is_fixed_wing(unit.role):
		return _fail("Fixed-wing aircraft and air actions must match.")
	if (
		unit.role == "Drone"
		and sides[unit.player].faction == "helix"
		and (
			kind
			in [
				"DroneDive",
				"AutoAttacking",
				"AttackingWhileInRange",
				"AttackMoving",
				"WaitingForTargets"
			]
		)
	):
		return _fail("Unarmed Helix scout cannot restore weapon orders.")
	if kind == "DroneDive" and unit.role != "Drone":
		return _fail("Only drones dive onto targets.")
	if kind == "Repairing" and unit.role not in ["RepairRobot", "Worker"]:
		return _fail("Invalid repair action owner.")
	if (
		unit.role in Catalog.STRUCTURES
		and kind not in ["WaitingForTargets", "AttackingWhileInRange", "AutoAttacking"]
	):
		return _fail("Immobile structure has a mobile action.")
	var fields = Snapshot.ACTION_FIELDS[kind]
	if action.state.size() != fields.size():
		return _fail("Action state does not match this game version.")
	for key in fields:
		if not action.state.has(key):
			return _fail("Missing action state.")
		var value = action.state[key]
		if kind == "EngineeringAction":
			continue  # Checked by the dedicated command schema below.
		var flag = (
			key
			in [
				"force_attack",
				"_lost_contact",
				"_finish_when_repaired",
				"_full_recovery",
				"_blocked",
				"sweep",
				"diving"
			]
		)
		var point = (
			key
			in [
				"_defense_origin",
				"_target_position",
				"destination",
				"origin",
				"endpoint",
				"_last_known_position",
				"_progress_position",
				"_last_known_target_unit_position",
				"_last_progress",
				"_charge_origin",
				"_field_origin",
				"_arrival_progress",
				"_point",
				"_velocity",
				"_aim_point"
			]
		)
		if not _type(value, "bool" if flag else ("maybevec" if point else "signed")):
			return _fail("Invalid action state value.")
	if kind == "EngineeringAction" and not _depth.engineering_action(action.state, unit):
		return false
	if kind == "CollectTacticalCargo" and (action.state.elapsed < 0 or action.state.elapsed > 2.1):
		return _fail("Invalid repair-crate interaction timer.")
	if kind == "AutoAttacking":
		if (
			not action.state._defense_origin is Vector3
			or action.state._defense_radius < 0
			or action.state._defense_radius > 64
		):
			return _fail("Invalid defensive response bounds.")
	if not _action_state(kind, action.state):
		return false

	if action.references.size() != LINKS[kind][0].size():
		return _fail("Missing action references.")
	for key in action.references:
		if key not in LINKS[kind][0] or not action.references[key] is String:
			return _fail("Invalid action reference.")
		var id = action.references[key]
		if not _entity_reference(id):
			return false
		if (
			id.begins_with("obstacle-")
			and (
				kind
				not in [
					"AutoAttacking", "AttackingWhileInRange", "MovingToUnit", "CollectTacticalCargo"
				]
			)
		):
			return _fail("Unsupported action on a destructible obstacle.")
		if key == "_resource_unit":
			if id != "" and not id.begins_with("resource-"):
				return _fail("Expected a resource reference.")
		elif kind not in ["MovingToUnit", "Scavenging"] and not _unit_reference(id):
			return false
		if (
			kind == "Garrisoning"
			and (
				not Catalog.is_infantry(unit.role)
				or not _garrison_target(id, unit)
				or action.state._capture_elapsed < 0
				or (
					action.state._capture_elapsed
					> (12.2 if _poi_ids.get(id) in ["refinery", "data_relay"] else 15.2)
				)
				or (
					not _neutral_ids.has(id)
					and not _poi_ids.has(id)
					and action.state._capture_elapsed != 0.0
				)
				or action.state._elapsed < 0
				or action.state._elapsed > .25
			)
		):
			return _fail("Invalid garrison action.")
		if (
			_neutral_ids.has(id)
			and (
				kind
				not in ["AutoAttacking", "AttackingWhileInRange", "MovingToUnit", "Garrisoning"]
			)
		):
			return _fail("Unsupported action on a neutral target.")
		if (
			_poi_ids.has(id)
			and (
				kind
				not in [
					"RecoveringAtService",
					"Repairing",
					"MovingToUnit",
					"Garrisoning",
					"AutoAttacking",
					"AttackingWhileInRange"
				]
			)
		):
			return _fail("Unsupported action on a captured facility.")
		var target = entities.get(id, {})
		if target.is_empty():
			continue
		if (
			key == "_resource_unit"
			and not target.get("wreck", {}).is_empty()
			and sides[unit.player].faction != "frontier"
		):
			return _fail("Only Frontier engineers may harvest wrecks.")
		if key == "_resource_unit" and not target.has("amount"):
			return _fail("Gather target is not a resource.")
		if (
			kind == "CollectingResourcesSequentially"
			and action.state._state == 5
			and (
				sides[unit.player].faction != "helix"
				or unit.cargo.resource_a + unit.cargo.resource_b < 4
			)
		):
			return _fail("Invalid phase delivery state.")
		if kind == "CollectingResourcesSequentially" and key == "_resource_unit":
			var expected_kind = "resource_a" if action.state._kind == 1 else "resource_b"
			if action.state._kind == 0 or target.kind != expected_kind:
				return _fail("Resource target does not match its field assignment.")
		if (
			kind == "Scavenging"
			and (
				sides[unit.player].faction != "frontier"
				or unit.role not in ["Tank", "AntiAirVehicle", "AdvancedTank"]
				or target.get("wreck", {}).is_empty()
			)
		):
			return _fail("Invalid wreck scavenge action.")
		if (
			key != "_resource_unit"
			and not target.has("role")
			and kind not in ["MovingToUnit", "Scavenging", "Repairing"]
		):
			return _fail("Action target is not a unit.")
		if (
			kind in ["Constructing", "ConstructingWhileInRange"]
			and (
				unit.role != "Worker"
				or target.get("role") not in Catalog.STRUCTURES
				or target.get("player") != unit.player
			)
		):
			return _fail("Invalid construction target.")
		if (
			key == "_cc_unit"
			and (
				(
					target.get("role")
					not in (
						["CommandCenter", "ForwardRefinery"]
						if sides[unit.player].faction == "bastion"
						else ["CommandCenter"]
					)
				)
				or target.get("player") != unit.player
			)
		):
			return _fail("Invalid resource delivery target.")
		if (
			kind == "Repairing"
			and target.get("player") not in ([unit.player, ""] if id in _poi_ids else [unit.player])
		):
			return _fail("Repair target is not allied.")
		if (
			kind == "RecoveringAtService"
			and (
				target.get("player") != unit.player
				or (
					target.get("role")
					!= (
						"Barracks"
						if Catalog.is_infantry(unit.role)
						else (
							"AircraftFactory" if Catalog.is_aircraft(unit.role) else "RepairDepot"
						)
					)
				)
				or target.construction != 1.0
			)
		):
			return _fail("Invalid recovery facility.")

	for key in action.children:
		if key not in LINKS[kind][1] or not action.children[key] is Dictionary:
			return _fail("Invalid %s child slot: %s." % [kind, key])
		if not _action(action.children[key], unit, depth + 1):
			return _fail("Invalid %s child: %s" % [kind, error])
	if (
		kind == "CollectingResourcesSequentially"
		and action.state._state in [4, 5]
		and not action.children.get("_sub_action", {}).is_empty()
	):
		return _fail("Waiting harvester has an active child action.")
	for slot in action.children:
		var child = action.children[slot]
		if child.is_empty():
			continue
		var allowed = ["AttackingWhileInRange"]
		if slot == "_sub_action":
			allowed = (
				{
					"WaitingForTargets": ["AttackingWhileInRange", "AutoAttacking"],
					"Following": ["MovingToUnit"],
					"Constructing": ["MovingToUnit", "ConstructingWhileInRange"],
					"CollectingResourcesSequentially":
					["Moving", "MovingToUnit", "CollectingResourcesWhileInRange"],
				}
				. get(kind, [])
			)
		if child.kind not in allowed:
			return _fail("Action child has the wrong role.")
	for key in action.timers:
		if (
			key not in LINKS[kind][2]
			or not _shape(action.timers[key], "left:num wait:num stopped:bool paused:bool")
			or action.timers[key].wait <= 0
			or action.timers[key].left > action.timers[key].wait
		):
			return _fail("Invalid action timer.")
	return true


func _action_state(kind, state):
	if kind == "Patrolling":
		if (
			not _type(state.origin, "vec")
			or not _position(state.origin)
			or not _type(state.endpoint, "vec")
			or not _position(state.endpoint)
			or not _type(state.destination, "vec")
			or state.destination not in [state.origin, state.endpoint]
		):
			return _fail("Invalid patrol route.")
	if kind == "AirStation" and (not _type(state._point, "vec") or not state.sweep is bool):
		return _fail("Invalid air station.")
	if kind == "AirIdle" and (not _type(state._scan_left, "signed") or absf(state._scan_left) > 1):
		return _fail("Invalid air patrol scan.")
	if kind == "AttackingWhileInRange":
		if not _type(state._charge_origin, "vec") or state._charge_left < -1:
			return _fail("Invalid weapon preparation origin or duration.")
		if state._charge_left == -1:
			if state._charge_total != 0:
				return _fail("Inactive weapon preparation has a duration.")
		elif (
			state._charge_left < 0
			or state._charge_total <= 0
			or state._charge_total > 0.75
			or state._charge_left > state._charge_total
		):
			return _fail("Invalid weapon preparation duration.")
	for field in ["_shot_limit", "_shots", "_state"]:
		if state.has(field) and not _type(state[field], "int"):
			return _fail("Invalid action counter.")
	if kind == "CollectingResourcesSequentially":
		if state._state < 0 or state._state > 5 or state._phase_left < 0 or state._phase_left > 1.2:
			return _fail("Invalid harvesting state.")
		if (
			not _type(state._kind, "int")
			or state._kind < 0
			or state._kind > 2
			or not _type(state._waiting_reason, "int")
			or state._waiting_reason < 0
			or state._waiting_reason > 4
			or not _type(state._field_origin, "vec")
			or not _position(state._field_origin)
			or state._retry_left < 0
			or state._retry_left > 0.5
			or (state._state == 4 and state._waiting_reason == 0)
			or (state._state != 4 and state._waiting_reason != 0)
			or (state._waiting_reason in [1, 2] and state._kind == 0)
		):
			return _fail("Invalid resource field assignment.")
	if (
		kind == "RecoveringAtService"
		and (
			not _type(state._last_progress, "vec")
			or state._elapsed < 0
			or state._elapsed > 0.3
			or state._stalled < 0
			or state._stalled > 5.3
			or state._retry_left < 0
			or state._retry_left > 10.0
		)
	):
		return _fail("Invalid recovery progress.")

	if kind in ["Moving", "AttackMoving", "Patrolling"]:
		if (
			state._arrival_elapsed < 0
			or state._arrival_elapsed > 2.0
			or (state._arrival_elapsed > 0 and state._arrival_progress == null)
			or (state._arrival_progress != null and not _position(state._arrival_progress))
		):
			return _fail("Invalid crowded-arrival progress.")
	if kind in ["Moving", "MovingToUnit"] and not _type(state._target_position, "vec"):
		return _fail("Missing movement destination.")
	if kind == "AttackMoving" and not _type(state.destination, "vec"):
		return _fail("Missing attack-move destination.")
	if kind == "FollowingToReachDistance" and state._distance_to_reach <= 0:
		return _fail("Invalid following distance.")
	return true


func _order(order, unit):
	if order.is_empty():
		return true
	if (
		order.get("kind")
		in ["engineering", "sweep", "repair_barrier", "dismantle", "collect_tactical"]
	):
		return _depth.order_state(order, unit)
	if order.get("kind") == "current":
		return _shape(order, "kind:text")
	if order.get("kind") in ["move", "attack_move", "patrol"]:
		var shape = "kind:text point:vec"
		for optional in [
			"formation:text",
			"group_center:vec",
			"formation_width:num",
			"cohesion_members:list",
			"waypoints:list"
		]:
			if order.has(optional.split(":")[0]):
				shape += " " + optional
		if not _shape(order, shape):
			return false
		if order.get("formation", "line") not in ["line", "box", "flank", "staggered"]:
			return _fail("Invalid order formation.")
		if (
			order.has("cohesion_members")
			and not Benchmark.valid_tactics(
				self,
				{
					"formation": order.get("formation", "line"),
					"cohesion_members": order.cohesion_members
				},
				unit
			)
		):
			return false
		if order.get("formation_width", 0.0) > 200.0 or order.get("waypoints", []).size() > 128:
			return _fail("Invalid formation route size.")
		for point in order.get("waypoints", []):
			if not _type(point, "vec") or not _position(point):
				return _fail("Invalid formation route point.")
		return true
	if (
		order.get("kind")
		not in [
			"attack",
			"force_attack",
			"repair",
			"gather",
			"scavenge",
			"construct",
			"follow",
			"approach",
			"recover",
			"garrison"
		]
	):
		return _fail("Unsupported queued order.")
	if not _shape(order, "kind:text point:vec target:text") or not _entity_reference(order.target):
		return false
	if (
		order.target.begins_with("obstacle-")
		and order.kind not in ["attack", "force_attack", "approach", "collect_tactical"]
	):
		return _fail("Unsupported order on a destructible obstacle.")
	if order.kind not in ["gather", "approach", "scavenge"] and not _unit_reference(order.target):
		return false
	if (
		order.kind == "garrison"
		and (not Catalog.is_infantry(unit.role) or not _garrison_target(order.target, unit))
	):
		return _fail("Invalid garrison order.")
	if (
		_neutral_ids.has(order.target)
		and order.kind not in ["attack", "force_attack", "approach", "garrison"]
	):
		return _fail("Unsupported order on a neutral target.")
	if (
		_poi_ids.has(order.target)
		and (
			order.kind
			not in ["recover", "repair", "approach", "garrison", "attack", "force_attack"]
		)
	):
		return _fail("Unsupported facility order.")
	var target = entities.get(order.target, {})
	if target.is_empty():
		return true
	if (
		order.kind == "scavenge"
		and (
			sides[unit.player].faction != "frontier"
			or unit.role not in ["Tank", "AntiAirVehicle", "AdvancedTank"]
			or target.get("wreck", {}).is_empty()
		)
	):
		return _fail("Invalid queued wreck scavenging.")
	if order.kind == "recover":
		var expected = (
			"Barracks"
			if Catalog.is_infantry(unit.role)
			else ("AircraftFactory" if Catalog.is_aircraft(unit.role) else "RepairDepot")
		)
		if (
			unit.role in Catalog.STRUCTURES
			or target.get("role") != expected
			or target.get("player") != unit.player
		):
			return _fail("Invalid queued recovery.")
	if (
		order.kind == "construct"
		and (
			unit.role != "Worker"
			or target.get("role") not in Catalog.STRUCTURES
			or target.get("player") != unit.player
		)
	):
		return _fail("Invalid queued construction.")
	if (
		order.kind == "repair"
		and (
			unit.role not in ["Worker", "RepairRobot"]
			or (
				target.get("player")
				not in ([unit.player, ""] if order.target in _poi_ids else [unit.player])
			)
		)
	):
		return _fail("Invalid queued repair.")
	if (
		order.kind == "gather"
		and not target.get("wreck", {}).is_empty()
		and sides[unit.player].faction != "frontier"
	):
		return _fail("Only Frontier engineers may queue salvage.")
	if (
		order.kind == "gather"
		and (
			unit.role != "Worker"
			or (
				not target.has("amount")
				and (target.get("role") != "CommandCenter" or target.get("player") != unit.player)
			)
		)
	):
		return _fail("Invalid queued harvesting.")
	return true


func _mission(value, id, map_path):
	var core = value.duplicate()
	if id != "":
		if not core.has("hero"):
			return _fail("Missing campaign hero state.")
		var hero = core.hero
		if (
			not _shape(hero, "unit:text tier:int cooldown:num")
			or hero.tier < 1
			or hero.tier > 3
			or hero.cooldown > 30
		):
			return _fail("Invalid campaign hero state.")
		var record = entities.get(hero.unit, {})
		if record.get("role") != "Hero" or record.get("player") != "player-0":
			return _fail("Campaign hero does not belong to the commander.")
		core.erase("hero")
	elif core.has("hero"):
		return _fail("Unexpected campaign hero state.")
	var narration = load("res://source/match/campaign/CampaignNarration.gd") if id != "" else null
	if id != "" and id in narration.missions():
		if not core.has("story") or not narration.valid_state(core.story, id):
			return _fail("Missing or invalid campaign conversation state.")
		core.erase("story")
	elif core.has("story"):
		return _fail("Unexpected campaign conversation state.")
	if id == "command_horizon":
		if not core.has("opposition"):
			return _fail("Missing campaign opposition state.")
		if not _opposition(core.opposition, id):
			return false
		core.erase("opposition")
	elif core.has("opposition"):
		return _fail("Unexpected campaign opposition state.")
	if core.has("points_of_interest"):
		if _site_definitions(map_path).is_empty() and not core.points_of_interest.is_empty():
			return _fail("Facilities do not belong to this map.")
		core.erase("points_of_interest")
	return _mission_rules(core, id, map_path)


# Capture relays a skirmish map carries; their state is the map's mission.
func _skirmish_relays(map_path) -> int:
	if (
		map_path
		in [
			"res://source/match/maps/AlpineRelay.tscn",
			"res://source/match/maps/IndustrialCrossroads.tscn"
		]
	):
		return 2
	if not ability_definitions.is_empty():
		return ability_definitions.get("_relays", {}).get(map_path, 0)
	return Registry.layout(map_path).get("relays", []).size()


func _site_definitions(map_path) -> Array:
	if _scenario.is_empty() and not ability_definitions.is_empty():
		return ability_definitions.get("_sites", {}).get(map_path, [])
	return (
		ScenarioDocument.site_definitions(_scenario)
		if not _scenario.is_empty()
		else Sites.definitions(map_path)
	)


func _site_records(records, map_path):
	if not records is Array:
		return _fail("Invalid facility records.")
	var sites = Sites
	var definitions = _site_definitions(map_path)
	if definitions.is_empty():
		return records.is_empty() or _fail("Unexpected captured facilities.")
	if records.size() != definitions.size():
		return _fail("Invalid facility population.")
	for index in records.size():
		var site = records[index]
		if not _shape(
			site,
			(
				"id:text hp:num owner:text candidate:text progress:num contested:bool "
				+ "income_left:num stock_a:int stock_b:int jobs:list radar_left:num radar_points:list"
			)
		):
			return false
		if (
			site.id != "poi-%d" % index
			or site.owner != "" and not sides.has(site.owner)
			or site.candidate != "" and not sides.has(site.candidate)
		):
			return _fail("Invalid facility identity or ownership.")
		if (
			site.progress >= 15.2
			or site.radar_left > 3.0
			or site.radar_points.size() > 140 * sides.size()
			or site.hp > 300
			or site.income_left > 10
			or site.stock_a > 600
			or site.stock_b > 300
			or site.jobs.size() > 3
		):
			return _fail("Invalid facility budget or clock.")
		for point in site.radar_points:
			if not _type(point, "vec") or not _position(point):
				return _fail("Invalid radar return.")
		var definition = definitions[index]
		_poi_ids[site.id] = definition.kind
		entities[site.id] = {
			"role": "RepairDepot" if definition.kind == "repair" else "PointOfInterest",
			"player": site.owner,
			"construction": 1.0,
			"position": Vector3(definition.position.x, 0, definition.position.y)
		}
		if definition.kind != "mercenary" and not site.jobs.is_empty():
			return _fail("This facility cannot recruit.")
		for job in site.jobs:
			if (
				site.owner == ""
				or not _shape(job, "role:text left:num paid_cost:dict")
				or job.role not in sites.ROLES
			):
				return _fail("Invalid mercenary contract.")
			if (
				job.paid_cost != sites.price(job.role)
				or job.left > sites.Mercenaries.UNITS[job.role].seconds
			):
				return _fail("Invalid mercenary payment or duration.")
			sides[site.owner].mobile += 1
	return true


func _opposition(value, mission):
	if not _shape(
		value,
		(
			"active:bool production_left:num admitted:int boss_started:bool boss_defeated:bool "
			+ "boss:text warning_left:signed target:list salvo_left:num reinforcements:list"
		)
	):
		return false
	if (
		value.production_left > 120
		or value.admitted > 100000
		or value.warning_left < -1
		or value.warning_left > 4
		or value.salvo_left > 14
		or value.target.size() != 3
		or value.reinforcements.size() > 4
	):
		return _fail("Invalid opposition budget or warning.")
	for coordinate in value.target:
		if not _type(coordinate, "signed"):
			return _fail("Invalid barrage point.")
	if (
		not _position(Vector3(value.target[0], value.target[1], value.target[2]))
		or absf(value.target[1]) > 1
	):
		return _fail("Barrage point outside map.")
	if value.boss != "":
		var boss = entities.get(value.boss, {})
		if (
			mission != "command_horizon"
			or boss.get("role") != "AdvancedTank"
			or boss.get("player") != "player-1"
		):
			return _fail("Invalid siege commander.")
	elif value.warning_left >= 0:
		return _fail("Barrage has no commander.")
	var unique = []
	for reference in value.reinforcements:
		var unit = entities.get(reference, {})
		if (
			reference in unique
			or unit.get("player") != "player-1"
			or unit.get("role") not in ["Infantry", "Tank"]
		):
			return _fail("Invalid reinforcement reference.")
		unique.append(reference)
	return true


func _mission_rules(value, id, map_path):
	if id != "" and Campaigns.is_story(id):
		return _hero_operation(value, id)
	if id == "command_horizon":
		return _horizon_mission(value)
	if id == "broken_foundry":
		return _foundry_mission(value)
	if id == "supply_line":
		return _convoy_mission(value)
	if id == "split_signal":
		if not _shape(
			value,
			(
				"control_seconds:num network_seconds:num command_left:num "
				+ "defence_started:bool defence_time:num waves_sent:int "
				+ "waves_warned:int network_badge:bool relays:list"
			)
		):
			return false
		if (
			value.control_seconds >= 120
			or value.network_seconds > 20
			or value.command_left > 60
			or value.waves_sent > value.waves_warned
			or value.waves_warned > 6
			or value.relays.size() != 3
			or value.network_badge != (value.network_seconds >= 20)
		):
			return _fail("Invalid Split Signal progression.")
		for relay in value.relays:
			if not _relay(relay):
				return false
		return true
	var relay_count = _skirmish_relays(map_path) if id == "" else 0
	if relay_count > 0:
		if not _shape(value, "relays:list") or value.relays.size() != relay_count:
			return _fail("Invalid skirmish relay state.")
		for relay in value.relays:
			if not _relay(relay):
				return false
		return true
	if id == "":
		return value.is_empty() or _fail("Unexpected mission state.")
	if not _shape(
		value,
		(
			"phase:int hold_seconds:num command_left:num defence_started:bool "
			+ "defence_time:num waves_sent:int waves_warned:int reuse_badge:bool "
			+ "relay:dict"
		)
	):
		return false
	if (
		value.phase > 2
		or value.hold_seconds >= 60
		or value.command_left > 60
		or value.waves_sent > value.waves_warned
		or value.waves_warned > 3
	):
		return _fail("Invalid mission progression.")
	return _relay(value.relay)


func _relay(value):
	if (
		not _shape(value, "progress:num contested:bool owner:text candidate:text")
		or value.progress > 10
		or value.owner not in ["", "player-0", "player-1"]
		or value.candidate not in ["", "player-0", "player-1"]
	):
		return _fail("Invalid relay state.")
	return true


func _fog(value):
	if value == {"available": false}:
		return true
	if (
		not _shape(value, "available:bool width:int height:int png:text")
		or not value.available
		or Vector2(value.width, value.height) != map_size * 2
	):
		return _fail("Invalid explored-map dimensions.")
	var bytes = Marshalls.base64_to_raw(value.png)
	if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return _fail("Invalid explored-map image.")
	var width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19]
	var height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23]
	if width != value.width or height != value.height:
		return _fail("Exploration image header exceeds map bounds.")
	fog_image = Image.new()
	return fog_image.load_png_from_buffer(bytes) == OK or _fail("Exploration image is damaged.")


func _identify(value, prefix):
	if not value.id.begins_with(prefix) or value.id in entities or value.id.length() > 32:
		return _fail("Invalid or duplicate entity ID.")
	entities[value.id] = value
	return true


func _entity_reference(id):
	return (
		(
			id is String
			and (
				id == ""
				or _neutral_ids.has(id)
				or _poi_ids.has(id)
				or _tactical_ids.has(id)
				or (
					(
						id.begins_with("unit-")
						or id.begins_with("resource-")
						or id.begins_with("obstacle-")
					)
					and id.length() <= 32
				)
			)
		)
		or _fail("Invalid entity reference domain.")
	)


func _unit_reference(id):
	return (
		(
			_entity_reference(id)
			and (
				id == ""
				or id.begins_with("unit-")
				or id.begins_with("obstacle-")
				or _neutral_ids.has(id)
				or _poi_ids.has(id)
				or _tactical_ids.has(id)
			)
			and (not entities.has(id) or entities[id].has("role"))
		)
		or _fail("Expected a unit reference.")
	)


func _position(point):
	return (
		point.x >= -1
		and point.z >= -1
		and point.x <= map_size.x + 1
		and point.z <= map_size.y + 1
		and absf(point.y) <= 10
	)


func _airspace_position(point):
	return (
		point.x >= -AIRSPACE_SAVE_MARGIN
		and point.z >= -AIRSPACE_SAVE_MARGIN
		and point.x <= map_size.x + AIRSPACE_SAVE_MARGIN
		and point.z <= map_size.y + AIRSPACE_SAVE_MARGIN
		and absf(point.y) <= AIRSPACE_SAVE_HEIGHT
	)


func _shape(value, specification):
	if not value is Dictionary:
		return _fail("Expected a save record.")
	var fields = specification.split(" ")
	if value.size() != fields.size():
		return _fail("Save record fields do not match this game version.")
	for field in fields:
		var parts = field.split(":")
		if not value.has(parts[0]) or not _type(value[parts[0]], parts[1]):
			return _fail("Invalid save field: " + parts[0])
	return true


func _type(value, kind):
	match kind:
		"bool":
			return value is bool
		"text":
			return value is String and value.to_utf8_buffer().size() <= 2 * 1024 * 1024
		"dict":
			return value is Dictionary
		"list":
			return value is Array
		"int":
			return value is int and value >= 0
		"signedint":
			return value is int
		"signed":
			return (value is int or value is float) and is_finite(value) and absf(value) <= 1e12
		"num":
			return _type(value, "signed") and value >= 0
		"maybenum":
			return value == null or _type(value, "num")
		"vec":
			return (
				value is Vector3
				and value.is_finite()
				and maxf(absf(value.x), maxf(absf(value.y), absf(value.z))) <= 10000
			)
		"maybevec":
			return value == null or _type(value, "vec")
		"color":
			return (
				value is Color
				and [value.r, value.g, value.b, value.a].all(
					func(n): return is_finite(n) and n >= 0 and n <= 1
				)
			)
	return false


func _fail(message):
	if error.is_empty():
		error = message
	return false


func _convoy_mission(value):
	if not _shape(value, "convoy:list responses:list resolved:list"):
		return false
	if value.convoy.size() != 3 or value.responses.size() != 3 or value.resolved.size() != 3:
		return _fail("Invalid convoy mission size.")
	var seen = []
	var delivered = 0
	for entry in value.convoy:
		if not _shape(entry, "unit:text leg:int clearance:num delivered:bool"):
			return false
		if entry.leg > 3 or entry.clearance >= 12 or entry.delivered != (entry.leg == 3):
			return _fail("Invalid convoy checkpoint state.")
		if entry.delivered:
			delivered += 1
			if entry.unit != "" or entry.clearance != 0:
				return _fail("Extracted truck remains active.")
		if entry.unit != "":
			if entry.unit in seen or not entities.has(entry.unit):
				return _fail("Invalid convoy truck reference.")
			var unit = entities[entry.unit]
			if unit.role != "SupplyTruck" or unit.player != "player-0":
				return _fail("Invalid convoy truck owner or role.")
			seen.append(entry.unit)
	for unit in entities.values():
		if unit.get("role") == "SupplyTruck" and unit.id not in seen:
			return _fail("Untracked convoy truck.")
	if delivered >= 2 or delivered + seen.size() < 2:
		return _fail("Convoy mission is already finished.")
	for index in 3:
		var time = value.responses[index]
		if not _type(time, "signed") or time < -1 or time > 10 or not value.resolved[index] is bool:
			return _fail("Invalid convoy response timer.")
		if value.resolved[index] and time != 0:
			return _fail("Invalid resolved convoy response.")
	return true


func _foundry_mission(value):
	if not _shape(
		value,
		(
			"alarm:bool hold_seconds:num command_left:num response_left:signed "
			+ "response_done:bool nodes:list relay:dict"
		)
	):
		return false
	if (
		value.nodes.size() != 2
		or value.command_left <= 0
		or value.command_left > 60
		or value.hold_seconds >= 30
	):
		return _fail("Invalid Broken Foundry progression.")
	var seen = []
	var disabled = 0
	for entry in value.nodes:
		if not _shape(entry, "unit:text disabled:bool batches:int left:num"):
			return false
		if entry.batches > 3 or entry.left > 45 or (entry.batches == 3 and entry.left != 0):
			return _fail("Invalid foundry production budget.")
		if not value.alarm and (entry.batches != 0 or (not entry.disabled and entry.left != 10)):
			return _fail("Foundry production began before the alarm.")
		if entry.disabled:
			disabled += 1
			if entry.unit != "" or entry.left != 0:
				return _fail("Disabled foundry node has production state.")
		else:
			var unit = entities.get(entry.unit, {})
			if (
				entry.unit in seen
				or unit.get("role") != "VehicleFactory"
				or unit.get("player") != "player-1"
			):
				return _fail("Invalid foundry node reference.")
			seen.append(entry.unit)
	if not _relay(value.relay):
		return false
	if disabled < 2:
		if (
			value.hold_seconds != 0
			or value.relay.owner != ""
			or value.relay.candidate != ""
			or value.relay.progress != 0
			or value.response_left != -1
			or value.response_done
		):
			return _fail("Foundry captured before production was disabled.")
	elif value.response_left < 0 or value.response_left > 10:
		return _fail("Invalid foundry response countdown.")
	if value.response_done and value.response_left != 0:
		return _fail("Resolved foundry response has a timer.")
	return true


func _horizon_mission(value):
	if not _shape(
		value,
		(
			"alternate_route:bool deployed:bool hold_seconds:num command_left:num "
			+ "command_destroyed:bool target_command:text defence_started:bool defence_time:num "
			+ "waves_sent:int waves_warned:int challenge:text relay:dict"
		)
	):
		return false
	if (
		value.command_left <= 0
		or value.command_left > 60
		or value.hold_seconds > 30
		or value.deployed != (value.hold_seconds == 30)
		or value.waves_sent > value.waves_warned
		or value.waves_warned > 4
		or value.challenge not in ["", "lean", "reinforced"]
	):
		return _fail("Invalid Command Horizon progression.")
	if (
		not value.defence_started
		and (
			value.defence_time != 0
			or value.waves_sent != 0
			or value.waves_warned != 0
			or value.hold_seconds != 0
			or value.deployed
		)
	):
		return _fail("Deployment defence started before capture.")
	if value.command_destroyed:
		if value.target_command != "":
			return _fail("Destroyed command still has a unit reference.")
	else:
		var unit = entities.get(value.target_command, {})
		if unit.get("role") != "CommandCenter" or unit.get("player") != "player-1":
			return _fail("Invalid finale command reference.")
	if not _relay(value.relay):
		return false
	if (
		value.deployed
		and value.command_destroyed
		and value.relay.owner == "player-0"
		and not value.relay.contested
	):
		var point = load("res://source/match/maps/CommandHorizonMap.gd").DEPLOYMENT
		if entities.values().any(
			func(unit):
				return (
					Catalog.is_infantry(unit.get("role"))
					and unit.get("player") == "player-0"
					and (unit.position * Vector3(1, 0, 1)).distance_to(point) <= 3
				)
		):
			return _fail("Command Horizon has already finished.")
	return true


func _ambient(saved, map_path):
	var entries = AmbientCatalog.entries(map_path)
	if saved.size() != entries.size():
		return _fail("Invalid neutral population.")
	var seen = {}
	for record in saved:
		if not _shape(
			record, "id:text travel:num stop_left:num phase:num walking:bool combat:dict"
		):
			return false
		var matches = entries.filter(func(entry): return entry.id == record.id)
		if matches.size() != 1 or seen.has(record.id):
			return _fail("Invalid neutral identity.")
		seen[record.id] = true
		if not _neutral_combat(record.combat, AmbientCatalog.STATS[matches[0].kind].health):
			return false
		_neutral_ids["neutral-" + record.id] = false
		if record.travel >= matches[0].length or record.stop_left > 2.5 or record.phase >= TAU:
			return _fail("Invalid neutral motion.")
	return true


func _neutral_combat(value, maximum):
	return (
		_shape(value, "hp:num death_age:num panic_left:num hit_left:num")
		and value.hp <= maximum
		and value.death_age <= 30
		and value.panic_left <= 7
		and value.hit_left <= .3
		and (value.hp == 0 or value.death_age == 0)
	)


func _neutral_buildings(saved, map_path):
	var catalog = AmbientCatalog
	var assets = catalog.structures(map_path)
	if saved.size() != assets.size():
		return _fail("Invalid neutral building population.")
	var assigned = []
	for index in saved.size():
		var record = saved[index]
		if not _shape(
			record,
			"id:text combat:dict occupants:list slots:list owner:text entry_points:list evacuating:list"
		):
			return false
		if (
			record.id != "neutral-building-%d" % index
			or not _neutral_combat(record.combat, catalog.BUILDING_HEALTH)
		):
			return _fail("Invalid neutral building state.")
		_neutral_ids[record.id] = assets[index] in catalog.HABITABLE
		if assets[index] not in catalog.HABITABLE and not record.occupants.is_empty():
			return _fail("This neutral structure cannot house infantry.")
		if (
			record.occupants.size() > Catalog.GARRISON_CAPACITY
			or (record.combat.hp == 0 and not record.occupants.is_empty())
		):
			return _fail("Invalid garrison capacity.")
		if not _depth.evacuation_state(record):
			return false
		if record.slots.size() != record.occupants.size():
			return _fail("Missing garrison slot.")
		var slots = []
		for slot in record.slots:
			if (
				not _type(slot, "int")
				or slot < 0
				or slot >= Catalog.GARRISON_CAPACITY
				or slot in slots
			):
				return _fail("Invalid garrison slot.")
			slots.append(slot)
		var owner = record.owner
		if (
			owner != ""
			and (not sides.has(owner) or record.combat.hp == 0 or not _neutral_ids[record.id])
		):
			return _fail("Invalid neutral building owner.")
		if owner == "" and not record.occupants.is_empty():
			return _fail("Garrison has no owner.")
		for id in record.occupants:
			if not id is String or not entities.has(id) or id in assigned:
				return _fail("Invalid garrison occupant.")
			var unit = entities[id]
			if (
				not Catalog.is_infantry(unit.get("role"))
				or (owner != "" and owner != unit.player)
				or (
					id not in record.evacuating
					and (
						unit.action.get("kind") != "Garrisoning"
						or not unit.action.get("references", {}) is Dictionary
						or unit.action.get("references", {}).get("_target_unit") != record.id
					)
				)
			):
				return _fail("Invalid garrison ownership or action.")
			owner = unit.player
			assigned.append(id)
	return true


func _garrison_target(id, unit) -> bool:
	if _neutral_ids.get(id, false) or _poi_ids.has(id):
		return true
	var target = entities.get(id, {})
	if target.get("role") == "FieldBunker":
		return target.get("player") == unit.player
	return (
		target.get("role") == "AdvancedTank"
		and target.get("player") == unit.player
		and sides[unit.player].faction == "frontier"
	)


func _mobile_garrisons(units, buildings, engineering) -> bool:
	var assigned = []
	for building in buildings:
		assigned.append_array(building.occupants)
	var hosts = units.duplicate()
	for entry in engineering:
		if entry.kind == "bunker":
			hosts.append(
				{
					"id": entry.id,
					"player": entry.owner,
					"role": "FieldBunker",
					"garrison_mount": entry.garrison
				}
			)
	for host in hosts:
		if not host.has("garrison_mount"):
			continue
		var mount = host.garrison_mount
		var bunker = host.role == "FieldBunker"
		var capacity = 6 if bunker else 4
		if (
			(host.role != "AdvancedTank" and not bunker)
			or sides[host.player].faction != ("bastion" if bunker else "frontier")
			or not _shape(mount, "occupants:list slots:list evacuating:list")
			or mount.occupants.size() > capacity
			or mount.slots.size() != mount.occupants.size()
		):
			return _fail("Invalid mobile garrison capacity or host.")
		var slots = []
		for slot in mount.slots:
			if not _type(slot, "int") or slot >= capacity or slot in slots:
				return _fail("Invalid mobile garrison slot.")
			slots.append(slot)
		var evacuating = []
		for id in mount.evacuating:
			if not id is String or id not in mount.occupants or id in evacuating:
				return _fail("Invalid mobile garrison evacuation.")
			evacuating.append(id)
		for id in mount.occupants:
			if not id is String or not entities.has(id) or id in assigned:
				return _fail("Invalid mobile garrison occupant.")
			var passenger = entities[id]
			if (
				not Catalog.is_infantry(passenger.get("role"))
				or passenger.player != host.player
				or passenger.regarrison_lock_left > 0.0
				or not passenger.action is Dictionary
				or (
					id not in evacuating
					and (
						passenger.action.get("kind") != "Garrisoning"
						or not passenger.action.get("references", {}) is Dictionary
						or passenger.action.references.get("_target_unit") != host.id
					)
				)
			):
				return _fail("Invalid mobile garrison passenger ownership or action.")
			assigned.append(id)
	return true


func _hero_operation(value, id):
	if not _shape(
		value, "stage:int elapsed:num wave_left:num waves:int targets:list escort:text relays:list"
	):
		return false
	var objectives = Campaigns.stories()[id].objectives
	if (
		value.stage >= objectives.size()
		or value.elapsed > 120
		or value.wave_left > 40
		or value.waves > 4
		or value.targets.size() != objectives.size()
		or value.relays.size() != objectives.size()
	):
		return _fail("Invalid hero operation progression.")
	var objective = objectives[value.stage]
	if value.elapsed > (objective.seconds if objective.kind == "hold" else 0):
		return _fail("Invalid objective hold time.")
	if objective.kind == "escort" and value.escort == "":
		return _fail("Active story convoy is missing.")
	var assigned_targets = []
	for index in value.targets.size():
		var ref = value.targets[index]
		if ref != "":
			if ref in assigned_targets:
				return _fail("Duplicate operation target.")
			assigned_targets.append(ref)
			var target = entities.get(ref, {})
			if (
				objectives[index].kind != "destroy"
				or target.get("player") != "player-1"
				or target.get("role") != objectives[index].role
			):
				return _fail("Invalid operation target.")
		if not _relay(value.relays[index]):
			return false
	if value.escort != "":
		var escort = entities.get(value.escort, {})
		if escort.get("player") != "player-0" or escort.get("role") != "SupplyTruck":
			return _fail("Invalid story convoy.")
	return true


# Authored battlefields version their layouts; every other map is revision 1.
static func _map_revision(map_path):
	return Registry.revision(map_path)


func _obstacles(records):
	if records.size() > 1024:
		return _fail("Too many destructible obstacles.")
	for record in records:
		if (
			not _shape(
				record,
				(
					"id:text role:text position:vec rotation:vec hp:num hp_max:num "
					+ "radius:num obstacle_height:num light_barricade:bool"
					+ (
						" ruin:dict"
						if record is Dictionary and record.get("role") == "StructureRuin"
						else ""
					)
				)
			)
			or not _identify(record, "obstacle-")
			or record.role not in ["DestructibleObstacle", "StructureRuin"]
			or not _position(record.position)
			or record.hp_max <= 0.0
			or record.hp_max > 10000.0
			or record.hp > record.hp_max
			or record.radius <= 0.0
			or record.radius > 20.0
			or record.obstacle_height <= 0.0
			or record.obstacle_height > 20.0
		):
			return _fail("Invalid destructible obstacle.")
		if record.role == "StructureRuin":
			if (
				not _shape(
					record.ruin, "source_role:text source_faction:text materials:int age:num"
				)
				or record.ruin.source_role not in Catalog.STRUCTURES
				or record.ruin.source_faction not in Factions.IDS
				or record.ruin.materials > 1000
				or record.ruin.age > 86400.0
				or record.hp_max != 80.0
				or record.obstacle_height != .8
				or not record.light_barricade
			):
				return _fail("Invalid structural ruin.")
	return true
