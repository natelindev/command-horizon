extends RefCounted

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const TacticalButton = preload("res://source/main-menu/TacticalButton.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")


static func build(hud, result):
	hud.get_parent()._get_human_player().get_node("BattleVoice").finish(hud.get_parent().result)
	if hud._overlay != null:
		hud._overlay.queue_free()
	hud.get_tree().paused = true

	var game = hud.get_parent()
	var outcome_name = str(result)
	var is_victory = outcome_name.ends_with("Victory") or outcome_name == "Victory"
	var is_defeat = outcome_name.ends_with("Defeat") or outcome_name == "Defeat"
	var is_draw = outcome_name == "Draw"

	hud._overlay = Control.new()
	hud._overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud._overlay)

	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 9
	hud._overlay.add_child(overlay_canvas)

	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.05, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(shade)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(center)

	# Main debrief frame (The ONLY PanelContainer under hud._overlay)
	var panel = PanelContainer.new()
	BattleTheme.apply(panel, 20, 16)
	center.add_child(panel)
	var viewport = hud.get_viewport()
	var fit_result = func():
		var available = viewport.get_visible_rect().size - Vector2(48, 48)
		panel.custom_minimum_size = Vector2(minf(740, available.x), minf(560, available.y))
	fit_result.call()
	viewport.size_changed.connect(fit_result)
	panel.tree_exiting.connect(func(): viewport.size_changed.disconnect(fit_result))

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# Top Status Banner
	var accent_color = (
		Color("a6d77e") if is_victory else (Color("e8735a") if is_defeat else Color("d8bc80"))
	)
	var banner_bg = (
		Color("0d2118") if is_victory else (Color("210d0d") if is_defeat else Color("1a1811"))
	)
	var banner_border = (
		Color("8fc26a88") if is_victory else (Color("d0604888") if is_defeat else Color("d8bc8066"))
	)

	var banner_code = (
		"STATUS: OPERATION COMPLETE · TAC-NET SECURED"
		if is_victory
		else (
			"STATUS: FORCES COMPROMISED · RETRY RECOMMENDED"
			if is_defeat
			else "STATUS: SIMULTANEOUS NEUTRALIZATION"
		)
	)
	var banner_title = (
		"VICTORY // MISSION ACCOMPLISHED"
		if is_victory
		else (
			"DEFEAT // COMMAND SIGNAL LOST"
			if is_defeat
			else ("DRAW // STALEMATE" if is_draw else outcome_name)
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
	# A recessed status screen tinted by the outcome; the title carries the accent.
	var banner_style = BattleTheme.socket(0, 0)
	banner_style.modulate = banner_bg.lightened(.55)
	banner_bg_node.add_theme_stylebox_override("panel", banner_style)
	var glow = Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style = BattleTheme.glow(.35)
	glow_style.modulate = Color(banner_border, .4)
	glow.add_theme_stylebox_override("panel", glow_style)
	banner_bg_node.add_child(glow)
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
	title_lbl.text = hud.tr(banner_title)
	title_lbl.theme_type_variation = "HudHeading"
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", accent_color.lerp(BattleTheme.IVORY, .25))
	banner_titles.add_child(title_lbl)

	var sub_lbl = Label.new()
	var sub_text = (
		(hud.tr(mission_prefix) + "  ·  " if not mission_prefix.is_empty() else "")
		+ hud.tr(banner_code)
	)
	sub_lbl.text = sub_text
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", accent_color)
	banner_titles.add_child(sub_lbl)

	var clock_box = VBoxContainer.new()
	clock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_layout.add_child(clock_box)

	var clock_lbl = Label.new()
	clock_lbl.text = (
		hud.tr("Battle duration") + ": " + game.battle_record._clock(game.simulation_time)
	)
	clock_lbl.add_theme_font_size_override("font_size", 13)
	clock_lbl.add_theme_color_override("font_color", Color("d8bc80"))
	clock_box.add_child(clock_lbl)

	# Dual-Pane Debrief & Telemetry Body
	var body_scroll = ScrollContainer.new()
	body_scroll.name = "ResultBodyScroll"
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	body_scroll.get_v_scroll_bar().custom_step = 30
	root_vbox.add_child(body_scroll)
	var body_layout = HBoxContainer.new()
	body_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_layout.add_theme_constant_override("separation", 14)
	body_scroll.add_child(body_layout)

	# Left Pane: Mission Debrief
	var left_pane = VBoxContainer.new()
	left_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pane.add_theme_constant_override("separation", 6)
	body_layout.add_child(left_pane)

	var debrief_title = Label.new()
	debrief_title.text = (
		hud.tr("MISSION DEBRIEF") if hud._is_campaign() else hud.tr("COMBAT DEBRIEF")
	)
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
	debrief_bg.add_theme_stylebox_override("panel", BattleTheme.socket(0, 0))
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
	survivor_lbl.text = hud.tr("Surviving forces")
	survivor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survivor_lbl.add_theme_font_size_override("font_size", 13)
	survivor_lbl.add_theme_color_override("font_color", BattleTheme.IVORY)
	survivor_row.add_child(survivor_lbl)

	var survivor_val = Label.new()
	var pop_count = game._get_human_player().population()
	survivor_val.text = (
		"%d / 100" % pop_count
		if game.settings.skirmish and not hud._is_campaign()
		else "%d" % pop_count
	)
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
	if hud._is_campaign():
		var narration = load("res://source/match/campaign/CampaignNarration.gd")
		var cue = (
			game.settings.mission_id + ".victory" if game.result == "Victory" else "common.defeat"
		)
		var ending = narration.record(cue, Globals.options.language)
		if not ending.is_empty():
			summary_text += "\n\n" + ending.text
	if not hud._is_campaign() and summary_text.begins_with("Battle time "):
		var parts = summary_text.split("\n\n", false, 1)
		if parts.size() > 1:
			summary_text = parts[1]
	details.text = hud.tr(summary_text)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("font_size", 12)
	details.add_theme_color_override("font_color", Color("c0ccd2"))
	details_box.add_child(details)
	var next_step = preload("res://source/match/campaign/OpeningGuidance.gd").debrief(game)
	if not next_step.is_empty():
		var advice = Label.new()
		advice.name = "NextStep"
		advice.text = hud.tr("Try next") + "\n" + hud.tr(next_step)
		advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		advice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		advice.add_theme_font_size_override("font_size", 12)
		advice.add_theme_color_override("font_color", BattleTheme.IVORY)
		details_box.add_child(advice)

	if game.battle_record.data.statistics.recorded_from > 0:
		var note = Label.new()
		note.text = (
			hud.tr("Economy and destruction recorded since %s")
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
	telemetry_title.text = hud.tr("TACTICAL TELEMETRY")
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
	telemetry_bg.add_theme_stylebox_override("panel", BattleTheme.socket(0, 0))
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

	var statistics = game.battle_record.statistics_rows()
	if not hud._is_campaign():
		var opponents = game.get_tree().get_nodes_in_group("players").filter(
			func(player): return player != game._get_human_player()
		)
		if not opponents.is_empty():
			statistics.push_front(["AI difficulty", Difficulty.name_of(opponents[0].difficulty)])

	for entry in statistics:
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 22
		rows.add_child(row)

		var label = Label.new()
		label.text = hud.tr(entry[0])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("9ab0ba"))
		row.add_child(label)

		var value = Label.new()
		var count = entry[1]
		value.text = str(count)
		value.add_theme_font_size_override("font_size", 14)
		if entry[0] in ["Units lost", "Buildings lost"] and count > 0:
			value.add_theme_color_override("font_color", BattleTheme.SIGNAL_BAD)
		elif entry[0] in ["Enemy units destroyed", "Enemy buildings destroyed"] and count > 0:
			value.add_theme_color_override("font_color", BattleTheme.HEALTH_OK)
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
	load_btn.pressed.connect(func(): hud.get_node("/root/SaveManager").open_dialog())
	actions.add_child(load_btn)

	var setup_btn = TacticalButton.new()
	setup_btn.name = "SetupButton"
	setup_btn.index_code = "03 //"
	setup_btn.text = hud._setup_title()
	setup_btn.subtitle_text = "Mission select" if hud._is_campaign() else "Map & rules"
	setup_btn.button_height = 42
	setup_btn.pressed.connect(hud._back_to_setup)
	actions.add_child(setup_btn)

	var menu_btn = TacticalButton.new()
	menu_btn.name = "MainMenuButton"
	menu_btn.index_code = "04 //"
	menu_btn.text = "Main menu"
	menu_btn.subtitle_text = "Exit to title"
	menu_btn.button_height = 42
	menu_btn.pressed.connect(hud._back_to_menu)
	actions.add_child(menu_btn)

	for button in actions.get_children():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
