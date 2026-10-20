extends "res://source/match/units/FixedWingAircraft.gd"

# Level bomber: one stick of gravity bombs per sortie. The bombsight predicts
# where a released bomb lands from altitude and ground speed and starts the
# stick when that point reaches the target; a bad pass loops around for another.

const Weapons = preload("res://source/match/combat/WeaponCatalog.gd")
const LOADOUT = {
	"bomb": {"weapon": Weapons.GRAVITY_BOMB, "capacity": 6, "interval": 0.14},
}
const RELEASE_WINDOW = 1.4
const LATERAL_TOLERANCE = 1.6

var _stick_left = 0


func loadout():
	return LOADOUT


# Once started, the stick keeps walking across the area even if the target dies.
func _fire_control():
	if _stick_left > 0:
		if _cooldowns.bomb <= 0.0 and stores.bomb > 0:
			_release("bomb", LOADOUT.bomb, aim_target if can_strike(aim_target) else null)
		elif stores.bomb <= 0:
			_stick_left = 0
		return
	super()


func _solution(_spec, target):
	if _stick_left > 0:
		return true
	var impact = bomb_impact()
	var forward = (-global_basis.z * Vector3(1, 0, 1)).normalized()
	var offset = (target.global_position - impact) * Vector3(1, 0, 1)
	var along = offset.dot(forward)
	var lateral = absf(offset.dot(forward.rotated(Vector3.UP, PI / 2.0)))
	return along <= 0.4 and along > -RELEASE_WINDOW and lateral < LATERAL_TOLERANCE


func _release(store, spec, target):
	if _stick_left <= 0:
		# The whole load goes down in one stick, walking across the target.
		_stick_left = stores[store]
	_stick_left -= 1
	super(store, spec, target)


# Ground point a bomb released now would hit (drag ignored: a slight overshoot
# that the stick spacing covers).
func bomb_impact():
	var height = maxf(0.0, global_position.y - _flight._ground_height(global_position))
	var fall = sqrt(2.0 * height / Weapons.GRAVITY)
	var ground_velocity = _flight.flight_velocity() * Vector3(1, 0, 1)
	return global_position * Vector3(1, 0, 1) + ground_velocity * fall


func capture_air(reference):
	var saved = super(reference)
	saved.stick_left = _stick_left
	return saved


func restore_air(saved, entities):
	super(saved, entities)
	_stick_left = saved.stick_left
