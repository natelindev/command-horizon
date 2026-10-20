# gdlint: disable=max-returns
extends "res://source/match/hud/BastionDemoHUD.gd"

const CampaignCatalog = preload("res://source/match/campaign/CampaignCatalog.gd")
const CampaignObjectives = preload("res://source/match/campaign/CampaignObjectives.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const HudKey = preload("res://source/match/hud/HudKey.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
var alert_panel = null
## Every building producing or under construction, docked under the system plate.
var production_overview = null
var direct_orders
var command_feedback
var technology_panel = null
var research_status
## Top-right console plate: mission clock, system keys and the alerts beacon slot.
var system_plate: PanelContainer
var alert_slot: Control
var _hero_action: Button
var _hero_select: Button
var _escort_action: Button
var _dialogue_skip: Button
var _technology_scroll = null
var _technology_button
var _objective = null
var _objective_hint: Label
var _view_objective: Button
var _clock = null
var _clock_state = null
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
var _assignment_hint
var _notice_slot: ScrollContainer
var _assignment_release = false
var _hint_left = 0.0
var _pending_notice = ""
var _briefing: PanelContainer
var _resources: Control


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_resources = get_parent().get_node("HUD/MarginContainer2/Resources")
	# Mission briefing: hangs from the resources plate at the top of the left column.
	var panel = PanelContainer.new()
	_briefing = panel
	panel.name = "MissionBriefing"
	panel.position = Vector2(0, HudLayout.COLUMN_TOP)
	panel.custom_minimum_size.x = HudLayout.COLUMN_WIDTH
	_style(panel)
	panel.get_theme_stylebox("panel").content_margin_top = 12
	panel.get_theme_stylebox("panel").content_margin_bottom = 10
	add_child(panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var title = Label.new()
	var players = get_tree().get_nodes_in_group("players")
	title.text = (
		tr("Free-for-all · %d commanders") % players.size()
		if players.size() > 2
		else "%s  vs  %s" % [Factions.NAMES[players[0].faction], Factions.NAMES[players[1].faction]]
	)
	title.add_theme_font_size_override("font_size", 15)
	var header = BattleTheme.heading(content, title, 30)
	# Long matchups trim on the nameplate; the full title stays available on hover.
	title.tooltip_text = title.text
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	if not _is_campaign():
		_difficulty_tag(header, players)
		# Match setup already names the factions. Keep the battle objective prominent.
		header.hide()
	_objective = Label.new()
	_objective.add_theme_font_size_override("font_size", 13)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _is_campaign():
		_objective.tooltip_text = title.text
		_objective.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(_objective)
	if _is_campaign() and CampaignCatalog.is_story(get_parent().settings.mission_id):
		_objective_hint = Label.new()
		_objective_hint.name = "ObjectiveInstructions"
		_objective_hint.add_theme_font_size_override("font_size", 12)
		_objective_hint.add_theme_color_override("font_color", BattleTheme.MUTED)
		_objective_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(_objective_hint)
	_build_system_plate()
	Globals.options.changed.connect(_refresh_shortcuts)
	_assignment_hint = Label.new()
	_assignment_hint.add_theme_font_size_override("font_size", 13)
	_assignment_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_assignment_hint.hide()
	# Reserve two lines so notices cannot move the mission controls below this panel.
	# Longer feedback remains readable by scrolling instead of growing over the minimap.
	_notice_slot = ScrollContainer.new()
	_notice_slot.custom_minimum_size = Vector2(HudLayout.COLUMN_WIDTH - 32, 42)
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
	if get_parent().settings.mission_id.is_empty():
		if "relays" in get_parent().map and not get_parent().map.relays.is_empty():
			var markers = load("res://source/match/hud/RelayMarkers.gd").new()
			markers.name = "RelayMarkers"
			markers.hud = self
			assignment_layer.add_child(markers)
	production_overview = load("res://source/match/hud/ProductionOverview.gd").new()
	production_overview.hud = self
	add_child(production_overview)
	alert_panel = load("res://source/match/hud/BattleAlertsPanel.gd").new()
	alert_panel.hud = self
	add_child(alert_panel)
	direct_orders = load("res://source/match/hud/DirectOrders.gd").new()
	direct_orders.name = "DirectOrders"
	add_child(direct_orders)
	command_feedback = load("res://source/match/hud/CommandFeedback.gd").new()
	command_feedback.hud = self
	add_child(command_feedback)


func _style(panel):
	BattleTheme.apply(panel)


func _build_system_plate():
	system_plate = PanelContainer.new()
	system_plate.name = "SystemPlate"
	system_plate.theme = BattleTheme.create()
	var plate = BattleTheme.strip(16, 0)
	plate.content_margin_top = HudLayout.TOP_RAIL + 1
	plate.content_margin_bottom = 7
	plate.content_margin_right = 10
	system_plate.add_theme_stylebox_override("panel", plate)
	system_plate.custom_minimum_size.y = HudLayout.TOP_PLATE
	add_child(system_plate)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var column = VBoxContainer.new()
	system_plate.add_child(column)
	column.add_child(row)
	var readout = PanelContainer.new()
	readout.name = "MissionClock"
	readout.add_theme_stylebox_override("panel", BattleTheme.socket(10, 1))
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	readout.custom_minimum_size = Vector2(84, 36)
	readout.tooltip_text = "100 units per side"
	row.add_child(readout)
	var clock_column = VBoxContainer.new()
	clock_column.add_theme_constant_override("separation", -5)
	clock_column.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_child(clock_column)
	_clock = Label.new()
	_clock.theme_type_variation = "HudNumeral"
	_clock.add_theme_font_size_override("font_size", 20)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_column.add_child(_clock)
	_clock_state = Label.new()
	_clock_state.theme_type_variation = "HudCaption"
	_clock_state.uppercase = true
	_clock_state.add_theme_font_size_override("font_size", 10)
	_clock_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_clock_state.custom_minimum_size.x = 72
	clock_column.add_child(_clock_state)
	row.add_child(VSeparator.new())
	_pause_button = _key(row, "pause", _toggle_pause)
	_attack_button = _key(row, "attack_move", _arm_attack)
	_attack_button.toggle_mode = true
	_technology_button = _key(row, "tech", open_technology)
	_technology_button.name = "OpenTechnology"
	_technology_button.tooltip_text = "Technology"
	if "points_of_interest" in get_parent().map:
		var sites = _key(row, "sites", open_sites)
		sites.name = "OpenSites"
		sites.tooltip_text = "Capturable facilities"
	if (
		not _is_campaign()
		and "relays" in get_parent().map
		and not get_parent().map.relays.is_empty()
	):
		var relays = _key(row, "relays", open_relays)
		relays.name = "OpenRelays"
		relays.tooltip_text = "View relay ownership, capture progress and locations."
	_menu_button = _key(row, "menu", _open_menu)
	for key in [_technology_button, _menu_button]:
		key.accessibility_name = key.tooltip_text
	row.add_child(VSeparator.new())
	# BattleAlertsPanel docks its beacon here; it lives on a higher canvas layer.
	alert_slot = Control.new()
	alert_slot.name = "AlertSlot"
	alert_slot.custom_minimum_size = Vector2(164, 38)
	alert_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alert_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(alert_slot)
	if _is_campaign():
		var hero_row = HBoxContainer.new()
		column.add_child(hero_row)
		_hero_select = _button(hero_row, "Hero", _select_hero)
		_view_objective = _button(hero_row, "View objective", _focus_objective)
		_view_objective.name = "ViewObjective"
		_hero_action = _button(hero_row, "Ability", func(): get_parent().campaign_hero.activate())
		_escort_action = _button(hero_row, "Advance convoy", func(): get_parent().advance_escort())
		_dialogue_skip = _button(
			hero_row, "Skip dialogue", func(): get_parent().campaign_story.skip_dialogue()
		)
	_refresh_shortcuts()


func _key(parent, glyph, callback):
	var key = HudKey.new()
	key.glyph = BattleTheme.icon(glyph)
	key.custom_minimum_size = Vector2(44, 42)
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.pressed.connect(callback)
	parent.add_child(key)
	return key


func _sync_key(key, title, action):
	# Icon keys carry their shortcut in the badge and the full hint in the tooltip.
	key.badge = Bindings.label(action)
	key.tooltip_text = Bindings.hint(title, action)
	key.accessibility_name = key.tooltip_text


func _difficulty_tag(header, players):
	var human = get_parent()._get_human_player()
	var opponents = players.filter(func(player): return player != human)
	if opponents.is_empty():
		return
	var tag = Label.new()
	tag.name = "OpponentDifficulty"
	tag.text = Difficulty.TAGS[Difficulty.clamp_level(opponents[0].difficulty)]
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color("a9b4b3"))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(tag)


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
	_refresh_hero_controls()
	if is_instance_valid(technology_panel):
		technology_panel.refresh()
		_technology_scroll.custom_minimum_size.y = minf(
			technology_panel.get_combined_minimum_size().y,
			maxf(100, get_viewport().get_visible_rect().size.y - 256)
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
	# Campaign controls below this card must stay still during held clicks.
	_notice_slot.visible = _is_campaign() or _assignment_hint.visible or research_status.visible
	_notice_slot.custom_minimum_size.y = 42 if _is_campaign() or _assignment_hint.visible else 34
	_briefing.size.y = _briefing.get_combined_minimum_size().y
	# Full visibility and spectators show every player's resource plate.
	_resources.fit_height(_briefing.size.y + HudLayout.COLUMN_TOP - HudLayout.TOP_PLATE)
	_briefing.position.y = maxf(
		HudLayout.COLUMN_TOP,
		_resources.get_global_rect().end.y + HudLayout.COLUMN_TOP - HudLayout.TOP_PLATE
	)
	if _is_campaign():
		var help = CampaignObjectives.instructions(get_parent())
		_objective.tooltip_text = help
		_objective.accessibility_description = help
		_view_objective.tooltip_text = help
		if _objective_hint != null:
			_objective_hint.text = help
	var seconds = int(get_parent().simulation_time)
	_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	var paused = get_tree().paused
	# The caption names a campaign operation or a pause; a skirmish clock needs no label.
	_clock_state.text = "Paused" if paused else (_match_label() if _is_campaign() else "")
	_clock_state.visible = not _clock_state.text.is_empty()
	_clock_state.add_theme_color_override(
		"font_color", BattleTheme.accent() if paused else BattleTheme.MUTED
	)
	_clock_state.tooltip_text = "PAUSED — orders ready on resume" if paused else ""
	system_plate.position = Vector2(
		get_viewport().get_visible_rect().size.x - system_plate.size.x, 0
	)


func _unhandled_input(event):
	var focus = get_viewport().gui_get_focus_owner()
	if event is InputEventKey and (focus is LineEdit or focus is TextEdit):
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
	_assignment_hint.hide()
	if is_instance_valid(direct_orders):
		direct_orders.cancel()


## Replaces the selection and centres the camera, as HUD shortcuts do. Pending map
## assignments, direct orders and structure placement end; unit orders are kept.
func select_units(units, focus = null):
	if _overlay != null or get_parent().finished:
		return false
	if units.is_empty():
		return false
	cancel_map_assignment()
	_refresh_shortcuts()
	(
		get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	MatchSignals.deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	get_parent().get_node("IsometricCamera3D").set_position_safely(
		focus if focus is Vector3 and focus.is_finite() else units[0].global_position_yless
	)
	return true


func pause_after_load():
	_pause_owned = true
	get_tree().paused = true
	_refresh_shortcuts()


func _toggle_pause():
	if _overlay != null or get_parent().finished:
		return
	super()
	_refresh_shortcuts()


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
	load("res://source/match/hud/SkirmishResults.gd").build(self, result)


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
		return CampaignCatalog.OPERATIONS[get_parent().settings.mission_id].title
	return "Skirmish"


func _back_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")


## Arms the Bastion Anchor sector: the next map click places the ability.
func arm_signature_sector(units):
	direct_orders.cancel()
	(
		get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	_assignment_kind = "signature"
	_hint_left = 0.0
	_assignment_units = units
	_assignment_hint.show()
	_notice_slot.scroll_vertical = 0
	_assignment_hint.text = (
		"Choose an Anchor sector (6 m). Units keep their orders. %s / right-click cancels."
		% Bindings.label("toggle_match_menu")
	)


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
	accept_signature_sector(get_viewport().get_camera_3d().get_ray_intersection(event.position))
	return true


func accept_signature_sector(point):
	var units = _assignment_units.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	if units.is_empty() or _assignment_kind == "":
		_assignment_kind = ""
		_assignment_hint.hide()
		return false
	if point == null or not point.is_finite():
		return false
	var map_size = get_parent().map.size
	if point.x < 0 or point.z < 0 or point.x > map_size.x or point.z > map_size.y:
		_assignment_hint.text = "Choose a point inside the battlefield."
		return false
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


func show_notice(message):
	# Keep an in-progress map assignment intact; it owns the instruction line.
	if map_assignment_active():
		_pending_notice = message
		return
	_assignment_hint.text = message
	_notice_slot.scroll_vertical = 0
	_assignment_hint.show()
	load("res://source/match/hud/HudMotion.gd").play(_assignment_hint, true)
	_hint_left = 6.0


func _refresh_shortcuts():
	if is_instance_valid(direct_orders) and not direct_orders.kind.is_empty():
		direct_orders.prompt()
	if is_instance_valid(_pause_button):
		_sync_key(_pause_button, "Resume" if _pause_owned else "Pause", "pause_battle")
		_pause_button.glyph = BattleTheme.icon("resume" if _pause_owned else "pause")
	if is_instance_valid(_attack_button):
		_sync_key(_attack_button, "Attack move", "attack_move")
		if _attack_armed:
			_attack_button.tooltip_text = "Choose destination…"
		_attack_button.set_pressed_no_signal(_attack_armed)
	if is_instance_valid(_menu_button):
		_sync_key(_menu_button, "Menu", "toggle_match_menu")
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
	if _overlay != null or get_parent().finished:
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
	_technology_scroll.custom_minimum_size = Vector2(510, 100)
	_technology_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	_technology_scroll.get_v_scroll_bar().custom_step = 28
	box.add_child(_technology_scroll)
	technology_panel = load("res://source/match/hud/ResearchPanel.gd").new()
	technology_panel.player = get_parent()._get_human_player()
	technology_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_technology_scroll.add_child(technology_panel)


func open_relays():
	if _overlay != null or get_parent().finished:
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


func open_camp(site):
	if _overlay != null or get_parent().finished:
		return
	cancel_map_assignment()
	(
		get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	MatchSignals.deselect_all_units.emit()
	get_parent().find_child("UnitMenus").open_camp(site)


func open_sites(site = null):
	if _overlay != null or get_parent().finished:
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
	var box = _make_overlay("Capturable facilities")
	_button(box, "Back to battle", _close_menu).grab_focus()
	var overview = load("res://source/match/hud/PointOfInterestOverview.gd").new()
	overview.name = "PointOfInterestOverview"
	overview.focus_site = site
	overview.hud = self
	box.add_child(overview)


func _focus_objective():
	if _overlay != null or get_parent().finished:
		return
	var point = CampaignObjectives.point(get_parent())
	get_parent().get_node("IsometricCamera3D").set_position_safely(point)


func _select_hero():
	var hero = get_parent().campaign_hero
	if hero == null or not hero.alive():
		return
	MatchSignals.deselect_all_units.emit()
	hero.unit.get_node("Selection").select()
	get_parent().get_node("IsometricCamera3D").set_position_safely(hero.unit.global_position)


func _refresh_hero_controls():
	if _hero_action == null:
		return
	var game = get_parent()
	var hero = game.campaign_hero
	if hero != null:
		_hero_action.text = (
			tr(hero.title()) + (" · %ds" % ceili(hero.cooldown) if hero.cooldown > 0 else "")
		)
		_hero_action.tooltip_text = tr(hero.description()) + "\n" + tr("Hero tier %d") % hero.tier
		_hero_action.disabled = (
			not hero.alive() or hero.cooldown > 0 or game.finished or get_tree().paused
		)
		_hero_select.disabled = not hero.alive()
	_escort_action.visible = (
		game.has_method("advance_escort") and game.current_objective().kind == "escort"
	)
	_escort_action.disabled = game.finished
	_dialogue_skip.visible = (
		game.campaign_story != null and not game.campaign_story.current.is_empty()
	)
