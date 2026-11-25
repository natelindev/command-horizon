extends RefCounted

const Cache = preload("res://source/utils/RuntimeCache.gd")
const ROSTERS = {
	"bastion": preload("res://source/match/factions/bastion.tres"),
	"helix": preload("res://source/match/factions/helix.tres"),
	"frontier": preload("res://source/match/factions/frontier.tres")
}
const Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")
const Bastion = preload("res://source/match/BastionCatalog.gd")
const Frontier = preload("res://source/match/FrontierCatalog.gd")
const FrontierSurfaces = preload("res://source/match/FrontierMaterials.gd")
const SurfaceTextures = preload("res://source/match/SurfaceTextures.gd")
const ObjectMaterials = preload("res://source/match/ObjectMaterials.gd")
# Loaded at runtime: the airfield builder reads this catalog.
const RUNWAY_AIRFIELD = "res://source/match/units/structure-geometries/RunwayAirfield.gd"
const Rules = preload("res://source/match/FactionRules.gd")
const IDS = Rules.IDS
const NAMES = Rules.NAMES
const BASTION_MODELS = {
	"Worker": "demo/Worker",
	"Tank": "demo/Tank",
	"RepairRobot": "demo/RepairRobot",
	"CombatRobot": "demo/BulwarkWalker",
	"AdvancedTank": "demo/SiegeColossus",
	"AntiAirVehicle": "demo/FlakHalftrack",
	"Drone": "demo/Drone",
	"Helicopter": "air-v1/Helicopter",
	"Fighter": "air-v1/Fighter",
	"Bomber": "air-v1/Bomber",
}
const HELIX_MODELS = {
	"Worker": "MuleEngineer",
	"Infantry": "VectorOperator",
	"Tank": "NeedleSkimmer",
	"RepairRobot": "MenderRobot",
	"CombatRobot": "PhaseLancer",
	"AdvancedTank": "PrismSkimmer",
	"Drone": "KiteScout",
	"Helicopter": "WraithTiltrotor",
	"Fighter": "TalonInterceptor",
	"Bomber": "ShrikeBomber",
	"AntiAirVehicle": "SkywardInterceptor",
	"CommandCenter": "NexusHQ",
	"Barracks": "OperatorHub",
	"VehicleFactory": "RoboticsFoundry",
	"AircraftFactory": "FlightDeck",
	"PowerPlant": "FluxGenerator",
	"CommandLab": "SignalLab",
	"RepairDepot": "ServiceCradle",
	"AntiGroundTurret": "LanceSentry",
	"AntiAirTurret": "SkywardArray",
}
const HELIX_NAMES = {
	"Worker": "Flux Skimmer",
	"Infantry": "Vector operator",
	"AssaultInfantry": "Arc shocktrooper",
	"RocketInfantry": "Ion specialist",
	"SniperInfantry": "Phase infiltrator",
	"Tank": "Needle skimmer",
	"RepairRobot": "Mender robot",
	"CombatRobot": "Phase Lancer",
	"AdvancedTank": "Prism Skimmer",
	"Drone": "Kite drone",
	"Helicopter": "Wraith gunship",
	"Fighter": "Talon interceptor",
	"Bomber": "Shrike bomber",
	"AntiAirVehicle": "Skyward Interceptor",
	"CommandCenter": "Nexus HQ",
	"Barracks": "Operator hub",
	"VehicleFactory": "Robotics foundry",
	"AircraftFactory": "Flight deck",
	"PowerPlant": "Flux generator",
	"CommandLab": "Signal lab",
	"RepairDepot": "Service cradle",
	"AntiGroundTurret": "Prism emitter pylon",
	"AntiAirTurret": "Skyward array",
}
const HELIX_DESCRIPTIONS = {
	"AntiGroundTurret":
	(
		"Focused prism beam against ground targets. Links with nearby allied prism pylons "
		+ "and skimmers to amplify damage. Uses 2 power."
	),
	"Worker":
	(
		"Unarmed Flux Skimmer: hover across rough ground and gather electronics 25% faster. "
		+ "Reach a foundation to deploy a nanite beacon, then return to gathering "
		+ "while the building assembles itself."
	),
	"Infantry":
	(
		"Fast cybernetic operator with rapid plasma carbine. High mobility makes it "
		+ "ideal for capturing relays and flanking."
	),
	"AssaultInfantry":
	(
		"High-energy shocktrooper armed with twin pulse repeaters. Relentless "
		+ "close-quarters energy fire and rapid sprint."
	),
	"RocketInfantry":
	(
		"Energy disruptor soldier firing guided ion torpedoes to penetrate vehicle "
		+ "armor and overload electronics."
	),
	"SniperInfantry":
	(
		"Long-range thermal beam infiltrator. Stationary and not firing for 3 s enables "
		+ "optic camouflage; nearby enemies within 3 m and target flares reveal it."
	),
	"Tank":
	(
		"High-speed repulsor hover skimmer armed with rapid twin pulse lasers. "
		+ "Uses superior mobility to flank and outrange heavy armor."
	),
	"CombatRobot":
	(
		"Phase Shift teleports 8 m in a chosen direction every 15 seconds. "
		+ "Precision: 12 m anti-armor lance, 0.75 s charge; weak against infantry. "
		+ "Interception: full air damage, 33% ground damage. "
		+ "Switching disables fire for 2 s."
	),
	"AdvancedTank":
	(
		"Mobile coherent beam skimmer. Its continuous laser refracts through up to two "
		+ "adjacent enemies; nearby allied prisms link to amplify focused damage."
	),
	"Drone":
	(
		"Unarmed electronic-warfare scout. Chaff disrupts hostile missile guidance "
		+ "around allied units for 8 s. Requires a Signal lab; 30 s cooldown."
	),
	"Helicopter":
	(
		"Attack helicopter. Rockets against ground forces while hovering in place; reloads on "
		+ "cooldown in the field. Vulnerable to rocket infantry and anti-air."
	),
	"CommandCenter": "Produces Flux Skimmers, receives harvested resources and supplies 8 power.",
	"Barracks":
	(
		"Trains four infantry classes and a unique hero. Two infantry recovery "
		+ "slots within 5 m. Uses 3 power."
	),
	"CommandLab":
	(
		"With a robotics foundry, unlocks Lancers and Wraiths. Research "
		+ "Coordination for Prism Skimmers. Uses 5 power."
	),
}
const UNIT_COSTS = Rules.UNIT_COSTS
const HELIX_COSTS = Rules.HELIX_COSTS
const BUILD_COSTS = {
	"ForwardRefinery": [35, 10],
	"CommandCenter": [80, 20],
	"Barracks": [20, 0],
	"VehicleFactory": [45, 12],
	"AircraftFactory": [45, 20],
	"PowerPlant": [15, 0],
	"CommandLab": [50, 30],
	"RepairDepot": [25, 10],
	"AntiGroundTurret": [20, 8],
	"AntiAirTurret": [20, 12],
}
# Seconds at full power. Keep early reinforcements responsive while preserving
# the extra commitment for heavy units, heroes and additional technology.
const BUILD_TIMES = {
	"ForwardRefinery": 18.0,
	"CommandCenter": 35.0,
	"Barracks": 14.0,
	"VehicleFactory": 24.0,
	"AircraftFactory": 26.0,
	"PowerPlant": 12.0,
	"CommandLab": 28.0,
	"RepairDepot": 18.0,
	"AntiGroundTurret": 14.0,
	"AntiAirTurret": 16.0,
}
const FRONTIER_BUILD_COSTS = {
	"CommandCenter": [65, 15],
	"Barracks": [16, 0],
	"VehicleFactory": [35, 8],
	"PowerPlant": [12, 0],
	"CommandLab": [38, 20],
	"RepairDepot": [20, 6],
	"AntiGroundTurret": [16, 5],
	"AntiAirTurret": [16, 8],
}
const UNIT_TIMES = {
	"Hero": 30.0,
	"AssaultInfantry": 8.0,
	"SniperInfantry": 11.0,
	"RocketInfantry": 10.0,
	"Worker": 6.0,
	"Infantry": 5.0,
	"Tank": 14.0,
	"RepairRobot": 12.0,
	"CombatRobot": 18.0,
	"AdvancedTank": 24.0,
	"Drone": 8.0,
	"Helicopter": 20.0,
	"Fighter": 18.0,
	"Bomber": 26.0,
	"AntiAirVehicle": 14.0,
}
const SPECIALIST_TIMES = {
	"bastion": {"AdvancedTank": 22.0, "AssaultInfantry": 7.0},
	"helix": {"Drone": 6.0, "CombatRobot": 16.0, "Helicopter": 18.0},
	"frontier": {"Worker": 5.0, "Tank": 12.0, "RepairRobot": 10.0, "AdvancedTank": 26.0},
}
const UNIT_REQUIRES = {
	"bastion": {"CombatRobot": "RepairDepot"},
	"helix": {},
	"frontier": {"CombatRobot": "", "AdvancedTank": "RepairDepot"},
}
const TECH_SUMMARY = {
	"bastion":
	(
		"Structures have 25% more health and resist 15% of ballistic gun and rocket damage. "
		+ "Repair depots maintain nearby armor within 5 m for free. Depots unlock Sentinels; "
		+ "Coordination unlocks siege armor. Anchor sectors reward holding ground."
	),
	"helix":
	(
		"Build a flight deck after an operator hub. Signal labs unlock "
		+ "Phase Lancers and Wraiths; Coordination unlocks mobile "
		+ "Prism Skimmers."
	),
	"frontier":
	(
		"Motor pools unlock demolition buggies; field workshops unlock Battle Rigs without "
		+ "Coordination. Scrapper rigs recover tank wrecks; Maneuver Burst "
		+ "enables fast raids."
	),
}
const BUILD_REQUIRES = {
	"ForwardRefinery": "",
	"VehicleFactory": "Barracks",
	"AircraftFactory": "VehicleFactory",
	"CommandLab": "VehicleFactory",
	"RepairDepot": "VehicleFactory",
	"AntiGroundTurret": "Barracks",
	"AntiAirTurret": "VehicleFactory",
}


