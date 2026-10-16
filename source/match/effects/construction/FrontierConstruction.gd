extends "res://source/match/effects/construction/ConstructionRig.gd"

# Frontier: crooked timber poles and lashed planks go up first, a leaning derrick
# swings salvaged plates into place and the scrap pile beside the site is used up.

const WOOD = [Color("6e5034"), Color("7d5e3c"), Color("5a4330"), Color("85694a")]
const SCRAP = [Color("6b3720"), Color("4d4f3c"), Color("6f716c"), Color("3f4c54"), Color("5a301c")]
const ROPE = Color("2f281f")
const STANDOFF = .24

var _random = RandomNumberGenerator.new()
var _hoist
var _rope
var _plate
var _apex = Vector3.ZERO


func _build():
	emit_interval = .26
	_random.seed = site_seed()
	var timber = finish("frontier-timber", Color.WHITE, 0.0, .95)
	var lo = bounds.position - Vector3(STANDOFF, 0, STANDOFF)
	var hi = bounds.end + Vector3(STANDOFF, 0, STANDOFF)
	var top = bounds.end.y + .2
	# Poles go up first and stand at uneven heights with a little lean.
	var poles = []
	for x in [lo.x, hi.x]:
		var count = maxi(2, roundi((hi.z - lo.z) / 1.1) + 1)
		for index in count:
			var z = lerpf(lo.z, hi.z, float(index) / (count - 1))
			z += _random.randf_range(-.12, .12) if index not in [0, count - 1] else 0.0
			poles.append(Vector3(x, 0, z))
	var back = maxi(1, roundi((hi.x - lo.x) / 1.2))
	for index in range(1, back):
		poles.append(Vector3(lerpf(lo.x, hi.x, float(index) / back), 0, lo.z))
	for base in poles:
		var lean = Vector3(_random.randf_range(-.08, .08), 0, _random.randf_range(-.08, .08))
		var height = top + _random.randf_range(.05, .45)
		_add(
			"Poles",
			ROD,
			timber,
			rod(base, base + lean + Vector3(0, height, 0), _random.randf_range(.07, .09)),
			_wood(),
			-1.0
		)
	# Lashed ledgers and planks follow the rising work, unevenly spaced and sloped.
	var y = .55
	while y < top:
		for x in [lo.x, hi.x]:
			if _random.randf() < .2:
				continue
			var slope = _random.randf_range(-.06, .06)
			_add(
				"Timber",
				BOX,
				timber,
				rod(Vector3(x, y - slope, lo.z), Vector3(x, y + slope, hi.z), .06),
				_wood(),
				y
			)
			var outward = signf(x - bounds.get_center().x)
			for plank in 2:
				_add(
					"Timber",
					BOX,
					timber,
					block(
						Vector3(
							x + outward * (.1 + plank * .14),
							y + .04,
							(lo.z + hi.z) * .5 + _random.randf_range(-.15, .15)
						),
						Vector3(.12, .03, (hi.z - lo.z) * _random.randf_range(.55, .85)),
						_random.randf_range(-.04, .04)
					),
					_wood(),
					y
				)
		if _random.randf() < .7:
			_add(
				"Timber",
				BOX,
				timber,
				rod(
					Vector3(lo.x, y, lo.z),
					Vector3(hi.x, y + _random.randf_range(-.08, .08), lo.z),
					.06
				),
				_wood(),
				y
			)
		y += _random.randf_range(.6, .8)
	# Cross bracing on a few bays.
	for x in [lo.x, hi.x]:
		var from = Vector3(x, .1, lo.z + .05)
		var to = Vector3(x, minf(top, 1.6), lerpf(lo.z, hi.z, .55))
		_add("Timber", BOX, timber, rod(from, to, .05), _wood(), .6)
	_build_pile(hi)
	_build_derrick(lo, top)


func _wood():
	return WOOD[_random.randi() % WOOD.size()]


