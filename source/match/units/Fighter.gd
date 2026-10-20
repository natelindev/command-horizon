extends "res://source/match/units/FixedWingAircraft.gd"

# Air superiority: guided air-to-air missiles at range, cannon bursts up close.
# Both need the target inside the nose cone; fire control never turns the jet.

const Weapons = preload("res://source/match/combat/WeaponCatalog.gd")
const LOADOUT = {
	"missile":
	{"weapon": Weapons.AIR_TO_AIR, "capacity": 4, "interval": 1.1, "range": 11.0, "cone": 0.55},
	"cannon":
	{"weapon": Weapons.JET_CANNON, "capacity": 60, "interval": 0.09, "range": 6.0, "cone": 0.2},
}


func loadout():
	return LOADOUT


func _solution(spec, target):
	var offset = target.global_position - global_position
	var distance = offset.length()
	if distance > spec.range or distance < 1.0:
		return false
	var forward = -global_basis.z
	return forward.angle_to(offset) <= spec.cone


# Lead pursuit: aim where the target will be when the fighter closes.
func strike_point(target):
	var closing = maxf(_flight.airspeed, 1.0)
	var distance = global_position.distance_to(target.global_position)
	var lead = _match.projectile_system.velocity_of(target) * minf(distance / closing, 1.5)
	return target.global_position + lead
