extends RefCounted

## Shared presentation rules; bands never change authoritative movement or damage.
const PROFILES = {
	"bastion": {"interval": .45, "socket": Vector3(.25, .65, .5), "cue": "damage_diesel"},
	"helix": {"interval": .4, "socket": Vector3(.35, .55, .15), "cue": "damage_plasma"},
	"frontier": {"interval": .5, "socket": Vector3(-.25, .65, -.35), "cue": "damage_steam"},
}


static func band_for(ratio: float, previous: int) -> int:
	if ratio <= 0.0:
		return 0
	if ratio < .25 or (previous == 2 and ratio <= .28):
		return 2
	if ratio < .50 or (previous > 0 and ratio <= .53):
		return 1
	return 0


static func profile(faction: String) -> Dictionary:
	return PROFILES.get(faction, PROFILES.bastion)
