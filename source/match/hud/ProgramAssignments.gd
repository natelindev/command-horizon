extends Control

const Library = preload("res://source/match/programs/ProgramLibrary.gd")


# Projected tactical boundaries use neutral lines and never intercept world input.
func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta):
	queue_redraw()


func _draw():
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var sectors = []
	var drew_representative = false
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units") or unit.program == null:
			continue
		if unit.signature != null and unit.signature.kind == "anchor":
			var sector = unit.signature.sector
			if sector not in sectors:
				sectors.append(sector)
				_draw_sector(camera, sector)
		if drew_representative:
			continue
		var program = unit.program
		var drew_assignment = false
		if program.anchor != null and _shows_guard_area(unit):
			drew_assignment = true
			for index in range(32):
				var first = (
					program.anchor
					+ (
						Vector3(cos(index * TAU / 32), 0.05, sin(index * TAU / 32))
						* program.config.radius
					)
				)
				var second = (
					program.anchor
					+ (
						Vector3(
							cos((index + 0.65) * TAU / 32), 0.05, sin((index + 0.65) * TAU / 32)
						)
						* program.config.radius
					)
				)
				draw_line(
					camera.unproject_position(first),
					camera.unproject_position(second),
					Color(1, 1, 1, 0.45),
					1.5,
					true
				)
		if program.safe_point != null:
			drew_assignment = true
			var point = camera.unproject_position(program.safe_point)
			draw_line(point - Vector2(5, 0), point + Vector2(5, 0), Color.WHITE, 2)
			draw_line(point - Vector2(0, 5), point + Vector2(0, 5), Color.WHITE, 2)
		if (
			program.config.preset == "strike_return"
			and program.anchor != null
			and program.safe_point != null
		):
			draw_dashed_line(
				camera.unproject_position(program.anchor),
				camera.unproject_position(program.safe_point),
				Color(1, 1, 1, 0.45),
				1.5,
				6
			)
		if program.route.size() == 2 and Library.behavior(program.config.preset) == "patrol":
			drew_assignment = true
			draw_dashed_line(
				camera.unproject_position(program.route[0]),
				camera.unproject_position(program.route[1]),
				Color(1, 1, 1, 0.45),
				1.5,
				6
			)
		# One representative assignment avoids a wall of overlapping circles in large selections.
		drew_representative = drew_assignment


func _shows_guard_area(unit):
	var program = unit.program
	if program.lua_source.is_empty():
		return Library.behavior(program.config.preset) == "guard"
	if program.saved_record.get("mode") == "visual":
		return program.saved_record.rules.rules.any(func(row): return row.action == "guard")
	return (
		is_instance_valid(unit.action)
		and unit.action.has_method("guards_assigned_area")
		and unit.action.guards_assigned_area()
	)


func _draw_sector(camera, center):
	for index in 32:
		var a = center + Vector3(cos(index * TAU / 32), 0.05, sin(index * TAU / 32)) * 6.0
		var b = (
			center
			+ Vector3(cos((index + 0.65) * TAU / 32), 0.05, sin((index + 0.65) * TAU / 32)) * 6.0
		)
		draw_line(
			camera.unproject_position(a), camera.unproject_position(b), Color(1, 1, 1, 0.6), 2, true
		)
