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
			player.start_coordination(lab)
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
	_cancel.pressed.connect(_cancel_active)
	row.add_child(_cancel)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 5
	_progress.show_percentage = false
	add_child(_progress)
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
	var id = Technologies.next_in_branch(branch, research.completed)
	if id != "":
		research.start(id, lab)
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
	_refresh_coordination(running)
	for branch in _branches:
		_refresh_branch(branch)


func _refresh_coordination(busy):
	var reason = ""
	if player.coordination_unlocked:
		reason = tr("Research complete.")
	elif busy:
		reason = tr("Finish or cancel the current research first.")
	elif not is_instance_valid(lab) or not lab.is_constructed():
		reason = tr("Requires a completed friendly lab.")
	elif not player.lab_research_unlocked():
		reason = tr("Requires a completed vehicle factory and lab.")
	elif not player.has_resources(player.COORDINATION_COST):
		reason = (
			tr("Need %d M / %d E more.")
			% [
				maxi(0, player.COORDINATION_COST.resource_a - player.resource_a),
				maxi(0, player.COORDINATION_COST.resource_b - player.resource_b)
			]
		)
	var description = (
		tr("Coordination unlocks long-range armor and %s. One research project at a time.")
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
		player.coordination_unlocked,
		player.coordination_left > 0,
		player.coordination_left
	)


func _refresh_branch(branch):
	var research = player.technology
	var id = Technologies.next_in_branch(branch, research.completed)
	var complete = id == ""
	if complete:
		id = branch + "_2" if branch in ["weapons", "armor"] else branch
	var item = Technologies.ITEMS[id]
	_update_tile(
		_branches[branch].button,
		branch,
		tr(Technologies.title(id, player.faction)),
		{"resource_a": item.cost.x, "resource_b": item.cost.y},
		tr(Technologies.description(id, player.faction)),
		item.seconds,
		tr(research.reason(id, lab)),
		complete,
		research.active == id,
		research.left
	)


func _update_tile(
	button, branch, title, cost, description, seconds, reason, complete, active, left
):
	button.show_role(ICONS[branch], title, cost)
	button.disabled = complete or reason != ""
	var state = tr("Completed") if complete else ""
	if active:
		state = tr("%d s remaining") % ceili(left / player.production_factor())
	button.show_state(state)
	var timing = tr("%d s research at current power.") % ceili(seconds / player.production_factor())
	if active:
		timing = tr("Researching · %d s remaining") % ceili(left / player.production_factor())
		reason = ""
	elif complete:
		timing = tr("Research complete.")
	# Match production tooltips: title, description, price, then timing/status.
	var price = tr("%d M / %d E") % [cost.resource_a, cost.resource_b]
	button.tooltip_text = title + "\n" + description + "\n" + price + "\n" + timing
	if reason != "":
		button.tooltip_text += "\n" + reason
	button.accessibility_name = title
	button.accessibility_description = button.tooltip_text
