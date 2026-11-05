extends VBoxContainer

const Technologies = preload("res://source/match/research/TechnologyCatalog.gd")
const ResearchButton = preload("res://source/match/hud/ResearchButton.gd")
const WEAPONS_ICON = preload("res://assets/ui/research/weapons.svg")
const ARMOR_ICON = preload("res://assets/ui/research/armor.svg")
const SERVICE_ICON = preload("res://assets/ui/research/service.svg")
const DOCTRINE_ICON = preload("res://assets/ui/research/doctrine.svg")
const COORDINATION_ICON = preload("res://assets/ui/research/coordination.svg")
const ATTACK_ICON = preload("res://assets/ui/hud/icons/attack.svg")
const MOVE_ICON = preload("res://assets/ui/hud/icons/move.svg")
const MATERIALS_ICON = preload("res://assets/ui/economy/materials.svg")
const ICONS = {
	"weapons": WEAPONS_ICON,
	"armor": ARMOR_ICON,
	"service": SERVICE_ICON,
	"doctrine": DOCTRINE_ICON,
	"coordination": COORDINATION_ICON,
	"dual_purpose_aa": WEAPONS_ICON,
	"plasma_shields": ARMOR_ICON,
	"tank_stabilizers": ATTACK_ICON,
	"tandem_rockets": preload("res://assets/ui/infantry/RocketInfantry.svg"),
	"reactive_armor": ARMOR_ICON,
	"siege_logistics": SERVICE_ICON,
	"flux_capacitors": WEAPONS_ICON,
	"scrap_cannibalization": MATERIALS_ICON,
	"high_octane": MOVE_ICON,
	"bunker_reinforcements": ARMOR_ICON,
	"fortress_doctrine": DOCTRINE_ICON,
	"iron_blitz": ATTACK_ICON,
	"beam_amplification": WEAPONS_ICON,
	"phase_thrusters": MOVE_ICON,
	"phase_overload": DOCTRINE_ICON,
	"continuous_coherence": COORDINATION_ICON,
	"concealed_claymores": WEAPONS_ICON,
	"guerrilla_insurgency": DOCTRINE_ICON,
	"salvage_war_machine": MATERIALS_ICON,
}
var lab
var player
var _status
var _progress
var _start
var _cancel
var _grid
var _branches = {}
var _queue_list
var _queue_title
var _queue_rows = []


func _ready():
	if player == null and is_instance_valid(lab):
		player = lab.player
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.name = "ResearchChoices"
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	_start = _tile("coordination")
	_start.name = "ResearchCoordination"
	_start.pressed.connect(
		func():
			player.technology.enqueue("coordination", lab)
			refresh()
	)
	for branch in Technologies.BRANCHES:
		if not Technologies.available(branch, player.faction):
			continue
		var button = _tile(branch)
		button.pressed.connect(_research_branch.bind(branch))
		_branches[branch] = {"button": button}
	var footer = HBoxContainer.new()
	footer.name = "ResearchState"
	footer.add_theme_constant_override("separation", 8)
	add_child(footer)
	var row = HBoxContainer.new()
	row.name = "ActiveResearch"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	footer.add_child(row)
	var active_icon = TextureRect.new()
	active_icon.name = "ActiveIcon"
	active_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	active_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	active_icon.custom_minimum_size = Vector2(32, 32)
	row.add_child(active_icon)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.hide()
	row.add_child(_status)
	_cancel = Button.new()
	_cancel.name = "CancelResearch"
	_cancel.icon = load("res://source/match/hud/BattleTheme.gd").icon("stop")
	_cancel.add_theme_constant_override("icon_max_width", 16)
	_cancel.custom_minimum_size = Vector2(36, 32)
	_cancel.accessibility_name = tr("Cancel & refund")
	_cancel.tooltip_text = "Cancel and refund. Dependent queued upgrades are refunded too."
	_cancel.pressed.connect(_cancel_active)
	row.add_child(_cancel)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 5
	_progress.show_percentage = false
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_progress)
	row.move_child(_progress, 1)
	_queue_list = HBoxContainer.new()
	_queue_list.name = "ResearchQueue"
	_queue_list.add_theme_constant_override("separation", 4)
	footer.add_child(_queue_list)
	_queue_title = Label.new()
	_queue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_title.add_theme_font_size_override("font_size", 13)
	_queue_title.hide()
	_queue_list.add_child(_queue_title)
	resized.connect(_fit_grid)
	_fit_grid()
	refresh()


