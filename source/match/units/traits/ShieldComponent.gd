extends RefCounted

## Authoritative shield state. The unit advances this with simulation time so
## pause, manually stepped scenarios and save restoration share the same clock.
signal changed
signal broken
signal recharge_started
signal recharged

const RECHARGE_DELAY = 5.0
const RECHARGE_RATE = 8.0

var charge: float = 0.0
var capacity: float = 0.0
var last_damage_time: float = -INF
var recharge_delay: float = RECHARGE_DELAY
var _recharging = false


func set_capacity(maximum: float):
	maximum = maxf(0.0, maximum)
	if is_equal_approx(maximum, capacity):
		return
	# Equipping shields fills them once; applying unrelated research never heals.
	charge = maximum if capacity == 0.0 else minf(charge, maximum)
	capacity = maximum
	_recharging = false
	changed.emit()


func absorb(amount: float, now: float) -> float:
	if amount <= 0.0 or capacity <= 0.0:
		return amount
	# Hull damage resets the delay even after the shield has collapsed.
	last_damage_time = now
	_recharging = false
	var absorbed = minf(amount, charge)
	if absorbed > 0.0:
		charge -= absorbed
		changed.emit()
		if charge == 0.0:
			broken.emit()
	return amount - absorbed


func drain(amount: float, now: float):
	absorb(amount, now)


func tick(delta: float, now: float, factor: float = 1.0):
	if (
		delta <= 0.0
		or factor <= 0.0
		or capacity <= 0.0
		or charge >= capacity
		or now - last_damage_time < recharge_delay
	):
		return
	if not _recharging:
		_recharging = true
		recharge_started.emit()
	charge = minf(capacity, charge + RECHARGE_RATE * delta * factor)
	changed.emit()
	if charge == capacity:
		_recharging = false
		recharged.emit()
