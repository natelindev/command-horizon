extends RefCounted

enum Mass { LIGHT, MEDIUM, HEAVY }
const HEAVY_TYPES = ["Tank", "AdvancedTank", "SiegeColossus", "BattleRig", "MobileRig"]
const LIGHT_TYPES = [
	"Infantry", "RocketInfantry", "AntiAirInfantry", "Commando", "Hero", "Drone", "ReconDrone"
]


static func mass_tier(unit) -> int:
	if unit.type in HEAVY_TYPES:
		return Mass.HEAVY
	if (
		unit.type in LIGHT_TYPES
		or unit.type.ends_with("Infantry")
		or unit.type.begins_with("Mercenary")
	):
		return Mass.LIGHT
	return Mass.MEDIUM


# A private random stream: cosmetics never consume the simulation's global RNG.
var random = RandomNumberGenerator.new()
var phase: float
var cadence: float
var amplitude: float
var idle_delay: float
var idle_period: float
# Per-unit gait and response variation keeps squads and convoys out of lockstep.
var stride_scale: float
var lead_foot: int
var yaw_response: float
var drift_rates: Vector3
var recoil_duration := 0.24
var recoil_strength := 1.0
var recoil_roll := 0.0


func _init(identity: int):
	random.seed = identity * 104729 + 73819
	phase = random.randf_range(0.0, TAU)
	cadence = random.randf_range(0.88, 1.12)
	amplitude = random.randf_range(0.8, 1.2)
	idle_delay = random.randf_range(4.0, 7.5)
	idle_period = random.randf_range(6.0, 10.0)
	stride_scale = random.randf_range(0.94, 1.06)
	lead_foot = random.randi_range(0, 1)
	yaw_response = random.randf_range(0.9, 1.1)
	drift_rates = Vector3(
		random.randf_range(0.55, 0.8), random.randf_range(0.9, 1.3), random.randf_range(0.4, 0.62)
	)


func next_shot():
	# Quick return, soft suspension, or a firmer kick; no shot/cooldown delay.
	var variant = random.randi_range(0, 2)
	recoil_duration = [0.19, 0.28, 0.34][variant] * random.randf_range(0.95, 1.05)
	recoil_strength = random.randf_range(0.85, 1.15)
	recoil_roll = random.randf_range(-0.012, 0.012)


func next_fidget(kinds: int) -> int:
	return random.randi_range(0, kinds - 1)


func death_motion(
	infantry: bool, airborne: bool, mobile: bool, away = Vector3.ZERO, facing = Basis()
) -> Dictionary:
	# Tilt (x, z) topples the body toward local (-sin a, 0, cos a). Fall away from
	# the last hit when one is known (local space); otherwise any direction.
	var angle = random.randf_range(-PI, PI)
	if not away.is_zero_approx():
		angle = atan2(-away.x, away.z) + random.randf_range(-0.5, 0.5)
	var tilt = random.randf_range(1.25, 1.55) if infantry else random.randf_range(0.10, 0.24)
	if airborne:
		tilt = random.randf_range(0.55, 1.1)
	if not mobile:
		tilt = 0.0
	var slide = random.randf_range(0.08, 0.25) if mobile else 0.0
	var duration = random.randf_range(0.5, 0.95) if not airborne else random.randf_range(0.9, 1.4)
	if infantry:
		# Knees give way before the body topples, so the fall reads as a collapse.
		duration = random.randf_range(0.85, 1.2)
	return {
		"tilt":
		Vector3(
			cos(angle) * tilt, random.randf_range(-0.12, 0.12) if mobile else 0.0, sin(angle) * tilt
		),
		# World-space drift in the direction of the fall.
		"slide": (facing * Vector3(-sin(angle), 0, cos(angle))) * Vector3(1, 0, 1) * slide,
		"duration": duration,
		"sink_start": random.randf_range(5.5, 6.4),
		"airborne": airborne,
		"mobile": mobile,
		"infantry": infantry,
		# Infantry slump to match the fall: forward, backward or sideways.
		"style": 1 if cos(angle) > .35 else (0 if cos(angle) < -.35 else 2),
		"spin": _spin() if airborne else 0.0,
	}


func _spin():
	# Stricken aircraft yaw as they fall instead of dropping like a stone.
	return random.randf_range(2.2, 4.5) * (-1.0 if random.randf() < 0.5 else 1.0)
