extends RefCounted

const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")


static func instructions(game):
	var mission = game.settings.mission_id
	if Catalog.is_story(mission):
		var objective = game.current_objective()
		var action = ""
		match objective.kind:
			"capture":
				action = game.tr("Move infantry within 3 m. Capture takes 10 uncontested seconds.")
			"hold":
				action = (
					(
						game
						. tr(
							(
								"Capture with infantry, then hold for %d uncontested seconds. Progress pauses if "
								+ "control is lost."
							)
						)
					)
					% objective.seconds
				)
			"destroy":
				action = game.tr("Attack the marked enemy target until it is destroyed.")
			"escort":
				action = (
					game
					. tr(
						"Click Advance convoy to send the truck to its destination. Protect it with your army."
					)
				)
		return (
			action
			+ "\n"
			+ game.tr(
				"Your hero must survive and be within 24 m of the destination to finish this stage."
			)
		)
	match mission:
		"supply_line":
			return (
				game
				. tr(
					(
						"Deliver at least 2 of 3 trucks. At each checkpoint, stop for 12 uncontested seconds, "
						+ "then click Advance convoy again. Order escorts separately. Keep your hero alive."
					)
				)
			)
		"first_orders":
			return game.tr(
				preload("res://source/match/campaign/OpeningGuidance.gd").first_orders(game).text
			)
		"split_signal":
			return (
				game
				. tr(
					(
						"Capture with infantry within 3 m for 10 seconds. Hold any two relays uncontested for "
						+ "120 seconds; progress pauses when fewer than two are clear. Keep your hero alive."
					)
				)
			)
		"broken_foundry":
			return (
				game
				. tr(
					(
						"Destroy both production nodes. Capture foundry control with infantry, then keep "
						+ "infantry within 3 m for 30 uncontested seconds. Keep your hero alive."
					)
				)
			)
		"command_horizon":
			return (
				game
				. tr(
					(
						"Capture deployment and keep infantry there for 30 seconds. Destroy enemy HQ and the "
						+ "siege commander, retain the deployment guard, then bring Aegis within 18 m of the "
						+ "Spire controls."
					)
				)
			)
	return ""


static func point(game):
	var mission = game.settings.mission_id
	if Catalog.is_story(mission):
		var objective = game.current_objective()
		var target = objective.destination if objective.kind == "escort" else objective.point
		return Vector3(target[0], 0, target[1])
	match mission:
		"supply_line":
			for entry in game.convoy:
				if game._alive(entry):
					return game.map.POINTS[entry.leg]
		"first_orders":
			if game.phase < 2:
				return game.map.get_node("SpawnPoints").get_child(0).position
			return game.relay.global_position
		"split_signal":
			for relay in game.map.relays:
				if relay.captured_by != game._get_human_player() or relay.contested:
					return relay.global_position
			return game.map.relays[1].global_position
		"broken_foundry":
			for index in game.nodes.size():
				if not game.nodes[index].disabled:
					return game.map.NODES[index]
			return game.map.CONTROL
		"command_horizon":
			return game.map.TARGET if game.deployed and game.zone_held() else game.map.DEPLOYMENT
	return Vector3.ZERO
