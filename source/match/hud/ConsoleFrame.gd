extends Control

## Structural chrome of the battle console, drawn beneath the functional panels:
## a rail across the top that the resource and system plates hang from, a rail
## along the bottom joining the minimap housing to the command deck, and an
## empty deck housing that keeps the console whole while nothing is selected.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")

var top_rail: Panel
var bottom_rail: Panel
var empty_deck: PanelContainer
var _hazards = []
var _minimap: Control
var _deck: Control
var _queue: Control


func _ready():
	name = "ConsoleFrame"
	# Chrome follows the deck while the battle is paused too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = BattleTheme.create()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap = get_node_or_null("../MarginContainer/Minimap")
	_deck = get_node_or_null("../MarginContainer3/VBoxContainer/UnitMenus")
	_queue = get_node_or_null("../MarginContainer3/VBoxContainer/ProductionQueue")
	top_rail = _rail("TopRail")
	bottom_rail = _rail("BottomRail")
	for index in 2:
		var stripe = Panel.new()
		stripe.name = "Hazard%d" % index
		stripe.add_theme_stylebox_override("panel", BattleTheme.stripe())
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)
		_hazards.append(stripe)
	empty_deck = PanelContainer.new()
	empty_deck.name = "EmptyDeck"
	empty_deck.theme_type_variation = "HudHousing"
	# Console chrome is solid: clicks on it never reach the battlefield behind.
	empty_deck.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(empty_deck)
	var screen = PanelContainer.new()
	screen.theme_type_variation = "HudSocket"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_deck.add_child(screen)
	var caption = Label.new()
	caption.text = "Awaiting orders"
	caption.uppercase = true
	caption.theme_type_variation = "HudCaption"
	caption.add_theme_font_size_override("font_size", 15)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.modulate = Color(1, 1, 1, .7)
	screen.add_child(caption)
	_layout()


func _rail(rail_name):
	var rail = Panel.new()
	rail.name = rail_name
	rail.add_theme_stylebox_override("panel", BattleTheme.rail())
	rail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rail)
	return rail


func _process(_delta):
	_layout()


func _layout():
	var viewport = get_viewport_rect().size
	top_rail.position = Vector2.ZERO
	top_rail.size = Vector2(viewport.x, HudLayout.TOP_RAIL)
	var left = 0.0
	if is_instance_valid(_minimap) and _minimap.is_visible_in_tree():
		left = _minimap.get_global_rect().end.x
	var right = viewport.x
	var deck_shown = is_instance_valid(_deck) and _deck.is_visible_in_tree()
	var width = viewport.x - left
	if deck_shown:
		right = _deck.get_global_rect().position.x
	else:
		right = viewport.x - width
	# Tuck the rail ends under both housings so the joints read as one console.
	bottom_rail.position = Vector2(left - 24, viewport.y - HudLayout.BOTTOM_RAIL)
	bottom_rail.size = Vector2(maxf(0, right - left + 48), HudLayout.BOTTOM_RAIL)
	var stripe_size = Vector2(72, 10)
	var stripe_y = viewport.y - HudLayout.BOTTOM_RAIL / 2 - stripe_size.y / 2
	_hazards[0].position = Vector2(left + 14, stripe_y)
	_hazards[1].position = Vector2(right - 14 - stripe_size.x, stripe_y)
	for stripe in _hazards:
		stripe.size = stripe_size
		stripe.visible = right - left > stripe_size.x * 2 + 60
	empty_deck.visible = is_instance_valid(_deck) and not deck_shown
	if empty_deck.visible:
		var height = _minimap.size.y if is_instance_valid(_minimap) else HudLayout.CONSOLE_HEIGHT
		empty_deck.position = Vector2(viewport.x - width, viewport.y - height)
		empty_deck.size = Vector2(width, height)
