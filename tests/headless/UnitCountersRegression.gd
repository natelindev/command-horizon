extends "res://tests/headless/SaveRestoreEdges.gd"

const UnitCounters = preload("res://source/match/combat/UnitCounters.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const RosterInfo = preload("res://source/match/hud/RosterInfo.gd")


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_test_definitions()
	_test_tooltip_formatting()
	_test_unit_facts()
	await _test_roster_integration()
	for message in errors:
		push_error(message)
	print("Unit counters regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _test_definitions():
	var combat_roles = [
		"Infantry",
		"AssaultInfantry",
		"RocketInfantry",
		"SniperInfantry",
		"Tank",
		"AdvancedTank",
		"CombatRobot",
		"AntiAirVehicle",
		"Drone",
		"Helicopter",
		"Fighter",
		"Bomber",
		"MercenaryWarden",
		"MercenaryRanger",
		"MercenaryLancer",
	]
	for role in combat_roles:
		_check(UnitCounters.COUNTERS.has(role), "Missing counter definition for %s" % role)
		var entry = UnitCounters.COUNTERS.get(role, {})
		_check(not entry.get("role_label", "").is_empty(), "Empty role label for %s" % role)
		var counters = UnitCounters.counters_for(role)
		_check(
			counters.size() >= 3,
			"%s must have multiple counters (got %d)" % [role, counters.size()]
		)
		for counter in counters:
			_check(
				(
					Catalog.NAMES.has(counter)
					or UnitCounters.COUNTERS.has(counter)
					or counter in ["MercenaryWarden", "MercenaryRanger", "MercenaryLancer"]
				),
				"Unknown counter unit '%s' for role '%s'" % [counter, role]
			)
		var strong = UnitCounters.strong_against(role)
		for target in strong:
			_check(
				(
					Catalog.NAMES.has(target)
					or UnitCounters.COUNTERS.has(target)
					or target in ["Worker", "SupplyTruck"]
				),
				"Unknown target unit '%s' in strong_against for role '%s'" % [target, role]
			)


func _test_tooltip_formatting():
	for faction in ["bastion", "helix", "frontier"]:
		var tank_tooltip = UnitCounters.format_tooltip("Tank", faction)
		_check(tank_tooltip.contains("Strong vs:"), "%s: Tank tooltip missing Strong vs" % faction)
		_check(
			tank_tooltip.contains("Countered by:"),
			"%s: Tank tooltip missing Countered by" % faction
		)
		var rocket_tooltip = UnitCounters.format_tooltip("RocketInfantry", faction)
		_check(
			rocket_tooltip.contains("Strong vs:"), "%s: Rocket tooltip missing Strong vs" % faction
		)
		_check(
			rocket_tooltip.contains("Countered by:"),
			"%s: Rocket tooltip missing Countered by" % faction
		)
	var helix_rocket_counters = UnitCounters.format_tooltip("RocketInfantry", "helix")
	_check(
		(
			helix_rocket_counters.contains("Phase infiltrator")
			or helix_rocket_counters.contains("Sniper")
			or helix_rocket_counters.contains("Operator")
		),
		"Helix counter tooltip should reflect Helix unit titles"
	)


func _test_unit_facts():
	var facts = UnitCounters.format_facts("Tank", "bastion")
	_check(facts.size() >= 3, "Tank facts should include role and counter items")
	_check(facts[0].contains("Role:"), "First fact should be tactical role")
	_check(facts[1].contains("Strong vs:"), "Second fact should be strong against")
	_check(facts[2].contains("Countered by:"), "Third fact should be countered by")


func _test_roster_integration():
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn", true)
	var player = game._get_human_player()
	var factory = _units(player, "VehicleFactory")[0]
	var info = RosterInfo.inspect(factory, "Tank", false)
	_check(info.text.contains("Strong vs:"), "Roster tooltip missing Strong vs line")
	_check(info.text.contains("Countered by:"), "Roster tooltip missing Countered by line")
	paused = false
	game.queue_free()
	await _frames(5)
