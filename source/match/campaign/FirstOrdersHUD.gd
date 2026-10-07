extends "res://source/match/hud/SkirmishHUD.gd"

const LESSONS = [
	[
		"01 / BRING COMMAND ONLINE",
		(
			"Select an engineer, choose Command lab, then place it near your base.\n\n"
			+ "Right-click salvage to harvest. Materials build your army; electronics fund chips."
		)
	],
	[
		"02 / GIVE THE UNIT A PROGRAM",
		(
			"Select your repair robot. Choose Service area, click Assign area / route, "
			+ "choose a point, then Apply & run.\n\n"
			+ "Or fit a tank chip at HQ (4 E), choose Guard area, and set area + safe point. "
			+ "Direct orders always override programs."
		)
	],
	[
		"03 / SECURE THE RELAY",
		(
			"Infantry within 3 m capture in 10 seconds. Clear enemy ground combatants, "
			+ "then hold for 60 uncontested seconds.\n\nTanks screen; repair robots support. "
			+ "Enemy recapture resets the hold. Three responses arrive from the east."
		)
	]
]
var lesson_panel
var _lesson_title: Label
var _lesson_text: Label
var _relay_status: Label
var _hold_bar: ProgressBar
var _optional: Label
var _find_button: Button
var _command_panel: PanelContainer
var _relay_marker: Label


func _ready():
	super()
	_command_panel = get_child(0)
	lesson_panel = PanelContainer.new()
	lesson_panel.custom_minimum_size.x = 325
	_style(lesson_panel)
	add_child(lesson_panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	lesson_panel.add_child(content)
	_lesson_title = _lesson_label(content, "", 14)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_lesson_text = _lesson_label(scroll, "", 13)
	_lesson_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lesson_text.custom_minimum_size.x = 293
	_lesson_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_relay_status = _lesson_label(content, "", 13)
	_hold_bar = ProgressBar.new()
	_hold_bar.max_value = 60
	_hold_bar.show_percentage = false
	_hold_bar.custom_minimum_size.y = 8
	content.add_child(_hold_bar)
	_optional = _lesson_label(content, "", 12)
	_optional.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons = HBoxContainer.new()
	content.add_child(buttons)
	_find_button = _button(buttons, "Find engineer", _find_unit)
	_button(buttons, "View relay", _view_relay)
	# The briefing discloses the objective location, not the units around it.
	var markers = CanvasLayer.new()
	markers.layer = -1
	add_child(markers)
	_relay_marker = _lesson_label(markers, "◆  LOGISTICS RELAY\nInfantry capture point", 14)
	_relay_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relay_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relay_marker.add_theme_color_override("font_shadow_color", Color.BLACK)
	_relay_marker.add_theme_constant_override("shadow_offset_x", 2)
	_relay_marker.add_theme_constant_override("shadow_offset_y", 2)
	var minimap_marker = ColorRect.new()
	minimap_marker.color = Color("eee3c3")
	minimap_marker.size = Vector2(6, 6)
	minimap_marker.pivot_offset = Vector2(3, 3)
	minimap_marker.rotation = PI / 4
	minimap_marker.z_index = 2
	minimap_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().find_child("MinimapViewport").add_child(minimap_marker)
	var point = get_parent().map.get_node("Relay").position
	minimap_marker.position = Vector2(point.x, point.z) * 2 - Vector2(3, 3)


func _lesson_label(parent, text, size):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _process(delta):
	super(delta)
	var mission = get_parent()
	if mission.relay != null:
		var camera = get_viewport().get_camera_3d()
		var point = mission.relay.global_position + Vector3.UP * 4.5
		_relay_marker.position = camera.unproject_position(point) - _relay_marker.size * 0.5
		_relay_marker.visible = (
			not camera.is_position_behind(point)
			and get_viewport().get_visible_rect().encloses(_relay_marker.get_rect())
		)
	var top = _command_panel.position.y + _command_panel.size.y + 10
	lesson_panel.position = Vector2(14, top)
	lesson_panel.size = Vector2(
		325, maxf(220, get_viewport().get_visible_rect().size.y - 230 - top)
	)
	_lesson_title.text = LESSONS[mission.phase][0]
	_lesson_text.text = LESSONS[mission.phase][1]
	_find_button.text = ["Find engineer", "Find repair robot", "Find infantry"][mission.phase]
	_hold_bar.value = mission.hold_seconds
	_relay_status.text = (
		"Relay · %d / 60 s · responses %d / 3" % [int(mission.hold_seconds), mission.waves_sent]
	)
	_optional.text = (
		"Optional complete · Adaptive doctrine"
		if mission.reuse_badge
		else "Optional badge: change retreat %, save a version, then load and apply it."
	)


func _find_unit():
	var mission = get_parent()
	var role = ["Worker", "RepairRobot", "Infantry"][mission.phase]
	var units = mission._get_human_player().get_children().filter(
		func(unit):
			return "type" in unit and unit.type == role and not unit.is_queued_for_deletion()
	)
	if units.is_empty():
		show_notice(
			(
				"Train a replacement at your "
				+ (
					"HQ."
					if role == "Worker"
					else ("vehicle factory." if role == "RepairRobot" else "barracks.")
				)
			)
		)
		return
	MatchSignals.deselect_all_units.emit()
	units[0].get_node("Selection").select()
	mission.get_node("IsometricCamera3D").set_position_safely(units[0].global_position_yless)


func _view_relay():
	var mission = get_parent()
	mission.get_node("IsometricCamera3D").set_position_safely(mission.relay.global_position)