static func roster(faction: String):
	return ROSTERS.get(faction, ROSTERS.bastion)


static func scene_path(faction: String, role: String) -> String:
	return roster(faction).scene_for(role)


static func batch_size(faction: String, role: String) -> int:
	return roster(faction).batch_size(role)


static func production_options(faction: String, producer_role: String) -> Array:
	return (
		roster(faction)
		. production
		. get(producer_role, Bastion.PRODUCES.get(producer_role, []))
		. duplicate()
	)


static func base_health(faction: String, role: String) -> float:
	var authored = roster(faction).statistics.get(role, {})
	if authored.has("hp_max"):
		return authored.hp_max
	var properties = load("res://source/match/MatchConstants.gd").Units.DEFAULT_PROPERTIES
	var base = properties.get(Bastion.scene_path(role), {}).get("hp_max", 0.0)
	if role in Bastion.STRUCTURES:
		return roundf(base * 1.25) if faction == "bastion" else base
	return roundf(base * health_factor(faction, role))


static func production_cost(player, role: String) -> Dictionary:
	var price = cost(player, role).duplicate()
	var count = batch_size(player.faction, role) if player.get_meta("skirmish", false) else 1
	price.resource_a *= count
	price.resource_b *= count
	return price


static func power_usage(faction: String, role: String) -> int:
	var demand = Bastion.POWER_USAGE.get(role, 0)
	return maxi(1, ceili(demand * 0.5)) if faction == "frontier" and demand > 0 else demand