func _build_pile(hi):
	# Stacked from the ground up; the highest pieces are used first.
	var metal = finish("frontier-scrap", Color.WHITE, .4, .82)
	var center = Vector3(hi.x + .7, 0, bounds.get_center().z + bounds.size.z * .18)
	var level = 0.0
	var count = 12
	for index in count:
		var key = float(index + 1) / count
		var spot = (
			center + Vector3(_random.randf_range(-.3, .3), level, _random.randf_range(-.4, .4))
		)
		var choice = index % 4
		if choice == 1:
			var drum = Transform3D(
				Basis.from_scale(Vector3(.28, .4, .28)), spot + Vector3(0, .2, 0)
			)
			if _random.randf() < .5:
				drum = Transform3D(
					Basis(Vector3.UP, _random.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2), spot
				)
				drum = drum.scaled_local(Vector3(.28, .4, .28))
				drum.origin.y += .14
			_add("Drums", ROD, metal, drum, SCRAP[_random.randi() % SCRAP.size()], key)
			continue
		var size = (
			Vector3(_random.randf_range(.45, .8), .05, _random.randf_range(.3, .55))
			if choice != 3
			else Vector3.ONE * _random.randf_range(.26, .36)
		)
		var piece = Transform3D(
			(
				Basis(Vector3.UP, _random.randf() * TAU)
				* Basis(Vector3.RIGHT, _random.randf_range(-.15, .15))
				* Basis.from_scale(size)
			),
			spot + Vector3(0, size.y * .5, 0)
		)
		_add(
			"Scrap",
			BOX,
			metal,
			piece,
			WOOD[1] if choice == 3 else SCRAP[_random.randi() % SCRAP.size()],
			key
		)
		level = minf(level + size.y * .8, .45)


func _build_derrick(lo, top):
	var timber = finish("frontier-timber", Color.WHITE, 0.0, .95)
	var rope = finish("frontier-rope", ROPE, 0.0, 1.0)
	var center = bounds.get_center()
	_apex = Vector3(lo.x + .55, top + .7, center.z)
	_hoist = Node3D.new()
	_hoist.name = "Derrick"
	add_child(_hoist)
	for offset in [-.45, .45]:
		_add(
			"DerrickFrame",
			ROD,
			timber,
			rod(Vector3(lo.x - .55, 0, center.z + offset), _apex, .09),
			WOOD[0],
			0.0,
			_hoist
		)
	_add(
		"DerrickFrame",
		ROD,
		timber,
		rod(Vector3(lo.x - 1.0, 0, center.z), _apex, .04),
		ROPE,
		0.0,
		_hoist
	)
	var swing = Node3D.new()
	swing.name = "Swing"
	swing.position = _apex
	_hoist.add_child(swing)
	_rope = _part(swing, "Rope", BOX, Transform3D(), rope, false)
	_plate = _part(
		swing,
		"SalvagePlate",
		BOX,
		block(Vector3.ZERO, Vector3(.75, .05, .5), .3),
		finish("frontier-plate", SCRAP[0], .4, .8)
	)


func update(_delta):
	_reveal("Timber", front_height() + .5)
	var remaining = 1.0 - progress * .9
	_reveal("Scrap", remaining)
	_reveal("Drums", remaining)
	var swing = _rope.get_parent()
	swing.rotation.z = sin(work * 1.7) * .2
	swing.rotation.x = sin(work * 1.1) * .08
	var drop = clampf(_apex.y - front_height() - .35, .35, _apex.y - .4)
	_rope.transform = rod(Vector3.ZERO, Vector3(0, -drop + .03, 0), .02)
	_plate.position = Vector3(0, -drop, 0)
	_plate.rotation.y = .3 + sin(work * .7) * .3


func emit_effects(effects, random):
	var inset = bounds.size * .12
	var along_x = random.randf() < .5
	var local_point = Vector3(
		random.randf_range(bounds.position.x + inset.x, bounds.end.x - inset.x),
		front_height() - .05,
		bounds.end.z - inset.z if random.randf() < .5 else bounds.position.z + inset.z
	)
	var tangent = Vector3.RIGHT
	if not along_x:
		local_point.x = (
			bounds.end.x - inset.x if random.randf() < .5 else bounds.position.x + inset.x
		)
		local_point.z = random.randf_range(bounds.position.z + inset.z, bounds.end.z - inset.z)
		tangent = Vector3.BACK
	tangent = (global_transform.basis * tangent).normalized() * (1 if random.randf() < .5 else -1)
	var point = _site_point(local_point)
	# Angle grinders throw a flat fan of sparks along the seam.
	for index in 6:
		effects.construction_puff(
			"spark",
			point,
			(
				tangent * random.randf_range(1.8, 3.6)
				+ Vector3(random.randf_range(-.4, .4), random.randf_range(.3, 1.2), 0)
			),
			Color("ffab40"),
			random.randf_range(.05, .08)
		)
	if random.randf() < .35:
		var corner = Vector3(
			bounds.position.x if random.randf() < .5 else bounds.end.x,
			.15,
			random.randf_range(bounds.position.z, bounds.end.z)
		)
		effects.construction_puff(
			"dust",
			_site_point(corner),
			Vector3(random.randf_range(-.2, .2), .25, random.randf_range(-.2, .2)),
			Color(.62, .52, .38, .32),
			random.randf_range(.6, .9)
		)
