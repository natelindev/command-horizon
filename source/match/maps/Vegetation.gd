extends RefCounted

# Reuse the shipped models at world sizes that read beside soldiers and vehicles.
const ROOT = "res://assets/models/environment/"
const TREES = {
	"desert":
	[
		"desert/DesertAcacia",
		"desert/DesertMesquite",
		"desert/DesertJuniper",
		"desert/DesertWindswept"
	],
	"alpine": ["alpine/SnowPineGrove"],
	"coastal": ["coastal/CoastalPineStand", "coastal/ShorePines"],
	"urban": ["industrial-surroundings/BirchScrub"]
}
static var _heights = {}


static func tree(biome, index, height = 7.0):
	var variants = TREES.get(biome, TREES.desert)
	var model = load(ROOT + variants[index % variants.size()] + ".glb").instantiate()
	fit_height(model, height)
	model.set_meta("vegetation_kind", "tree")
	return model


static func bush(index):
	var model = load(ROOT + "industrial-surroundings/BirchScrub.glb").instantiate()
	fit_height(model, 1.6 + (index % 3) * .15)
	model.set_meta("vegetation_kind", "bush")
	return model


static func fit_height(model, height):
	# Call on a fresh model before setting its placement scale. Cache one mesh
	# traversal per shared asset; no vegetation code runs during simulation.
	var path = model.scene_file_path
	if not _heights.has(path):
		_heights[path] = bounds(model).size.y
	var original: float = _heights[path]
	if original > .001:
		model.scale *= height / original
	model.set_meta("vegetation_height", height)
	model.set_meta("vegetation_kind", "tree")


static func fit_footprint(model, radius):
	# Preserve the authored ground obstacle when a mature tree grows taller.
	var box = bounds(model)
	var reach = (
		Vector2(
			maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z))
		)
		. length()
	)
	if reach > radius:
		model.scale *= Vector3(radius / reach, 1.0, radius / reach)


static func bounds(node, frame = Transform3D.IDENTITY):
	var current: Transform3D = frame * node.transform if node is Node3D else frame
	var result = current * node.get_aabb() if node is MeshInstance3D else AABB()
	for child in node.get_children():
		var box: AABB = bounds(child, current)
		if box.has_volume():
			result = result.merge(box) if result.has_volume() else box
	return result