static func power_supply(_faction: String, role: String) -> int:
	return Bastion.POWER_SUPPLY.get(role, 0)


static func title(faction, role):
	if role in Mercenaries.ROLES:
		return Mercenaries.UNITS[role].title
	if role == "Hero":
		return (
			{"bastion": "Marshal Aegis", "helix": "Spectre Nyx", "frontier": "Pathfinder Rook"}
			. get(faction, "Marshal Aegis")
		)
	if role in Bastion.MISSION_NAMES:
		return Bastion.MISSION_NAMES[role]
	if faction == "frontier" and Frontier.NAMES.has(role):
		return Frontier.NAMES[role]
	if faction == "helix" and HELIX_NAMES.has(role):
		return HELIX_NAMES[role]
	return Bastion.NAMES.get(role, role)


static func icon(faction, role):
	if role in Mercenaries.ROLES:
		return "res://assets/ui/mercenaries/%s.png" % role
	if role in Bastion.INFANTRY_ROLES:
		return "res://assets/ui/infantry/%s/%s.png" % [faction, role]
	if faction == "frontier":
		return "res://assets/ui/frontier/%s.png" % Frontier.MODELS[role]
	return (
		"res://assets/ui/helix/%s.png" % HELIX_MODELS[role]
		if faction == "helix"
		else Bastion.icon_path(role)
	)


