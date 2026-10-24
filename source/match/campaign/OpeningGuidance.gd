extends RefCounted

## Read current mission state, including restored saves. Guidance never advances
## objectives or adds an attack timer while the player is learning.
const Factions = preload("res://source/match/FactionCatalog.gd")
const Bindings = preload("res://source/input/KeyBindings.gd")


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
		if not units.any(func(unit): return unit.type == "Tank"):
			var factories = units.filter(func(unit): return unit.type == "VehicleFactory")
			if factories.any(func(unit): return not unit.is_under_construction()):
				return _step(
					"TRAIN A TANK",
					(
						"Select your vehicle factory and train a tank. "
						+ "Gather more resources if needed."
					),
					"VehicleFactory"
				)
			if not units.any(func(unit): return unit.type == "Worker"):
				return _step(
					"TRAIN AN ENGINEER",
					"Select your HQ and train an engineer to rebuild the vehicle factory.",
					"CommandCenter"
				)
			if not factories.is_empty():
				return _step(
					"FINISH THE VEHICLE FACTORY",
					(
						"Keep an engineer at the vehicle factory foundation. "
						+ "Right-click it to resume construction."
					),
					"Worker"
				)
			return _step(
				"REBUILD THE VEHICLE FACTORY",
				(
					"Select an engineer. In Build, choose Vehicle factory and place it near your HQ. "
					+ "Then train a tank."
				),
				"Worker"
			)
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


## One practical hint at a time, chosen from the actual army state. This never
## adds tutorial gates or changes the campaign's objective/attack schedule.
static func practical_tip(game) -> String:
	var player = game._get_human_player()
	var units = player.get_children().filter(
		func(unit):
			return unit.is_in_group("units") and not unit.is_queued_for_deletion() and unit.hp > 0
	)
	var hurt = units.any(
		func(unit):
			return (
				unit.movement_speed > 0 and unit.attack_range != null and unit.hp < unit.hp_max * .5
			)
	)
	if hurt:
		return (
			TranslationServer
			. translate(
				(
					"Preserve your veterans: move wounded troops behind your line, then choose Recover health. "
					+ "Repair support restores vehicles between fights."
				)
			)
		)
	if game.phase == 0:
		return TranslationServer.translate(
			(
				"Keep spare engineers gathering while one builds. A resource cost is paid when you "
				+ "queue production; low power can stall the queue."
			)
		)
	if game.phase == 1:
		return (
			(TranslationServer.translate(
				(
					"Direct orders take control immediately. Hold %s when choosing a destination "
					+ "to queue the next order."
				)
			))
			% Bindings.label("shift_selecting")
		)
	if game.relay.captured_by == player:
		return TranslationServer.translate(
			(
				"Reinforce from your barracks before the next response. Rally infantry near your "
				+ "armor, and keep one squad inside the capture area."
			)
		)
	return (
		(TranslationServer.translate(
			(
				"Use Attack move (%s) for the approach so troops stop to fight. Use Move (%s) for "
				+ "a retreat that takes priority over fighting."
			)
		))
		% [Bindings.label("attack_move"), Bindings.label("move_order")]
	)


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
