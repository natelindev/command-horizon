extends Node

## Simulation-owned morale pressure; posture never changes physical hit bodies.
signal changed

enum Band { CLEAR, SUPPRESSED, PINNED }

const MAXIMUM = 100.0
const RECOVERY_DELAY = 2.0
const RECOVERY_RATE = 20.0
const NEAR_MISS_LIMIT = 20.0
var meter: float = 0.0
var band: int = Band.CLEAR
var recovery_left: float = 0.0
var near_misses: Array = []


static func eligible(unit) -> bool:
	return (
		unit.type != "Hero" and load("res://source/match/BastionCatalog.gd").is_infantry(unit.type)
	)


func add_pressure(amount: float, near_miss := false) -> float:
	var unit = get_parent()
	if amount <= 0.0 or not eligible(unit) or unit.hp <= 0.0 or unit.has_meta("garrison_host"):
		return 0.0
	if near_miss:
		var spent = 0.0
		for entry in near_misses:
			spent += entry.amount
		amount = minf(amount, maxf(0.0, NEAR_MISS_LIMIT - spent))
		if amount <= 0.0:
			return 0.0
		near_misses.append({"left": 1.0, "amount": amount})
	meter = minf(MAXIMUM, meter + amount)
	recovery_left = RECOVERY_DELAY
	_update_band()
	changed.emit()
	return amount


func _physics_process(delta: float):
	if not is_finite(delta) or delta <= 0.0:
		return
	for entry in near_misses:
		entry.left -= delta
	near_misses = near_misses.filter(func(entry): return entry.left > 0.000001)
	var recovery_delta = maxf(0.0, delta - recovery_left)
	recovery_left = maxf(0.0, recovery_left - delta)
	if meter > 0.0 and recovery_delta > 0.0:
		meter = maxf(0.0, meter - recovery_delta * RECOVERY_RATE)
		_update_band()
		changed.emit()


func _update_band():
	var previous = band
	if meter >= 90.0:
		band = Band.PINNED
	elif band == Band.PINNED and meter >= 80.0:
		pass
	elif meter >= 50.0 or (band != Band.CLEAR and meter >= 45.0):
		band = Band.SUPPRESSED
	else:
		band = Band.CLEAR
	if (previous == Band.CLEAR) != (band == Band.CLEAR):
		_adjust_reload(1.2 if band != Band.CLEAR else 1.0 / 1.2)


func _adjust_reload(ratio: float):
	# Preserve the fraction already reloaded, including the currently ticking shot.
	var unit = get_parent()
	if unit._match == null:
		return
	var now = int(unit._match.simulation_time * 1000.0)
	var ready_at = unit.get_meta("next_attack_availability_time", now)
	if ready_at > now:
		unit.set_meta("next_attack_availability_time", now + roundi((ready_at - now) * ratio))
	for action in unit.find_children("*", "Node", true, false):
		if "_one_shot_timer" in action and is_instance_valid(action._one_shot_timer):
			var timer = action._one_shot_timer
			if (
				timer.time_left > 0.0
				and (not "_charge_left" in action or action._charge_left < 0.0)
			):
				timer.start(timer.time_left * ratio)


func speed_factor() -> float:
	return 0.4 if band == Band.PINNED else (0.7 if band == Band.SUPPRESSED else 1.0)


func reload_factor() -> float:
	return 1.2 if band != Band.CLEAR else 1.0


func direct_damage_factor(weapon: Dictionary) -> float:
	var non_explosive = (
		weapon.get("kind", "") in ["bullet", "rail"] and weapon.get("splash", 0.0) <= 0.0
	)
	return 0.8 if band == Band.PINNED and non_explosive else 1.0


func capture() -> Dictionary:
	return {
		"meter": meter,
		"band": band,
		"recovery_left": recovery_left,
		"near_misses": near_misses.duplicate(true)
	}


func restore(saved: Dictionary):
	meter = clampf(float(saved.get("meter", 0.0)), 0.0, MAXIMUM)
	band = clampi(int(saved.get("band", 0)), Band.CLEAR, Band.PINNED)
	recovery_left = clampf(float(saved.get("recovery_left", 0.0)), 0.0, RECOVERY_DELAY)
	near_misses = saved.get("near_misses", []).duplicate(true)
	changed.emit()
