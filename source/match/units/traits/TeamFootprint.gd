extends MeshInstance3D

# Mark diameter relative to the unit's movement radius.
const SPREAD = 2.3
const Cache = preload("res://source/utils/RuntimeCache.gd")

var _unit = null


func _init(unit):
	name = "TeamFootprint"
	_unit = unit
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
	if _unit.has_node("AirToTerrainMarker"):
		set_process(true)
	else:
		set_process(false)


func _process(_delta):
	if _unit != null and is_instance_valid(_unit):
		position.y = -_unit.position.y
