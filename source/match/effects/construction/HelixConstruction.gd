extends "res://source/match/effects/construction/ConstructionRig.gd"

# Helix: four emitter pylons frame a fabrication pad. A glowing scan frame rides the
# print line up the pylons while nanite motes drift off the freshly printed layer.

const SHELL = Color("e4eaee")
const BASE = Color("1b2630")
const ENERGY = Color("5fe3ff")
const STANDOFF = .28

var _frame
var _height = 1.0


func _build():
	emit_interval = .16
	var shell = finish("helix-shell", Color.WHITE, .15, .28)
	var glow = finish("helix-energy", ENERGY, 0.0, .3, 2.6)
	var lo = bounds.position - Vector3(STANDOFF, 0, STANDOFF)
	var hi = bounds.end + Vector3(STANDOFF, 0, STANDOFF)
	_height = bounds.end.y + .35
	var center = bounds.get_center()
	for corner in [
		Vector3(lo.x, 0, lo.z),
		Vector3(hi.x, 0, lo.z),
		Vector3(lo.x, 0, hi.z),
		Vector3(hi.x, 0, hi.z)
	]:
		var inward = (Vector3(center.x, 0, center.z) - corner).normalized()
		var yaw = atan2(inward.x, inward.z)
		_add(
			"Pylons",
			BOX,
			shell,
			block(corner + Vector3(0, .06, 0), Vector3(.3, .12, .3), yaw),
			BASE
		)
		_add(
			"Pylons",
			BOX,
			shell,
			block(corner + Vector3(0, _height * .5, 0), Vector3(.1, _height, .14), yaw),
			SHELL
		)
		_add(
			"Glow",
			BOX,
			glow,
			block(
				corner + inward * .075 + Vector3(0, _height * .5, 0),
				Vector3(.035, _height - .2, .02),
				yaw
			)
		)
		_add(
			"Glow",
			BOX,
			glow,
			block(corner + Vector3(0, _height + .06, 0), Vector3(.13, .1, .13), yaw)
		)
	# A thin pad outline marks the fabrication footprint from any zoom level.
	for edge in [
		[Vector3(lo.x, .025, lo.z), Vector3(hi.x, .025, lo.z)],
		[Vector3(lo.x, .025, hi.z), Vector3(hi.x, .025, hi.z)],
		[Vector3(lo.x, .025, lo.z), Vector3(lo.x, .025, hi.z)],
		[Vector3(hi.x, .025, lo.z), Vector3(hi.x, .025, hi.z)]
	]:
		_add("Glow", BOX, glow, rod(edge[0], edge[1], .04))
	_frame = Node3D.new()
	_frame.name = "ScanFrame"
	add_child(_frame)
	var size = hi - lo
	for edge in [
		[Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z)],
		[Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z)],
		[Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z)],
		[Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z)]
	]:
		_add("ScanBars", BOX, glow, rod(edge[0], edge[1], .045), Color.WHITE, 0.0, _frame)
	var sheet = MeshInstance3D.new()
	sheet.name = "ScanSheet"
	var plane = PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	sheet.mesh = plane
	sheet.position = Vector3(center.x, 0, center.z)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.material_override = _sheet_material()
	_frame.add_child(sheet)


static func _sheet_material():
	var finishes = Cache.bucket("construction_finishes")
	var key = "helix-sheet"
	if not finishes.has(key):
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(.45, .9, 1.0, .07)
		finishes[key] = material
	return finishes[key]


func update(_delta):
	var bob = 0.0 if steady else sin(work * 2.4) * .06
	_frame.position.y = clampf(front_height() + .04 + bob, .05, _height)


func emit_effects(effects, random):
	var inset = bounds.size * .22
	for index in 2:
		var local_point = Vector3(
			random.randf_range(bounds.position.x + inset.x, bounds.end.x - inset.x),
			front_height() + .05,
			random.randf_range(bounds.position.z + inset.z, bounds.end.z - inset.z)
		)
		effects.construction_puff(
			"mote",
			_site_point(local_point),
			Vector3(random.randf_range(-.12, .12), random.randf_range(.35, .7), 0),
			Color("8aeeff"),
			random.randf_range(.1, .16)
		)
