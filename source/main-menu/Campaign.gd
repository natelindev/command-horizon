extends Control

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
var progress_path = Progress.PATH
var _difficulty: OptionButton
var _challenge: OptionButton
var _operation_buttons = []
var _mission_id = "supply_line"
var _briefing: Label
var _completion: Label
var _note: Label
var _response: Label
var _start_button: Button
var _starting = false
var _progress
var _ids = [
	"supply_line",
	"first_orders",
	"split_signal",
	"air_corridor",
	"broken_foundry",
	"command_horizon"
]


func _ready():
	var background = ColorRect.new()
	background.color = Color("0c1520")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var heading = _label(column, "BASTION CAMPAIGN", 30)
	var operations = HBoxContainer.new()
	operations.add_theme_constant_override("separation", 12)
	column.add_child(operations)
	var group = ButtonGroup.new()
	for index in _ids.size():
		var entry = Catalog.OPERATIONS[_ids[index]]
		var button = _button(
			operations,
			(
				entry.number
				+ " · "
				+ ["Supply", "Orders", "Signal", "Air", "Foundry", "Horizon"][index]
			),
			_select_operation.bind(index)
		)
		button.custom_minimum_size.x = 0
		button.tooltip_text = entry.title
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_operation_buttons.append(button)
	_progress = Progress.new()
	_progress.read_progress(progress_path)
	heading.text = "BASTION CAMPAIGN · %d / 6" % _progress.completed_count()
	_completion = _label(column, "", 14)
	_briefing = _label(column, "", 17)
	_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note = _label(column, "", 14)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _progress.error.is_empty():
		_label(column, _progress.error, 13)
	_difficulty = OptionButton.new()
	_difficulty.custom_minimum_size.y = 40
	column.add_child(_difficulty)
	_challenge = OptionButton.new()
	_challenge.custom_minimum_size.y = 40
	for title in [
		"Standard mission",
		"Lean deployment · fewer reserves and funds",
		"Reinforced garrison · extra defenders and response units"
	]:
		_challenge.add_item(title)
	_challenge.item_selected.connect(func(_index): _refresh_horizon_response())
	_difficulty.item_selected.connect(func(_index): _refresh_horizon_response())
	column.add_child(_challenge)
	_response = _label(column, "", 13)
	_response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(column, "Six operations available. Optional rewards never remove required counters.", 13)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_start_button = _button(actions, "", _start)
	_button(
		actions,
		"Main menu",
		func(): get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
	)
	_select_operation(0)
	_start_button.grab_focus()


