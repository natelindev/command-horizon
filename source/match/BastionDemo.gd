extends "res://source/match/Match.gd"

const MatchSettings = preload("res://source/data-model/MatchSettings.gd")
const PlayerSettings = preload("res://source/data-model/PlayerSettings.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")

var _previous_god_mode = false


func _enter_tree():
	_previous_god_mode = FeatureFlags.god_mode
	FeatureFlags.god_mode = false
	settings = MatchSettings.new()
	for index in range(2):
		var player_settings = PlayerSettings.new()
		player_settings.controller = (
			Constants.PlayerType.HUMAN if index == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player_settings.color = Color("e0ad46") if index == 0 else Color("c65455")
		settings.players.append(player_settings)
	map = load("res://source/match/maps/BastionDesert.tscn").instantiate()
	super()


func _ready():
	super()
	_camera.size_max = 40
	_camera.rotation_degrees.y = -30
	_camera.default_y_rotation_degrees = -30
	_camera.set_size_safely(25)
	_camera.set_position_safely(Vector3(15, 0, 16))
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	var human = _get_human_player()
	human.get_node("StructurePlacementHandler").process_mode = Node.PROCESS_MODE_ALWAYS
	for unit in human.get_children():
		if "type" in unit and unit.type == "Worker":
			var resource = (
				Utils
				. Match
				. Resources
				. find_resource_unit_closest_to_unit_yet_no_further_than(unit, 30, null)
			)
			if resource != null:
				unit.action = (
					load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
					. new(resource)
				)
	add_child(load("res://source/match/hud/BastionDemoHUD.gd").new())


func _exit_tree():
	FeatureFlags.god_mode = _previous_god_mode


func _spawn_player_units(player, spawn_transform):
	var human = player is Human
	player.resource_a = 120 if human else 90
	player.resource_b = 70 if human else 50
	var roster = [
		["CommandCenter", Vector3(0, 0, 0)],
		["PowerPlant", Vector3(-6, 0, 0)],
		["Barracks", Vector3(0, 0, 6)],
		["VehicleFactory", Vector3(6, 0, 0)],
		["Worker", Vector3(-4, 0, 8)],
		["Worker", Vector3(-2, 0, 9)],
		["Infantry", Vector3(3, 0, 10)],
		["Infantry", Vector3(4, 0, 10)],
		["Tank", Vector3(7, 0, 7)],
		["Drone", Vector3(-2, 0, -3)],
	]
	if human:
		roster += [
			["AircraftFactory", Vector3(6, 0, -6)],
			["CommandLab", Vector3(0, 0, -6)],
			["RepairDepot", Vector3(-6, 0, 6)],
			["AntiGroundTurret", Vector3(11, 0, 5)],
			["AntiAirTurret", Vector3(-6, 0, -5)],
			["RepairRobot", Vector3(5, 0, 8)],
			["CombatRobot", Vector3(7, 0, 10)],
			["AdvancedTank", Vector3(10, 0, 9)],
			["Helicopter", Vector3(9, 0, -2)],
		]
	for entry in roster:
		var offset = entry[1] if human else -entry[1]
		var transform_to_spawn = Transform3D(Basis(), spawn_transform.origin + offset)
		_setup_and_spawn_unit(
			load(Catalog.scene_path(entry[0])).instantiate(), transform_to_spawn, player, false
		)
