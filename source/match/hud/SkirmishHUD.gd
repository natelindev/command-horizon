# gdlint: disable=max-returns
extends "res://source/match/hud/BastionDemoHUD.gd"

const Factions = preload("res://source/match/FactionCatalog.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")
const TacticalButton = preload("res://source/main-menu/TacticalButton.gd")
var program_editor = null
var lua_draft = {}
var visual_draft = {}
var battle_plan = null
var alert_panel = null
var direct_orders
var technology_panel = null
var research_status
var _technology_scroll = null
var _technology_button
var _objective = null
var _clock = null
var _overlay = null
var _attack_button = null
var _menu_button
var _menu_help
var _attack_armed: bool:
	get:
		return is_instance_valid(direct_orders) and direct_orders.kind == "attack_move"
var _menu_was_paused = false
var _assignment_kind = ""
var _assignment_units = []
var _assignment_points = []
var _assignment_hint
var _notice_slot: ScrollContainer
var _assignment_release = false
var _hint_left = 0.0
var _pending_notice = ""


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	var panel = PanelContainer.new()
	panel.position = Vector2(16, 86)
	_style(panel)
	panel.get_theme_stylebox("panel").content_margin_top = 6
	panel.get_theme_stylebox("panel").content_margin_bottom = 6
	add_child(panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var title = Label.new()
	var players = get_tree().get_nodes_in_group("players")
	title.text = (
		"%s  vs  %s" % [Factions.NAMES[players[0].faction], Factions.NAMES[players[1].faction]]
	)
	title.add_theme_font_size_override("font_size", 17)
	BattleTheme.heading(content, title, 30)
	_objective = Label.new()
	_objective.add_theme_font_size_override("font_size", 12)
	content.add_child(_objective)
	_clock = Label.new()
	_clock.add_theme_color_override("font_color", Color("a9b4b3"))
	_clock.add_theme_font_size_override("font_size", 12)
	content.add_child(_clock)
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	content.add_child(buttons)
	_pause_button = _button(buttons, Bindings.hint("Pause", "pause_battle"), _toggle_pause)
	_attack_button = _button(buttons, Bindings.hint("Attack move", "attack_move"), _arm_attack)
	_menu_button = _button(buttons, Bindings.hint("Menu", "toggle_match_menu"), _open_menu)
	_technology_button = _button(buttons, "Tech", open_technology)
	_technology_button.name = "OpenTechnology"
	if not _is_campaign() and "relays" in get_parent().map:
		var relays = _button(buttons, "Relays", open_relays)
		relays.name = "OpenRelays"
		relays.tooltip_text = "View relay ownership, capture progress and locations."
	Globals.options.changed.connect(_refresh_shortcuts)
	_assignment_hint = Label.new()
	_assignment_hint.add_theme_font_size_override("font_size", 13)
	_assignment_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_assignment_hint.hide()
	# Reserve two lines so notices cannot move the mission controls below this panel.
	# Longer feedback remains readable by scrolling instead of growing over the minimap.
	_notice_slot = ScrollContainer.new()
	_notice_slot.custom_minimum_size = Vector2(350, 42)
	_notice_slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_notice_slot.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_notice_slot.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	_notice_slot.get_v_scroll_bar().custom_step = 21
	content.add_child(_notice_slot)
	var messages = VBoxContainer.new()
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice_slot.add_child(messages)
	_assignment_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages.add_child(_assignment_hint)
	research_status = load("res://source/match/hud/ResearchStatus.gd").new()
	research_status.hud = self
	messages.add_child(research_status)
	var assignment_layer = CanvasLayer.new()
	assignment_layer.layer = -1
	add_child(assignment_layer)
	assignment_layer.add_child(load("res://source/match/hud/ProgramAssignments.gd").new())
	if get_parent().settings.mission_id.is_empty():
		if "relays" in get_parent().map:
			var markers = load("res://source/match/hud/RelayMarkers.gd").new()
			markers.name = "RelayMarkers"
			markers.hud = self
			assignment_layer.add_child(markers)
		battle_plan = load("res://source/match/hud/SkirmishPlanPanel.gd").new()
		battle_plan.hud = self
		add_child(battle_plan)
	alert_panel = load("res://source/match/hud/BattleAlertsPanel.gd").new()
	alert_panel.hud = self
	add_child(alert_panel)
	direct_orders = load("res://source/match/hud/DirectOrders.gd").new()
	direct_orders.name = "DirectOrders"
	add_child(direct_orders)


func _style(panel):
	BattleTheme.apply(panel)


func _button(parent, text_value, callback):
	var button = Button.new()
	button.theme = BattleTheme.create()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size.y = 32
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _process(_delta):
	if is_instance_valid(technology_panel):
		technology_panel.refresh()
		_technology_scroll.custom_minimum_size.y = maxf(
			100, get_viewport().get_visible_rect().size.y - 256
		)
	if _hint_left > 0:
		_hint_left -= _delta
		if _hint_left <= 0 and not map_assignment_active():
			_assignment_hint.hide()
	if not map_assignment_active() and _hint_left <= 0 and _pending_notice != "":
		var notice = _pending_notice
		_pending_notice = ""
		show_notice(notice)
	_objective.text = get_parent().objective_text()
	var seconds = int(get_parent().simulation_time)
	_clock.text = (
		"%02d:%02d · %s · 100 units per side"
		% [
			seconds / 60,
			seconds % 60,
			"PAUSED — orders ready on resume" if get_tree().paused else _match_label()
		]
	)


func _unhandled_input(event):
	var focus = get_viewport().gui_get_focus_owner()
	if event is InputEventKey and (focus is LineEdit or focus is TextEdit):
		return
	if is_instance_valid(program_editor):
		return
	if get_parent().finished:
		return
	if (
		alert_panel != null
		and alert_panel.panel.visible
		and event.is_action_pressed("toggle_match_menu", false, true)
	):
		alert_panel.close()
		get_viewport().set_input_as_handled()
		return
	if _handle_assignment_input(event):
		return
	if event.is_action_pressed("toggle_match_menu", false, true):
		if not direct_orders.kind.is_empty() and _overlay == null:
			direct_orders.cancel()
			get_viewport().set_input_as_handled()
			return
		if _overlay != null:
			_close_menu()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	if _overlay != null:
		return
	if direct_orders.handle_input(event):
		return
	super(event)


func _arm_attack():
	direct_orders.arm("attack_move")


func map_assignment_active():
	return (
		_assignment_kind != ""
		or (is_instance_valid(direct_orders) and not direct_orders.kind.is_empty())
	)


func cancel_map_assignment():
	_assignment_kind = ""
	_assignment_units.clear()
	_assignment_points.clear()
	_assignment_hint.hide()
	if is_instance_valid(direct_orders):
		direct_orders.cancel()


func pause_after_load():
	_pause_owned = true
	get_tree().paused = true
	_pause_button.text = Bindings.hint("Resume", "pause_battle")


func _toggle_pause():
	if is_instance_valid(program_editor):
		return
	if _overlay != null or get_parent().finished:
		return
	super()
	_pause_button.text = (
		Bindings.hint("Resume", "pause_battle")
		if _pause_owned
		else Bindings.hint("Pause", "pause_battle")
	)


func _make_overlay(title_text, cinematic = false):
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 9
	_overlay.add_child(overlay_canvas)
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.07, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 480
	_style(panel)
	center.add_child(panel)
	var layout = HBoxContainer.new()
	layout.add_theme_constant_override("separation", 28)
	panel.add_child(layout)
	if cinematic:
		BattleTheme.artwork(layout, 270)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cinematic:
		box.custom_minimum_size.x = 430
	box.add_theme_constant_override("separation", 12)
	layout.add_child(box)
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 32)
	BattleTheme.heading(box, title, 72)
	return box