func _select_operation(index):
	_mission_id = _ids[index]
	_challenge.visible = _mission_id == "command_horizon"
	_challenge.disabled = not _progress.horizon_complete
	_challenge.tooltip_text = (
		"Complete Command Horizon to unlock replay challenges."
		if not _progress.horizon_complete
		else "Challenges preserve tactical pause, manual orders and required counters."
	)
	_challenge.select(0)
	_operation_buttons[index].set_pressed_no_signal(true)
	var split = _ids[index] == "split_signal"
	var air = _ids[index] == "air_corridor"
	var supply = _ids[index] == "supply_line"
	if _mission_id == "command_horizon":
		_horizon_briefing()
		return
	if _mission_id == "broken_foundry":
		_foundry_briefing()
		return
	if air:
		_air_briefing()
		return
	_completion.text = (
		"Completed"
		if (
			_progress.supply_complete
			if supply
			else (_progress.split_complete if split else _progress.complete)
		)
		else "Available"
	)
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
		_difficulty.add_item(title)
	_difficulty.select(1)
	_start_button.text = "Start " + Catalog.OPERATIONS[_ids[index]].title
	if supply:
		_briefing.text = (
			"A Bastion convoy must cross a contested freight corridor.\n\n"
			+ "1. Scout and clear three checkpoints with infantry and tanks.\n"
			+ "2. Advance or hold the convoy; use repair robots on damaged trucks.\n"
			+ "3. Each truck stops for 12 seconds at a clear checkpoint. Extract at least two.\n\n"
			+ "Two truck losses mean defeat. Use Tactical pause to plan orders. "
			+ "No base building or programs are required."
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
			_difficulty.add_item(label)
		_difficulty.select(1)
	elif split:
		_briefing.text = (
			"Helix is fragmenting the mountain uplink. Keep two fronts supplied "
			+ "while you reconnect it.\n\n1. Capture any two of three relays with "
			+ "infantry.\n2. Hold two uncontested relays for 120 cumulative "
			+ "seconds.\n3. Split your armor and repair programs across separate "
			+ "assignments.\n\nYour command lab and tank chips are ready. Direct "
			+ "orders always take priority.\nDefeat: lose all forces and HQ, or "
			+ "fail to rebuild HQ within 60 seconds."
		)
		_note.text = (
			"Optional: hold all three relays for 20 cumulative seconds to earn Air Corridor support.\n"
			+ ("Support earned. " if _progress.network_badge else "")
			+ "This support removes the initial Wraith patrol in Air Corridor."
		)
		_response.text = (
			"Six warned responses from the northeast and southeast, starting "
			+ "after your first capture."
		)
	else:
		_briefing.text = (
			"Helix has cut access to a logistics relay. Restore your command "
			+ "network,\nteach a support unit its assignment, and take the relay "
			+ "back.\n\n1. Build a command lab.\n2. Assign a retreat or repair "
			+ "program.\n3. Capture the relay with infantry and hold for 60 "
			+ "uncontested seconds.\n\nDefeat: lose all forces and HQ, or fail to "
			+ "rebuild HQ within 60 seconds.\nReinforcements begin after you "
			+ "secure the relay. No code or network required."
		)
		_note.text = (
			"Optional: save and reuse a changed retreat threshold to earn Adaptive doctrine.\n"
			+ (
				"Adaptive doctrine · earned"
				if _progress.doctrine_badge
				else "The badge is cosmetic. Presets alone can complete the operation."
			)
		)
		_response.text = "Three objective-directed responses. Unit health and damage stay the same."


func _air_briefing():
	_completion.text = "Completed" if _progress.air_complete else "Available"
	_briefing.text = (
		"Open an evacuation corridor across the industrial quarry.\n\n"
		+ "1. Ground troops destroy both anti-air batteries. Use the north or south bypass.\n"
		+ "2. Position a ground screen east of the quarry; aircraft can fly directly across.\n"
		+ "3. Launch and escort one evacuation flight at a time. Two flights must escape.\n\n"
		+ "Helix Lancers threaten aircraft; your ground troops counter them. "
		+ "Walkers provide mobile anti-air. Stationary aircraft repair at the flight hangar.\n"
		+ "Two flight losses or unrecovered HQ loss mean defeat. Presets or direct orders both work."
	)
	_note.text = (
		"Optional: save all three flights to record +20 electronics for operation 05.\n"
		+ (
			"Split Signal support: initial Wraith patrol removed."
			if _progress.network_badge
			else "Split Signal's network badge removes the initial Wraith patrol."
		)
	)
	_response.text = "Each launch warns one finite ground/air response. Flights wait for your command."
	_difficulty.clear()
	for title in [
		"Story · 2 units per response",
		"Standard · 3 units per response",
		"Veteran · 5 units per response"
	]:
		_difficulty.add_item(title)
	_difficulty.select(1)
	_start_button.text = "Start Air Corridor"


func _foundry_briefing():
	_completion.text = (
		"Completed · finale approach unlocked" if _progress.foundry_complete else "Available"
	)
	_briefing.text = (
		"Take the industrial works without losing your support force.\n\n"
		+ "1. Destroy the north and south production nodes to cancel their unfinished units.\n"
		+ "2. Scout around warehouses; infantry and armor take separate street approaches.\n"
		+ "3. Infantry capture in 10 seconds, then secure 30 cumulative, uncontested seconds.\n\n"
		+ "Protect repair robots. Repair channels do not stack; Guard areas bound pursuit.\n"
		+ "Direct orders and presets both work. Rebuild a lost HQ within 60 seconds."
	)
	_note.text = (
		"Completion unlocks an alternate approach in the finale.\n"
		+ (
			"Air Corridor support: +20 starting electronics."
			if _progress.air_support
			else "Saving all Air Corridor flights grants +20 starting electronics here."
		)
	)
	_response.text = (
		"District entry starts three finite paid batches per node. "
		+ "Disabling both warns one final east response."
	)
	_difficulty.clear()
	for title in [
		"Story · 1 unit per batch", "Standard · 2 units per batch", "Veteran · 3 units per batch"
	]:
		_difficulty.add_item(title)
	_difficulty.select(1)
	_start_button.text = "Start Broken Foundry"


func _horizon_briefing():
	_completion.text = (
		"Finale completed · replay challenges unlocked"
		if _progress.horizon_complete
		else "Available"
	)
	_briefing.text = (
		"Secure the forward deployment zone, then break Helix command.\n\n"
		+ "1. Infantry capture the zone in 10s, then hold for 30 cumulative uncontested seconds.\n"
		+ "2. Leave a guard and infantry at deployment while your mixed strike force destroys the HQ.\n\n"
		+ "Reuse saved doctrines. Recapture lost deployment to finish; rebuild your HQ within 60s."
	)
	_note.text = (
		(
			"Broken Foundry support: the north ground passage is open."
			if _progress.foundry_complete
			else "Use the south ground pass. Broken Foundry completion opens a north passage."
		)
		+ "\nRequired troops, chips, Coordination and air support are available in every run."
	)
	if _progress.lean_complete or _progress.reinforced_complete:
		_completion.text += (
			" · "
			+ ("Lean " if _progress.lean_complete else "")
			+ ("Reinforced" if _progress.reinforced_complete else "")
		)
	_difficulty.clear()
	for title in ["Story", "Standard", "Veteran"]:
		_difficulty.add_item(title)
	_difficulty.select(1)
	_refresh_horizon_response()
	_start_button.text = "Start Command Horizon"


func _refresh_horizon_response():
	if _mission_id != "command_horizon":
		return
	var ground = [2, 3, 4][_difficulty.selected] + (1 if _challenge.selected == 2 else 0)
	var air = [1, 1, 2][_difficulty.selected]
	_response.text = "Four warned responses · %d ground + %d air units each." % [ground, air]
	if _challenge.selected == 1:
		_response.text += " Lean: 4 tanks, 8 infantry, 2 engineers; 80 materials / 40 electronics."
	elif _challenge.selected == 2:
		_response.text += " Reinforced: 4 extra HQ infantry and the extra ground unit per response."


func _label(parent, text, size):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent, text, callback):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _start():
	if _starting:
		return
	_starting = true
	_start_button.disabled = true
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = _mission_id
	if _mission_id == "command_horizon":
		settings.campaign_challenge = ["", "lean", "reinforced"][_challenge.selected]
	settings.map_path = Catalog.OPERATIONS[settings.mission_id].map
	for index in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			Constants.PlayerType.HUMAN if index == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if index == 0 else "helix"
		player.color = Color("e3ad48") if index == 0 else Color("38c8ce")
		player.difficulty = _difficulty.selected
		settings.players.append(player)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = settings.map_path
	get_tree().root.add_child(loading)
	get_tree().current_scene = loading
	queue_free()
