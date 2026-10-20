extends "res://tests/playtest/SustainPressureMatches.gd"

var armor_recovery
var armor_protected = []


func _play_case(index):
	armor_recovery = load("res://tests/playtest/reference/ArmorRecoveryPolicy.gd").new()
	armor_protected.clear()
	await super(index)


func _place(role, builder):
	# Pay for a depot before the lab; use the established placement and builder rules.
	if role == "CommandLab" and not human.has_completed_structure("RepairDepot"):
		role = "RepairDepot"
	super(role, builder)


func _command():
	armor_protected = armor_recovery.update(
		game, human, plan_rules.owned_units(human), phase == "recover"
	)
	super()
	metrics.armor_recovery = armor_recovery.episodes
	for unit in armor_protected:
		_check(
			is_instance_of(unit.action, armor_recovery.Recover),
			"Commander replaced armor treatment"
		)
		metrics.armor_control_checks = metrics.get("armor_control_checks", 0) + 1
	if archive_prefix != "":
		if not armor_protected.is_empty():
			_archive_progress("armor_recovery")
		if armor_recovery.episodes.any(func(episode): return episode.result == "ready"):
			_archive_progress("armor_ready")


func _protected_from_command(unit):
	return unit in armor_protected or super(unit)

