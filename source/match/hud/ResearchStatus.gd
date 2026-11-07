extends VBoxContainer

const Presentation = preload("res://source/match/hud/ResearchPresentation.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
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
	_button.add_theme_constant_override("icon_max_width", 20)
	_button.expand_icon = true
	_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 6
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("fill", BattleTheme.bar_fill(BattleTheme.accent()))
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)
	get_node("/root/MatchSignals").research_completed.connect(_completed)
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
		_project()
		var queued = player.technology.queued
		if not queued.is_empty():
			_button.text += tr(" · %d queued") % queued.size()
			_button.tooltip_text += "\n" + tr("Queued research · %d") % queued.size()
			for index in queued.size():
				_button.tooltip_text += (
					"\n%d. %s"
					% [index + 1, tr(Technologies.title(queued[index].id, player.faction))]
				)
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


func _project():
	var project = Presentation.project(player, get_tree().paused)
	_button.icon = Presentation.icon_for(project.id)
	_progress.value = project.progress
	_button.text = project.summary
	_button.tooltip_text = project.detail + "\n" + tr("Open Tech to review research.")


func _choices():
	_button.icon = null
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
		choices.append(tr("Coordination · 20 M / 20 E"))
	for branch in Technologies.BRANCHES:
		var id = Technologies.next_in_branch(branch, player.technology.completed)
		if id != "" and player.technology.reason(id, labs[0]) == "":
			var cost = Technologies.ITEMS[id].cost
			choices.append(
				(
					tr("%s · %d M / %d E")
					% [tr(Technologies.title(id, player.faction)), cost.x, cost.y]
				)
			)
	if choices.is_empty():
		return
	_button.text = (
		(
			tr("Research available · %d choice")
			if choices.size() == 1
			else tr("Research available · %d choices")
		)
		% choices.size()
	)
	_button.tooltip_text = (
		tr("Open Tech to choose research. Each project is paid separately.")
		+ "\n"
		+ "\n".join(choices)
	)


func _completed(owner_player, _technology):
	if owner_player == player:
		refresh()
		load("res://source/match/hud/HudMotion.gd").play(_button)
