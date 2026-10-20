extends RefCounted

# Scanned CC0 ground layers; see assets/textures/terrain/README.md. Layers load
# on first use, so a match only keeps the textures its map shows.
const ROOT = "res://assets/textures/terrain/"
const SLOTS = ["base", "path", "accent"]
# Physical width of each scan in metres.
const TILES = {
	"grass": 15.0,
	"ground_rock": 20.0,
	"sand": 15.0,
	"coast_sand": 15.0,
	"dirt": 25.0,
	"asphalt": 30.0,
	"snow": 80.0,
	# Stretched from 5 m: its stains repeat as a visible camouflage pattern at scale.
	"concrete": 7.5,
}
# Default detail strength per scan; presets may override per slot.
const STRENGTH = {"concrete": .55}
# Base fills the field, path follows roads and tracks, accent carries the
# biome feature (bare patches, salt crust, snow or exposed rock).
const PRESETS = {
	"temperate": {"base": "grass", "path": "dirt", "accent": "ground_rock"},
	"desert": {"base": "ground_rock", "path": "sand", "accent": "sand"},
	# Pebbles under pale snow tones and the snow scan's dark shrubs both read as
	# clutter at full strength; keep them as faint texture.
	"alpine":
	{
		"base": "ground_rock",
		"path": "dirt",
		"accent": "snow",
		"base_strength": .45,
		"accent_strength": .55,
	},
	# Snow throughout: tracks are packed snow and the accent is blue ice.
	"polar":
	{
		"base": "snow",
		"path": "snow",
		"accent": "sand",
		"base_strength": .5,
		"path_strength": .4,
		"accent_strength": .3,
	},
	# Authored works: cinder ground, asphalt roads, bare earth patches.
	"works":
	{
		"base": "ground_rock",
		"path": "asphalt",
		"accent": "dirt",
		"chroma": .3,
		"base_strength": .6,
	},
	# Catalog urban and coastal maps are paved throughout (4 m joints). Concrete
	# fills the whole view there, so its repeating stains stay faint.
	"urban":
	{
		"base": "concrete",
		"path": "asphalt",
		"accent": "dirt",
		"chroma": .2,
		"base_strength": .32,
	},
	"coastal":
	{
		"base": "concrete",
		"path": "dirt",
		"accent": "coast_sand",
		"chroma": .3,
		"base_strength": .32,
	},
}
const SHADER_ROOT = "res://source/shaders/3d/"
# Layers for the dedicated ground shaders, keyed by shader file. Their masks are
# documented where each shader calls terrain_surface().
const SNOWFIELD = {
	"base": "snow",
	"path": "dirt",
	"accent": "ground_rock",
	"base_strength": .55,
	"accent_strength": .6,
}
const DUNES = {"base": "sand", "path": "dirt", "accent": "ground_rock"}
const DISTRICT = {"base": "grass", "path": "asphalt", "accent": "concrete", "chroma": .3}
const WORKS = {"base": "ground_rock", "path": "asphalt", "accent": "concrete", "chroma": .3}
const SHADERS = {
	# Catalog battlefields pass their biome explicitly; scene-authored ones are temperate.
	"battlefield.gdshader": PRESETS.temperate,
	"desert.gdshader": DUNES,
	"frontier.gdshader": DUNES,
	"alpine.gdshader": SNOWFIELD,
	"split_signal.gdshader": SNOWFIELD,
	"coastal_ground.gdshader": DISTRICT,
	"district_ground.gdshader": DISTRICT,
	"foundry_ground.gdshader": DISTRICT,
	"horizon_ground.gdshader": WORKS,
	"supply_ground.gdshader": WORKS,
}


# Configures a ground material from its shader; other materials are left alone.
static func apply(material):
	if not material is ShaderMaterial or material.shader == null:
		return false
	var path = material.shader.resource_path
	if not path.begins_with(SHADER_ROOT) or not SHADERS.has(path.get_file()):
		return false
	configure(material, SHADERS[path.get_file()])
	return true


static func configure(material, layers):
	if layers is String:
		layers = PRESETS[layers]
	for slot in SLOTS:
		var layer = layers[slot]
		material.set_shader_parameter(slot + "_color", load(ROOT + layer + "_color.jpg"))
		material.set_shader_parameter(slot + "_normal", load(ROOT + layer + "_normal.jpg"))
		material.set_shader_parameter(slot + "_data", load(ROOT + layer + "_data.webp"))
		material.set_shader_parameter(slot + "_tile", TILES[layer])
		material.set_shader_parameter(
			slot + "_strength", layers.get(slot + "_strength", STRENGTH.get(layer, .85))
		)
	if layers.has("chroma"):
		material.set_shader_parameter("terrain_chroma", layers.chroma)
