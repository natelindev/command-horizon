extends RefCounted

## Pure Risk-the-Batch Refining constants and deterministic conversion math.
## Never preload autoload-dependent scripts here; SnapshotSchema and headless
## tests import this module before autoloads exist.

const BASTION_BATCHES = {
	"standard": {"raw": 30, "refined": 12, "duration": 15.0, "requires": ""},
	"heavy": {"raw": 60, "refined": 30, "duration": 30.0, "requires": ""},
	"super_heavy":
	{"raw": 100, "refined": 60, "duration": 42.0, "requires": "pressurized_furnaces"},
}
const BASTION_FIELD_FED_WINDOW = 15.0
const BASTION_FIELD_FED_BONUS = 0.20
const BASTION_OVERPRESSURE_BONUS = 0.30
const BASTION_OVERPRESSURE_POWER = 4
const BASTION_OVERPRESSURE_COOLDOWN = 15.0
const BASTION_ABORT_REFUND = 0.50
const BASTION_PRESSURIZED_ABORT_REFUND = 0.80
const BASTION_PRESSURIZED_SPLASH_FACTOR = 0.75
const BASTION_FORTRESS_IDLE_REPAIR = 4.0
const BASTION_SLAG_SURGE_RADIUS = 8.0
const BASTION_SLAG_SURGE_FACTOR = 1.25
const BASTION_SLAG_SURGE_DURATION = 15.0
const BASTION_RUPTURE_DAMAGE = 45.0
const BASTION_RUPTURE_RADIUS = 3.5

const HELIX_SIPHON_RATE = 2.0
const HELIX_MIN_SPACING = 8.0
const HELIX_LATTICE_RANGE = 14.0
const HELIX_LATTICE_AURA_RADIUS = 10.0
const HELIX_LATTICE_SHIELD_AURA = 6.0
const HELIX_BROWNOUT_BLEED = 0.12
const HELIX_BROWNOUT_CANCEL = 2.0
const HELIX_FAILSAFE_GRACE = 6.0
const HELIX_EMP_RADIUS = 4.5
const HELIX_EMP_SHIELD_DRAIN = 50.0
const HELIX_EMP_STALL = 1.5
const HELIX_OVERLOAD_PULSE_RADIUS = 10.0
const HELIX_TIERS = {
	1: {"time": 15.0, "raw": 30.0, "refined": 12, "requires": ""},
	2: {"time": 30.0, "raw": 60.0, "refined": 32, "requires": ""},
	3: {"time": 45.0, "raw": 90.0, "refined": 60, "requires": ""},
	4: {"time": 60.0, "raw": 120.0, "refined": 100, "requires": "harmonic_lattice"},
}

const FRONTIER_BATCH_RAW = 24
const FRONTIER_BATCH_REFINED = 12
const FRONTIER_BATCH_DURATION = 16.0
const FRONTIER_DEPLOY_SECONDS = 1.5
const FRONTIER_PACK_SECONDS = 2.0
const FRONTIER_QUICK_PACK_SECONDS = 0.5
const FRONTIER_HOT_ZONE_RADIUS = 10.0
const FRONTIER_HOT_ZONE_BONUS = 0.40
const FRONTIER_BLAST_DAMAGE = 40.0
const FRONTIER_BLAST_RADIUS = 4.0
const FRONTIER_GUERRILLA_BLAST_DAMAGE = 80.0
const FRONTIER_GUERRILLA_BLAST_RADIUS = 5.5
const FRONTIER_FUEL_INJECT_RADIUS = 9.0
const FRONTIER_FUEL_INJECT_DURATION = 15.0
const FRONTIER_FUEL_INJECT_FACTOR = 1.25
const FRONTIER_FENCE_RAW = 40
const FRONTIER_FENCE_REFINED = 10
const FRONTIER_FENCE_COOLDOWN = 25.0

const SPILL_MIN_PROGRESS = 0.20
const SPILL_SHARE = 0.45
const SPILL_MIN_REFINED = 4
const CANISTER_LIFETIME = 90.0
const CANISTER_CLAIM_SECONDS = 0.5
const CATALYST_RADIUS = 12.0
const CATALYST_BONUS = 0.20
const RELAY_CANISTER_INTERVAL = 60.0
const RELAY_CANISTER_REFINED = 15


static func has_tech(player, tech_id: String) -> bool:
	if tech_id.is_empty():
		return true
	return (
		player != null
		and "technology" in player
		and player.technology != null
		and tech_id in player.technology.completed
	)


static func bastion_batch(batch_id: String) -> Dictionary:
	return BASTION_BATCHES.get(batch_id, BASTION_BATCHES.standard)


static func bastion_batch_unlocked(player, batch_id: String) -> bool:
	if not BASTION_BATCHES.has(batch_id):
		return false
	return has_tech(player, BASTION_BATCHES[batch_id].requires)


static func helix_tier(tier: int) -> Dictionary:
	return HELIX_TIERS.get(clampi(tier, 1, 4), HELIX_TIERS[1])


static func helix_tier_for_charge(charge_seconds: float, max_tier: int = 3) -> int:
	var reached = 0
	for tier in range(1, clampi(max_tier, 1, 4) + 1):
		if charge_seconds + 0.0001 >= HELIX_TIERS[tier].time:
			reached = tier
	return reached


static func helix_yield_for_charge(charge_seconds: float, max_tier: int = 3) -> int:
	if charge_seconds <= 0.0:
		return 0
	var capped = minf(charge_seconds, HELIX_TIERS[clampi(max_tier, 1, 4)].time)
	var reached = helix_tier_for_charge(capped, max_tier)
	if reached == 0:
		var t1 = HELIX_TIERS[1]
		return floori(t1.refined * (capped / t1.time))
	var base = HELIX_TIERS[reached]
	var extra_seconds = maxf(0.0, capped - base.time)
	var base_rate = float(base.refined) / base.time
	return int(base.refined) + floori(extra_seconds * base_rate)


static func spill_amount(accrued_refined: float, progress: float) -> int:
	if progress < SPILL_MIN_PROGRESS or accrued_refined <= 0.0:
		return 0
	return maxi(SPILL_MIN_REFINED, floori(accrued_refined * SPILL_SHARE))
