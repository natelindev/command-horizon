extends RefCounted

## Read current mission state, including restored saves. Guidance never advances
## objectives or adds an attack timer while the player is learning.
const Factions = preload("res://source/match/FactionCatalog.gd")


static func first_orders(game):
	var player = game._get_human_player()
	var units = player.get_children().filter(
		func(unit):
			return unit.is_in_group("units") and not unit.is_queued_for_deletion() and unit.hp > 0
	)
	if game.phase == 0:
		if not units.any(func(unit): return unit.type == "Worker"):
			return _step(
				"TRAIN AN ENGINEER",
				"Select your HQ and train an engineer to build the command lab.",
				"CommandCenter"
			)
		for unit in units:
			if unit.type == "CommandLab" and unit.is_under_construction():
				return _step(
					"FINISH THE COMMAND LAB",
					"Keep an engineer at the foundation. Right-click it to resume construction.",
					"Worker"
				)
		var cost = Factions.cost(player, "CommandLab", true)
		if player.resource_a < cost.resource_a:
			return _step(
				"GATHER MATERIALS",
				(
					"Select an engineer and right-click a materials pile. It will gather and deliver "
					+ "automatically."
				),
				"Worker"
			)
		if player.resource_b < cost.resource_b:
			return _step(
				"GATHER ELECTRONICS",
				(
					"Select an engineer and right-click an electronics pile. Wait for delivery, then "
					+ "build the lab."
				),
				"Worker"
			)
		return _step(
			"BUILD THE COMMAND LAB",
			(
				"Select an engineer. In Build, choose Command lab and place it near your HQ. You "
				+ "can take your time here."
			),
			"Worker"
		)
	if game.phase == 1:
		return _step(
			"SET A GUARD POSITION",
			(
				"Select a tank. Open Orders, choose Guard, then click a position near your base. "
				+ "The tank will move there and defend it."
			),
			"Tank"
		)
	if game.relay.captured_by == player:
		if game.relay.contested:
			return _step(
				"CLEAR THE RELAY",
				"Attack enemy ground units near the relay. The hold timer continues when the area is clear.",
				"Tank"
			)
		return _step(
			"DEFEND THE RELAY",
			(
				"Keep infantry at the relay and screen the eastern approach with armor. Hold for 60 "
				+ "uncontested seconds."
			),
			"Infantry"
		)
	if not units.any(func(unit): return unit.type == "Infantry"):
		return _step(
			"TRAIN CAPTURE INFANTRY",
			"Select your barracks and train infantry. Vehicles cannot capture the relay.",
			"Barracks"
		)
	return _step(
		"CAPTURE THE RELAY",
		(
			"Select infantry and move them within 3 m of the relay. Capture takes 10 uncontested "
			+ "seconds. Bring armor to protect them."
		),
		"Infantry"
	)


static func _step(title, text, role):
	return {"title": title, "text": text, "role": role}


static func debrief(game):
	match game.settings.mission_id:
		"supply_line":
			return (
				"In First Orders, keep engineers gathering while you build your command lab."
				if game.result == "Victory"
				else "Send escorts ahead, keep your hero protected, and repair trucks between checkpoints."
			)
		"first_orders":
			if game.result == "Victory":
				return "In your next battle, use infantry to capture and armor to screen their approach."
			return "Keep an engineer near your HQ for repairs. Use tactical pause to plan your next orders."
	return ""
