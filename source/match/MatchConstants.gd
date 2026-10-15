const OWNED_PLAYER_CIRCLE_COLOR = Color("7fd9a0")
const ADVERSARY_PLAYER_CIRCLE_COLOR = Color("ee6b5e")
const RESOURCE_CIRCLE_COLOR = Color("e8c56a")
const DEFAULT_CIRCLE_COLOR = Color("eef1f1")
const MAPS = {
	"res://source/match/maps/ExpandedDesertFrontier.tscn":
	{"name": "Desert Frontier — Expanded", "players": 2, "size": Vector2i(192, 144)},
	"res://source/match/maps/ExpandedAlpineRelay.tscn":
	{"name": "Alpine Relay — Expanded", "players": 2, "size": Vector2i(192, 156)},
	"res://source/match/maps/ExpandedCoastalFoundry.tscn":
	{"name": "Coastal Foundry — Expanded", "players": 2, "size": Vector2i(192, 156)},
	"res://source/match/maps/BastionDesert.tscn":
	{"name": "Desert Frontier (original)", "players": 2, "size": Vector2i(64, 64)},
	"res://source/match/maps/DesertFrontier.tscn":
	{"name": "Desert Frontier", "players": 2, "size": Vector2i(128, 96)},
	"res://source/match/maps/PlainAndSimple.tscn":
	{
		"name": "Open Plains",
		"players": 4,
		"size": Vector2i(50, 50),
	},
	"res://source/match/maps/BigArena.tscn":
	{
		"name": "Great Expanse",
		"players": 8,
		"size": Vector2i(100, 100),
	},
	"res://source/match/maps/AlpineRelay.tscn":
	{"name": "Alpine Relay", "players": 2, "size": Vector2i(128, 104)},
	"res://source/match/maps/IndustrialCrossroads.tscn":
	{"name": "Industrial Crossroads", "players": 2, "size": Vector2i(128, 104)},
	"res://source/match/maps/CoastalFoundry.tscn":
	{"name": "Coastal Foundry", "players": 2, "size": Vector2i(128, 104)},
}


class Navigation:
	enum Domain { AIR, TERRAIN }

	const DOMAIN_TO_GROUP_MAPPING = {
		Domain.AIR: "air_navigation_input",
		Domain.TERRAIN: "terrain_navigation_input",
	}


class Air:
	const Y = 1.5
	const PLANE = Plane(Vector3.UP, Y)

	class Navmesh:
		const CELL_SIZE = 0.4
		const CELL_HEIGHT = 0.4
		const MAX_AGENT_RADIUS = 0.8


class Terrain:
	const PLANE = Plane(Vector3.UP, 0)

	class Navmesh:
		const CELL_SIZE = 0.3
		const CELL_HEIGHT = 0.3
		const MAX_AGENT_RADIUS = 0.9  # max radius of movable units


class Resources:
	class A:
		const COLOR = Color("d6ab64")
		const MATERIAL_PATH = "res://source/match/resources/materials/resource_a.material.tres"
		const COLLECTING_TIME_S = 1.0

	class B:
		const COLOR = Color("65cdd8")
		const MATERIAL_PATH = "res://source/match/resources/materials/resource_b.material.tres"
		const COLLECTING_TIME_S = 1.5


