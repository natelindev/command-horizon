extends CanvasLayer

const HudLayout = preload("res://source/match/hud/HudLayout.gd")

var voice
# Campaign dialogue remains readable when routine unit captions are disabled.
var always_show_captions = false
var _card
var _line = {}
var _minimap: Control
var _commands: Control
var _unit_menu: Control
var _resources: Control


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
	_resources = get_parent().get_node_or_null("HUD/MarginContainer2/Resources")
	for control in [_minimap, _commands, _resources]:
		if is_instance_valid(control):
			control.item_rect_changed.connect(_refresh)
			control.visibility_changed.connect(_refresh)
	voice.caption_changed.connect(_on_line)
	_on_line(voice.current)


func _on_line(line):
	_line = line.duplicate()
	_refresh()


func _refresh():
	# Story portraits identify the speaking character even with captions off.
	_card.visible = (
		not _line.is_empty()
		and (
			always_show_captions
			or Globals.options.subtitles
			or not _line.get("portrait", "").is_empty()
		)
	)
	var space = _horizontal_space()
	_card.custom_minimum_size.x = minf(560, maxf(1, space.y - space.x))
	_card.size.x = _card.custom_minimum_size.x
	if not _line.is_empty():
		_card.set_line(_line.speaker, _line.text, Globals.options.subtitle_size)
		_card.set_portrait(_line.get("portrait", ""))
		_card.set_caption_visible(always_show_captions or Globals.options.subtitles)
	_fit_card()


func _fit_card():
	_card.size = Vector2(_card.custom_minimum_size.x, _card.get_combined_minimum_size().y)
	_position_card()


func _position_card():
	var space = _horizontal_space()
	# Wrapping can move a new line into or out of the roster's vertical band.
	# Refit its width once the container reports the actual caption height.
	var width = minf(560, space.y - space.x)
	if not is_equal_approx(_card.custom_minimum_size.x, width):
		_card.custom_minimum_size.x = width
		_card.size.x = width
	_card.position = Vector2(
		space.x + (space.y - space.x - _card.size.x) / 2, _caption_top(_card.size.y)
	)


func _caption_top(height):
	var viewport = get_viewport().get_visible_rect().size
	# The bottom console now spans the width. Keep captions above its queue rack,
	# with the same reservation for empty and selected states to avoid jumping text.
	var top = viewport.y - HudLayout.CONSOLE_HEIGHT
	if is_instance_valid(_minimap) and _minimap.is_visible_in_tree():
		top = _minimap.get_global_rect().position.y
	return maxf(HudLayout.TOP_PLATE + 8, top - 96 - height)


func _horizontal_space():
	var left = 12.0
	var right = get_viewport().get_visible_rect().size.x - 12
	if is_instance_valid(_minimap) and _minimap.is_visible_in_tree():
		left = maxf(left, _minimap.get_global_rect().end.x + 12)
	if is_instance_valid(_resources) and _resources.is_visible_in_tree():
		var roster = _resources.get_global_rect()
		# One or two plates remain above the caption. A tall scrollable roster
		# occupies its vertical band, so reserve that column without moving the
		# ordinary layout or making selection shift the caption.
		if roster.end.y + HudLayout.GAP > _caption_top(_card.size.y):
			left = maxf(left, roster.end.x + HudLayout.GAP)
	return Vector2(left, maxf(left + 1, right))
