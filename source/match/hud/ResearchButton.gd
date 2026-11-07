extends "res://source/match/hud/RosterButton.gd"

## Keep research state below the portrait, never on top of the name or price.
var research_state = "available"
var _research_mode = false
var _state: Label
var _marker: Label
var _portrait_column: VBoxContainer
var _research_progress: ProgressBar


func _init():
	super()
	var socket = _body.get_node("Portrait")
	_body.remove_child(socket)
	_portrait_column = VBoxContainer.new()
	_portrait_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_portrait_column.add_theme_constant_override("separation", 0)
	_portrait_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_portrait_column)
	_body.move_child(_portrait_column, 0)
	_portrait_column.add_child(socket)
	_marker = Label.new()
	_marker.name = "ResearchState"
	_marker.custom_minimum_size = Vector2(38, 14)
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.add_theme_font_override("font", BattleTheme.display_font())
	_marker.add_theme_font_size_override("font_size", 10)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.hide()
	_portrait_column.add_child(_marker)
	_state = Label.new()
	_state.add_theme_font_override("font", BattleTheme.numeral_font())
	_state.add_theme_font_size_override("font_size", 13)
	_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state.hide()
	_title.get_parent().add_child(_state)
	_research_progress = ProgressBar.new()
	_research_progress.name = "ResearchProgress"
	_research_progress.show_percentage = false
	_research_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_research_progress.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_research_progress.offset_left = 6
	_research_progress.offset_right = -6
	_research_progress.offset_top = -5
	_research_progress.offset_bottom = -2
	_research_progress.add_theme_stylebox_override(
		"background", BattleTheme.surface(Color.TRANSPARENT, 0, 0)
	)
	_research_progress.add_theme_stylebox_override(
		"fill", BattleTheme.bar_fill(BattleTheme.accent())
	)
	_research_progress.hide()
	add_child(_research_progress)


func compact_layout(side = 48.0):
	_compact = true
	_icon_size = side
	for edge in ["left", "top", "right", "bottom"]:
		get_node("Tile").add_theme_constant_override("margin_" + edge, 4)
	var socket = _portrait_column.get_node("Portrait")
	socket.custom_minimum_size = Vector2(side - 8, side - 22)
	socket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.get_parent().hide()
	_marker.custom_minimum_size.x = 0
	_fit_contents()


func show_state(value: String, marker_only = false):
	# Market exchange and air-contract tiles share the original text-state API.
	_state.text = value
	_state.visible = not marker_only and not value.is_empty()


func show_research(state: String, marker: String, progress = 0.0):
	if not _research_mode:
		# Generated art already includes transparent breathing room. Use that padding
		# instead of growing two tile rows beyond the tabbed Frontier lab's budget.
		_portrait_column.get_node("Portrait").add_theme_stylebox_override(
			"panel", BattleTheme.socket(0, 0)
		)
	_research_mode = true
	research_state = state
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not _compact:
		_portrait_column.get_node("Portrait").custom_minimum_size = Vector2(32, 32)
	_marker.show()
	_marker.text = marker
	_marker.add_theme_color_override(
		"font_color",
		BattleTheme.accent() if state in ["active", "queued", "completed"] else BattleTheme.MUTED
	)
	_research_progress.visible = state == "active"
	_research_progress.value = progress
	queue_redraw()


func _draw():
	super()
	if not _research_mode:
		return
	# Purchased and unavailable tiles retain readable pictures, captions and prices.
	_body.modulate = Color(1, 1, 1, .78) if disabled else Color.WHITE
	if research_state in ["active", "queued", "completed"]:
		_body.modulate = Color.WHITE
		var fill = BattleTheme.accent()
		fill.a = .1 if research_state == "active" else .04
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), fill)
