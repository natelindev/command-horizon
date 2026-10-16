extends "res://source/match/effects/construction/ConstructionRig.gd"

# Bastion: a steel scaffold with hazard-striped toe boards rises one lift ahead of
# the weld line while a yellow gantry crane travels over the site, lowering girders.

const STEEL = Color("8f989d")
const DECK = Color("3b4247")
const HAZARD = [Color("e0a522"), Color("26282a")]
const CRANE = Color("d79a1c")
const DARK = Color("2a2d30")
const LIFT = .6
const STANDOFF = .2

var _gantry
var _trolley
var _cable
var _load
var _span = 1.0
var _crane_height = 1.0
var _travel = 0.0


func _build():
	var steel = finish("scaffold", Color.WHITE, .3, .6)
	var lo = bounds.position - Vector3(STANDOFF, 0, STANDOFF)
	var hi = bounds.end + Vector3(STANDOFF, 0, STANDOFF)
	var levels = ceili((bounds.size.y + .25) / LIFT)
	for level in levels + 1:
		var y = bounds.position.y + level * LIFT
		# Uprights at the corners and every ~1.3 m, one lift tall, keyed by their base.
		if level < levels:
			for point in _perimeter_posts(lo, hi):
				_add(
					"Steel",
					BOX,
					steel,
					rod(Vector3(point.x, y, point.y), Vector3(point.x, y + LIFT, point.y), .05),
					STEEL,
					y
				)
		if level == 0:
			continue
		for corners in [
			[Vector3(lo.x, y, lo.z), Vector3(hi.x, y, lo.z)],
			[Vector3(lo.x, y, hi.z), Vector3(hi.x, y, hi.z)],
			[Vector3(lo.x, y, lo.z), Vector3(lo.x, y, hi.z)],
			[Vector3(hi.x, y, lo.z), Vector3(hi.x, y, hi.z)]
		]:
			_add("Steel", BOX, steel, rod(corners[0], corners[1], .035), STEEL, y - LIFT)
		# Work decks with hazard-striped edges on the two long flanks.
		for x in [lo.x, hi.x]:
			var outward = signf(x - bounds.get_center().x)
			var deck_x = x + outward * .13
			_add(
				"Steel",
				BOX,
				steel,
				block(Vector3(deck_x, y - .02, (lo.z + hi.z) * .5), Vector3(.26, .03, hi.z - lo.z)),
				DECK,
				y - LIFT
			)
			var stripes = maxi(2, roundi((hi.z - lo.z) / .24))
			var stripe = (hi.z - lo.z) / stripes
			for index in stripes:
				_add(
					"Steel",
					BOX,
					steel,
					block(
						Vector3(deck_x + outward * .1, y + .01, lo.z + stripe * (index + .5)),
						Vector3(.08, .04, stripe)
					),
					HAZARD[(index + level) % 2],
					y - LIFT
				)
			# One diagonal brace per lift keeps the frame legible from above.
			var from_z = lo.z if level % 2 == 0 else hi.z
			var to_z = hi.z if level % 2 == 0 else lo.z
			_add(
				"Steel",
				BOX,
				steel,
				rod(Vector3(x, y - LIFT, from_z), Vector3(x, y, to_z), .035),
				STEEL,
				y - LIFT
			)
	_build_gantry(lo, hi)


func _perimeter_posts(lo, hi):
	var posts = []
	var columns = maxi(1, roundi((hi.x - lo.x) / 1.3))
	var rows = maxi(1, roundi((hi.z - lo.z) / 1.3))
	for column in columns + 1:
		var x = lerpf(lo.x, hi.x, float(column) / columns)
		posts.append(Vector2(x, lo.z))
		posts.append(Vector2(x, hi.z))
	for row in range(1, rows):
		var z = lerpf(lo.z, hi.z, float(row) / rows)
		posts.append(Vector2(lo.x, z))
		posts.append(Vector2(hi.x, z))
	return posts


