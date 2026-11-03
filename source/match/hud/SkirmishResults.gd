extends RefCounted

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")


static func build(hud, result):
	var game = hud.get_parent()
	var presentation = game.get_node_or_null("BattlePresentation")
	if presentation != null:
		presentation.end_collapse()
	game._get_human_player().get_node("BattleVoice").finish(game.result)
	if hud._overlay != null:
		hud._overlay.queue_free()
	hud.get_tree().paused = true
	BattleTheme.use_faction(game._get_human_player().faction)
	hud._overlay = Control.new()
	hud._overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud._overlay)
	var canvas = CanvasLayer.new()
	canvas.layer = 9
	hud._overlay.add_child(canvas)
	var shade = ColorRect.new()
	shade.color = Color(.015, .025, .035, .85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	var panel = PanelContainer.new()
	panel.name = "ResultsPanel"
	BattleTheme.apply(panel, 24, 20)
	center.add_child(panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	var victory = str(result).ends_with("Victory")
	var defeat = str(result).ends_with("Defeat")
	var accent = (
		BattleTheme.HEALTH_OK
		if victory
		else BattleTheme.SIGNAL_BAD if defeat else BattleTheme.COPPER
	)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	_icon(header, "stance" if victory else "alerts", 40, accent)
	var headings = VBoxContainer.new()
	headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(headings)
	_label(headings, hud.tr("BATTLE REPORT"), 13, BattleTheme.accent())
	var title = _label(
		headings, hud.tr("Victory" if victory else "Defeat" if defeat else str(result)), 36, accent
	)
	title.theme_type_variation = "HudHeading"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var context = _label(
		headings,
		hud.tr("MISSION DEBRIEF" if hud._is_campaign() else "COMBAT DEBRIEF"),
		13,
		BattleTheme.MUTED
	)
	if " · " in str(result):
		context.text = hud.tr(str(result).split(" · ")[0])
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var scroll = ScrollContainer.new()
	scroll.name = "ResultBodyScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	scroll.get_v_scroll_bar().custom_step = 36
	content.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	var record = game.battle_record
	var data = record.data
	var owner = game._get_human_player()
	var roster = final_roster(game)
	var overview = GridContainer.new()
	overview.name = "ResultOverview"
	overview.columns = 4
	overview.add_theme_constant_override("h_separation", 12)
	overview.add_theme_constant_override("v_separation", 12)
	body.add_child(overview)
	for entry in [
		["Battle duration", record._clock(game.simulation_time), "pause"],
		["Enemy units destroyed", data.statistics.units_destroyed, "attack"],
		["Units produced", data.forces_trained + data.engineers_trained, "plan"],
		["Surviving units", roster.forces + roster.engineers, "stance"]
	]:
		var box = _card(overview)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		_icon(row, entry[2], 24, BattleTheme.accent())
		var value = _label(row, str(entry[1]), 30, BattleTheme.IVORY)
		value.add_theme_font_override("font", BattleTheme.numeral_font())
		var caption = _label(box, hud.tr(entry[0]), 13, BattleTheme.MUTED)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var statistics = GridContainer.new()
	statistics.name = "Statistics"
	statistics.columns = 2
	statistics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	statistics.add_theme_constant_override("h_separation", 16)
	statistics.add_theme_constant_override("v_separation", 16)
	body.add_child(statistics)
	var difficulty = "—"
	var opponents = game.get_tree().get_nodes_in_group("players").filter(
		func(player): return player != owner
	)
	if not opponents.is_empty():
		difficulty = hud.tr(Difficulty.name_of(opponents[0].difficulty))
	var groups = [
		[
			"COMBAT",
			"attack",
			[
				["Enemy units destroyed", data.statistics.units_destroyed, "attack"],
				["Enemy buildings destroyed", data.statistics.structures_destroyed, "sites"],
				["Combat units lost", data.forces_lost, "alerts"],
				["Engineers lost", data.engineers_lost, "recover"],
				["AI difficulty", difficulty, "stance"]
			]
		],
		[
			"FORCES",
			"stance",
			[
				["Combat units trained", data.forces_trained, "plan"],
				["Engineers trained", data.engineers_trained, "recover"],
				["Combat units surviving", roster.forces, "hold"],
				["Engineers surviving", roster.engineers, "recover"],
				["Army capacity used", owner.population(), "stance"]
			]
		],
		[
			"ECONOMY",
			"cargo",
			[
				["Materials mined", data.statistics.materials, "cargo"],
				["Electronics mined", data.statistics.electronics, "tech"],
				["Materials remaining", owner.resource_a, "cargo"],
				["Electronics remaining", owner.resource_b, "tech"],
				[
					"Resources mined / min",
					roundi(
						(
							(data.statistics.materials + data.statistics.electronics)
							* 60.0
							/ maxf(1.0, game.simulation_time)
						)
					),
					"return"
				]
			]
		],
		[
			"BASE & TECHNOLOGY",
			"sites",
			[
				["Buildings completed", data.statistics.structures_built, "sites"],
				["Buildings surviving", roster.structures, "hold"],
				["Completed buildings lost", data.structures_lost, "alerts"],
				["Unfinished buildings lost", data.foundations_lost, "plan"],
				[
					"Research completed",
					(
						(owner.technology.completed.size() if owner.technology != null else 0)
						+ int(owner.coordination_unlocked)
					),
					"tech"
				]
			]
		]
	]
	for group in groups:
		var box = _card(statistics)
		var heading = HBoxContainer.new()
		heading.add_theme_constant_override("separation", 10)
		box.add_child(heading)
		_icon(heading, group[1], 22, BattleTheme.accent())
		_label(heading, hud.tr(group[0]), 16, BattleTheme.accent())
		box.add_child(HSeparator.new())
		for entry in group[2]:
			_stat(box, hud.tr(entry[0]), entry[1], entry[2])
	_debrief(body, hud, game)

	var next_op = ""
	var next_title = ""
	if hud._is_campaign() and victory:
		var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
		next_op = catalog.next_operation(game.settings.mission_id)
		if not next_op.is_empty():
			next_title = catalog.operations()[next_op].title

	var actions = GridContainer.new()
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	content.add_child(actions)
	var next_btn = null
	if not next_op.is_empty():
		next_btn = _button(
			actions,
			"NextOperationButton",
			hud.tr("Next operation: %s") % hud.tr(next_title),
			"plan",
			func(): hud.continue_campaign_to(next_op)
		)
		next_btn.theme_type_variation = "BattlePrimaryButton"
	elif hud._is_campaign() and victory:
		var victory_btn = _button(
			actions,
			"CampaignVictoryButton",
			hud.tr("Campaign Completed! Return to Hub"),
			"stance",
			hud._back_to_setup
		)
		victory_btn.theme_type_variation = "BattlePrimaryButton"
	var replay = _button(
		actions, "PlayAgainButton", hud.tr("Play again"), "reverse", func(): game.restart()
	)
	var inspect = _button(
		actions,
		"InspectBattlefieldButton",
		hud.tr("Inspect battlefield"),
		"move",
		func(): presentation.inspect_battlefield()
	)
	inspect.disabled = presentation == null or not game.finished
	_button(
		actions,
		"LoadButton",
		hud.tr("Load saved battle"),
		"return",
		func(): hud.get_node("/root/SaveManager").open_dialog()
	)
	var setup_label = hud._setup_title()
	if hud._is_campaign() and victory:
		setup_label = hud.tr("Command hub (Workshop)")
	_button(actions, "SetupButton", hud.tr(setup_label), "plan", hud._back_to_setup)
	_button(actions, "MainMenuButton", hud.tr("Main menu"), "menu", hud._back_to_menu)
	if is_instance_valid(next_btn):
		next_btn.grab_focus()
	else:
		replay.grab_focus()
	var viewport = hud.get_viewport()
	var fit = func():
		var available = viewport.get_visible_rect().size
		var target = Vector2(minf(1500, available.x - 40), minf(1000, available.y - 40))
		panel.custom_minimum_size = target
		# A previous larger minimum must not hold the centered frame off-screen.
		panel.size = target
		overview.columns = 2 if target.x < 760 else 4
		statistics.columns = 1 if target.x < 650 else 2
		actions.columns = 2 if target.x < 700 else 3
		title.add_theme_font_size_override("font_size", 26 if target.y < 650 else 36)
	fit.call()
	viewport.size_changed.connect(fit)
	panel.tree_exiting.connect(func(): viewport.size_changed.disconnect(fit))


static func final_roster(game):
	var counts = {"forces": 0, "engineers": 0, "structures": 0}
	for unit in game.get_units():
		if (
			unit.player != game._get_human_player()
			or unit.hp == null
			or unit.hp <= 0
			or unit.is_queued_for_deletion()
		):
			continue
		if unit.has_method("is_constructed"):
			if unit.is_constructed():
				counts.structures += 1
		elif unit.movement_speed > 0:
			counts["engineers" if unit.type == "Worker" else "forces"] += 1
	return counts


static func _card(parent):
	var card = MarginContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var backdrop = Panel.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel", BattleTheme.socket(0, 0))
	card.add_child(backdrop)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	card.add_child(margin)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	return box


static func _label(parent, text, size, color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func _icon(parent, name, size, color):
	var icon = TextureRect.new()
	icon.texture = BattleTheme.icon(name)
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


static func _stat(parent, text, count, icon):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 24
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	_icon(row, icon, 18, BattleTheme.MUTED)
	var label = _label(row, text, 14, BattleTheme.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(row, str(count), 18, BattleTheme.IVORY)


static func _button(parent, name, text, icon, callback):
	var button = Button.new()
	button.name = name
	button.text = text
	button.icon = BattleTheme.icon(icon)
	button.add_theme_constant_override("icon_max_width", 20)
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 16)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


static func _debrief(parent, hud, game):
	var next_step = preload("res://source/match/campaign/OpeningGuidance.gd").debrief(game)
	if not hud._is_campaign() and next_step.is_empty():
		return
	var box = _card(parent)
	box.name = "DebriefScroll"
	if hud._is_campaign():
		_label(box, hud.tr("MISSION DEBRIEF"), 16, BattleTheme.accent())
		var summary = game.result_summary()
		var narration = load("res://source/match/campaign/CampaignNarration.gd")
		var cue = (
			game.settings.mission_id + ".victory" if game.result == "Victory" else "common.defeat"
		)
		var ending = narration.scene(cue, Globals.options.language)
		for line in ending:
			summary += "\n\n" + line.speaker + ": " + line.text
		var hub_state = load("res://source/match/campaign/CampaignHubState.gd").new()
		hub_state.record_debrief(game)
		hub_state.read_state(hub_state.path_for(game))
		if game.settings.mission_id in hub_state.commendations:
			summary += "\n\n" + hud.tr("Preservation commendation earned")
		if game.result == "Victory":
			var progress = load("res://source/match/campaign/CampaignProgress.gd").new()
			var ppath = game.progress_path if "progress_path" in game else progress.PATH
			progress.read_progress(ppath)
			var fac = game._get_human_player().faction
			var avail = hub_state.points_available(fac, progress)
			var pts_text = "\n\n" + (hud.tr("Campaign Upgrade Points earned: +%d") % 100)
			if game.settings.mission_id in hub_state.commendations:
				pts_text += " " + hud.tr("(+50 Preservation Bonus)")
			pts_text += "\n" + (hud.tr("Total Upgrade Points available: %d") % avail)
			summary += pts_text
		var details = _label(box, hud.tr(summary), 14, BattleTheme.MUTED)
		details.name = "StoryDebrief"
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not next_step.is_empty():
		var advice = _label(
			box, hud.tr("Try next") + "\n" + hud.tr(next_step), 14, BattleTheme.IVORY
		)
		advice.name = "NextStep"
		advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
