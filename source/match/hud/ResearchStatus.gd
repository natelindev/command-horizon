extends VBoxContainer

const Technologies = preload("res://source/match/research/TechnologyCatalog.gd")
var hud
var _button
var _progress
var _elapsed = 0.0
@onready var player = hud.get_parent()._get_human_player()


func _ready():
	name = "ResearchStatus"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)
	_button = hud._button(self, "", hud.open_technology)
	_button.name = "ReviewResearch"
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.custom_minimum_size.y = 28
	_button.add_theme_font_size_override("font_size", 12)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 6
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)
	refresh()


func _process(delta):
	_sync_visibility()
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()


func refresh():
	if not is_instance_valid(player) or player.technology == null:
		hide()
		return
	var active = player.technology.active
	var running = active != "" or player.coordination_left > 0
	if running:
		_project(active)
	else:
		_choices()
	_progress.visible = running
	_button.accessibility_description = _button.tooltip_text
	_sync_visibility()


func _sync_visibility():
	_button.disabled = hud._overlay != null
	visible = (
		_button.text != ""
		and not hud.get_parent().finished
		and not hud.map_assignment_active()
		and not hud._assignment_hint.visible
	)


func _project(active):
	var title = Technologies.title(active, player.faction)
	var remaining = player.technology.left if active != "" else player.coordination_left
	var duration = (
		Technologies.ITEMS[active].seconds if active != "" else player.COORDINATION_DURATION
	)
	_progress.value = 100.0 * (1.0 - remaining / duration)
	if not player.has_completed_structure("CommandLab"):
		_button.text = title + " · rebuild lab"
		_button.tooltip_text = (
			(
				"%s is paused until a friendly lab completes. The project is already paid for. "
				+ "Open Tech to review it or cancel for a refund."
			)
			% title
		)
		return
	var low_power = player.production_factor() < 1.0
	var seconds = ceili(remaining / player.production_factor())
	var state = " · paused" if get_tree().paused else (" · low power" if low_power else "")
	_button.text = "%s · %d s%s" % [title, seconds, state]
	_button.tooltip_text = (
		"%s: about %d seconds remaining at current power.%s%s Open Tech to review research."
		% [
			title,
			seconds,
			" Low power runs research at 35% speed." if low_power else "",
			" Resume battle to continue." if get_tree().paused else ""
		]
	)


func _choices():
	_button.text = ""
	_button.tooltip_text = ""
	var labs = player.get_children().filter(
		func(unit):
			return (
				unit.is_in_group("units")
				and unit.type == "CommandLab"
				and unit.hp > 0
				and not unit.is_queued_for_deletion()
				and unit.is_constructed()
			)
	)
	if labs.is_empty() or not player.lab_research_unlocked():
		return
	var choices = PackedStringArray()
	if not player.coordination_unlocked and player.has_resources(player.COORDINATION_COST):
		choices.append("Coordination · 20 M / 20 E")
	for branch in Technologies.BRANCHES:
		var id = Technologies.next_in_branch(branch, player.technology.completed)
		if id != "" and player.technology.reason(id, labs[0]) == "":
			var cost = Technologies.ITEMS[id].cost
			choices.append(
				"%s · %d M / %d E" % [Technologies.title(id, player.faction), cost.x, cost.y]
			)
	if choices.is_empty():
		return
	_button.text = (
		"Research available · %d choice%s" % [choices.size(), "" if choices.size() == 1 else "s"]
	)
	_button.tooltip_text = (
		"Open Tech to choose research. Each project is paid separately.\n" + "\n".join(choices)
	)
