extends MeshInstance3D

# Mark diameter relative to the unit's movement radius.
const SPREAD = 2.3
const Cache = preload("res://source/utils/RuntimeCache.gd")

var _unit = null
var _last_position := Vector3.INF
var _last_selected := false
var _last_elevated := false
var _selection: Node = null
var _has_air_marker := false


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
	_selection = unit.get_node_or_null("Selection")
	_has_air_marker = unit.has_node("AirToTerrainMarker")
	set_process(true)


func _process(_delta):
	if not is_instance_valid(_unit):
		return
	var selected: bool = _unit.is_in_group("selected_units")
	if selected:
		if not _last_selected:
			_last_selected = true
			visible = false
		return
	var unit_pos: Vector3 = _unit.global_position
	if not _last_selected and unit_pos == _last_position:
		return
	_last_selected = false
	_last_position = unit_pos
	if _selection == null:
		_selection = _unit.get_node_or_null("Selection")
	_last_elevated = _selection != null and _selection._on_elevated_ground()
	visible = not _last_elevated
	if _has_air_marker:
		var ground = 0.0
		if (
			"_match" in _unit
			and is_instance_valid(_unit._match)
			and is_instance_valid(_unit._match.map)
		):
			ground = _unit._match.map.height_at(Vector2(unit_pos.x, unit_pos.z))
		position.y = ground - unit_pos.y
