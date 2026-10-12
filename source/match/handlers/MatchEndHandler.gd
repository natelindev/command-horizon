extends CanvasLayer

const Human = preload("res://source/match/players/human/Human.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

@onready var _panel_container = find_child("PanelContainer")
@onready var _victory_tile = find_child("Victory")
@onready var _defeat_tile = find_child("Defeat")
@onready var _finish_tile = find_child("Finish")
@onready var _exit_button = find_child("ExitButton")


func _ready():
	if not FeatureFlags.handle_match_end or find_parent("Match").settings.skirmish:
		queue_free()
		return
	hide()
	if _panel_container != null:
		BattleTheme.apply(_panel_container, 20, 16)
	_style_card(_victory_tile, Color("0d2118"), Color("2ecc71"))
	_style_card(_defeat_tile, Color("210d0d"), Color("e74c3c"))
	_style_card(_finish_tile, Color("141a20"), Color("d8bc80"))
	if _exit_button != null:
		_exit_button.theme = BattleTheme.create()
		_exit_button.theme_type_variation = "BattlePrimaryButton"
		_exit_button.custom_minimum_size.y = 42
		_exit_button.text = tr("Main menu")
	_victory_tile.hide()
	_defeat_tile.hide()
	_finish_tile.hide()
	await find_parent("Match").ready
	MatchSignals.setup_and_spawn_unit.connect(_on_new_unit)
	for unit in get_tree().get_nodes_in_group("units"):
		unit.tree_exited.connect(_on_unit_tree_exited)


func _style_card(card: Control, bg: Color, border: Color):
	if card == null:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", style)


func _handle_defeat():
	_defeat_tile.show()
	_show()
	MatchSignals.match_finished_with_defeat.emit()


func _handle_victory():
	_victory_tile.show()
	_show()
	MatchSignals.match_finished_with_victory.emit()


func _handle_finish():
	_finish_tile.show()
	_show()


func _show():
	show()
	get_tree().paused = true


func _on_new_unit(unit, _transform, _player):
	unit.tree_exited.connect(_on_unit_tree_exited)


func _on_unit_tree_exited():
	if visible or not is_inside_tree():
		return
	var players = Utils.Set.new()
	for unit in get_tree().get_nodes_in_group("units"):
		players.add(unit.player)
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human
	)
	if not human_players.is_empty() and not players.has(human_players[0]):
		_handle_defeat()
	elif not human_players.is_empty() and players.has(human_players[0]) and players.size() == 1:
		_handle_victory()
	elif players.size() == 1:
		_handle_finish()


func _on_exit_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