func _tile(branch):
	var button = ResearchButton.new()
	button.name = "Research" + branch.capitalize()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(button)
	return button


func _fit_grid():
	# Research choices retain their visible names, prices and state.
	_grid.columns = clampi(floori((size.x + 6) / 156), 1, _grid.get_child_count())


func _cancel_active():
	if not is_instance_valid(player):
		return
	if player.technology.active != "":
		player.technology.cancel()
	else:
		player.cancel_coordination()
	refresh()


func _research_branch(branch):
	if not is_instance_valid(player):
		return
	var research = player.technology
	var id = Technologies.next_in_branch(branch, research.planned_technologies())
	if id != "":
		research.enqueue(id, lab)
	refresh()


func _cancel_queued(index):
	if is_instance_valid(player):
		player.technology.cancel_queued(index)
		refresh()


func refresh():
	if not is_instance_valid(player) or _status == null:
		return
	if not is_instance_valid(lab) or lab.is_queued_for_deletion():
		var labs = player.get_children().filter(
			func(unit):
				return (
					"type" in unit
					and unit.type == "CommandLab"
					and unit.is_constructed()
					and not unit.is_queued_for_deletion()
				)
		)
		lab = labs[0] if not labs.is_empty() else null
	var research = player.technology
	var technology_running = research.active != ""
	var running = technology_running or player.coordination_left > 0.0
	_status.text = research.status() if technology_running else player.coordination_status()
	_status.get_parent().visible = running
	_progress.visible = running
	var duration = (
		Technologies.ITEMS[research.active].seconds
		if technology_running
		else player.COORDINATION_DURATION
	)
	var remaining = research.left if technology_running else player.coordination_left
	_progress.value = 100.0 * (1.0 - maxf(0.0, remaining) / duration)
	var active = research.active if technology_running else "coordination"
	_status.get_parent().get_node("ActiveIcon").texture = _icon_for(active)
	_status.get_parent().tooltip_text = _status.text
	_cancel.tooltip_text = (
		_status.text + "\n" + tr("Cancel and refund. Dependent queued upgrades are refunded too.")
	)
	_refresh_coordination()
	for branch in _branches:
		_refresh_branch(branch)
	_refresh_queue()


func _refresh_coordination():
	var reason = tr(player.technology.queue_reason("coordination", lab))
	var description = (
		tr("Coordination unlocks long-range armor and %s. Queued projects run in order.")
		% tr(load("res://source/match/FactionCatalog.gd").signature_title(player.faction))
	)
	_update_tile(
		_start,
		"coordination",
		tr("Coordination"),
		player.COORDINATION_COST,
		description,
		player.COORDINATION_DURATION,
		reason,
		{
			"complete": player.coordination_unlocked,
			"active": player.coordination_left > 0,
			"left": player.coordination_left,
			"queued": player.technology.queued.any(func(entry): return entry.id == "coordination")
		}
	)


func _refresh_branch(branch):
	var research = player.technology
	var id = Technologies.next_in_branch(branch, research.planned_technologies())
	# A branch with no further purchase keeps its latest active/queued/completed
	# card visible. The ordered list below holds every already purchased project.
	if id == "":
		id = branch + "_3" if branch in ["weapons", "armor"] else branch
	var complete = id in research.completed
	var item = Technologies.ITEMS[id]
	_update_tile(
		_branches[branch].button,
		branch,
		tr(Technologies.title(id, player.faction)),
		{"resource_a": item.cost.x, "resource_b": item.cost.y},
		tr(Technologies.description(id, player.faction)),
		item.seconds,
		tr(research.queue_reason(id, lab)),
		{
			"complete": complete,
			"active": research.active == id,
			"left": research.left,
			"queued": research.queued.any(func(entry): return entry.id == id)
		}
	)


