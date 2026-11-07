extends RefCounted

# Cosmetic roles only. Combat timing, damage and refraction remain authoritative
# in ProjectileSystem. Width is the whole ribbon, including its soft edge.
const RAIL = {
	"role": 0,
	"prism": false,
	"width": .38,
	"duration": .24,
	"power": 2.5,
	"color": Color("b6d9e1"),
	"core": Color("edfcff")
}
const PRISM = {
	"role": 0,
	"prism": true,
	"width": .72,
	"duration": .28,
	"power": 1.65,
	"color": Color("a08aff"),
	"core": Color("e6edff")
}
const LINK = {
	"role": 1,
	"prism": true,
	"width": .22,
	"duration": .32,
	"power": .8,
	"color": Color("52dcca"),
	"core": Color("a4fff2")
}
const REFRACTION = {
	"role": 2,
	"prism": true,
	"width": .28,
	"duration": .18,
	"power": 1.3,
	"color": Color("ad89ff"),
	"core": Color("dbc9ff")
}
const THERMAL = {
	"role": 3,
	"prism": false,
	"width": .16,
	"duration": .16,
	"power": 1.7,
	"color": Color("ff9670"),
	"core": Color("ffe3b0")
}
const ALL = [RAIL, PRISM, LINK, REFRACTION, THERMAL]


static func for_weapon(faction: String, unit_type: String, weapon: Dictionary) -> Dictionary:
	if weapon.get("id", "") == "thermal_beam":
		return THERMAL
	var prism = weapon.get("prism", false)
	# Legacy callers without a weapon ID still identify the two optical platforms.
	prism = (
		prism
		or (
			not weapon.has("id")
			and faction == "helix"
			and unit_type in ["AdvancedTank", "AntiGroundTurret"]
		)
	)
	if not prism:
		return RAIL
	match weapon.get("beam_role", "primary"):
		"link":
			return LINK
		"refraction":
			return REFRACTION
	return PRISM
