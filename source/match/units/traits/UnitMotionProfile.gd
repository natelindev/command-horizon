extends RefCounted

# A private random stream: cosmetics never consume the simulation's global RNG.
var random = RandomNumberGenerator.new()
var phase: float
var cadence: float
var amplitude: float
var idle_delay: float
var idle_period: float
var recoil_duration = 0.24
var recoil_strength = 1.0
var recoil_roll = 0.0


func _init(identity: int):
	random.seed = identity * 104729 + 73819
	phase = random.randf_range(0.0, TAU)
	cadence = random.randf_range(0.88, 1.12)
	amplitude = random.randf_range(0.8, 1.2)
	idle_delay = random.randf_range(4.0, 7.5)
	idle_period = random.randf_range(6.0, 10.0)


func next_shot():
	# Quick return, soft suspension, or a firmer kick; no shot/cooldown delay.
	var variant = random.randi_range(0, 2)
	recoil_duration = [0.19, 0.28, 0.34][variant] * random.randf_range(0.95, 1.05)
	recoil_strength = random.randf_range(0.85, 1.15)
	recoil_roll = random.randf_range(-0.012, 0.012)


func death_motion(infantry: bool, airborne: bool, mobile: bool) -> Dictionary:
	var angle = random.randf_range(-PI, PI)
	var tilt = random.randf_range(1.25, 1.55) if infantry else random.randf_range(0.10, 0.24)
	if airborne:
		tilt = random.randf_range(0.55, 1.1)
	if not mobile:
		tilt = 0.0
	var slide = random.randf_range(0.08, 0.25) if mobile else 0.0
	return {
		"tilt":
		Vector3(
			cos(angle) * tilt, random.randf_range(-0.12, 0.12) if mobile else 0.0, sin(angle) * tilt
		),
		"slide": Vector3(sin(angle), 0, -cos(angle)) * slide,
		"duration": random.randf_range(0.5, 0.95) if not airborne else random.randf_range(0.9, 1.4),
		"sink_start": random.randf_range(5.5, 6.4),
		"airborne": airborne,
		"mobile": mobile,
	}
