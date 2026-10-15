extends MeshInstance3D

# Mark diameter relative to the unit's movement radius.
const SPREAD = 2.3

static var _plane: PlaneMesh


func _init(unit):
	name = "TeamFootprint"
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.size = Vector2.ONE
	mesh = _plane
	material_override = unit.player.get_footprint_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var diameter = maxf(.5, unit.radius * SPREAD)
	scale = Vector3(diameter, 1.0, diameter)
