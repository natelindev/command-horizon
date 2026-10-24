extends VBoxContainer

const Technologies = preload("res://source/match/research/TechnologyCatalog.gd")
const ResearchButton = preload("res://source/match/hud/ResearchButton.gd")
const WEAPONS_ICON = preload("res://assets/ui/research/weapons.svg")
const ICONS = {
	"weapons": WEAPONS_ICON,
	"armor": preload("res://assets/ui/research/armor.svg"),
	"service": preload("res://assets/ui/research/service.svg"),
	"doctrine": preload("res://assets/ui/research/doctrine.svg"),
	"coordination": preload("res://assets/ui/research/coordination.svg"),
	"dual_purpose_aa": WEAPONS_ICON,
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
		var button = _tile(branch)
		button.pressed.connect(_research_branch.bind(branch))
		_branches[branch] = {"button": button}
	var row = HBoxContainer.new()
	row.name = "ActiveResearch"
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_cancel = Button.new()
	_cancel.name = "CancelResearch"
	_cancel.text = "Cancel & refund"
	_cancel.tooltip_text = "Cancel and refund. Dependent queued upgrades are refunded too."
	_cancel.pressed.connect(_cancel_active)
	row.add_child(_cancel)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 5
	_progress.show_percentage = false
	add_child(_progress)
	_queue_list = VBoxContainer.new()
	_queue_list.name = "ResearchQueue"
	_queue_list.add_theme_constant_override("separation", 4)
	add_child(_queue_list)
	_queue_title = Label.new()
	_queue_title.add_theme_font_size_override("font_size", 13)
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
	# Use the actual panel width: the selected lab and the Tech overlay differ.
	_grid.columns = clampi(floori((size.x + 6) / 160), 1, _grid.get_child_count())


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
		id = branch + "_2" if branch in ["weapons", "armor"] else branch
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
	button.show_role(ICONS[branch], title, cost)
	button.disabled = progress.complete or reason != ""
	var state = tr("Completed") if progress.complete else ""
	if progress.queued:
		state = tr("Queued")
	if progress.active:
		state = tr("%d s remaining") % ceili(progress.left / player.production_factor())
	button.show_state(state)
	var timing = tr("%d s research at current power.") % ceili(seconds / player.production_factor())
	if progress.active:
		timing = (
			tr("Researching · %d s remaining") % ceili(progress.left / player.production_factor())
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
		var row = HBoxContainer.new()
		row.name = "QueuedResearch%d" % index
		row.add_theme_constant_override("separation", 8)
		_queue_list.add_child(row)
		var title = Label.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 13)
		row.add_child(title)
		var cancel = Button.new()
		cancel.theme_type_variation = "BattleQuietButton"
		cancel.text = tr("Cancel")
		cancel.pressed.connect(_cancel_queued.bind(index))
		row.add_child(cancel)
		_queue_rows.append({"row": row, "title": title, "cancel": cancel})
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
		row.title.text = "%d. %s" % [index + 1, title]
		row.cancel.text = tr("Cancel")
		row.cancel.accessibility_name = tr("Cancel queued %s") % title
		row.cancel.tooltip_text = (
			tr("Refund %d M / %d E. Dependent queued upgrades are refunded too.")
			% [entry.paid.resource_a, entry.paid.resource_b]
		)
		row.cancel.accessibility_description = row.cancel.tooltip_text
