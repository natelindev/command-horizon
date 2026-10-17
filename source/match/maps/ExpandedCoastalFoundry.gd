extends "res://source/match/maps/CoastalFoundry.gd"

const Layout = preload("res://source/match/maps/ExpandedMapLayout.gd")
const Opening = preload("res://source/match/maps/StartingResourceLayout.gd")
const EXPANSION = 1.5
const EXTRA_FIELDS = [
	Vector2(24, 96),
	Vector2(168, 96),
	Vector2(58, 143),
	Vector2(134, 143),
]


func overview():
	var result = Layout.overview(
		super.overview(), EXPANSION, EXTRA_FIELDS, Sites.definitions(scene_file_path)
	)
	result.road_width = result.get("road_width", 4.0) * EXPANSION
	return Opening.overview(self, result)


func _ready():
	super._ready()
	Layout.expand(self, FIELDS, EXPANSION)
	exterior.ground.mesh.surface_get_material(0).set_shader_parameter("layout_scale", EXPANSION)
	Layout.add_fields(self, EXTRA_FIELDS, false)
	Opening.apply(self, FIELDS.map(func(field): return field * EXPANSION))


func get_topdown_polygon_2d():
	var polygon = []
	for point in SHORE:
		polygon.append(point * EXPANSION)
	return polygon


func _ground_and_water():
	super._ground_and_water()
	var material = $Geometry/Terrain.mesh.surface_get_material(0)
	material.set_shader_parameter("layout_scale", EXPANSION)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var polygon = PackedVector2Array(get_topdown_polygon_2d())
	var triangles = Geometry2D.triangulate_polygon(polygon)
	for index in triangles:
		var point = polygon[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(point / size)
		surface.add_vertex(Vector3(point.x, 0, point.y))
	$Geometry/Terrain.mesh = surface.commit()
	water_material.set_shader_parameter("layout_scale", EXPANSION)


func _box(point, dimensions, color):
	# Keep continuous seawalls along the larger shoreline. Props retain their size.
	if dimensions.y in [1.65, 0.12]:
		dimensions.z = (dimensions.z - .15) * EXPANSION + .15
	return super._box(point, dimensions, color)
