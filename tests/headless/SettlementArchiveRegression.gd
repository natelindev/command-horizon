extends "res://tests/headless/AmbientLifeRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in ["DesertFrontier", "PlainAndSimple", "ExpandedDesertFrontier"]:
		await _create(map_name)
		paused = true
		var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
		var data = capture.capture(game)
		if map_name == "ExpandedDesertFrontier":
			var sites = load("res://source/match/world/PointOfInterestCatalog.gd")
			var definitions = sites.definitions(game.settings.map_path)
			for index in definitions.size():
				if definitions[index].kind == "mercenary":
					var site = data.mission.points_of_interest[index]
					site.owner = data.players[0].id
					site.jobs = [
						{
							"role": "Infantry",
							"left": 8.0,
							"paid_cost": sites.price(game._get_human_player().faction, "Infantry")
						}
					]
					break
		var old_population = Ambient.entries(game.settings.map_path, false).size()
		data.ambient = data.ambient.slice(0, old_population)
		data.neutral_buildings = data.neutral_buildings.slice(
			0, Ambient.structures(game.settings.map_path, false).size()
		)
		var loader = load("res://source/match/saves/MatchRestore.gd").new()
		var restored = await loader.restore(self, data)
		_check(restored.ok, "Pre-settlement save rejected: " + restored.get("error", ""))
		if restored.ok:
			game = restored.game
			_check(
				game.get_node("NeutralWorld").buildings.size() == 2, "Legacy save lacks settlements"
			)
			var life = game.map.get_node("AmbientLife")
			_check(
				life.actors.size() == Ambient.entries(game.settings.map_path).size(),
				"Legacy save lacks residents"
			)
			_check(
				life.capture().slice(0, old_population) == data.ambient, "Legacy population changed"
			)
		await _close()
	for message in errors:
		push_error(message)
	print("Settlement archives: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
