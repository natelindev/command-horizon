extends RefCounted

# The weapon facts a round carries after leaving the muzzle. Rounds outlive their
# shooter, so damage, ownership and hit feedback read these frozen values; the
# shooter itself is only used while it remains alive.

var player = null
var type = ""
var attack_damage = 0.0
var attack_domains = []
var weapon_mode = ""
var origin = Vector3.ZERO
var force_attack = false
var global_position:
	get:
		var unit = shooter()
		return unit.global_position if unit != null else origin
var _shooter = null


static func from(unit, muzzle):
	var shot = new()
	shot.player = unit.player
	shot.type = unit.type
	shot.attack_damage = float(unit.attack_damage)
	shot.attack_domains = unit.attack_domains.duplicate()
	shot.weapon_mode = unit.weapon_mode if "weapon_mode" in unit else ""
	shot.origin = muzzle
	shot._shooter = weakref(unit)
	shot.force_attack = load("res://source/match/combat/CombatRules.gd").explicit_attack(
		unit, unit.aim_target
	)
	return shot


func shooter():
	var unit = _shooter.get_ref() if _shooter != null else null
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return null
	return unit


# Hit feedback prefers the live shooter so retaliation and statistics keep using
# the existing unit-based paths; a destroyed shooter is represented by this record.
func feedback_source():
	var unit = shooter()
	return unit if unit != null else self
