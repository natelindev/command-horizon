extends ScrollContainer

## Match status is public; this list never inspects an opponent's units or position.
const Factions = preload("res://source/match/FactionRules.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const ROW_HEIGHT = 22.0
const VISIBLE_ROWS = 4
const ANNOUNCEMENT_SECONDS = 6.0
var hud
var rows = {}
var _game
var _list
var _elapsed = 0.0
var _announcement
var _announcement_title
var _announcement_detail
var _announcement_left = 0.0
var _announcements = []
var _announced_player


func _ready():
	name = "CommanderRoster"
	_game = hud.get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	follow_focus = true
	get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	get_v_scroll_bar().custom_step = ROW_HEIGHT
	accessibility_name = tr("Commander status")
	theme = BattleTheme.create()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)
	for player in _game.get_node("Players").get_children():
		if "faction" in player:
			_add_row(player)
	custom_minimum_size.y = min(rows.size(), VISIBLE_ROWS) * ROW_HEIGHT
	_build_announcement()
	_game.player_eliminated.connect(_on_eliminated)
	Globals.options.changed.connect(refresh)
	refresh()


func _add_row(player):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override("separation", 8)
	_list.add_child(row)
	var identity = Label.new()
	identity.add_theme_font_size_override("font_size", 12)
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(identity)
	var status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status)
	rows[player] = {"row": row, "identity": identity, "status": status}


func commander_name(player):
	var faction = tr(Factions.NAMES.get(player.faction, player.faction))
	var identity = "%d · %s" % [player.get_index() + 1, faction]
	if player == _game._get_human_player():
		identity += " · " + tr("You")
	return identity


func refresh():
	accessibility_name = tr("Commander status")
	for player in rows:
		var row = rows[player]
		var eliminated = _game._defeat_timers.get(player, 60.0) <= 0.0
		row.identity.text = commander_name(player)
		row.status.text = tr("Eliminated") if eliminated else tr("In battle")
		var detail = "%s · %s" % [row.identity.text, row.status.text]
		row.identity.tooltip_text = detail
		row.identity.accessibility_name = detail
		row.status.accessibility_name = row.status.text
		row.identity.add_theme_color_override("font_color", BattleTheme.MUTED)
		row.status.add_theme_color_override(
			"font_color", Color("e0c38d") if eliminated else BattleTheme.MUTED
		)
	if is_instance_valid(_announced_player):
		_announcement_title.text = tr("Commander eliminated")
		_announcement_detail.text = commander_name(_announced_player)
		_announcement.accessibility_name = (
			_announcement_title.text + ": " + _announcement_detail.text
		)


func _process(delta):
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()
	var available = (
		not _game.finished
		and not _game.restoring
		and hud._overlay == null
		and not is_instance_valid(Globals.settings_dialog)
		and not is_instance_valid(get_node("/root/SaveManager").dialog)
	)
	# The player should receive the full notice after closing a menu or dialog.
	if available and _announcement_left > 0.0:
		_announcement_left -= delta / maxf(Engine.time_scale, 0.001)
		if _announcement_left <= 0.0:
			_show_next_announcement()
	_announcement.visible = _announcement_left > 0.0 and available
	var viewport = get_viewport_rect().size
	var top = maxf(HudLayout.TOP_PLATE, hud.system_plate.size.y) + 12.0
	var left = HudLayout.COLUMN_WIDTH + HudLayout.GAP
	var resources = hud._resources.get_global_rect()
	# A visible resource roster can extend down alongside the notice, and large
	# balances make its plates wider than the objective column.
	if resources.end.y > top:
		left = maxf(left, resources.end.x + HudLayout.GAP)
	var width = viewport.x - HudLayout.GAP - left
	_announcement.size = Vector2(minf(440.0, width), 0)
	_announcement.position = Vector2(left + (width - _announcement.size.x) / 2.0, top)


func _on_eliminated(player):
	refresh()
	_announcements.append(player)
	if _announcement_left <= 0.0:
		_show_next_announcement()


func _show_next_announcement():
	if _announcements.is_empty():
		_announcement_left = 0.0
		_announced_player = null
		_announcement.hide()
		return
	_announced_player = _announcements.pop_front()
	_announcement_left = ANNOUNCEMENT_SECONDS
	refresh()


func _build_announcement():
	_announcement = PanelContainer.new()
	_announcement.name = "EliminationAnnouncement"
	_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._style(_announcement)
	hud.add_child(_announcement)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announcement.add_child(column)
	_announcement_title = Label.new()
	_announcement_title.add_theme_font_size_override("font_size", 17)
	_announcement_title.add_theme_color_override("font_color", Color("e0c38d"))
	_announcement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_announcement_title)
	_announcement_detail = Label.new()
	_announcement_detail.add_theme_font_size_override("font_size", 14)
	_announcement_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_announcement_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_announcement_detail)
	_announcement.hide()