static func selection_portrait(faction, role) -> Texture2D:
	# Selection cards are tall and narrow. Trim the transparent square canvas so
	# a standing soldier can use their height, without changing shared art files.
	var selection_portraits = Cache.bucket("selection_portraits")
	var key = faction + ":" + role
	if selection_portraits.has(key):
		return selection_portraits[key]
	var texture = portrait(faction, role)
	if texture == null:
		return null
	var image = texture.get_image()
	var region = Rect2(image.get_used_rect()).grow(3).intersection(
		Rect2(Vector2.ZERO, image.get_size())
	)
	var framed = AtlasTexture.new()
	framed.atlas = texture
	framed.region = region
	selection_portraits[key] = framed
	return framed


static func portrait(faction, role) -> Texture2D:
	if role == "Hero":
		return load("res://source/main-menu/ArtworkCatalog.gd").commander(faction)
	if role in Mercenaries.ROLES:
		return load(icon(faction, role))
	# Pre-rendered model portraits, shared by the selection bay, rosters and queues.
	# A role without a faction portrait borrows the Bastion plate; otherwise none.
	var paths = [Bastion.icon_path(role)]
	if (
		role in Bastion.INFANTRY_ROLES
		or (faction == "frontier" and Frontier.MODELS.has(role))
		or (faction == "helix" and HELIX_MODELS.has(role))
	):
		paths.push_front(icon(faction, role))
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)
	return null


static func description(faction, role):
	var text = _description(faction, role)
	if faction == "bastion" and role in Bastion.STRUCTURES:
		return (
			TranslationServer.translate(text)
			+ "\n"
			+ (TranslationServer.translate(
				(
					"Bastion bulkheads: +25% structure health and 15% less damage from "
					+ "ballistic guns and rockets. Energy weapons ignore this protection."
				)
			))
		)
	return text


static func _description(faction, role):
	if role in Mercenaries.ROLES:
		return Mercenaries.UNITS[role].description
	if role == "Hero":
		return {
			"bastion":
			(
				"Marshal Aegis: armored frontline hero with a rapid heavy rifle. "
				+ "One alive or training; retrain after death. Requires a command lab."
			),
			"helix":
			(
				"Spectre Nyx: mobile precision hero with a long-range anti-armor "
				+ "lance. One alive or training; retrain after death. Requires a command lab."
			),
			"frontier":
			(
				"Pathfinder Rook: fast assault hero with a heavy automatic rifle. "
				+ "One alive or training; retrain after death. Requires a command lab."
			)
		}[faction]
	if faction == "frontier" and Frontier.DESCRIPTIONS.has(role):
		return Frontier.DESCRIPTIONS[role]
	if faction == "bastion" and role == "RepairDepot":
		return (
			"Automatically repairs one adjacent ground vehicle within 5 m at no resource cost. "
			+ "Extra service slot with Siege Logistics. Repairs do not stack. Uses 3 power."
		)
	if faction == "bastion" and role == "CommandLab":
		return (
			"Unlocks heroes. Research Coordination for siege tanks "
			+ "and Anchor sectors. Sentinels require a repair depot. Uses 5 power."
		)
	if role == "RepairRobot":
		return (
			"Repairs one mechanical ground ally or completed building at a time, at no resource cost. "
			+ "3 m reach, measured from a building's edge."
		)
	if faction == "helix" and HELIX_DESCRIPTIONS.has(role):
		return HELIX_DESCRIPTIONS[role]
	return Bastion.DESCRIPTIONS.get(role, "")


