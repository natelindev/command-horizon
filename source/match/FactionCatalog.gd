extends RefCounted

const Bastion = preload("res://source/match/BastionCatalog.gd")
const Frontier = preload("res://source/match/FrontierCatalog.gd")
const FrontierSurfaces = preload("res://source/match/FrontierMaterials.gd")
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
	"Helicopter": "WraithStriker",
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
	"Tank": "Needle skimmer",
	"RepairRobot": "Mender robot",
	"CombatRobot": "Lancer walker",
	"AdvancedTank": "Prism artillery",
	"Drone": "Kite scout",
	"Helicopter": "Wraith striker",
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
		"Fast operators against infantry and light machines; weak against heavy armor. "
		+ "Capture relays and recover at an operator hub."
	),
	"Tank":
	(
		"Fast frontline skimmer with a ground-only cannon and less hull strength than "
		+ "Bastion armor. Use mobility and repair support."
	),
	"CombatRobot":
	(
		"Precision: 8 m anti-armor lance, 0.75 s charge; weak against infantry. "
		+ "Interception: aircraft only. Switching disables fire for 2 s."
	),
	"AdvancedTank":
	(
		"10 m ground-only precision fire. Deploys while stationary for 1.5 s; each shot "
		+ "charges for 0.75 s. Moving retracts supports."
	),
	"Drone":
	(
		"Fast, unarmed scout with extended vision. Reveal routes and defenses before "
		+ "committing your army."
	),
	"Helicopter":
	(
		"Fast strike aircraft for ground raids and air combat. Avoid dedicated anti-air and "
		+ "return to a flight deck for service."
	),
	"CommandCenter": "Produces Mule engineers, receives harvested resources and supplies 20 power.",
	"Barracks":
	(
		"Trains four infantry classes and a unique hero. Two infantry recovery "
		+ "slots within 5 m. Uses 3 power."
	),
	"CommandLab":
	(
		"With a robotics foundry, unlocks chip programs, Lancers and Wraiths. Research "
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
const BUILD_TIMES = {
	"CommandCenter": 45.0,
	"Barracks": 20.0,
	"VehicleFactory": 35.0,
	"AircraftFactory": 35.0,
	"PowerPlant": 20.0,
	"CommandLab": 40.0,
	"RepairDepot": 25.0,
	"AntiGroundTurret": 20.0,
	"AntiAirTurret": 20.0,
}
const UNIT_TIMES = {
	"Hero": 40.0,
	"AssaultInfantry": 12.0,
	"SniperInfantry": 16.0,
	"RocketInfantry": 14.0,
	"Worker": 8.0,
	"Infantry": 8.0,
	"Tank": 20.0,
	"RepairRobot": 18.0,
	"CombatRobot": 24.0,
	"AdvancedTank": 32.0,
	"Drone": 12.0,
	"Helicopter": 28.0,
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
	if role == "Hero":
		return (
			{"bastion": "Marshal Aegis", "helix": "Spectre Nyx", "frontier": "Pathfinder Rook"}
			. get(faction, "Marshal Aegis")
		)
	if role in Bastion.INFANTRY_ROLES and role != "Infantry":
		return Bastion.NAMES[role]
	if role in Bastion.MISSION_NAMES:
		return Bastion.MISSION_NAMES[role]
	if faction == "frontier":
		return Frontier.NAMES[role]
	return HELIX_NAMES[role] if faction == "helix" else Bastion.NAMES[role]


static func icon(faction, role):
	if role in Bastion.INFANTRY_ROLES:
		return "res://assets/ui/infantry/%s/%s.png" % [faction, role]
	if faction == "frontier":
		return "res://assets/ui/frontier/%s.png" % Frontier.MODELS[role]
	return (
		"res://assets/ui/helix/%s.png" % HELIX_MODELS[role]
		if faction == "helix"
		else Bastion.icon_path(role)
	)


static func description(faction, role):
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
	if role == "RepairRobot":
		return (
			"Repairs one mechanical ground ally or completed building at a time. "
			+ "3 m reach, measured from a building's edge."
		)
	if faction == "helix" and HELIX_DESCRIPTIONS.has(role):
		return HELIX_DESCRIPTIONS[role]
	return Bastion.DESCRIPTIONS[role]


static func cost(player, role, building = false):
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
	return (
		UNIT_TIMES[role]
		if player.get_meta("skirmish", false)
		else Constants.Match.Units.PRODUCTION_TIMES[Bastion.scene_path(role)]
	)


static func requirement(player, role, building = false):
	if building:
		return BUILD_REQUIRES.get(role, "") if player.get_meta("skirmish", false) else ""
	if role == "Helicopter" and player.get_meta("skirmish", false):
		return "CommandLab"
	return Bastion.REQUIRES.get(role, "")


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
	if not building and role == "AdvancedTank" and player.get_meta("skirmish", false):
		if not player.coordination_unlocked:
			return false
	var required = requirement(player, role, building)
	return required == "" or player.has_completed_structure(required)


static func prepare_model(unit, faction):
	var geometry = unit.get_node("Geometry")
	if faction in ["helix", "frontier"]:
		for child in geometry.get_children():
			child.free()
		var model_role = "Infantry" if Bastion.is_infantry(unit.type) else unit.type
		geometry.add_child(model_geometry(faction, model_role, unit.radius))
		unit.set_meta("model_faction", faction)
	if Bastion.is_infantry(unit.type):
		load("res://source/match/units/traits/InfantryEquipment.gd").equip(unit, faction)


static func helix_geometry(role, radius):
	return model_geometry("helix", role, radius)


static func model_geometry(faction, role, radius):
	var models = Frontier.MODELS if faction == "frontier" else HELIX_MODELS
	var model = load("res://assets/models/%s/v1/%s.glb" % [faction, models[role]]).instantiate()
	if faction == "frontier":
		FrontierSurfaces.apply(model)
	var bounds = _bounds(model, Transform3D.IDENTITY)
	var factor = radius * 1.85 / max(bounds.size.x, bounds.size.z)
	if role == "Infantry":
		factor = 1.15 / bounds.size.y
	elif role in ["Drone", "Helicopter"]:
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


static func chip_cost(faction):
	return Rules.chip_cost(faction)


static func chip_seconds(faction):
	return Rules.chip_seconds(faction)


static func health_factor(faction):
	return Rules.health_factor(faction)


static func signature_title(faction):
	return Rules.signature_title(faction)


static func signature_cooldown(faction):
	return Rules.signature_cooldown(faction)


static func apply_stats(unit):
	if unit.type == "RocketInfantry":
		unit.get_node("Movement").speed *= .82
	elif unit.type == "SniperInfantry":
		unit.get_node("Movement").speed *= .9
	elif unit.type == "Hero":
		match unit.player.faction:
			"helix":
				unit.attack_damage = 15
				unit.attack_interval = 1.5
				unit.attack_range = 9.0
			"frontier":
				unit.attack_damage = 7
				unit.attack_interval = .45
				unit.attack_range = 5.0
	if unit.player.faction == "frontier" and unit.movement_speed > 0:
		unit.hp_max = roundi(unit.hp_max * health_factor("frontier"))
		unit.hp = unit.hp_max
		unit.get_node("Movement").speed *= (
			1.2 if (Bastion.is_infantry(unit.type) or unit.type == "Drone") else 1.1
		)
		if unit.type == "Drone":
			unit.sight_range += 2.0
		if unit.type == "AdvancedTank":
			unit.attack_interval = 2.2
	if unit.player.faction == "helix" and unit.movement_speed > 0:
		unit.hp_max = roundi(unit.hp_max * 0.8)
		unit.hp = unit.hp_max
		unit.get_node("Movement").speed *= 1.2
		if unit.type in ["Drone", "Tank"]:
			unit.sight_range += 2.0
		if unit.type == "AdvancedTank":
			unit.attack_range = 10.0
			unit.get_node("Movement").speed *= 0.75
	if unit.type == "CombatRobot":
		unit.configure_weapon()
