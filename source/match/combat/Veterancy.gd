extends RefCounted

## Experience rewards damage actually dealt to enemy armies, never scenery,
## friendly fire, overkill or raw survival time. The award is normalized by the
## victim's maximum health so rapid-fire weapons do not earn ranks faster.
const THRESHOLDS = [100.0, 300.0, 600.0]
const NAMES = ["Recruit", "Bronze", "Silver", "Gold"]
const MAX_EXPERIENCE = 600.0


static func rank_for(experience: float) -> int:
	var rank = 0
	for threshold in THRESHOLDS:
		if experience >= threshold:
			rank += 1
	return rank


static func eligible(unit) -> bool:
	return (
		is_instance_valid(unit)
		and unit is Node
		and "experience" in unit
		and unit.hp != null
		and unit.hp > 0
		and not unit.is_queued_for_deletion()
		and unit.movement_speed > 0
		and unit.attack_damage != null
		and unit.attack_damage > 0
	)


static func award(source, target, actual_damage: float, killed: bool):
	if (
		not eligible(source)
		or not target.is_in_group("units")
		or load("res://source/match/Players.gd").allied(source.player, target.player)
		or target.hp_max == null
		or target.hp_max <= 0
		or actual_damage <= 0
	):
		return
	source.experience += 100.0 * actual_damage / target.hp_max + (25.0 if killed else 0.0)


static func reload_factor(rank: int) -> float:
	return 1.0 - 0.04 * clampi(rank, 0, 3)


static func speed_factor(rank: int) -> float:
	return 1.0 + 0.03 * clampi(rank, 0, 3)


static func description(experience: float) -> String:
	var rank = rank_for(experience)
	var label = TranslationServer.translate(NAMES[rank])
	if rank == 0:
		return label
	return (
		"%s · %s"
		% [
			label,
			(
				TranslationServer.translate("Reload %d%% faster · Movement +%d%%")
				% [rank * 4, rank * 3]
			)
		]
	)
