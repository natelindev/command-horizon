extends Node3D

## Bounded muzzle sleeves. No per-unit material duplication or work while cold.
const MAX_HOT_WEAPONS = 24
const COOLING = 1.4
var entries := []
var _sleeve := CylinderMesh.new()


func _ready():
	_sleeve.top_radius = .105
	_sleeve.bottom_radius = .105
	_sleeve.height = .26
	_sleeve.radial_segments = 12
	_sleeve.rings = 1
	_sleeve.cap_top = false
	_sleeve.cap_bottom = false
	set_process(false)


func shot(unit):
	if Globals.options.reduced_flashes:
		return
	for entry in entries:
		if entry.unit.get_ref() == unit:
			entry.heat = minf(1.0, entry.heat + .55)
			return
	if entries.size() >= MAX_HOT_WEAPONS:
		return
	var node := MeshInstance3D.new()
	node.mesh = _sleeve
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://source/shaders/3d/weapon_heat.gdshader")
	node.material_override = material
	add_child(node)
	entries.append({"unit": weakref(unit), "node": node, "heat": .55, "material": material})
	set_process(true)
	_update(entries.back(), 0.0)


func _process(delta):
	for index in range(entries.size() - 1, -1, -1):
		var entry = entries[index]
		var unit = entry.unit.get_ref()
		if (
			unit == null
			or unit.is_queued_for_deletion()
			or Globals.options.reduced_flashes
			or entry.heat < .025
		):
			entry.node.queue_free()
			entries.remove_at(index)
		else:
			_update(entry, delta)
	set_process(not entries.is_empty())


func _update(entry, delta):
	entry.heat *= exp(-COOLING * delta)
	var unit = entry.unit.get_ref()
	entry.node.visible = unit.is_visible_in_tree()
	var muzzle = unit.get_node_or_null("ProjectileOrigin")
	if muzzle != null:
		entry.node.global_transform = (
			muzzle.global_transform * Transform3D(Basis(Vector3.RIGHT, PI * .5), Vector3.BACK * .14)
		)
	entry.material.set_shader_parameter("heat", entry.heat)