func _open_menu():
	if is_instance_valid(program_editor):
		return
	if _overlay != null or get_parent().finished:
		return
	_menu_was_paused = get_tree().paused
	get_tree().paused = true
	var box = _make_overlay("Battle paused", true)
	var help_text = Label.new()
	_menu_help = help_text
	help_text.text = _controls_help()
	help_text.custom_minimum_size.x = 430
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.add_theme_font_size_override("font_size", 14)
	box.add_child(help_text)
	help_text.hide()
	var resume = _button(box, "Resume battle", _close_menu)
	resume.theme_type_variation = "BattlePrimaryButton"
	resume.grab_focus()
	_button(box, "Save / Load battle", func(): get_node("/root/SaveManager").open_dialog("save"))
	_button(box, "Settings", func(): Globals.open_settings())
	_button(box, "Restart match", func(): get_parent().restart())
	_button(box, _setup_title(), _back_to_setup)
	_button(box, "Main menu", _back_to_menu)
	var controls = _button(box, "Controls", func(): help_text.visible = not help_text.visible)
	controls.toggle_mode = true
	box.move_child(help_text, box.get_child_count() - 1)
	for child in box.get_children():
		if child is Button:
			child.custom_minimum_size.y = 40
			child.add_theme_font_size_override("font_size", 16)
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if child != resume:
				child.theme_type_variation = "BattleQuietButton"


