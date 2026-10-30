extends RefCounted

const Cache = preload("res://source/utils/RuntimeCache.gd")
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
const HELIX_MODELS = {
	"Worker": "MuleEngineer",
	"Infantry": "VectorOperator",
	"Tank": "NeedleSkimmer",
	"RepairRobot": "MenderRobot",
	"CombatRobot": "LancerWalker",
	"AdvancedTank": "PrismArtillery",
	"Drone": "KiteScout",
	"Helicopter": "WraithTiltrotor",
	"Fighter": "TalonInterceptor",
	"Bomber": "ShrikeBomber",
	"AntiAirVehicle": "HaloSkimmer",
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
	"Worker": "Mule engineer",
	"Infantry": "Vector operator",
	"AssaultInfantry": "Arc shocktrooper",
	"RocketInfantry": "Ion specialist",
	"SniperInfantry": "Phase infiltrator",
	"Tank": "Needle skimmer",
	"RepairRobot": "Mender robot",
	"CombatRobot": "Lancer walker",
	"AdvancedTank": "Prism artillery",
	"Drone": "Kite drone",
	"Helicopter": "Wraith gunship",
	"Fighter": "Talon interceptor",
	"Bomber": "Shrike bomber",
	"AntiAirVehicle": "Halo AA skimmer",
	"CommandCenter": "Nexus HQ",
	"Barracks": "Operator hub",
	"VehicleFactory": "Robotics foundry",
	"AircraftFactory": "Flight deck",
	"PowerPlant": "Flux generator",
	"CommandLab": "Signal lab",
	"RepairDepot": "Service cradle",
	"AntiGroundTurret": "Lance sentry",
	"AntiAirTurret": "Skyward array",
}
const HELIX_DESCRIPTIONS = {
	"Worker":
	"Unarmed engineer: harvest materials and electronics, deliver to HQ and construct your base.",
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
		"Long-range cybernetic marksman equipped with thermal optics and an instant "
		+ "thermal beam rifle."
	),
	"Tank":
	(
		"High-speed repulsor hover skimmer armed with rapid twin pulse lasers. "
		+ "Uses superior mobility to flank and outrange heavy armor."
	),
	"CombatRobot":
	(
		"Precision: 12 m anti-armor lance, 0.75 s charge; weak against infantry. "
		+ "Interception: full air damage, 33% ground damage (100% with Dual-purpose AA). "
		+ "Switching disables fire for 2 s."
	),
	"AdvancedTank":
	(
		"14 m ground-only precision fire. Deploys while stationary for 1.5 s; each shot "
		+ "charges for 0.75 s. Moving retracts supports."
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
	"CommandCenter": "Produces Mule engineers, receives harvested resources and supplies 8 power.",
	"Barracks":
	(
		"Trains four infantry classes and a unique hero. Two infantry recovery "
		+ "slots within 5 m. Uses 3 power."
	),
	"CommandLab":
	(
		"With a robotics foundry, unlocks Lancers and Wraiths. Research "
		+ "Coordination for Prism artillery. Uses 5 power."
	),
}
const UNIT_COSTS = Rules.UNIT_COSTS
const HELIX_COSTS = Rules.HELIX_COSTS
const BUILD_COSTS = {
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
		"Repair depots unlock Sentinels; Coordination unlocks siege armor. "
		+ "Anchor sectors reward holding ground."
	),
	"helix":
	(
		"Build a flight deck after an operator hub. Signal labs unlock "
		+ "mode-switching Lancers and Wraiths; Coordination unlocks deploying "
		+ "Prisms."
	),
	"frontier":
	(
		"Motor pools unlock Jackals; field workshops unlock Ironbacks without "
		+ "Coordination. Scrapper rigs recover tank wrecks; Maneuver Burst "
		+ "enables fast raids."
	),
}
const BUILD_REQUIRES = {
	"VehicleFactory": "Barracks",
	"AircraftFactory": "VehicleFactory",
	"CommandLab": "VehicleFactory",
	"RepairDepot": "VehicleFactory",
	"AntiGroundTurret": "Barracks",
	"AntiAirTurret": "VehicleFactory",
}


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
	if faction == "bastion" and role == "CommandLab":
		return (
			"Unlocks heroes. Research Coordination for siege tanks "
			+ "and Anchor sectors. Sentinels require a repair depot. Uses 5 power."
		)
	if role == "RepairRobot":
		return (
			"Repairs one mechanical ground ally or completed building at a time. "
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
	var values = BUILD_COSTS if building else Rules.unit_costs(player.faction)
	return {"resource_a": values[role][0], "resource_b": values[role][1]}


static func duration(player, role):
	if role in Mercenaries.ROLES:
		return Mercenaries.UNITS[role].seconds
	return (
		SPECIALIST_TIMES.get(player.faction, {}).get(role, UNIT_TIMES[role])
		if player.get_meta("skirmish", false)
		else Constants.Match.Units.PRODUCTION_TIMES[Bastion.scene_path(role)]
	)


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
		(faction == "helix" and HELIX_MODELS.has(unit.type))
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
	var model = load("res://assets/models/%s/v1/%s.glb" % [faction, models[role]]).instantiate()
	if faction == "frontier":
		FrontierSurfaces.apply(model)
	else:
		SurfaceTextures.apply_armor(model)
	var bounds = _bounds(model, Transform3D.IDENTITY)
	var factor = radius * 1.85 / max(bounds.size.x, bounds.size.z)
	if role == "Infantry":
		factor = 1.15 / bounds.size.y
	elif Bastion.is_aircraft(role):
		factor *= 1.35
	if faction == "frontier" and role == "AdvancedTank":
		factor *= 1.2  # Long cannon overhang must not shrink the refurbished heavy hull.
	model.scale = Vector3.ONE * factor
	model.position = (
		-Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	)
	return model


static func _bounds(node, parent_transform):
	var transform_here = parent_transform * node.transform if node is Node3D else parent_transform
	var result = transform_here * node.get_aabb() if node is MeshInstance3D else AABB()
	for child in node.get_children():
		result = result.merge(_bounds(child, transform_here))
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
		unit.hp_max = roundi(unit.hp_max * 0.8)
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
