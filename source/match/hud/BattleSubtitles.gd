extends CanvasLayer

const HudLayout = preload("res://source/match/hud/HudLayout.gd")

var voice
var _card
var _line = {}
var _minimap: Control
var _commands: Control
var _unit_menu: Control


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	_card = load("res://source/match/hud/SubtitleCard.gd").new()
	add_child(_card)
	_card.resized.connect(_position_card)
	_card.minimum_size_changed.connect(_fit_card)
	get_viewport().size_changed.connect(_refresh)
	Globals.options.changed.connect(_refresh)
	_minimap = get_parent().get_node_or_null("HUD/MarginContainer/Minimap")
	_commands = get_parent().get_node_or_null("HUD/MarginContainer3")
	_unit_menu = get_parent().find_child("UnitMenus")
	for control in [_minimap, _commands]:
		if is_instance_valid(control):
			control.item_rect_changed.connect(_refresh)
			control.visibility_changed.connect(_refresh)
	voice.caption_changed.connect(_on_line)
	_on_line(voice.current)


func _on_line(line):
	_line = line.duplicate()
	_refresh()


func _refresh():
	_card.visible = Globals.options.subtitles and not _line.is_empty()
	var space = _horizontal_space()
	_card.custom_minimum_size.x = minf(560, maxf(1, space.y - space.x))
	_card.size.x = _card.custom_minimum_size.x
	if not _line.is_empty():
		_card.set_line(_line.speaker, _line.text, Globals.options.subtitle_size)
	_fit_card()


func _fit_card():
	_card.size = Vector2(_card.custom_minimum_size.x, _card.get_combined_minimum_size().y)
	_position_card()


func _position_card():
	var viewport = get_viewport().get_visible_rect().size
	var space = _horizontal_space()
	# Captions ride on the bottom rail between the minimap housing and the deck.
	_card.position = Vector2(
		space.x + (space.y - space.x - _card.size.x) / 2,
		viewport.y - HudLayout.BOTTOM_RAIL - 8 - _card.size.y
	)


func _horizontal_space():
	var left = 12.0
	var right = get_viewport().get_visible_rect().size.x - 12
	if is_instance_valid(_minimap) and _minimap.is_visible_in_tree():
		left = maxf(left, _minimap.get_global_rect().end.x + 12)
	# Keep room for selection controls even while empty, so selecting a unit does
	# not move a caption. Wider production/command layouts reserve their real bounds.
	if is_instance_valid(_unit_menu):
		right -= _unit_menu.custom_minimum_size.x
	if is_instance_valid(_commands) and _commands.is_visible_in_tree():
		right -= _commands.get_theme_constant("margin_right")
		right = minf(right, _commands.get_global_rect().position.x - 12)
	return Vector2(left, maxf(left + 1, right))
