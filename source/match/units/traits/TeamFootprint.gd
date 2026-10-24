extends MeshInstance3D

# Mark diameter relative to the unit's movement radius.
const SPREAD = 2.3
const Cache = preload("res://source/utils/RuntimeCache.gd")


func _init(unit):
	name = "TeamFootprint"
	var meshes = Cache.bucket("team_footprint_meshes")
	if not meshes.has("plane"):
		var plane = PlaneMesh.new()
		plane.size = Vector2.ONE
		meshes.plane = plane
	mesh = meshes.plane
	material_override = unit.player.get_footprint_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var diameter = maxf(.5, unit.radius * SPREAD)
	scale = Vector3(diameter, 1.0, diameter)
