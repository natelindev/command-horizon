extends Control

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")
const MenuChrome = preload("res://source/main-menu/MenuChrome.gd")
var progress_path = Progress.PATH
var _difficulty: OptionButton
var _challenge: OptionButton
var _operation_buttons = []
var _mission_id = "supply_line"
var _hero_story: Label
var _briefing: Label
var _completion: Label
var _note: Label
var _response: Label
var _start_button: Button
var _starting = false
var _challenge_box: VBoxContainer
var _theater_intel: Label
var _progress
var _ids = Catalog.ORDER.bastion.duplicate()
var _faction = "bastion"
var _faction_picker: OptionButton
var _operation_list: VBoxContainer
var _heading: Label
var _body: GridContainer
var _hero_art: TextureRect
var _backdrop = null
var _header = {}


func _ready():
	ArtTheme.Console.use_faction(_faction)
	theme = ArtTheme.create()
	_progress = Progress.new()
	_progress.read_progress(progress_path)
	_backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	_backdrop.dim = .50
	_backdrop.left_focus = 0.35
	_backdrop.set_accent(ArtTheme.accent())
	add_child(_backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_faction_picker = OptionButton.new()
	for title in ["Bastion Directorate", "Helix Systems", "Free Frontier Coalition"]:
		_faction_picker.add_item(tr(title))
	_faction_picker.fit_to_longest_item = false
	_faction_picker.custom_minimum_size = Vector2(210, 32)
	_faction_picker.item_selected.connect(_select_faction)

	_header = MenuChrome.screen_header(column, tr("CAMPAIGN"), "", _faction_picker)
	_heading = _header.title

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	_body = GridContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("h_separation", 14)
	_body.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_body)
	var operations = PanelContainer.new()
	operations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	operations.size_flags_stretch_ratio = 0.88
	operations.theme_type_variation = "HudHousing"
	operations.add_theme_stylebox_override("panel", ArtTheme.panel(12))
	_body.add_child(operations)
	var ops_col = VBoxContainer.new()
	ops_col.add_theme_constant_override("separation", 8)
	operations.add_child(ops_col)
	MenuChrome.nameplate_heading(ops_col, tr("Operations"))
	_operation_list = VBoxContainer.new()
	_operation_list.add_theme_constant_override("separation", 6)
	ops_col.add_child(_operation_list)

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.25
	panel.theme_type_variation = "HudHousing"
	panel.add_theme_stylebox_override("panel", ArtTheme.panel(14))
	_body.add_child(panel)
	var dossier = VBoxContainer.new()
	dossier.add_theme_constant_override("separation", 8)
	panel.add_child(dossier)

	var top_card = HBoxContainer.new()
	top_card.add_theme_constant_override("separation", 12)
	dossier.add_child(top_card)

	var portrait_frame = PanelContainer.new()
	portrait_frame.theme_type_variation = "HudSocket"
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_card.add_child(portrait_frame)

	_hero_art = TextureRect.new()
	_hero_art.name = "CommanderPortrait"
	_hero_art.custom_minimum_size = Vector2(72, 72)
	_hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_hero_art)

	var dossier_head = VBoxContainer.new()
	dossier_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_head.alignment = BoxContainer.ALIGNMENT_CENTER
	dossier_head.add_theme_constant_override("separation", 4)
	top_card.add_child(dossier_head)

	_completion = _label(dossier_head, "", 13, ArtTheme.accent())
	_completion.add_theme_font_override("font", ArtTheme.heading_font())
	_hero_story = _label(dossier_head, "", 14, ArtTheme.IVORY)
	_hero_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_theater_intel = _label(dossier_head, "Your hero must survive.", 12, ArtTheme.MUTED)
	_theater_intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var intel_socket = PanelContainer.new()
	intel_socket.theme_type_variation = "HudSocket"
	intel_socket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier.add_child(intel_socket)

	var intel_col = VBoxContainer.new()
	intel_col.add_theme_constant_override("separation", 6)
	intel_socket.add_child(intel_col)
	_briefing = _label(intel_col, "", 14, ArtTheme.IVORY)
	_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note = _label(intel_col, "", 12, ArtTheme.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_response = _label(intel_col, "", 12, ArtTheme.MUTED)
	_response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var opts_row = HBoxContainer.new()
	opts_row.add_theme_constant_override("separation", 12)
	dossier.add_child(opts_row)
	var diff_col = VBoxContainer.new()
	diff_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_col.add_theme_constant_override("separation", 3)
	opts_row.add_child(diff_col)
	_label(diff_col, "Difficulty", 12, ArtTheme.MUTED)
	_difficulty = OptionButton.new()
	_difficulty.fit_to_longest_item = false
	_difficulty.custom_minimum_size.y = 30
	_difficulty.item_selected.connect(func(_index): _refresh_horizon_response())
	diff_col.add_child(_difficulty)

	_challenge_box = VBoxContainer.new()
	_challenge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_challenge_box.add_theme_constant_override("separation", 3)
	opts_row.add_child(_challenge_box)
	_label(_challenge_box, "Replay challenge", 12, ArtTheme.MUTED)
	_challenge = OptionButton.new()
	_challenge.fit_to_longest_item = false
	_challenge.custom_minimum_size.y = 30
	for title in [
		"Standard mission",
		"Lean deployment · fewer reserves and funds",
		"Reinforced garrison · extra defenders and response units"
	]:
		_challenge.add_item(tr(title))
	_challenge.item_selected.connect(func(_index): _refresh_horizon_response())
	_challenge_box.add_child(_challenge)
	if not _progress.error.is_empty():
		_label(dossier, _progress.error, 12)

	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var main_btn = _button(
		actions,
		"Main menu",
		func(): get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
	)
	main_btn.custom_minimum_size = Vector2(130, 38)
	var hub_btn = _button(
		actions,
		"Command hub",
		func(): get_tree().change_scene_to_file("res://source/main-menu/CampaignHub.tscn")
	)
	hub_btn.custom_minimum_size = Vector2(140, 38)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_start_button = _button(actions, "Start", _start)
	_start_button.theme_type_variation = "BattlePrimaryButton"
	_start_button.custom_minimum_size = Vector2(210, 38)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_select_faction(0)
	_start_button.grab_focus()


func _layout():
	_body.columns = 2 if get_viewport_rect().size.x >= 800 else 1


func _select_faction(index):
	_faction = ["bastion", "helix", "frontier"][index]
	_hero_art.texture = Artwork.commander(_faction)
	ArtTheme.Console.use_faction(_faction)
	theme = ArtTheme.create()
	if _backdrop != null:
		_backdrop.set_accent(ArtTheme.accent())
	MenuChrome.sync_header_accent(_header, ArtTheme.accent())
	for panel in _body.get_children():
		panel.add_theme_stylebox_override("panel", ArtTheme.panel(12))
	_ids = Catalog.ORDER[_faction].duplicate()
	for child in _operation_list.get_children():
		_operation_list.remove_child(child)
		child.queue_free()
	_operation_buttons.clear()
	var group = ButtonGroup.new()
	for slot in _ids.size():
		var operation = Catalog.operations()[_ids[slot]]
		var button = _button(
			_operation_list,
			operation.number + " · " + tr(operation.title),
			_select_operation.bind(slot)
		)
		button.theme_type_variation = "BattleCardButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 36)
		_operation_buttons.append(button)
	var hub_state = load("res://source/match/campaign/CampaignHubState.gd").new()
	var state_path = hub_state.path_for(self)
	hub_state.read_state(state_path)
	var pts_avail = hub_state.points_available(_faction, _progress)
	_heading.text = (
		"%s · %d / %d · %s"
		% [
			tr("CAMPAIGN"),
			_ids.filter(func(id): return _progress.completed(id)).size(),
			_ids.size(),
			tr("%d Tech Points Available") % pts_avail
		]
	)
	var next_op = _progress.next_uncompleted_operation(_faction)
	var def_slot = _ids.find(next_op)
	if def_slot < 0:
		def_slot = 0
	_select_operation(def_slot)


func _select_operation(index):
	_mission_id = _ids[index]
	var unlocked = _progress.is_operation_unlocked(_mission_id, _faction)
	_challenge.visible = _mission_id == "command_horizon"
	if is_instance_valid(_challenge_box):
		_challenge_box.visible = _challenge.visible
	_challenge.disabled = not _progress.horizon_complete
	_challenge.tooltip_text = (
		"Complete Command Horizon to unlock replay challenges."
		if not _progress.horizon_complete
		else "Challenges preserve tactical pause, manual orders and required counters."
	)
	_challenge.select(0)
	for i in _operation_buttons.size():
		var op_btn: Button = _operation_buttons[i]
		var active = i == index
		op_btn.set_pressed_no_signal(active)
		op_btn.theme_type_variation = "BattlePrimaryButton" if active else "BattleCardButton"

	_theater_intel.text = tr("Your hero must survive.")
	var entry = Catalog.operations()[_mission_id]
	_hero_story.visible = not Catalog.is_story(_mission_id) and entry.has("summary")
	_hero_story.text = entry.get(
		"summary_zh" if Globals.options.language == "zh_CN" else "summary", ""
	)
	if Catalog.is_story(_mission_id):
		var operation = Catalog.operations()[_mission_id]
		_completion.text = (
			tr("Completed")
			if _progress.completed(_mission_id)
			else (tr("Available") if unlocked else tr("Locked"))
		)
		_briefing.text = (
			operation.summary_zh if Globals.options.language == "zh_CN" else operation.summary
		)
		var objectives = []
		for objective in operation.objectives:
			objectives.append(
				objective.zh_CN if Globals.options.language == "zh_CN" else objective.title
			)
		_note.text = "\n".join(objectives)
		if not unlocked:
			_note.text += "\n" + tr("Complete previous operation to unlock.")
		_response.text = tr("Finite enemy responses. Escort losses mean defeat.")
		_difficulty.clear()
		for title in ["Story", "Standard", "Veteran"]:
			_difficulty.add_item(tr(title))
		_difficulty.select(1)
		_start_button.text = tr("Start %s") % tr(operation.title)
		_start_button.disabled = not unlocked
		_start_button.tooltip_text = (
			"" if unlocked else tr("Complete previous operation to unlock.")
		)
		return
	var split = _ids[index] == "split_signal"
	var supply = _ids[index] == "supply_line"
	if _mission_id == "command_horizon":
		_horizon_briefing()
		_start_button.disabled = not unlocked
		_start_button.tooltip_text = (
			"" if unlocked else tr("Complete previous operation to unlock.")
		)
		if not unlocked:
			_completion.text = tr("Locked")
		return
	if _mission_id == "broken_foundry":
		_foundry_briefing()
		_start_button.disabled = not unlocked
		_start_button.tooltip_text = (
			"" if unlocked else tr("Complete previous operation to unlock.")
		)
		if not unlocked:
			_completion.text = tr("Locked")
		return
	_completion.text = (
		tr("Completed")
		if (
			_progress.supply_complete
			if supply
			else (_progress.split_complete if split else _progress.complete)
		)
		else (tr("Available") if unlocked else tr("Locked"))
	)
	_start_button.disabled = not unlocked
	_start_button.tooltip_text = "" if unlocked else tr("Complete previous operation to unlock.")
	_difficulty.clear()
	for title in (
		[
			"Story · 4 units per response",
			"Standard · 6 units per response",
			"Veteran · 8 units per response"
		]
		if split
		else [
			"Story · 3 units per response",
			"Standard · 4 units per response",
			"Veteran · 5 units per response"
		]
	):
		_difficulty.add_item(tr(title))
	_difficulty.select(1)
	_start_button.text = tr("Start %s") % tr(Catalog.operations()[_ids[index]].title)
	if supply:
		_briefing.text = (
			"A Bastion convoy must cross a contested freight corridor.\n\n"
			+ "1. Scout and clear three checkpoints with infantry and tanks.\n"
			+ "2. Advance or hold the convoy; use repair robots on damaged trucks.\n"
			+ "3. Each truck stops for 12 seconds at a clear checkpoint. Extract at least two.\n\n"
			+ "Two truck losses mean defeat. Use Tactical pause to plan orders. "
			+ "No base building is required."
		)
		_note.text = (
			"Completion gives First Orders +20 starting materials. "
			+ (
				"Supply support earned."
				if _progress.supply_complete
				else "Protect the convoy to earn it."
			)
		)
		_response.text = (
			"Three finite, warned responses. Story / Standard / Veteran: "
			+ "3 / 4 / 5 defenders per checkpoint, 2 / 3 / 4 reinforcements."
		)
		_difficulty.clear()
		for label in ["Story", "Standard", "Veteran"]:
			_difficulty.add_item(tr(label))
		_difficulty.select(1)
	elif split:
		_briefing.text = (
			"Helix is fragmenting the mountain uplink. Keep two fronts supplied "
			+ "while you reconnect it.\n\n1. Capture any two of three relays with "
			+ "infantry.\n2. Hold two uncontested relays for 120 cumulative "
			+ "seconds.\n3. Split your armor and repair support across separate "
			+ "assignments.\n\nYour command lab and armored support are ready. Direct "
			+ "orders always take priority.\nDefeat: lose all forces and HQ, or "
			+ "fail to rebuild HQ within 60 seconds."
		)
		_note.text = tr("Hold all three relays for 20 seconds to reduce the guards at Cinder Ford.")
		if _progress.network_badge:
			_note.text += "\n" + tr("Support earned.")
		_response.text = (
			"Six warned responses from the northeast and southeast, starting "
			+ "after your first capture."
		)
	else:
		_briefing.text = (
			"Helix has cut access to a logistics relay. Restore your command "
			+ "network,\nposition your defenders, and take the relay back.\n\n"
			+ "1. Build a command lab.\n2. Order a tank to Guard a defensive "
			+ "position.\n3. Capture the relay with infantry and hold for 60 "
			+ "uncontested seconds.\n\nDefeat: lose all forces and HQ, or fail to "
			+ "rebuild HQ within 60 seconds.\nReinforcements begin after you "
			+ "secure the relay."
		)
		_note.text = (
			"Optional: use Guard and Follow together to earn Adaptive doctrine.\n"
			+ (
				"Adaptive doctrine · earned"
				if _progress.doctrine_badge
				else "The badge is cosmetic and not required to complete the operation."
			)
		)
		_response.text = "Three objective-directed responses. Unit health and damage stay the same."


func _foundry_briefing():
	_completion.text = (
		tr("Completed · finale approach unlocked")
		if _progress.foundry_complete
		else tr("Available")
	)
	_briefing.text = (
		"Take the industrial works without losing your support force.\n\n"
		+ "1. Destroy the north and south production nodes to cancel their unfinished units.\n"
		+ "2. Scout around warehouses; infantry and armor take separate street approaches.\n"
		+ "3. Infantry capture in 10 seconds, then secure 30 cumulative, uncontested seconds.\n\n"
		+ "Protect repair robots. Repair channels do not stack; Guard areas bound pursuit.\n"
		+ "Rebuild a lost HQ within 60 seconds."
	)
	_note.text = tr("Completion unlocks an alternate approach in the finale.") + "\n"
	_note.text += (
		tr("Rescue support: +20 starting electronics.")
		if _progress.foundry_support()
		else tr("Rescue the Cinder Ford survivors to gain +20 starting electronics here.")
	)
	_response.text = (
		"District entry starts three finite paid batches per node. "
		+ "Disabling both warns one final east response."
	)
	_difficulty.clear()
	for title in [
		"Story · 1 unit per batch", "Standard · 2 units per batch", "Veteran · 3 units per batch"
	]:
		_difficulty.add_item(tr(title))
	_difficulty.select(1)
	_start_button.text = tr("Start %s") % tr("Broken Foundry")


func _horizon_briefing():
	_completion.text = (
		tr("Finale completed · replay challenges unlocked")
		if _progress.horizon_complete
		else tr("Available")
	)
	_briefing.text = (
		"Secure the forward deployment zone, then break Helix command.\n\n"
		+ "1. Infantry capture the zone in 10s, then hold for 30 cumulative uncontested seconds.\n"
		+ "2. Leave a guard and infantry at deployment while your mixed strike force destroys the HQ.\n\n"
		+ "Recapture lost deployment to finish; rebuild your HQ within 60s."
	)
	_note.text = (
		(
			"Broken Foundry support: the north ground passage is open."
			if _progress.foundry_complete
			else "Use the south ground pass. Broken Foundry completion opens a north passage."
		)
		+ "\nRequired troops, Coordination and air support are available in every run."
	)
	if _progress.lean_complete or _progress.reinforced_complete:
		_completion.text += (
			" · "
			+ ("Lean " if _progress.lean_complete else "")
			+ ("Reinforced" if _progress.reinforced_complete else "")
		)
	_difficulty.clear()
	for title in ["Story", "Standard", "Veteran"]:
		_difficulty.add_item(tr(title))
	_difficulty.select(1)
	_refresh_horizon_response()
	_start_button.text = tr("Start %s") % tr("Command Horizon")


func _refresh_horizon_response():
	if _mission_id != "command_horizon":
		return
	var ground = [2, 3, 4][_difficulty.selected] + (1 if _challenge.selected == 2 else 0)
	var air = [1, 1, 2][_difficulty.selected]
	_response.text = tr("Four warned responses · %d ground + %d air units each.") % [ground, air]
	if _challenge.selected == 1:
		_response.text += tr(
			" Lean: 4 tanks, 8 infantry, 2 engineers; 80 materials / 40 electronics."
		)
	elif _challenge.selected == 2:
		_response.text += tr(
			" Reinforced: 4 extra HQ infantry and the extra ground unit per response."
		)


func _label(parent, text, size, color_value = Color("edf2f7")):
	var label = Label.new()
	label.text = tr(text)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color_value)
	parent.add_child(label)
	return label


func _button(parent, text, callback):
	var button = Button.new()
	button.text = tr(text)
	button.custom_minimum_size = Vector2(190, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _start():
	if _starting:
		return
	_starting = true
	_start_button.disabled = true
	var launch = load("res://source/main-menu/CampaignLaunch.gd")
	var challenge = (
		["", "lean", "reinforced"][_challenge.selected] if _mission_id == "command_horizon" else ""
	)
	launch.deploy(self, launch.settings_for(_mission_id, _difficulty.selected, challenge))