static func cost(player, role, building = false):
	if role in Mercenaries.ROLES:
		var price = Mercenaries.UNITS[role].cost
		return {"resource_a": price[0], "resource_b": price[1]}
	if not player.get_meta("skirmish", false):
		var values = (
			Constants.Match.Units.CONSTRUCTION_COSTS
			if building
			else Constants.Match.Units.PRODUCTION_COSTS
		)
		return values[Bastion.scene_path(role)]
	var values = (
		(
			FRONTIER_BUILD_COSTS
			if player.faction == "frontier" and FRONTIER_BUILD_COSTS.has(role)
			else BUILD_COSTS
		)
		if building
		else Rules.unit_costs(player.faction)
	)
	return {"resource_a": values[role][0], "resource_b": values[role][1]}


static func air_contract_roles(faction: String) -> Array:
	return ["Helicopter", "Fighter", "Bomber"] if faction == "frontier" else []


static func duration(player, role):
	if role in Mercenaries.ROLES:
		return Mercenaries.UNITS[role].seconds
	var base = (
		SPECIALIST_TIMES.get(player.faction, {}).get(role, UNIT_TIMES[role])
		if player.get_meta("skirmish", false)
		else Constants.Match.Units.PRODUCTION_TIMES[Bastion.scene_path(role)]
	)
	if (
		"technology" in player
		and player.technology != null
		and "siege_logistics" in player.technology.completed
		and role in ["Tank", "AdvancedTank", "CombatRobot"]
	):
		base *= 0.85
	return base


static func requirement(player, role, building = false):
	if building:
		if (
			player.get_meta("skirmish", false)
			and player.faction == "helix"
			and role == "AircraftFactory"
		):
			return "Barracks"
		return BUILD_REQUIRES.get(role, "") if player.get_meta("skirmish", false) else ""
	if player.get_meta("skirmish", false) and UNIT_REQUIRES.get(player.faction, {}).has(role):
		return UNIT_REQUIRES[player.faction][role]
	if role in ["Helicopter", "Fighter", "Bomber"] and player.get_meta("skirmish", false):
		return "CommandLab"
	return Bastion.REQUIRES.get(role, "")


static func requires_coordination(player, role):
	return (
		role == "AdvancedTank"
		and player.get_meta("skirmish", false)
		and player.faction != "frontier"
	)


static func hero_reserved(player, ignore_job = null):
	for unit in player.get_children():
		if not "type" in unit or unit.is_queued_for_deletion() or unit.hp == null or unit.hp <= 0:
			continue
		if unit.type == "Hero":
			return true
		var queue = unit.get_node_or_null("ProductionQueue")
		if queue != null:
			for job in queue.get_elements():
				if (
					job != ignore_job
					and Bastion.type_from_path(job.unit_prototype.resource_path) == "Hero"
				):
					return true
	return false


static func available(player, role, building = false, ignore_job = null):
	if not roster(player.faction).allows(role, building):
		return false
	if role == "ForwardRefinery" and player.faction != "bastion":
		return false
	if role == "Hero" and hero_reserved(player, ignore_job):
		return false
	if (
		building
		and player.get_meta("skirmish", false)
		and player.structure_count() >= Bastion.STRUCTURE_LIMIT
	):
		return false
	if not building and requires_coordination(player, role):
		if not player.coordination_unlocked:
			return false
	var required = requirement(player, role, building)
	return required == "" or player.has_completed_structure(required)


