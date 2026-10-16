extends RefCounted

# Skirmish commander levels. A level changes decisions only: every commander pays
# the same prices, gathers at the same rates and fields identical units. Normal
# is the reference commander that balance and the AI regressions are tuned for.
const EASY = 0
const NORMAL = 1
const HARD = 2
const NAMES = ["Easy", "Normal", "Hard"]
const TAGS = ["Easy AI", "Normal AI", "Hard AI"]
const DESCRIPTIONS = [
	"Builds slowly, attacks late with small groups and seldom retreats or uses abilities.",
	"Steady economy, regular attack waves, field repairs and unit programs.",
	"More engineers, a second factory, early coordinated waves and disciplined retreats.",
]
const FULL_RESEARCH = ["weapons_1", "armor_1", "service", "doctrine", "weapons_2", "armor_2"]
const PROFILES = [
	{
		# Seconds between commander decisions; slower play also delays reactions.
		"decision_interval": 3.0,
		# Simulation time before the first wave and between later offensive waves.
		"first_wave": 180.0,
		"wave_interval": 100.0,
		# Simultaneous strategic tasks and raid responses (assault, guard, capture...).
		"task_groups": 1,
		# Engineer target and the multiplier applied to optional building timings.
		"workers": 5,
		"timing_scale": 1.35,
		# Largest committed assault (0: every free combatant joins).
		"assault_limit": 6,
		# Standing army cap in units (0: population limit only). It starts at
		# army_start and grows by one unit every army_ramp seconds, so the opening
		# stays gentle and the commander never masses a late-game army.
		"army_limit": 14,
		"army_start": 3,
		"army_ramp": 30.0,
		# Additional vehicle factories beyond the first.
		"extra_factories": 0,
		# Research path and the standing guards required before starting upgrades.
		"research": ["weapons_1", "armor_1"],
		"research_guards": 8,
		# Wounded units withdraw for repair below this health fraction (0: never).
		"retreat_health": 0.0,
		# Defenders sent against each observed raid.
		"defense_responders": 4,
		# Unit programs and faction signature abilities.
		"programs": false,
		"signatures": false,
	},
	{
		"decision_interval": 1.5,
		"first_wave": 120.0,
		"wave_interval": 65.0,
		"task_groups": 2,
		"workers": 6,
		"timing_scale": 1.0,
		"assault_limit": 0,
		"army_limit": 0,
		"army_start": 0,
		"army_ramp": 1.0,
		"extra_factories": 0,
		"research": FULL_RESEARCH,
		"research_guards": 6,
		"retreat_health": 0.3,
		"defense_responders": 6,
		"programs": true,
		"signatures": true,
	},
	{
		"decision_interval": 0.75,
		"first_wave": 75.0,
		"wave_interval": 40.0,
		"task_groups": 3,
		"workers": 8,
		"timing_scale": 1.0,
		"assault_limit": 0,
		"army_limit": 0,
		"army_start": 0,
		"army_ramp": 1.0,
		"extra_factories": 1,
		"research": FULL_RESEARCH,
		"research_guards": 4,
		"retreat_health": 0.4,
		"defense_responders": 8,
		"programs": true,
		"signatures": true,
	},
]
# A second factory is not useful before the first production cycle is paid for.
const EXTRA_FACTORY_TIME = 210.0


static func clamp_level(level):
	return clampi(int(level), EASY, HARD)


static func of(level):
	return PROFILES[clamp_level(level)]


static func name_of(level):
	return NAMES[clamp_level(level)]


static func army_cap(level, seconds):
	# Mobile units the commander will keep ordered or fielded; 0 means uncapped.
	var profile = of(level)
	if profile.army_limit <= 0:
		return 0
	return mini(profile.army_limit, profile.army_start + floori(seconds / profile.army_ramp))