func _update_tile(button, branch, title, cost, description, seconds, reason, progress):
	button.show_role(_icon_for(branch), title, cost)
	button.disabled = progress.complete or reason != ""
	var state = tr("Completed") if progress.complete else ""
	if progress.queued:
		state = tr("Queued")
	if progress.active:
		state = tr("%d s remaining") % ceili(progress.left / player.research_factor())
	# The marker and tooltip carry research state; a third text line would grow
	# two choice rows plus a paid queue beyond the fixed console height.
	button.show_state(state, true)
	button.show_marker(
		(
			"✓"
			if progress.complete
			else (
				"…"
				if progress.queued
				else str(ceili(progress.left / player.research_factor())) if progress.active else ""
			)
		)
	)
	var timing = tr("%d s research at current power.") % ceili(seconds / player.research_factor())
	if progress.active:
		timing = (
			tr("Researching · %d s remaining") % ceili(progress.left / player.research_factor())
		)
		reason = ""
	elif progress.complete:
		timing = tr("Research complete.")
	elif progress.queued:
		timing = tr("Queued · paid in advance")
		reason = ""
	elif reason == "" and (player.technology.active != "" or player.coordination_left > 0):
		timing += "\n" + tr("Click to queue. Resources are reserved now.")
	# Match production tooltips: title, description, price, then timing/status.
	var price = tr("%d M / %d E") % [cost.resource_a, cost.resource_b]
	button.tooltip_text = title + "\n" + description + "\n" + price + "\n" + timing
	if reason != "":
		button.tooltip_text += "\n" + reason
	button.accessibility_name = title
	button.accessibility_description = button.tooltip_text


func _refresh_queue():
	var entries = player.technology.queued
	_queue_list.visible = not entries.is_empty()
	_queue_title.text = tr("Queued research · %d") % entries.size()
	# Keep controls alive across ordinary status refreshes so keyboard focus
	# survives research countdown updates and queue shifts.
	while _queue_rows.size() < entries.size():
		var index = _queue_rows.size()
		var button = ResearchButton.new()
		button.name = "QueuedResearch%d" % index
		button.compact_layout(44)
		button.show_hotkey(str(index + 1))
		button.pressed.connect(_cancel_queued.bind(index))
		_queue_list.add_child(button)
		_queue_rows.append({"row": button, "title": button._title, "cancel": button})
	while _queue_rows.size() > entries.size():
		var removed = _queue_rows.pop_back()
		if removed.cancel.has_focus():
			if _cancel.is_visible_in_tree():
				_cancel.grab_focus()
			else:
				_start.grab_focus()
		# A pressed button can have later listeners (including UI audio).
		# Hide the removed row now, then free it after signal delivery completes.
		removed.row.hide()
		removed.row.queue_free()
	for index in entries.size():
		var entry = entries[index]
		var row = _queue_rows[index]
		var title = tr(Technologies.title(entry.id, player.faction))
		row.cancel.show_role(_icon_for(entry.id), title, entry.paid)
		row.cancel.accessibility_name = tr("Cancel queued %s") % title
		row.cancel.tooltip_text = (
			row.cancel.accessibility_name
			+ "\n"
			+ tr(Technologies.description(entry.id, player.faction))
			+ "\n"
			+ tr("%d M / %d E") % [entry.paid.resource_a, entry.paid.resource_b]
			+ "\n"
			+ (
				tr("Refund %d M / %d E. Dependent queued upgrades are refunded too.")
				% [entry.paid.resource_a, entry.paid.resource_b]
			)
		)
		row.cancel.accessibility_description = row.cancel.tooltip_text


func _icon_for(id):
	var branch = id.trim_suffix("_1").trim_suffix("_2").trim_suffix("_3")
	return ICONS.get(branch, ICONS.coordination)
