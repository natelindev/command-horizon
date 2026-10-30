extends "res://tests/headless/SaveRestoreEdges.gd"

var tech_catalog
var factions
var rules


func _run():
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	rules = load("res://source/match/combat/CombatRules.gd")
	_test_catalog_contracts()
	_test_unit_and_faction_upgrades()
	for message in errors:
		push_error(message)
	print("Tech expansion regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _test_catalog_contracts():
	# 3-tier Weapons & Armor branches
	_check(
		tech_catalog.next_in_branch("weapons", []) == "weapons_1",
		"Weapons branch did not start at tier 1"
	)
	_check(
		tech_catalog.next_in_branch("weapons", ["weapons_1"]) == "weapons_2",
		"Weapons tier 1 did not advance to tier 2"
	)
	_check(
		tech_catalog.next_in_branch("weapons", ["weapons_1", "weapons_2"]) == "weapons_3",
		"Weapons tier 2 did not advance to tier 3"
	)
	_check(
		tech_catalog.next_in_branch("weapons", ["weapons_1", "weapons_2", "weapons_3"]) == "",
		"Completed weapons branch still has next tech"
	)

	_check(
		(
			tech_catalog.rank("weapons", []) == 0
			and tech_catalog.rank("weapons", ["weapons_1"]) == 1
			and tech_catalog.rank("weapons", ["weapons_1", "weapons_2"]) == 2
			and tech_catalog.rank("weapons", ["weapons_1", "weapons_2", "weapons_3"]) == 3
		),
		"Weapons rank calculation incorrect"
	)
	_check(
		tech_catalog.damage_factor("Tank", ["weapons_1", "weapons_2", "weapons_3"]) == 1.3,
		"Weapons tier 3 damage factor should be 1.3"
	)
	_check(
		tech_catalog.health_factor("Tank", ["armor_1", "armor_2", "armor_3"]) == 1.3,
		"Armor tier 3 health factor should be 1.3"
	)

	# Faction availability
	for faction in ["bastion", "helix", "frontier"]:
		_check(
			tech_catalog.available("tank_stabilizers", faction),
			"Tank stabilizers should be available to all factions"
		)
		_check(
			tech_catalog.available("tandem_rockets", faction),
			"Tandem rockets should be available to all factions"
		)
		_check(
			tech_catalog.available("reactive_armor", faction) == (faction == "bastion"),
			"Reactive armor availability mismatch"
		)
		_check(
			tech_catalog.available("siege_logistics", faction) == (faction == "bastion"),
			"Siege logistics availability mismatch"
		)
		_check(
			tech_catalog.available("plasma_shields", faction) == (faction == "helix"),
			"Plasma shields availability mismatch"
		)
		_check(
			tech_catalog.available("flux_capacitors", faction) == (faction == "helix"),
			"Flux capacitors availability mismatch"
		)
		_check(
			tech_catalog.available("scrap_cannibalization", faction) == (faction == "frontier"),
			"Scrap cannibalization availability mismatch"
		)
		_check(
			tech_catalog.available("high_octane", faction) == (faction == "frontier"),
			"High-octane availability mismatch"
		)


func _test_unit_and_faction_upgrades():
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	var state = tech_catalog.empty_state()
	state.completed = [
		"weapons_1",
		"weapons_2",
		"weapons_3",
		"armor_1",
		"armor_2",
		"armor_3",
		"tank_stabilizers",
		"tandem_rockets",
	]
	_check(
		tech_catalog.valid_state(state, true),
		"Valid state rejected completed 3-tier and unit upgrades"
	)

	# Test Bastion completed state
	var bastion_state = tech_catalog.empty_state()
	bastion_state.completed = ["armor_1", "reactive_armor", "siege_logistics"]
	_check(
		tech_catalog.valid_state(bastion_state, true), "Valid state rejected Bastion unique tech"
	)

	# Test Helix completed state
	var helix_state = tech_catalog.empty_state()
	helix_state.completed = ["weapons_1", "flux_capacitors", "plasma_shields"]
	_check(tech_catalog.valid_state(helix_state, true), "Valid state rejected Helix unique tech")

	# Test Frontier completed state
	var frontier_state = tech_catalog.empty_state()
	frontier_state.completed = ["weapons_1", "high_octane", "scrap_cannibalization"]
	_check(
		tech_catalog.valid_state(frontier_state, true), "Valid state rejected Frontier unique tech"
	)
