extends ScrollContainer

const Human = preload("res://source/match/players/human/Human.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")

var _reserved_height = 0.0
var _minimap: Control
@onready var _match = find_parent("Match")
@onready var _bars: VBoxContainer = $Bars

# TODO: handle human player removal/addition


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	get_v_scroll_bar().custom_step = HudLayout.TOP_PLATE + 4
	_minimap = _match.find_child("Minimap")
	await find_parent("Match").ready
	theme = BattleTheme.create()
	_hide_all_bars()
	_setup_all_bars()
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human
	)
	if (
		_match.settings.visibility == _match.settings.Visibility.PER_PLAYER
		and not human_players.is_empty()
	):
		_show_player_bars([human_players[0]])
	else:
		_show_player_bars(get_tree().get_nodes_in_group("players"))
	fit_height()


func _process(_delta):
	fit_height(_reserved_height)


## Keep the whole roster reachable above the minimap and any mission controls.
func fit_height(reserve_below = 0.0):
	_reserved_height = reserve_below
	var bottom = get_viewport_rect().size.y - HudLayout.GAP
	if is_instance_valid(_minimap) and _minimap.is_visible_in_tree():
		bottom = _minimap.get_global_rect().position.y - HudLayout.GAP
	var available = maxf(HudLayout.TOP_PLATE, bottom - global_position.y - reserve_below)
	var height = minf(_bars.get_combined_minimum_size().y, available)
	if not is_equal_approx(custom_minimum_size.y, height):
		custom_minimum_size.y = height
		reset_size()
		get_parent().reset_size()


func _hide_all_bars():
	for bar in _bars.get_children():
		bar.hide()


func _setup_all_bars():
	var bar_nodes = _bars.get_children()
	var players = get_tree().get_nodes_in_group("players")
	for i in range(players.size()):
		bar_nodes[i].setup(players[i])


func _show_player_bars(players):
	for player in players:
		for bar_node in _bars.get_children():
			if bar_node.player == player:
				bar_node.show()
