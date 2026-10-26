extends RefCounted


## Stable phases spread swarm perception across ticks. First checks happen
## within the existing interval; recurring cadence and shot timing are unchanged.
static func fraction(unit) -> float:
	var value: int = unit.get_meta("visual_seed", unit.get_instance_id())
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff
	value ^= value >> 16
	return float(value & 0xffffff) / 16777216.0


static func first_delay(unit, interval: float) -> float:
	return maxf(.001, interval * fraction(unit))
