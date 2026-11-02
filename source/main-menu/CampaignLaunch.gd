extends RefCounted

const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")


static func settings_for(mission_id: String, difficulty = 1, challenge = ""):
	var operation = Catalog.operations().get(mission_id)
	if (
		operation == null
		or difficulty not in [0, 1, 2]
		or challenge not in ["", "lean", "reinforced"]
	):
		return null
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = mission_id
	settings.campaign_challenge = challenge if mission_id == "command_horizon" else ""
	settings.map_path = operation.map
	for index in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			Constants.PlayerType.HUMAN if index == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = operation.faction if index == 0 else operation.enemy
		player.color = Constants.Player.COLORS[0 if index == 0 else 2]
		player.difficulty = difficulty
		settings.players.append(player)
	return settings


static func deploy(owner: Node, settings):
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = settings.map_path
	owner.get_tree().root.add_child(loading)
	owner.get_tree().current_scene = loading
	owner.queue_free()
