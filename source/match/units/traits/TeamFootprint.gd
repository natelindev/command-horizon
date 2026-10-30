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
	set_process(true)


func _process(_delta):
	if not is_instance_valid(_unit):
		return
	var selection = _unit.get_node_or_null("Selection")
	var elevated = selection != null and selection._on_elevated_ground()
	visible = not _unit.is_in_group("selected_units") and not elevated
	if _unit.has_node("AirToTerrainMarker"):
		var ground = 0.0
		if "_match" in _unit and is_instance_valid(_unit._match) and is_instance_valid(_unit._match.map):
			ground = _unit._match.map.height_at(Vector2(_unit.global_position.x, _unit.global_position.z))
		position.y = ground - _unit.global_position.y
