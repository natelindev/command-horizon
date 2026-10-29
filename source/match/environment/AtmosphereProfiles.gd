extends RefCounted

# Daytime art direction per biome: warm key light against a cooler fill, biome haze,
# and a restrained split-tone grade (cool lifted shadows, warm or neutral highlights).
# Curves are per-channel sRGB lookups applied after tonemapping.
const PROFILES = {
	"desert":
	{
		"key": Color("ffe2bd"),
		"fill": Color("8ea7c4"),
		"haze": Color("d6c2a6"),
		"exposure": .9,
		"contrast": 1.08,
		"saturation": 1.02,
		"shadows": Color(.02, .03, .055),
		"midtones": Color(.505, .5, .49),
		"highlights": Color(1.0, .985, .955),
	},
	"alpine":
	{
		"key": Color("fff2e0"),
		"fill": Color("8fb0d8"),
		"haze": Color("c4d3e0"),
		"exposure": .84,
		"contrast": 1.1,
		"saturation": 1.0,
		"shadows": Color(.015, .03, .065),
		"midtones": Color(.49, .5, .52),
		"highlights": Color(.99, .99, 1.0),
	},
	"coastal":
	{
		"key": Color("fff0d7"),
		"fill": Color("94b6c9"),
		"haze": Color("b5cdd6"),
		"exposure": .92,
		"contrast": 1.06,
		"saturation": 1.05,
		"shadows": Color(.02, .04, .055),
		"midtones": Color(.5, .5, .49),
		"highlights": Color(1.0, .98, .94),
	},
	"urban":
	{
		"key": Color("ffe3b9"),
		"fill": Color("9aabbe"),
		"haze": Color("b8bfc2"),
		"exposure": .92,
		"contrast": 1.08,
		"saturation": .97,
		"shadows": Color(.025, .03, .045),
		"midtones": Color(.5, .5, .49),
		"highlights": Color(1.0, .97, .92),
	},
	"temperate":
	{
		"key": Color("fff0d8"),
		"fill": Color("9db2c6"),
		"haze": Color("b3c3c9"),
		"exposure": .95,
		"contrast": 1.05,
		"saturation": 1.04,
		"shadows": Color(.02, .03, .045),
		"midtones": Color(.5, .5, .49),
		"highlights": Color(1.0, .98, .94),
	},
}

const BIOMES = {
	"DesertFrontier": "desert",
	"BastionDesert": "desert",
	"FirstOrdersMap": "desert",
	"SupplyLineMap": "desert",
	"AlpineRelay": "alpine",
	"SplitSignalMap": "alpine",
	"CoastalFoundry": "coastal",
	"IndustrialCrossroads": "urban",
	"BrokenFoundryMap": "urban",
	"CommandHorizonMap": "urban",
}


static func biome(map):
	var path = ""
	if map != null and "scene_file_path" in map:
		path = String(map.scene_file_path)
	var authored = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd").layout(path)
	if not authored.is_empty():
		return authored.get("biome", "temperate")
	var name = path.get_file().get_basename()
	return BIOMES.get(name, "temperate")


static func for_map(map):
	return PROFILES[biome(map)]


static func grade(profile):
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .5, 1.0])
	gradient.colors = PackedColorArray([profile.shadows, profile.midtones, profile.highlights])
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 256
	return texture
