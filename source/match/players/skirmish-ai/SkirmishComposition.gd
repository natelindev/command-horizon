extends RefCounted

const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const VEHICLE_ROSTER = ["Tank", "Tank", "CombatRobot", "AdvancedTank", "RepairRobot"]


static func observed(game, player):
	var threats = {"air": 0, "armor": 0, "infantry": 0}
	for unit in player.get_tree().get_nodes_in_group("units"):
		if (
			unit.player == player
			or unit.is_queued_for_deletion()
			or unit.hp <= 0
			or unit.attack_range == null
			or not game.battlefield.is_observed(player, unit)
		):
			continue
		if unit.movement_domain == Constants.Match.Navigation.Domain.AIR:
			threats.air += 1
		elif Rules.armor_for(unit.type) == 2:
			threats.armor += 1
		elif unit.type == "Infantry":
			threats.infantry += 1
	return threats


static func inventory(units):
	var counts = {}
	for unit in units:
		if unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		counts[unit.type] = counts.get(unit.type, 0) + 1
		var queue = unit.get_node_or_null("ProductionQueue")
		if queue == null:
			continue
		for job in queue.get_elements():
			var role = Catalog.type_from_path(job.unit_prototype.resource_path)
			counts[role] = counts.get(role, 0) + 1
	return counts


static func infantry_target(player, threats):
	# Vectors cover the Lancer's weak anti-infantry profile; Bastion also has
	# its autocannon walker for this role. Neither reaction inspects hidden forces.
	return mini(12, 6 + ceili(threats.infantry / 2.0)) if player.faction == "helix" else 6


static func vehicle_role(player, counts, threats, sequence):
	return vehicle_choice(player, counts, threats, sequence).role


static func vehicle_choice(player, counts, threats, sequence):
	var machinery = (
		counts.get("Tank", 0) + counts.get("CombatRobot", 0) + counts.get("AdvancedTank", 0)
	)
	var air_counters = mini(4, threats.air)
	var ground_counters = (
		mini(3, ceili(threats.armor / 2.0))
		if player.faction == "helix"
		else mini(3, ceili(threats.infantry / 3.0))
	)
	var walkers = mini(4, air_counters + ground_counters)
	if counts.get("CombatRobot", 0) < walkers and Factions.available(player, "CombatRobot"):
		return {"role": "CombatRobot", "priority": 1}
	var repair_target = mini(4, ceili(machinery / 5.0)) if machinery >= 3 else 0
	if counts.get("RepairRobot", 0) < repair_target:
		return {"role": "RepairRobot", "priority": 3}
	var heavy_counters = mini(3, ceili(threats.armor / 2.0)) if player.faction != "helix" else 0
	if (
		player.faction != "helix"
		and counts.get("AdvancedTank", 0) < heavy_counters
		and Factions.available(player, "AdvancedTank")
	):
		return {"role": "AdvancedTank", "priority": 1}
	var role = VEHICLE_ROSTER[sequence % VEHICLE_ROSTER.size()]
	# Baseline slots are composition goals too: a second factory must count a
	# counter already paid for in another queue before filling the same slot.
	var target = {
		"CombatRobot": maxi(walkers, ceili(machinery / 4.0)),
		"AdvancedTank": maxi(heavy_counters, ceili(machinery / 5.0)),
		"RepairRobot": repair_target
	}
	if (
		not Factions.available(player, role)
		or (target.has(role) and counts.get(role, 0) >= target[role])
	):
		return {"role": "Tank", "priority": 6}
	return {"role": role, "priority": 6}
