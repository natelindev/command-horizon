extends VBoxContainer

const Technologies = preload("res://source/match/research/TechnologyCatalog.gd")
var lab
var player
var _status
var _progress
var _start
var _cancel
var _description
var _branches = {}


func _ready():
	if player == null and is_instance_valid(lab):
		player = lab.player
	add_theme_constant_override("separation", 8)
	_status = _label(14)
	_description = _label(12)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 16
	_progress.show_percentage = false
	add_child(_progress)
	var row = HBoxContainer.new()
	add_child(row)
	_start = Button.new()
	_start.theme_type_variation = "BattlePrimaryButton"
	_start.name = "ResearchCoordination"
	_start.text = "Research Coordination · 20 M / 20 E"
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start.pressed.connect(
		func():
			player.start_coordination(lab)
			refresh()
	)
	row.add_child(_start)
	_cancel = Button.new()
	_cancel.name = "CancelResearch"
	_cancel.text = "Cancel & refund"
	_cancel.pressed.connect(_cancel_active)
	row.add_child(_cancel)
	var heading = _label(14)
	heading.text = "UNIT UPGRADES"
	for branch in Technologies.BRANCHES:
		var card = VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		add_child(card)
		var title = _label(14, card)
		title.add_theme_color_override("font_color", Color("d4bb8e"))
		var description = _label(12, card)
		var button = Button.new()
		button.name = "Research" + branch.capitalize()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _research_branch(branch))
		card.add_child(button)
		var reason = _label(12, card)
		reason.add_theme_color_override("font_color", Color("c2cbd4"))
		_branches[branch] = {
			"title": title, "description": description, "button": button, "reason": reason
		}
	refresh()


func _label(font_size, parent = null):
	if parent == null:
		parent = self
	var label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 470
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


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
	_description.text = (
		"Coordination unlocks long-range armor, squad programs and %s. One research project at a time."
		% load("res://source/match/FactionCatalog.gd").signature_title(player.faction)
	)
	_progress.visible = running
	var duration = (
		Technologies.ITEMS[research.active].seconds
		if technology_running
		else player.COORDINATION_DURATION
	)
	var remaining = research.left if technology_running else player.coordination_left
	_progress.value = 100.0 * (1.0 - maxf(0.0, remaining) / duration)
	_start.visible = not player.coordination_unlocked and not running
	_start.disabled = (
		not is_instance_valid(lab)
		or not player.basic_programs_unlocked()
		or not player.has_resources(player.COORDINATION_COST)
	)
	_start.tooltip_text = (
		"Requires a completed factory and lab. 30 s at full power; "
		+ "low power gives 35% research speed."
	)
	_cancel.visible = running
	for branch in _branches:
		_refresh_branch(branch, running)


func _refresh_branch(branch, busy):
	var research = player.technology
	var id = Technologies.next_in_branch(branch, research.completed)
	var complete = id == ""
	if complete:
		id = branch + "_2" if branch in ["weapons", "armor"] else branch
	var item = Technologies.ITEMS[id]
	var row = _branches[branch]
	row.title.text = Technologies.title(id, player.faction) + (" · complete" if complete else "")
	row.description.text = Technologies.description(id, player.faction)
	row.button.visible = not complete
	row.button.text = (
		"Research · %d M / %d E · %d s"
		% [item.cost.x, item.cost.y, ceili(item.seconds / player.production_factor())]
	)
	var reason = research.reason(id, lab)
	row.button.disabled = reason != ""
	row.button.tooltip_text = (
		row.title.text + ". " + row.description.text + ("\n" + reason if reason != "" else "")
	)
	row.reason.visible = not complete and not busy and reason != ""
	row.reason.text = reason