class Units:
	const PRODUCTION_COSTS = {
		"res://source/match/units/Hero.tscn": {"resource_a": 48, "resource_b": 24},
		"res://source/match/units/AssaultInfantry.tscn": {"resource_a": 10, "resource_b": 2},
		"res://source/match/units/SniperInfantry.tscn": {"resource_a": 12, "resource_b": 6},
		"res://source/match/units/RocketInfantry.tscn": {"resource_a": 12, "resource_b": 4},
		"res://source/match/units/Infantry.tscn": {"resource_a": 4, "resource_b": 0},
		"res://source/match/units/RepairRobot.tscn": {"resource_a": 8, "resource_b": 4},
		"res://source/match/units/CombatRobot.tscn": {"resource_a": 12, "resource_b": 8},
		"res://source/match/units/AdvancedTank.tscn": {"resource_a": 20, "resource_b": 12},
		"res://source/match/units/Worker.tscn":
		{
			"resource_a": 4,
			"resource_b": 0,
		},
		"res://source/match/units/Helicopter.tscn":
		{
			"resource_a": 16,
			"resource_b": 10,
		},
		"res://source/match/units/Drone.tscn":
		{
			"resource_a": 4,
			"resource_b": 2,
		},
		"res://source/match/units/Tank.tscn":
		{
			"resource_a": 12,
			"resource_b": 4,
		},
	}
	const PRODUCTION_TIMES = {
		"res://source/match/units/Hero.tscn": 40.0,
		"res://source/match/units/AssaultInfantry.tscn": 12.0,
		"res://source/match/units/SniperInfantry.tscn": 16.0,
		"res://source/match/units/RocketInfantry.tscn": 14.0,
		"res://source/match/units/Infantry.tscn": 3.0,
		"res://source/match/units/RepairRobot.tscn": 6.0,
		"res://source/match/units/CombatRobot.tscn": 8.0,
		"res://source/match/units/AdvancedTank.tscn": 12.0,
		"res://source/match/units/Worker.tscn": 3.0,
		"res://source/match/units/Helicopter.tscn": 6.0,
		"res://source/match/units/Drone.tscn": 3.0,
		"res://source/match/units/Tank.tscn": 6.0,
	}
	const PRODUCTION_QUEUE_LIMIT = 5
	const STRUCTURE_BLUEPRINTS = {
		"res://source/match/units/Barracks.tscn":
		"res://source/match/units/structure-geometries/Barracks.tscn",
		"res://source/match/units/PowerPlant.tscn":
		"res://source/match/units/structure-geometries/PowerPlant.tscn",
		"res://source/match/units/CommandLab.tscn":
		"res://source/match/units/structure-geometries/CommandLab.tscn",
		"res://source/match/units/RepairDepot.tscn":
		"res://source/match/units/structure-geometries/RepairDepot.tscn",
		"res://source/match/units/CommandCenter.tscn":
		"res://source/match/units/structure-geometries/CommandCenter.tscn",
		"res://source/match/units/VehicleFactory.tscn":
		"res://source/match/units/structure-geometries/VehicleFactory.tscn",
		"res://source/match/units/AircraftFactory.tscn":
		"res://source/match/units/structure-geometries/AircraftFactory.tscn",
		"res://source/match/units/AntiGroundTurret.tscn":
		"res://source/match/units/structure-geometries/AntiGroundTurret.tscn",
		"res://source/match/units/AntiAirTurret.tscn":
		"res://source/match/units/structure-geometries/AntiAirTurret.tscn",
	}
	const CONSTRUCTION_COSTS = {
		"res://source/match/units/Barracks.tscn": {"resource_a": 14, "resource_b": 0},
		"res://source/match/units/PowerPlant.tscn": {"resource_a": 10, "resource_b": 0},
		"res://source/match/units/CommandLab.tscn": {"resource_a": 18, "resource_b": 12},
		"res://source/match/units/RepairDepot.tscn": {"resource_a": 14, "resource_b": 6},
		"res://source/match/units/CommandCenter.tscn":
		{
			"resource_a": 50,
			"resource_b": 20,
		},
		"res://source/match/units/VehicleFactory.tscn":
		{
			"resource_a": 28,
			"resource_b": 8,
		},
		"res://source/match/units/AircraftFactory.tscn":
		{
			"resource_a": 30,
			"resource_b": 16,
		},
		"res://source/match/units/AntiGroundTurret.tscn":
		{
			"resource_a": 12,
			"resource_b": 4,
		},
		"res://source/match/units/AntiAirTurret.tscn":
		{
			"resource_a": 10,
			"resource_b": 8,
		},
	}
	const DEFAULT_PROPERTIES = {
		"res://source/match/units/Hero.tscn":
		{
			"hp": 110,
			"hp_max": 110,
			"attack_damage": 9,
			"attack_interval": 0.65,
			"attack_range": 9.0,
			"sight_range": 11.0,
			"attack_domains": [Navigation.Domain.TERRAIN]
		},
		"res://source/match/units/AssaultInfantry.tscn":
		{
			"hp": 42,
			"hp_max": 42,
			"attack_damage": 4,
			"attack_interval": 0.4,
			"attack_range": 5.5,
			"sight_range": 8.0,
			"attack_domains": [Navigation.Domain.TERRAIN]
		},
		"res://source/match/units/SniperInfantry.tscn":
		{
			"hp": 20,
			"hp_max": 20,
			"attack_damage": 12,
			"attack_interval": 2.1,
			"attack_range": 13.0,
			"sight_range": 14.0,
			"attack_domains": [Navigation.Domain.TERRAIN]
		},
		"res://source/match/units/RocketInfantry.tscn":
		{
			"hp": 32,
			"hp_max": 32,
			"attack_damage": 11,
			"attack_interval": 2.3,
			"attack_range": 10.0,
			"sight_range": 11.0,
			"attack_domains": [Navigation.Domain.TERRAIN]
		},
		"res://source/match/units/EvacTransport.tscn":
		{"hp": 150, "hp_max": 150, "sight_range": 8.0},
		"res://source/match/units/SupplyTruck.tscn": {"hp": 180, "hp_max": 180, "sight_range": 7.0},
		"res://source/match/units/Infantry.tscn":
		{
			"hp": 22,
			"hp_max": 22,
			"sight_range": 9.0,
			"attack_damage": 3,
			"attack_interval": 0.7,
			"attack_range": 7.0,
			"attack_domains": [Navigation.Domain.TERRAIN]
		},
		"res://source/match/units/RepairRobot.tscn": {"hp": 45, "hp_max": 45, "sight_range": 7.0},
		"res://source/match/units/CombatRobot.tscn":
		{
			"hp": 65,
			"hp_max": 65,
			"sight_range": 10.0,
			"attack_damage": 5,
			"attack_interval": 0.7,
			"attack_range": 8.0,
			"attack_domains": [Navigation.Domain.TERRAIN]
		},
		"res://source/match/units/AdvancedTank.tscn":
		{
			"hp": 105,
			"hp_max": 105,
			"sight_range": 14.0,
			"attack_damage": 18,
			"attack_interval": 2.0,
			"attack_range": 12.0,
			"attack_domains": [Navigation.Domain.TERRAIN]
		},
		"res://source/match/units/Barracks.tscn": {"hp": 220, "hp_max": 220, "sight_range": 8.0},
		"res://source/match/units/PowerPlant.tscn": {"hp": 160, "hp_max": 160, "sight_range": 8.0},
		"res://source/match/units/CommandLab.tscn": {"hp": 220, "hp_max": 220, "sight_range": 8.0},
		"res://source/match/units/RepairDepot.tscn": {"hp": 260, "hp_max": 260, "sight_range": 8.0},
		"res://source/match/units/Drone.tscn":
		{
			"sight_range": 13.0,
			"hp": 25,
			"hp_max": 25,
		},
		"res://source/match/units/Worker.tscn":
		{
			"sight_range": 5.0,
			"hp": 35,
			"hp_max": 35,
			"resources_max": 4,
		},
		"res://source/match/units/Helicopter.tscn":
		{
			"sight_range": 11.0,
			"hp": 50,
			"hp_max": 50,
			"attack_damage": 7,
			"attack_interval": 1.4,
			"attack_range": 9.0,
			"attack_domains": [Navigation.Domain.TERRAIN, Navigation.Domain.AIR],
		},
		"res://source/match/units/Tank.tscn":
		{
			"sight_range": 11.0,
			"hp": 80,
			"hp_max": 80,
			"attack_damage": 9,
			"attack_interval": 1.2,
			"attack_range": 9.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/CommandCenter.tscn":
		{
			"sight_range": 10.0,
			"hp": 500,
			"hp_max": 500,
		},
		"res://source/match/units/VehicleFactory.tscn":
		{
			"sight_range": 8.0,
			"hp": 320,
			"hp_max": 320,
		},
		"res://source/match/units/AircraftFactory.tscn":
		{
			"sight_range": 8.0,
			"hp": 300,
			"hp_max": 300,
		},
		"res://source/match/units/AntiGroundTurret.tscn":
		{
			"sight_range": 13.0,
			"hp": 120,
			"hp_max": 120,
			"attack_damage": 9,
			"attack_interval": 1.2,
			"attack_range": 12.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/AntiAirTurret.tscn":
		{
			"sight_range": 13.0,
			"hp": 100,
			"hp_max": 100,
			"attack_damage": 8,
			"attack_interval": 1.0,
			"attack_range": 12.0,
			"attack_domains": [Navigation.Domain.AIR],
		},
	}
	const PROJECTILES = {
		"res://source/match/units/Hero.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/AssaultInfantry.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/SniperInfantry.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/RocketInfantry.tscn":
		"res://source/match/units/projectiles/Rocket.tscn",
		"res://source/match/units/Infantry.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/CombatRobot.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/AdvancedTank.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/Helicopter.tscn":
		"res://source/match/units/projectiles/Rocket.tscn",
		"res://source/match/units/Tank.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/AntiGroundTurret.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/AntiAirTurret.tscn":
		"res://source/match/units/projectiles/Rocket.tscn"
	}
	const ADHERENCE_MARGIN_M = 0.3  # TODO: try lowering while fixing a 'push' problem
	const NEW_RESOURCE_SEARCH_RADIUS_M = 30
	const MOVING_UNIT_RADIUS_MAX_M = 1.0
	const EMPTY_SPACE_RADIUS_SURROUNDING_STRUCTURE_M = MOVING_UNIT_RADIUS_MAX_M * 2.5
	const STRUCTURE_CONSTRUCTING_SPEED = 0.3  # progress [0.0..1.0] per second


class VoiceNarrator:
	enum Events {
		MATCH_STARTED,
		MATCH_ABORTED,
		MATCH_FINISHED_WITH_VICTORY,
		MATCH_FINISHED_WITH_DEFEAT,
		BASE_UNDER_ATTACK,
		UNIT_UNDER_ATTACK,
		UNIT_LOST,
		UNIT_PRODUCTION_STARTED,
		UNIT_PRODUCTION_FINISHED,
		UNIT_CONSTRUCTION_FINISHED,
		UNIT_HELLO,
		UNIT_ACK_1,
		UNIT_ACK_2,
		NOT_ENOUGH_RESOURCES,
		RESEARCH_COMPLETED,
		LOW_POWER,
		POWER_RESTORED,
	}

	const EVENT_TO_ASSET_MAPPING = {
		Events.MATCH_STARTED:
		preload("res://assets/audio/voices/bastion/Command/MATCH_STARTED_0.ogg"),
		Events.MATCH_ABORTED:
		preload("res://assets/audio/voices/bastion/Command/MATCH_ABORTED_0.ogg"),
		Events.MATCH_FINISHED_WITH_VICTORY:
		preload("res://assets/audio/voices/bastion/Command/MATCH_FINISHED_WITH_VICTORY_0.ogg"),
		Events.MATCH_FINISHED_WITH_DEFEAT:
		preload("res://assets/audio/voices/bastion/Command/MATCH_FINISHED_WITH_DEFEAT_0.ogg"),
		Events.BASE_UNDER_ATTACK:
		preload("res://assets/audio/voices/bastion/Command/BASE_UNDER_ATTACK_0.ogg"),
		Events.UNIT_UNDER_ATTACK:
		preload("res://assets/audio/voices/bastion/Command/UNIT_UNDER_ATTACK_0.ogg"),
		Events.UNIT_LOST: preload("res://assets/audio/voices/bastion/Command/UNIT_LOST_0.ogg"),
		Events.UNIT_PRODUCTION_STARTED:
		preload("res://assets/audio/voices/bastion/Command/UNIT_PRODUCTION_STARTED_0.ogg"),
		Events.UNIT_PRODUCTION_FINISHED:
		preload("res://assets/audio/voices/bastion/Command/UNIT_PRODUCTION_FINISHED_0.ogg"),
		Events.UNIT_CONSTRUCTION_FINISHED:
		preload("res://assets/audio/voices/bastion/Command/UNIT_CONSTRUCTION_FINISHED_0.ogg"),
		Events.NOT_ENOUGH_RESOURCES:
		preload("res://assets/audio/voices/bastion/Command/NOT_ENOUGH_RESOURCES_0.ogg"),
	}