func _close_menu():
	_overlay.queue_free()
	_overlay = null
	technology_panel = null
	_technology_scroll = null
	get_tree().paused = _menu_was_paused


func show_result(result):
	get_parent()._get_human_player().get_node("BattleVoice").finish(get_parent().result)
	if _overlay != null:
		_overlay.queue_free()
	get_tree().paused = true

	var game = get_parent()
	var outcome_name = str(result)
	var is_victory = outcome_name.ends_with("Victory") or outcome_name == "Victory"
	var is_defeat = outcome_name.ends_with("Defeat") or outcome_name == "Defeat"
	var is_draw = outcome_name == "Draw"

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 9
	_overlay.add_child(overlay_canvas)

	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.05, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(shade)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(center)

	# Main debrief frame (The ONLY PanelContainer under _overlay)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 0)
	BattleTheme.apply(panel, 20, 16)
	center.add_child(panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# Top Status Banner
	var accent_color = Color("2ecc71") if is_victory else (Color("e74c3c") if is_defeat else Color("d8bc80"))
	var banner_bg = Color("0d2118") if is_victory else (Color("210d0d") if is_defeat else Color("1a1811"))
	var banner_border = Color("27ae6088") if is_victory else (Color("c0392b88") if is_defeat else Color("d8bc8066"))

	var banner_code = "STATUS: OPERATION COMPLETE · TAC-NET SECURED" if is_victory else (
		"STATUS: FORCES COMPROMISED · RETRY RECOMMENDED" if is_defeat else "STATUS: SIMULTANEOUS NEUTRALIZATION"
	)
	var banner_title = "VICTORY // MISSION ACCOMPLISHED" if is_victory else (
		"DEFEAT // COMMAND SIGNAL LOST" if is_defeat else (
			"DRAW // STALEMATE" if is_draw else outcome_name
		)
	)

	var mission_prefix = ""
	if " · " in outcome_name:
		mission_prefix = outcome_name.split(" · ")[0]

	var banner_card = MarginContainer.new()
	banner_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_card.add_theme_constant_override("margin_bottom", 6)
	root_vbox.add_child(banner_card)

	var banner_bg_node = Panel.new()
	banner_bg_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_bg_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_style = StyleBoxFlat.new()
	banner_style.bg_color = banner_bg
	banner_style.border_color = banner_border
	banner_style.set_border_width_all(1)
	banner_style.border_width_left = 5
	banner_style.border_color = accent_color
	banner_style.set_corner_radius_all(0)
	banner_bg_node.add_theme_stylebox_override("panel", banner_style)
	banner_card.add_child(banner_bg_node)

	var banner_inner = MarginContainer.new()
	banner_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_inner.add_theme_constant_override("margin_left", 24)
	banner_inner.add_theme_constant_override("margin_right", 24)
	banner_inner.add_theme_constant_override("margin_top", 18)
	banner_inner.add_theme_constant_override("margin_bottom", 16)
	banner_card.add_child(banner_inner)

	var banner_layout = HBoxContainer.new()
	banner_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_inner.add_child(banner_layout)

	var banner_titles = VBoxContainer.new()
	banner_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_titles.add_theme_constant_override("separation", 4)
	banner_layout.add_child(banner_titles)

	var title_lbl = Label.new()
	title_lbl.text = tr(banner_title)
	title_lbl.add_theme_font_size_override("font_size", 21)
	title_lbl.add_theme_color_override("font_color", BattleTheme.IVORY)
	banner_titles.add_child(title_lbl)

	var sub_lbl = Label.new()
	var sub_text = (tr(mission_prefix) + "  ·  " if not mission_prefix.is_empty() else "") + tr(banner_code)
	sub_lbl.text = sub_text
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", accent_color)
	banner_titles.add_child(sub_lbl)

	var clock_box = VBoxContainer.new()
	clock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_layout.add_child(clock_box)

	var clock_lbl = Label.new()
	clock_lbl.text = tr("Battle duration") + ": " + game.battle_record._clock(game.simulation_time)
	clock_lbl.add_theme_font_size_override("font_size", 13)
	clock_lbl.add_theme_color_override("font_color", Color("d8bc80"))
	clock_box.add_child(clock_lbl)

	# Dual-Pane Debrief & Telemetry Body
	var body_layout = HBoxContainer.new()
	body_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_layout.add_theme_constant_override("separation", 14)
	root_vbox.add_child(body_layout)

	# Left Pane: Mission Debrief
	var left_pane = VBoxContainer.new()
	left_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pane.add_theme_constant_override("separation", 6)
	body_layout.add_child(left_pane)

	var debrief_title = Label.new()
	debrief_title.text = tr("MISSION DEBRIEF") if _is_campaign() else tr("COMBAT DEBRIEF")
	debrief_title.add_theme_font_size_override("font_size", 12)
	debrief_title.add_theme_color_override("font_color", BattleTheme.MUTED)
	left_pane.add_child(debrief_title)

	var debrief_card = MarginContainer.new()
	debrief_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debrief_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_pane.add_child(debrief_card)

	var debrief_bg = Panel.new()
	debrief_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debrief_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debrief_bg.add_theme_stylebox_override("panel", BattleTheme.surface(Color("091116"), 0, 0))
	debrief_card.add_child(debrief_bg)

	var debrief_inner = MarginContainer.new()
	debrief_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debrief_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debrief_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debrief_inner.add_theme_constant_override("margin_left", 16)
	debrief_inner.add_theme_constant_override("margin_right", 16)
	debrief_inner.add_theme_constant_override("margin_top", 14)
	debrief_inner.add_theme_constant_override("margin_bottom", 14)
	debrief_card.add_child(debrief_inner)

	var debrief_box = VBoxContainer.new()
	debrief_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debrief_box.add_theme_constant_override("separation", 8)
	debrief_inner.add_child(debrief_box)

	var survivor_row = HBoxContainer.new()
	debrief_box.add_child(survivor_row)

	var survivor_lbl = Label.new()
	survivor_lbl.text = tr("Surviving forces")
	survivor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survivor_lbl.add_theme_font_size_override("font_size", 13)
	survivor_lbl.add_theme_color_override("font_color", BattleTheme.IVORY)
	survivor_row.add_child(survivor_lbl)

	var survivor_val = Label.new()
	var pop_count = game._get_human_player().population()
	survivor_val.text = "%d / 100" % pop_count if game.settings.skirmish and not _is_campaign() else "%d" % pop_count
	survivor_val.add_theme_font_size_override("font_size", 14)
	survivor_val.add_theme_color_override("font_color", Color("d8bc80"))
	survivor_row.add_child(survivor_val)

	var details_box = VBoxContainer.new()
	details_box.name = "DebriefScroll"
	details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_box.add_theme_constant_override("separation", 6)
	debrief_box.add_child(details_box)

	var details = Label.new()
	var summary_text = game.result_summary()
	if not _is_campaign() and summary_text.begins_with("Battle time "):
		var parts = summary_text.split("\n\n", false, 1)
		if parts.size() > 1:
			summary_text = parts[1]
	details.text = tr(summary_text)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("font_size", 12)
	details.add_theme_color_override("font_color", Color("c0ccd2"))
	details_box.add_child(details)

	if game.battle_record.data.statistics.recorded_from > 0:
		var note = Label.new()
		note.text = (
			tr("Economy and destruction recorded since %s")
			% game.battle_record._clock(game.battle_record.data.statistics.recorded_from)
		)
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color("798481"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details_box.add_child(note)

	# Right Pane: Tactical Telemetry
	var right_pane = VBoxContainer.new()
	right_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pane.add_theme_constant_override("separation", 6)
	body_layout.add_child(right_pane)

	var telemetry_title = Label.new()
	telemetry_title.text = tr("TACTICAL TELEMETRY")
	telemetry_title.add_theme_font_size_override("font_size", 12)
	telemetry_title.add_theme_color_override("font_color", BattleTheme.MUTED)
	right_pane.add_child(telemetry_title)

	var telemetry_card = MarginContainer.new()
	telemetry_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	telemetry_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_pane.add_child(telemetry_card)

	var telemetry_bg = Panel.new()
	telemetry_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	telemetry_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	telemetry_bg.add_theme_stylebox_override("panel", BattleTheme.surface(Color("091116"), 0, 0))
	telemetry_card.add_child(telemetry_bg)

	var telemetry_inner = MarginContainer.new()
	telemetry_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	telemetry_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	telemetry_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	telemetry_inner.add_theme_constant_override("margin_left", 16)
	telemetry_inner.add_theme_constant_override("margin_right", 16)
	telemetry_inner.add_theme_constant_override("margin_top", 14)
	telemetry_inner.add_theme_constant_override("margin_bottom", 14)
	telemetry_card.add_child(telemetry_inner)

	var rows = VBoxContainer.new()
	rows.name = "Statistics"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	telemetry_inner.add_child(rows)

	for entry in game.battle_record.statistics_rows():
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 22
		rows.add_child(row)

		var label = Label.new()
		label.text = tr(entry[0])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("9ab0ba"))
		row.add_child(label)

		var value = Label.new()
		var count = entry[1]
		value.text = str(count)
		value.add_theme_font_size_override("font_size", 14)
		if entry[0] in ["Units lost", "Buildings lost"] and count > 0:
			value.add_theme_color_override("font_color", Color("e06c75"))
		elif entry[0] in ["Enemy units destroyed", "Enemy buildings destroyed"] and count > 0:
			value.add_theme_color_override("font_color", Color("98c379"))
		else:
			value.add_theme_color_override("font_color", BattleTheme.IVORY)
		row.add_child(value)

	# Bottom Actions: Exactly 4 Buttons
	var actions = GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 8)
	root_vbox.add_child(actions)

	var replay = TacticalButton.new()
	replay.name = "PlayAgainButton"
	replay.index_code = "01 //"
	replay.text = "Play again"
	replay.subtitle_text = "Restart match"
	replay.button_height = 42
	replay.pressed.connect(func(): game.restart())
	actions.add_child(replay)
	replay.grab_focus()

	var load_btn = TacticalButton.new()
	load_btn.name = "LoadButton"
	load_btn.index_code = "02 //"
	load_btn.text = "Load saved battle"
	load_btn.subtitle_text = "Restore checkpoint"
	load_btn.button_height = 42
	load_btn.pressed.connect(func(): get_node("/root/SaveManager").open_dialog())
	actions.add_child(load_btn)

	var setup_btn = TacticalButton.new()
	setup_btn.name = "SetupButton"
	setup_btn.index_code = "03 //"
	setup_btn.text = _setup_title()
	setup_btn.subtitle_text = "Mission select" if _is_campaign() else "Map & rules"
	setup_btn.button_height = 42
	setup_btn.pressed.connect(_back_to_setup)
	actions.add_child(setup_btn)

	var menu_btn = TacticalButton.new()
	menu_btn.name = "MainMenuButton"
	menu_btn.index_code = "04 //"
	menu_btn.text = "Main menu"
	menu_btn.subtitle_text = "Exit to title"
	menu_btn.button_height = 42
	menu_btn.pressed.connect(_back_to_menu)
	actions.add_child(menu_btn)

	for button in actions.get_children():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _back_to_setup():
	get_tree().paused = false
	get_tree().change_scene_to_file(
		(
			"res://source/main-menu/Campaign.tscn"
			if _is_campaign()
			else "res://source/main-menu/Play.tscn"
		)
	)


