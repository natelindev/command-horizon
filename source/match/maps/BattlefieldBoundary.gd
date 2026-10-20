extends MeshInstance3D

# The scenic landscape continues beyond navigation and mouse-targeting space.
# Mark the land outline once, without adding physics bodies or per-frame work.
const DASH_LENGTH = 2.0
const DASH_GAP = 1.5
const ELEVATED_PIECE = 0.5


func _ready():
	name = "BattlefieldBoundary"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var polygon = PackedVector2Array(get_parent().get_topdown_polygon_2d())
	var outlines = Geometry2D.offset_polygon(polygon, -.35)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	for outline in outlines:
		for index in outline.size():
			var start = outline[index]
			var end = outline[(index + 1) % outline.size()]
			_strip(surface, start, end, .3, .045, Color("303b40"))
			var direction = (end - start).normalized()
			var length = start.distance_to(end)
			var distance = 0.0
			while distance < length:
				_strip(
					surface,
					start + direction * distance,
					start + direction * minf(distance + DASH_LENGTH, length),
					.13,
					.055,
					Color("e6b75a")
				)
				distance += DASH_LENGTH + DASH_GAP
	mesh = surface.commit()


func _strip(surface, start, end, half_width, height, color):
	var map = get_parent()
	# On elevated terrain the line drapes over tiers in short pieces.
	if map.is_elevated() and start.distance_to(end) > ELEVATED_PIECE:
		var pieces = ceili(start.distance_to(end) / ELEVATED_PIECE)
		for piece in pieces:
			_strip(
				surface,
				start.lerp(end, float(piece) / pieces),
				start.lerp(end, float(piece + 1) / pieces),
				half_width,
				height,
				color
			)
		return
	var direction = (end - start).normalized()
	var side = Vector2(-direction.y, direction.x) * half_width
	var corners = [start - side, start + side, end + side, end - side]
	surface.set_color(color)
	surface.set_normal(Vector3.UP)
	for index in [0, 1, 2, 0, 2, 3]:
		var point = corners[index]
		surface.add_vertex(Vector3(point.x, map.height_at(point) + height, point.y))