static func prepare_model(unit, faction):
	var geometry = unit.get_node("Geometry")
	if unit.type == "AircraftFactory":
		# The runway airfield is composed for its faction, not swapped and rescaled.
		for child in geometry.get_children():
			child.free()
		load(RUNWAY_AIRFIELD).build(geometry, faction)
		if "faction" in geometry:
			geometry.faction = faction
		unit.set_meta("model_faction", faction)
		SurfaceTextures.apply_armor(geometry)
		ObjectMaterials.apply(geometry)
		return
	if Bastion.is_infantry(unit.type):
		for child in geometry.get_children():
			child.free()
		geometry.add_child(
			load("res://source/match/units/traits/InfantryModel.gd").build(faction, unit.type)
		)
		unit.set_meta("model_faction", faction)
	elif (
		(faction == "bastion" and BASTION_MODELS.has(unit.type))
		or (faction == "helix" and HELIX_MODELS.has(unit.type))
		or (faction == "frontier" and Frontier.MODELS.has(unit.type))
	):
		for child in geometry.get_children():
			child.free()
		geometry.add_child(model_geometry(faction, unit.type, unit.radius))
		unit.set_meta("model_faction", faction)
	if Bastion.is_infantry(unit.type):
		load("res://source/match/units/traits/InfantryEquipment.gd").equip(unit, faction)
	SurfaceTextures.apply_armor(geometry)
	ObjectMaterials.apply(geometry)
	if Bastion.is_infantry(unit.type):
		load("res://source/match/units/traits/InfantryMeshBatch.gd").apply(
			geometry.get_node("InfantryRig")
		)


static func helix_geometry(role, radius):
	return model_geometry("helix", role, radius)


static func model_geometry(faction, role, radius):
	if role == "AircraftFactory":
		return load(RUNWAY_AIRFIELD).create(faction)
	var models = Frontier.MODELS if faction == "frontier" else HELIX_MODELS
	if faction == "bastion":
		if not BASTION_MODELS.has(role):
			return null
	elif not models.has(role):
		return null
	var path = (
		"res://assets/models/bastion/%s.glb" % BASTION_MODELS[role]
		if faction == "bastion"
		else "res://assets/models/%s/v1/%s.glb" % [faction, models[role]]
	)
	var model = load(path).instantiate()
	if faction == "frontier":
		FrontierSurfaces.apply(model)
	else:
		SurfaceTextures.apply_armor(model)
	var bounds = _bounds(model, Transform3D.IDENTITY)
	var factor = radius * 1.85 / maxf(.001, maxf(bounds.size.x, bounds.size.z))
	if role == "Infantry":
		factor = 1.15 / bounds.size.y
	elif Bastion.is_aircraft(role):
		factor *= 1.35
	if faction == "frontier" and role == "AdvancedTank":
		factor *= 1.1
	model.scale = Vector3.ONE * factor
	model.position = (
		-Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	)
	return model


static func _bounds(node, parent_transform):
	var transform_here = parent_transform * node.transform if node is Node3D else parent_transform
	var result = (
		transform_here * node.get_aabb() if node is MeshInstance3D and node.mesh != null else AABB()
	)
	for child in node.get_children():
		var child_bounds = _bounds(child, transform_here)
		if child_bounds.size != Vector3.ZERO:
			result = child_bounds if result.size == Vector3.ZERO else result.merge(child_bounds)
	return result


static func health_factor(faction, role = ""):
	return Rules.health_factor(faction, role)


static func signature_title(faction):
	return Rules.signature_title(faction)


static func signature_cooldown(faction):
	return Rules.signature_cooldown(faction)