func _is_campaign():
	return not get_parent().settings.mission_id.is_empty()


func _setup_title():
	return "Campaign" if _is_campaign() else "Skirmish setup"


func _match_label():
	if _is_campaign():
		return (
			load("res://source/match/campaign/CampaignCatalog.gd")
			. OPERATIONS[get_parent().settings.mission_id]
			. title
		)
	return "Skirmish"


func _back_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")


func arm_program_assignment(kind, units):
	direct_orders.cancel()
	(
		get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	_assignment_kind = kind
	_hint_left = 0.0
	_assignment_units = units
	_assignment_points.clear()
	_assignment_hint.show()
	_notice_slot.scroll_vertical = 0
	_assignment_hint.text = {
		"signature":
		"Choose an Anchor sector (6 m). Units keep their orders. %s / right-click cancels.",
		"anchor": "Click a guard point. %s / right-click cancels.",
		"safe": "Click a safe point for retreat. %s / right-click cancels.",
		"escort": "Click a friendly unit to escort. %s / right-click cancels.",
		"patrol": "Click the first patrol waypoint. %s / right-click cancels.",
		"install":
		(
			"Click your HQ or service building to fit chips (%d E each)."
			% Factions.chip_cost(units[0].player.faction)
		)
	}[kind]
	if "%s" in _assignment_hint.text:
		_assignment_hint.text = _assignment_hint.text % Bindings.label("toggle_match_menu")


func _handle_assignment_input(event):
	if _assignment_release and event is InputEventMouseButton and not event.pressed:
		_assignment_release = false
		get_viewport().set_input_as_handled()
		return true
	if _assignment_kind == "":
		return false
	if (
		event.is_action_pressed("toggle_match_menu", false, true)
		or (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_RIGHT
		)
	):
		_assignment_kind = ""
		_assignment_hint.hide()
		get_viewport().set_input_as_handled()
		return true
	if (
		not event is InputEventMouseButton
		or not event.pressed
		or event.button_index != MOUSE_BUTTON_LEFT
	):
		return false
	_assignment_release = true
	get_viewport().set_input_as_handled()
	var point = get_viewport().get_camera_3d().get_ray_intersection(event.position)
	var target = _pick_unit(event.position)
	accept_program_assignment(point, target)
	return true


func accept_program_assignment(point, target):
	var kind = _assignment_kind
	var units = _assignment_units.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	if units.is_empty() or kind == "":
		_assignment_kind = ""
		_assignment_hint.hide()
		return false
	if kind in ["anchor", "safe", "patrol", "signature"]:
		if point == null or not point.is_finite():
			return false
		var map_size = get_parent().map.size
		if point.x < 0 or point.z < 0 or point.x > map_size.x or point.z > map_size.y:
			_assignment_hint.text = "Choose a point inside the battlefield."
			return false
	if kind in ["anchor", "safe", "patrol"]:
		# Validate every selected ground unit before changing any program. Only
		# owned footprints are known here; hidden enemy geometry stays private.
		if (
			kind == "patrol"
			and not _assignment_points.is_empty()
			and _assignment_point_in_structure(units, _assignment_points[0])
		):
			_assignment_points.clear()
			_assignment_hint.text = ("First waypoint is blocked by your building. Choose it again.")
			return false
		if _assignment_point_in_structure(units, point * Vector3(1, 0, 1), kind == "safe"):
			_assignment_hint.text = (
				"Choose open ground or a completed repair facility for these units."
				if kind == "safe"
				else "Choose a point outside your buildings for ground units."
			)
			return false
	if kind == "signature":
		var abilities = units[0].player.signatures
		var count = abilities.activate(units, point)
		_assignment_kind = ""
		show_notice(
			(
				"Anchor assigned · %d units. Hold still inside the sector for 2 s." % count
				if count > 0
				else abilities.error
			)
		)
		return count > 0
	if kind == "escort":
		if (
			not is_instance_valid(target)
			or not "player" in target
			or target.player != units[0].player
		):
			_assignment_hint.text = "Choose a friendly unit."
			return false
		if target in units:
			_assignment_hint.text = "Choose an ally outside the selected escort group."
			return false
	if kind == "install":
		var eligible = units.filter(
			func(unit): return not unit.program.installed and unit.program.install_left <= 0
		)
		if eligible.is_empty() or not units[0].program.valid_service(target):
			_assignment_hint.text = "Choose a completed friendly HQ or service building."
			return false
		var fee = Factions.chip_cost(units[0].player.faction)
		if not units[0].player.has_resources({"resource_b": eligible.size() * fee}):
			_assignment_hint.text = (
				"Need %d electronics for %d chips." % [eligible.size() * fee, eligible.size()]
			)
			return false
		for unit in eligible:
			unit.program.install_at(target)
	elif kind == "patrol":
		_assignment_points.append(point * Vector3(1, 0, 1))
		if _assignment_points.size() == 1:
			_assignment_hint.text = "Click the second patrol waypoint."
			return false
		for unit in units:
			unit.program.disable()
			unit.program.route = _assignment_points.duplicate()
	else:
		for unit in units:
			unit.program.disable()
			if kind == "anchor":
				unit.program.anchor = point * Vector3(1, 0, 1)
			elif kind == "safe":
				unit.program.safe_point = point * Vector3(1, 0, 1)
			elif kind == "escort":
				unit.program.escort = target
	_assignment_kind = ""
	_hint_left = 4.0
	_assignment_hint.text = (
		"Installation ordered."
		if kind == "install"
		else "Assignment set. Resume your program, or apply a preset draft."
	)
	return true


func _assignment_point_in_structure(units, point, allow_service = false):
	return units.any(
		func(unit):
			if unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN:
				return false
			var structure = Utils.Match.Unit.Placement.owned_structure_at(unit.player, point)
			# Retreat uses a matching facility's service area, not its center.
			# Share the runtime eligibility rule, including ownership/completion.
			return (
				structure != null
				and (not allow_service or not Repairs.facility_eligible(structure, unit))
			)
	)


func show_notice(message):
	# Keep an in-progress map assignment intact; it owns the instruction line.
	if map_assignment_active():
		_pending_notice = message
		return
	_assignment_hint.text = message
	_notice_slot.scroll_vertical = 0
	_assignment_hint.show()
	_hint_left = 6.0


func open_lua_editor(units, path, entry = {}):
	_open_program_editor(units, path, "lua", entry)


func open_visual_editor(units, path, entry = {}):
	_open_program_editor(units, path, "visual", entry)


func _open_program_editor(units, path, mode, entry):
	if is_instance_valid(program_editor) or _overlay != null or get_parent().finished:
		return
	var editor_path = (
		"res://source/match/hud/VisualProgramEditor.gd"
		if mode == "visual"
		else "res://source/match/hud/LuaProgramEditor.gd"
	)
	program_editor = load(editor_path).new()
	program_editor.library_changed.connect(_refresh_program_library)
	program_editor.game = get_parent()
	program_editor.selection = units.duplicate()
	program_editor.library_path = path
	program_editor.initial = entry
	var cached = visual_draft if mode == "visual" else lua_draft
	if entry.is_empty() and not cached.is_empty():
		program_editor.initial = cached.draft
	get_parent().add_child(program_editor)
	if entry.is_empty() and not cached.is_empty():
		program_editor._roles.select(cached.role_index)
		program_editor._requirements.select(cached.requirement_index)
		program_editor._loaded = cached.loaded.duplicate(true)
		program_editor._assistant_state = cached.get("assistant_state", {}).duplicate(true)
		program_editor._refresh()
		if not cached.get("arena_report", {}).is_empty():
			program_editor._arena_finished(cached.arena_report)


func open_lua_copy(units, path, draft, was_paused):
	open_lua_editor(units, path, draft)
	if is_instance_valid(program_editor):
		program_editor._was_paused = was_paused


func _refresh_program_library():
	var menus = get_parent().find_child("UnitMenus")
	if menus != null:
		for panel in [menus._program_panel, menus._factory_program_panel]:
			if is_instance_valid(panel):
				panel.reload_library()


func _refresh_shortcuts():
	if is_instance_valid(direct_orders) and not direct_orders.kind.is_empty():
		direct_orders.prompt()
	if is_instance_valid(_pause_button):
		_pause_button.text = Bindings.hint("Resume" if _pause_owned else "Pause", "pause_battle")
	if is_instance_valid(_attack_button):
		_attack_button.text = (
			"Choose destination…" if _attack_armed else Bindings.hint("Attack move", "attack_move")
		)
	if is_instance_valid(_menu_button):
		_menu_button.text = Bindings.hint("Menu", "toggle_match_menu")
	if is_instance_valid(_menu_help):
		_menu_help.text = _controls_help()


func _controls_help():
	return (
		(
			"Drag: select · Hold %s: add selection / queue orders\n"
			+ "Right-click: contextual order\n"
			+ "%s: move · %s: attack target · %s: attack move; then click\n"
			+ "%s: tactical pause · Wheel: zoom\n"
			+ "%s / %s / %s / %s: pan · %s / %s: rotate\n"
			+ "%s: assign group 1 · %s: select group 1\n"
			+ "All group bindings: Settings → Controls"
		)
		% [
			Bindings.label("shift_selecting"),
			Bindings.label("move_order"),
			Bindings.label("attack_target"),
			Bindings.label("attack_move"),
			Bindings.label("pause_battle"),
			Bindings.label("move_map_up"),
			Bindings.label("move_map_left"),
			Bindings.label("move_map_down"),
			Bindings.label("move_map_right"),
			Bindings.label("rotate_map_clockwise"),
			Bindings.label("rotate_map_counterclockwise"),
			Bindings.label("unit_groups_set_1"),
			Bindings.label("unit_groups_access_1")
		]
	)


func open_technology():
	if _overlay != null or is_instance_valid(program_editor) or get_parent().finished:
		return
	cancel_map_assignment()
	(
		get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	_menu_was_paused = get_tree().paused
	get_tree().paused = true
	var box = _make_overlay("Technology")
	var close = _button(box, "Back to battle", _close_menu)
	close.grab_focus()
	_technology_scroll = ScrollContainer.new()
	_technology_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_technology_scroll.follow_focus = true
	_technology_scroll.custom_minimum_size = Vector2(
		510, maxf(100, get_viewport().get_visible_rect().size.y - 256)
	)
	_technology_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	_technology_scroll.get_v_scroll_bar().custom_step = 28
	box.add_child(_technology_scroll)
	technology_panel = load("res://source/match/hud/ResearchPanel.gd").new()
	technology_panel.player = get_parent()._get_human_player()
	technology_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_technology_scroll.add_child(technology_panel)


func open_relays():
	if _overlay != null or is_instance_valid(program_editor) or get_parent().finished:
		return
	cancel_map_assignment()
	(
		get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	_menu_was_paused = get_tree().paused
	get_tree().paused = true
	var box = _make_overlay("Relay objectives")
	_button(box, "Back to battle", _close_menu).grab_focus()
	var overview = load("res://source/match/hud/RelayOverview.gd").new()
	overview.name = "RelayOverview"
	overview.hud = self
	box.add_child(overview)