func _build_gantry(lo, hi):
	var rail = finish("rail", Color("2d3135"), .7, .4)
	var yellow = finish("crane", CRANE, .35, .45)
	var dark = finish("crane-dark", DARK, .6, .45)
	var lamp = finish("crane-lamp", Color("ffb24a"), 0.0, .4, 2.4)
	var leg_x = [lo.x - .45, hi.x + .45]
	_span = leg_x[1] - leg_x[0]
	_crane_height = bounds.end.y + .75
	_travel = (hi.z - lo.z) * .32
	for x in leg_x:
		_add(
			"Rails",
			BOX,
			rail,
			block(Vector3(x, .03, bounds.get_center().z), Vector3(.12, .06, hi.z - lo.z + 1.0))
		)
	_gantry = Node3D.new()
	_gantry.name = "Gantry"
	_gantry.position = Vector3(bounds.get_center().x, 0, bounds.get_center().z)
	add_child(_gantry)
	var half = _span * .5
	var frame = finish("crane-frame", Color.WHITE, .35, .45)
	for side in [-1, 1]:
		for offset in [-.32, .32]:
			_add(
				"CraneFrame",
				BOX,
				frame,
				rod(Vector3(side * half, .1, offset), Vector3(side * half, _crane_height, 0), .11),
				CRANE,
				0.0,
				_gantry
			)
		_add(
			"CraneFrame",
			BOX,
			frame,
			block(Vector3(side * half, .08, 0), Vector3(.2, .14, .82)),
			DARK,
			0.0,
			_gantry
		)
		_add(
			"CraneLights",
			BOX,
			lamp,
			block(Vector3(side * half, _crane_height + .14, 0), Vector3(.12, .1, .12)),
			Color.WHITE,
			0.0,
			_gantry
		)
		# Black and yellow warning bands on both girder ends.
		for index in 3:
			_add(
				"CraneFrame",
				BOX,
				frame,
				block(
					Vector3(side * (half + .05 - index * .12), _crane_height, .125),
					Vector3(.06, .2, .01)
				),
				DARK,
				0.0,
				_gantry
			)
	_add(
		"CraneFrame",
		BOX,
		frame,
		block(Vector3(0, _crane_height, 0), Vector3(_span + .3, .2, .24)),
		CRANE,
		0.0,
		_gantry
	)
	_trolley = _part(
		_gantry,
		"Trolley",
		BOX,
		block(Vector3(0, _crane_height - .16, 0), Vector3(.34, .16, .34)),
		dark
	)
	_cable = _part(_gantry, "Cable", BOX, Transform3D(), dark, false)
	_load = Node3D.new()
	_load.name = "Load"
	_gantry.add_child(_load)
	_part(_load, "HookBlock", BOX, block(Vector3(0, .1, 0), Vector3(.14, .16, .1)), yellow)
	_part(
		_load,
		"Girder",
		BOX,
		block(Vector3(0, -.03, 0), Vector3(minf(1.4, _span * .4), .1, .14)),
		finish("load", STEEL, .6, .45)
	)


func update(_delta):
	_reveal("Steel", front_height() + LIFT * .5)
	# The crane only travels while builders are on site.
	_gantry.position.z = bounds.get_center().z + sin(work * .32) * _travel
	var trolley_x = sin(work * .9 + 1.0) * _span * .28
	_trolley.position.x = trolley_x
	var hook = clampf(front_height() + .55, .6, _crane_height - .45)
	var top = _crane_height - .24
	_cable.transform = rod(Vector3(trolley_x, top, 0), Vector3(trolley_x, hook + .18, 0), .025)
	_load.position = Vector3(trolley_x, hook, 0)
	_load.rotation.y = sin(work * .5) * .35


func emit_effects(effects, random):
	# Welders work the corners of the newest course.
	var inset = bounds.size * .12
	var x = random.randf_range(bounds.position.x + inset.x, bounds.end.x - inset.x)
	var z = bounds.position.z + inset.z if random.randf() < .5 else bounds.end.z - inset.z
	if random.randf() < .5:
		x = bounds.position.x + inset.x if random.randf() < .5 else bounds.end.x - inset.x
		z = random.randf_range(bounds.position.z + inset.z, bounds.end.z - inset.z)
	var local_point = Vector3(x, front_height(), z)
	var point = _site_point(local_point)
	var outward = (
		((global_transform.basis * (local_point - bounds.get_center())) * Vector3(1, 0, 1))
		. normalized()
	)
	effects.construction_puff("flash", point, Vector3.ZERO, Color("cfe4ff"), .3)
	for index in 4:
		effects.construction_puff(
			"spark",
			point,
			(
				outward * random.randf_range(.6, 1.8)
				+ Vector3(random.randf_range(-.6, .6), random.randf_range(.6, 2.0), 0)
			),
			Color("ffc27a"),
			random.randf_range(.05, .09)
		)
