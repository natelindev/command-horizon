extends RefCounted

## Shared presentation only; purchase eligibility and payments stay in TechnologyResearch.
const Catalog = preload("res://source/match/research/TechnologyCatalog.gd")
const WEAPONS_ICON = preload("res://assets/ui/research/weapons.svg")
const ARMOR_ICON = preload("res://assets/ui/research/armor.svg")
const SERVICE_ICON = preload("res://assets/ui/research/service.svg")
const DOCTRINE_ICON = preload("res://assets/ui/research/doctrine.svg")
const COORDINATION_ICON = preload("res://assets/ui/research/generated/coordination.png")
const ATTACK_ICON = preload("res://assets/ui/hud/icons/attack.svg")
const ICONS = {
	"weapons": WEAPONS_ICON,
	"armor": ARMOR_ICON,
	"service": SERVICE_ICON,
	"doctrine": DOCTRINE_ICON,
	"coordination": COORDINATION_ICON,
	"dual_purpose_aa": WEAPONS_ICON,
	"plasma_shields": preload("res://assets/ui/research/generated/plasma_shields.png"),
	"tank_stabilizers": ATTACK_ICON,
	"tandem_rockets": preload("res://assets/ui/research/generated/tandem_rockets.png"),
	"reactive_armor": preload("res://assets/ui/research/generated/reactive_armor.png"),
	"siege_logistics": preload("res://assets/ui/research/generated/siege_logistics.png"),
	"flux_capacitors": preload("res://assets/ui/research/generated/flux_capacitors.png"),
	"scrap_cannibalization":
	preload("res://assets/ui/research/generated/scrap_cannibalization.png"),
	"high_octane": preload("res://assets/ui/research/generated/high_octane.png"),
	"bunker_reinforcements":
	preload("res://assets/ui/research/generated/bunker_reinforcements.png"),
	"fortress_doctrine": preload("res://assets/ui/research/generated/fortress_doctrine.png"),
	"iron_blitz": preload("res://assets/ui/research/generated/iron_blitz.png"),
	"beam_amplification": preload("res://assets/ui/research/generated/beam_amplification.png"),
	"phase_thrusters": preload("res://assets/ui/research/generated/phase_thrusters.png"),
	"phase_overload": preload("res://assets/ui/research/generated/phase_overload.png"),
	"continuous_coherence": preload("res://assets/ui/research/generated/continuous_coherence.png"),
	"concealed_claymores": preload("res://assets/ui/research/generated/concealed_claymores.png"),
	"guerrilla_insurgency": preload("res://assets/ui/research/generated/guerrilla_insurgency.png"),
	"salvage_war_machine": preload("res://assets/ui/research/generated/salvage_war_machine.png"),
}


static func icon_for(id: String) -> Texture2D:
	var branch = id.trim_suffix("_1").trim_suffix("_2").trim_suffix("_3")
	return ICONS.get(branch, ICONS.coordination)


static func project(player, paused: bool) -> Dictionary:
	var research = player.technology
	if research.active == "" and player.coordination_left <= 0:
		return {}
	var id = research.active if research.active != "" else "coordination"
	var remaining = research.left if research.active != "" else player.coordination_left
	var duration = (
		Catalog.ITEMS[id].seconds if id != "coordination" else Catalog.COORDINATION_DURATION
	)
	var rate = player.research_factor()
	var seconds = ceili(maxf(0, remaining) / rate)
	var percent = 100.0 * clampf(1.0 - remaining / duration, 0.0, 1.0)
	var missing_lab = not player.has_completed_structure("CommandLab")
	var title = _text(Catalog.title(id, player.faction))
	var state = ""
	if missing_lab:
		state = _text("Rebuild lab")
	elif paused:
		state = _text("Paused")
	elif rate < 1.0:
		state = _text("Low power · %d%%") % roundi(rate * 100)
	elif rate > 1.0:
		state = _text("Research rate · %d%%") % roundi(rate * 100)
	var status = _text("%d s · %d%%") % [seconds, floori(percent)]
	if state != "":
		status += " · " + state
	var detail = (
		title
		+ "\n"
		+ (
			_text("%d%% complete. %d s of work remaining at the current research rate.")
			% [floori(percent), seconds]
		)
	)
	detail += "\n" + (_text("Research rate: %d%%.") % roundi(rate * 100))
	if missing_lab:
		detail += (
			"\n"
			+ _text(
				"Research is paused until a friendly lab completes. The project is already paid for."
			)
		)
	if paused:
		detail += "\n" + _text("Resume battle to continue.")
	return {
		"id": id,
		"title": title,
		"seconds": seconds,
		"progress": percent,
		"rate": rate,
		"paused": paused,
		"missing_lab": missing_lab,
		"status": status,
		"summary": title + " · " + status,
		"detail": detail,
	}


static func _text(value: String) -> String:
	return TranslationServer.translate(value)
