extends RefCounted


static func building(game, point: Vector3):
	var body = load("res://source/match/maps/IndustrialLandmarks.gd").place(
		game.map, point, "ServiceOffice", 2.0, 0.36
	)
	var target = load("res://source/match/ambient/NeutralBuilding.gd").new()
	target.setup(body, "grenade-test-building")
	body.add_child(target)
	return target


static func occupy(target, unit) -> bool:
	unit.action = load("res://source/match/units/actions/Garrisoning.gd").new(target)
	return target.enter(unit)


static func position_thrower(target, unit) -> bool:
	for index in 32:
		var radial = Vector3(cos(index * TAU / 32), 0, sin(index * TAU / 32))
		unit.global_position = target.global_position + radial * (target.radius + 2.0)
		if unit.abilities._throw_clear(target.global_position + radial * target.radius, target):
			unit._match.battlefield.invalidate()
			return true
	return false
