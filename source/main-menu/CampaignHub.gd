extends Control

const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const HubState = preload("res://source/match/campaign/CampaignHubState.gd")
const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")
const FACTIONS = ["bastion", "helix", "frontier"]
const WORLDS = {
	"bastion": "BastionWarTrain", "helix": "HelixNexusCore", "frontier": "FrontierOutpost"
}
const HUB_TITLES = {
	"bastion": "The Iron Bastion", "helix": "Orbital Nexus Core", "frontier": "Dustfall Outpost"
}
const STATIONS = {
	"bastion": ["Command table", "Motor pool", "Radio console"],
	"helix": ["Harmonic spire", "Nanite foundry", "Data archive"],
	"frontier": ["The workbench", "Scrap yard", "The barricade"]
}
var progress_path = Progress.PATH
var hub_state_path = HubState.PATH
var music_faction = "bastion"
var faction = "bastion"
var world
var station = 0
var _progress
var _state
var _viewport: SubViewport
var _world_container: SubViewportContainer
var _panel: PanelContainer
var _body: VBoxContainer
var _heading: Label
var _status: Label
var _faction_picker: OptionButton
var _mission_picker: OptionButton
var _difficulty: OptionButton
var _challenge: OptionButton
var _summary: Label
var _start_button: Button
var _station_buttons = []
var _audio: AudioStreamPlayer
var _transmission = []
var _transmission_index = 0
var _caption: Label
var _commander_art: TextureRect
var _archive_art: TextureRect
var _starting = false
var _preview = null
var _preview_clock = 0.0
var _preview_left = 0.0


func _ready():
	_progress = Progress.new()
	_progress.read_progress(progress_path)
	_state = HubState.new()
	_state.read_state(hub_state_path)
	faction = _state.faction
	music_faction = faction
	ArtTheme.Console.use_faction(faction)
	theme = ArtTheme.create()
	_world_container = SubViewportContainer.new()
	_world_container.stretch = true
	_world_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_world_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.physics_object_picking = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_container.add_child(_viewport)
	var header = PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 16
	header.offset_right = -16
	header.offset_top = 14
	header.add_theme_stylebox_override("panel", ArtTheme.panel())
	add_child(header)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	_commander_art = _portrait(row, 52)
	_heading = _label(row, "", 22)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_picker = OptionButton.new()
	for title in ["Bastion Directorate", "Helix Systems", "Free Frontier Coalition"]:
		_faction_picker.add_item(tr(title))
	_faction_picker.fit_to_longest_item = false
	_faction_picker.custom_minimum_size.x = 170
	_faction_picker.item_selected.connect(_select_faction)
	row.add_child(_faction_picker)
	_faction_picker.select(FACTIONS.find(faction))
	_button(
		row,
		"Main menu",
		func(): get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
	)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ArtTheme.panel())
	add_child(_panel)
	_panel.resized.connect(func(): _layout.call_deferred())
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var group = ButtonGroup.new()
	for index in 3:
		var button = _button(tabs, "", _open_station.bind(index))
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_station_buttons.append(button)
	_status = _label(column, "", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 7)
	column.add_child(_body)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Voice"
	_audio.add_to_group("narration_audio")
	_audio.finished.connect(_next_transmission)
	add_child(_audio)
	resized.connect(_layout)
	_select_faction(FACTIONS.find(faction))
	_layout()


func _label(parent: Node, value: String, font_size = 16) -> Label:
	var label = Label.new()
	label.text = tr(value)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _portrait(parent: Node, side: int) -> TextureRect:
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(side, side)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(portrait)
	return portrait


