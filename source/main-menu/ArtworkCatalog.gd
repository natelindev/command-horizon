extends RefCounted

const Cache = preload("res://source/utils/RuntimeCache.gd")
const BACKGROUNDS = [
	"res://assets/ui/art/bastion-foundry-dawn.png",
	"res://assets/ui/art/helix-relay-night.png",
	"res://assets/ui/art/frontier-convoy-sunset.png",
	"res://assets/ui/art/hangar-battlefield-menu.png",
	"res://assets/ui/art/river-city-menu.png",
]
const COMMANDERS = {"bastion": "aegis", "helix": "nyx", "frontier": "rook"}
const SPEAKERS = [
	"aegis",
	"nyx",
	"rook",
	"voss",
	"kerrigan",
	"elias",
	"cantor",
	"arden",
	"ren",
	"ilan",
	"wren",
	"hask",
	"jory",
]


static func next_background() -> String:
	var state = Cache.bucket("menu_artwork")
	if not state.has("rng"):
		# UI choices must not consume the simulation's random sequence.
		state.rng = RandomNumberGenerator.new()
		state.rng.randomize()
	var choices = BACKGROUNDS.duplicate()
	choices.erase(state.get("last", ""))
	var path: String = choices[state.rng.randi_range(0, choices.size() - 1)]
	state.last = path
	return path


static func portrait_path(speaker: String) -> String:
	return "res://assets/ui/campaign/portraits/%s.png" % speaker if speaker in SPEAKERS else ""


static func commander(faction: String) -> Texture2D:
	return load(portrait_path(COMMANDERS.get(faction, "aegis")))