static func apply_stats(unit):
	if unit.type in Mercenaries.ROLES:
		unit.get_node("Movement").speed *= {
			"MercenaryWarden": .78, "MercenaryRanger": 1.16, "MercenaryLancer": .84
		}[unit.type]
	if unit.type == "RocketInfantry":
		unit.get_node("Movement").speed *= .82
	elif unit.type == "SniperInfantry":
		unit.get_node("Movement").speed *= .9
	elif unit.type == "Hero":
		match unit.player.faction:
			"helix":
				unit.attack_damage = 15
				unit.attack_interval = 1.5
				unit.attack_range = 13.0
				unit.sight_range = 14.0
			"frontier":
				unit.attack_damage = 7
				unit.attack_interval = .45
				unit.attack_range = 8.0
	if unit.player.faction == "frontier" and unit.movement_speed > 0:
		unit.hp_max = roundi(unit.hp_max * health_factor("frontier", unit.type))
		unit.hp = unit.hp_max
		if unit.attack_damage != null:
			unit.attack_damage *= Rules.damage_factor("frontier", unit.type)
		if Bastion.is_infantry(unit.type):
			unit.get_node("Movement").speed *= 1.2
		elif not Bastion.is_aircraft(unit.type):
			unit.get_node("Movement").speed *= 1.1
		if unit.type == "Tank":
			unit.attack_interval = 0.85
		elif unit.type == "AdvancedTank":
			unit.attack_interval = 2.2
		elif unit.type == "Infantry":
			unit.attack_interval = 0.65
		elif unit.type == "AssaultInfantry":
			unit.attack_interval = 0.48
		elif unit.type == "SniperInfantry":
			unit.attack_interval = 2.0
			unit.sight_range = 14.5
	if unit.player.faction == "helix" and unit.movement_speed > 0:
		unit.hp_max = roundi(unit.hp_max * health_factor("helix", unit.type))
		unit.hp = unit.hp_max
		unit.get_node("Movement").speed *= 1.2
		if unit.type in ["Drone", "Tank"]:
			unit.sight_range += 2.0
		if unit.type == "Drone":
			unit.attack_damage = null
			unit.attack_range = null
			unit.attack_interval = null
			unit.attack_domains = []
		if unit.type == "Tank":
			unit.attack_damage = 6
			unit.attack_interval = 0.65
		if unit.type == "AdvancedTank":
			unit.attack_range = 14.0
			unit.sight_range = 15.0
			unit.get_node("Movement").speed *= 0.75
		if unit.type == "Infantry":
			unit.attack_interval = 0.55
		elif unit.type == "AssaultInfantry":
			unit.attack_damage = 3.5
			unit.attack_interval = 0.38
		elif unit.type == "RocketInfantry":
			unit.attack_damage = 13
			unit.attack_interval = 2.1
		elif unit.type == "SniperInfantry":
			unit.attack_damage = 15
			unit.attack_interval = 2.3
			unit.attack_range = 13.5
			unit.sight_range = 15.0
	if unit.type == "AntiAirVehicle":
		match unit.player.faction:
			"helix":
				unit.attack_damage = 15
				unit.attack_interval = 1.4
				unit.attack_range = 12.0
			"frontier":
				unit.attack_damage = 4
				unit.attack_interval = 0.18
				unit.attack_range = 10.0
	if unit.type == "CombatRobot":
		unit.configure_weapon()
	# Authored absolute statistics replace mirrored multiplier identities for
	# signature roles; canonical role IDs remain stable for orders and saves.
	var authored = roster(unit.player.faction).statistics.get(unit.type, {})
	for property in authored:
		if property == "speed":
			unit.get_node("Movement").speed = authored[property]
		else:
			unit.set(property, authored[property])
	if authored.has("hp_max"):
		unit.hp = unit.hp_max
	if unit.player.faction == "bastion" and unit.movement_speed == 0 and unit.hp_max != null:
		unit.hp_max = roundi(unit.hp_max * 1.25)
		unit.hp = unit.hp_max