func _button(parent: Node, value: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = tr(value)
	# Native font metrics include CJK glyph widths and the themed key padding.
	button.custom_minimum_size.x = 84
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _select_faction(index: int):
	_audio.stop()
	_transmission.clear()
	faction = FACTIONS[index]
	_commander_art.texture = Artwork.commander(faction)
	_faction_picker.select(index)
	music_faction = faction
	ArtTheme.Console.use_faction(faction)
	theme = ArtTheme.create()
	_panel.add_theme_stylebox_override("panel", ArtTheme.panel())
	_heading.text = tr(HUB_TITLES[faction])
	if _state.error.is_empty():
		_state.faction = faction
		_state.save_state(hub_state_path)
	if is_instance_valid(world):
		_viewport.remove_child(world)
		world.queue_free()
	world = load("res://source/match/campaign/%s.tscn" % WORLDS[faction]).instantiate()
	_viewport.add_child(world)
	world.station_selected.connect(_open_station)
	for slot in 3:
		_station_buttons[slot].text = tr(STATIONS[faction][slot])
	_open_station(0)


func _open_station(index: int):
	station = index
	_audio.stop()
	_transmission.clear()
	for slot in _station_buttons.size():
		_station_buttons[slot].set_pressed_no_signal(slot == index)
	world.focus_station(index)
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_progress.read_progress(progress_path)
	_state.read_state(hub_state_path)
	var pts_avail = _state.points_available(faction, _progress)
	_status.text = (
		"%s · %d / %d · %s"
		% [
			tr("Operations completed"),
			_progress.completed_count(faction),
			Catalog.ORDER[faction].size(),
			tr("%d Tech Points Available") % pts_avail
		]
	)
	if not _state.error.is_empty():
		_status.text = tr(_state.error)
	for slot in 3:
		var tab_name = tr(STATIONS[faction][slot])
		if slot == 1 and pts_avail > 0:
			tab_name += " (★)"
		_station_buttons[slot].text = tab_name
	match index:
		0:
			_deployment()
		1:
			_workshop()
		2:
			_archive()
	_layout.call_deferred()


func _deployment():
	var row = HBoxContainer.new()
	_body.add_child(row)
	_mission_picker = OptionButton.new()
	_mission_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_picker.fit_to_longest_item = false
	for id in Catalog.ORDER[faction]:
		var entry = Catalog.operations()[id]
		var mark = ""
		if _progress.completed(id):
			mark = " ✓"
		elif not _progress.is_operation_unlocked(id, faction):
			mark = " 🔒"
		else:
			mark = " ►"
		_mission_picker.add_item(
			"%s · %s%s" % [entry.number, tr(entry.title), mark]
		)
	_mission_picker.item_selected.connect(_select_mission)
	row.add_child(_mission_picker)
	_difficulty = OptionButton.new()
	for title in ["Story", "Standard", "Veteran"]:
		_difficulty.add_item(tr(title))
	_difficulty.select(1)
	row.add_child(_difficulty)
	_start_button = _button(row, "Deploy", _deploy)
	_start_button.theme_type_variation = "BattlePrimaryButton"
	_summary = _label(_body, "", 16)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.max_lines_visible = 3
	var actions = HBoxContainer.new()
	_body.add_child(actions)
	_challenge = OptionButton.new()
	for title in ["Standard mission", "Lean deployment", "Reinforced garrison"]:
		_challenge.add_item(tr(title))
	actions.add_child(_challenge)
	_button(
		actions,
		"Full mission board",
		func(): get_tree().change_scene_to_file("res://source/main-menu/Campaign.tscn")
	)
	var next_id = _progress.next_uncompleted_operation(faction)
	var default_index = Catalog.ORDER[faction].find(next_id)
	if default_index < 0:
		default_index = 0
	_mission_picker.select(default_index)
	_select_mission(default_index)


func _select_mission(index: int):
	var id = Catalog.ORDER[faction][index]
	var entry = Catalog.operations()[id]
	var unlocked = _progress.is_operation_unlocked(id, faction)
	var prefix = ""
	if not unlocked:
		prefix = tr("LOCKED · Complete previous operation to deploy.") + "\n\n"
		_start_button.disabled = true
		_start_button.tooltip_text = tr("Complete previous operation to unlock.")
	else:
		_start_button.disabled = false
		_start_button.tooltip_text = ""
	_summary.text = (
		prefix
		+ (entry.summary_zh if Globals.options.language == "zh_CN" else entry.summary)
		+ "\n"
		+ tr("Secondary objective: return your hero with at least half hull intact.")
	)
	_challenge.visible = id == "command_horizon"
	_challenge.disabled = not _progress.horizon_complete
	_challenge.select(0)


func _deploy():
	if _starting:
		return
	var launch = load("res://source/main-menu/CampaignLaunch.gd")
	var settings = launch.settings_for(
		Catalog.ORDER[faction][_mission_picker.selected],
		_difficulty.selected,
		["", "lean", "reinforced"][_challenge.selected]
	)
	if settings != null:
		_starting = true
		launch.deploy(self, settings)


func _workshop():
	var tech = load("res://source/match/research/TechnologyCatalog.gd")
	var chosen = _state.doctrines.get(faction, "")
	var pts_avail = _state.points_available(faction, _progress)
	var pts_earned = _state.total_points_earned(faction, _progress)
	var pts_spent = _state.points_spent(faction)

	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	_body.add_child(header_row)

	var pts_label = _label(
		header_row,
		tr("%d Tech Points Available") % pts_avail + " · " + (tr("Earned: %d · Spent: %d") % [pts_earned, pts_spent]),
		15
	)
	pts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var reset_btn = _button(header_row, "Reset upgrades", _reset_upgrades)
	reset_btn.disabled = pts_spent <= 0

	var description = _label(_body, "Permanent campaign doctrine", 16)
	description.tooltip_text = tr(
		"Choose once for this faction. The doctrine applies to new campaign operations."
	)
	var choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	_body.add_child(choices)
	for id in HubState.DOCTRINES[faction]:
		var card = VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(card)
		var button = _button(card, tech.title(id, faction), _choose_doctrine.bind(id))
		button.disabled = not chosen.is_empty() or _progress.completed_count(faction) < 1
		button.tooltip_text = tr(tech.description(id, faction))
		if chosen == id:
			button.text += " ✓"
		var detail = _label(card, tech.description(id, faction), 13)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.max_lines_visible = 3
	if _progress.completed_count(faction) < 1:
		_label(_body, "Complete one operation to unlock a permanent doctrine.", 13)

	_label(_body, "Permanent campaign upgrades (applies to all operations)", 16)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 110
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_body.add_child(scroll)

	var up_grid = GridContainer.new()
	up_grid.columns = 3
	up_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_grid.add_theme_constant_override("h_separation", 8)
	up_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(up_grid)

	for id in HubState.FACTION_UPGRADES[faction]:
		var has = _state.has_upgrade(faction, id)
		var cost = HubState.UPGRADE_COSTS.get(id, 100)
		var can = _state.can_purchase_upgrade(faction, id, _progress)
		var btn_text = tech.title(id, faction)
		if has:
			btn_text += " ✓"
		else:
			btn_text += " · %d pts" % cost
		var btn = _button(up_grid, btn_text, _buy_upgrade.bind(id))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = has or not can
		var desc = tech.description(id, faction)
		if has:
			btn.tooltip_text = tr(desc) + "\n" + tr("Purchased")
		elif not can:
			if HubState.UPGRADE_REQUIREMENTS.has(id) and not _state.has_upgrade(faction, HubState.UPGRADE_REQUIREMENTS[id]):
				btn.tooltip_text = tr(desc) + "\n" + (tr("Requires %s") % tech.title(HubState.UPGRADE_REQUIREMENTS[id], faction))
			else:
				btn.tooltip_text = tr(desc) + "\n" + tr("Need more Tech Points")
		else:
			btn.tooltip_text = tr(desc)

	if faction == "frontier":
		_label(
			_body,
			(
				tr("Recovered wreck trophies")
				+ " · %d" % maxi(0, _state.recoveries.size() - _state.insignia.size())
			),
			13
		)
		var insignias = HBoxContainer.new()
		_body.add_child(insignias)
		for id in HubState.INSIGNIA:
			var button = _button(insignias, id, _forge.bind(id))
			button.disabled = (
				id in _state.insignia or _state.recoveries.size() <= _state.insignia.size()
			)
			button.tooltip_text = tr(
				"Forge a cosmetic insignia from one recovered operation trophy."
			)
			if id in _state.insignia:
				button.text += " ✓"


func _buy_upgrade(id: String):
	_state.purchase_upgrade(faction, id, hub_state_path, _progress)
	_open_station(1)


func _reset_upgrades():
	_state.reset_upgrades(faction, hub_state_path)
	_open_station(1)


func _choose_doctrine(id: String):
	if _progress.completed_count(faction) < 1:
		return
	_state.choose_doctrine(faction, id, hub_state_path)
	_open_station(1)


func _forge(id: String):
	_state.forge_insignia(id, hub_state_path)
	_open_station(1)


func _archive():
	var row = HBoxContainer.new()
	_body.add_child(row)
	var picker = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	row.add_child(picker)
	for id in Catalog.ORDER[faction]:
		var entry = Catalog.operations()[id]
		picker.add_item(
			"%s · %s%s" % [entry.number, tr(entry.title), " ✓" if _progress.completed(id) else ""]
		)
	_button(
		row,
		"Play transmission",
		func(): _play_transmission(Catalog.ORDER[faction][picker.selected])
	)
	_button(row, "Replay briefing", func(): _start_preview(Catalog.ORDER[faction][picker.selected]))
	var transmission = HBoxContainer.new()
	transmission.add_theme_constant_override("separation", 12)
	_body.add_child(transmission)
	_archive_art = _portrait(transmission, 80)
	_archive_art.texture = Artwork.commander(faction)
	_caption = _label(transmission, "", 16)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.max_lines_visible = 4
	_caption.text = tr(
		{
			"bastion": "Aegis: Orders matter. So do the people who carry them out.",
			"helix":
			"Nyx: An archive can preserve the truth, or bury it. Choose what you remember.",
			"frontier":
			"Rook: Dust Rangers and Iron Wardens. Different colors, same promise: bring your people home."
		}[faction]
	)
	var controls = HBoxContainer.new()
	_body.add_child(controls)
	_button(controls, "Stop transmission", func(): _audio.stop())
	if faction == "frontier":
		_button(controls, "Talk to Dust Rangers", _talk_mercenary.bind("MercenaryRanger"))
		_button(controls, "Talk to Iron Wardens", _talk_mercenary.bind("MercenaryWarden"))
	elif faction == "bastion":
		_button(controls, "Intercepted channel", _play_cue.bind("supply_line.checkpoint"))
	else:
		_button(controls, "Meridian records", _play_cue.bind("helix_the_gate.intro"))


func _play_transmission(id: String):
	var narration = load("res://source/match/campaign/CampaignNarration.gd")
	var cue = id + (".victory" if _progress.completed(id) else ".intro")
	_transmission = narration.scene(cue, Globals.options.language)
	_transmission_index = -1
	_status.text += (
		" · "
		+ tr(
			(
				"Preservation commendation earned"
				if id in _state.commendations
				else "Preservation commendation not yet earned"
			)
		)
	)
	_next_transmission()


func _play_cue(cue: String):
	_transmission = load("res://source/match/campaign/CampaignNarration.gd").scene(
		cue, Globals.options.language
	)
	_transmission_index = -1
	_next_transmission()


func _talk_mercenary(role: String):
	_audio.stop()
	_transmission.clear()
	var bank = load("res://source/match/audio/UnitVoiceBank.gd").new()
	var lines = bank.role_lines("frontier", role)
	var line = lines.get("select", [])[0]
	var title = load("res://source/match/world/MercenaryCatalog.gd").UNITS[role].title
	_caption.text = tr(title) + "\n" + tr(line.text)
	_archive_art.texture = load("res://source/match/FactionCatalog.gd").portrait("frontier", role)
	_audio.stream = load(line.stream)
	_audio.play()


func _next_transmission():
	if is_instance_valid(_preview):
		return
	_transmission_index += 1
	if _transmission_index >= _transmission.size() or not is_instance_valid(_caption):
		return
	var line = _transmission[_transmission_index]
	_caption.text = "%s\n%s" % [line.speaker, line.text]
	var portrait = line.get("portrait", "")
	_archive_art.texture = load(portrait) if not portrait.is_empty() else Artwork.commander(faction)
	_audio.stream = load(line.stream)
	_audio.play()


func _start_preview(id: String):
	_audio.stop()
	var narration = load("res://source/match/campaign/CampaignNarration.gd")
	_transmission = narration.scene(
		id + (".briefing" if narration.lines().has(id + ".briefing") else ".intro"),
		Globals.options.language
	)
	_transmission_index = -1
	_preview_clock = 0.0
	_preview = load("res://source/match/campaign/CampaignBriefing.tscn").instantiate()
	add_child(_preview)
	_preview.configure(id)
	var duration = 0.0
	for line in _transmission:
		var stream = load(line.stream)
		duration += maxf(line.get("duration", -1.0), stream.get_length())
	_preview.duration = maxf(45, duration)
	_preview.skip_button.pressed.connect(_close_preview)
	_preview.skip_button.grab_focus()
	_next_preview_line()


func _next_preview_line():
	_transmission_index += 1
	if _transmission_index >= _transmission.size():
		_preview_left = INF
		return
	var line = _transmission[_transmission_index]
	_audio.stream = load(line.stream)
	_audio.play()
	_preview_left = maxf(line.get("duration", -1.0), _audio.stream.get_length())
	_preview.caption.set_line(line.speaker, line.text, Globals.options.subtitle_size)
	_preview.caption.set_caption_visible(true)


func _process(delta):
	if not is_instance_valid(_preview):
		return
	_preview_clock += delta
	_preview_left -= delta
	_preview.seek(_preview_clock)
	if _preview_left <= 0:
		_next_preview_line()
	if _preview_clock >= _preview.duration and _transmission_index >= _transmission.size():
		_close_preview()


func _close_preview():
	_audio.stop()
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	_transmission.clear()
	_station_buttons[station].grab_focus()


func _unhandled_key_input(event):
	if is_instance_valid(_preview) and event.is_action_pressed("ui_cancel"):
		_close_preview()
		get_viewport().set_input_as_handled()


func _layout():
	if not is_instance_valid(_panel):
		return
	_panel.position = Vector2(16, 0)
	_panel.size.x = maxf(1, size.x - 32)
	_panel.size.y = minf(size.y - 80, _panel.get_combined_minimum_size().y)
	_panel.position.y = size.y - _panel.size.y - 14
	_world_container.offset_bottom = -maxf(0, _panel.size.y * .45)


func _exit_tree():
	if is_instance_valid(_audio):
		_audio.stop()
