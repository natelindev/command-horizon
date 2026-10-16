extends PanelContainer

const Plan = preload("res://source/match/SkirmishPlan.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
# A collapsed plan stays collapsed for later battles in the same session.
static var _collapsed = false
var hud
## Where hiding or restoring the plan is remembered: the player's settings file.
var options_path = Constants.OPTIONS_FILE_PATH
var _body
var _title
var _description
var _action
var _idle
var _army
var _damaged
var _support
var _elapsed = 0.0
var _toggle
var _programs
var _scroll: ScrollContainer
var _content: VBoxContainer
var _plate: StyleBox
## The header key hides the whole card; a compact restore key takes its place.
var _dismiss: Button
var _restore: Button
var _dismissed = false


func _ready():
	custom_minimum_size.x = HudLayout.COLUMN_WIDTH
	size.x = HudLayout.COLUMN_WIDTH
	hud._style(self)
	_plate = get_theme_stylebox("panel")
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_content = box
	var heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	box.add_child(heading)
	_toggle = hud._button(heading, "Battle plan  ▾", _toggle_body)
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.theme_type_variation = "BattleQuietButton"
	_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_programs = hud._button(heading, "", _select_program_issues)
	_programs.name = "SelectProgramIssues"
	_programs.tooltip_text = (
		"Select units with blocked programs or program errors. Review their program status, "
		+ "then reassign or Resume. Selection keeps their orders and does not restart programs."
	)
	_dismiss = hud._button(heading, "", set_dismissed.bind(true))
	_dismiss.name = "HideBattlePlan"
	_dismiss.theme_type_variation = "BattleQuietButton"
	_dismiss.icon = BattleTheme.icon("hide")
	_dismiss.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dismiss.add_theme_constant_override("icon_max_width", 18)
	_dismiss.custom_minimum_size.x = 36
	_dismiss.tooltip_text = "Hide battle plan"
	_dismiss.accessibility_name = tr("Hide battle plan")
	_dismiss.accessibility_description = tr("Show it again with the Battle plan key.")
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	_title = _label(_body, 16)
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	# The step's explanation reads on demand: the title's tooltip and accessible
	# description carry it, so the card shows only what to do next.
	_description = _label(_body, 12)
	_description.add_theme_color_override("font_color", Color("a9b4b3"))
	_description.visible = false
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_body.add_child(actions)
	_action = hud._button(actions, "", _select_step)
	_action.theme_type_variation = "BattlePrimaryButton"
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_support = hud._button(actions, "", _select_support)
	_support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_support.name = "SelectRepairSupport"
	var shortcuts = HFlowContainer.new()
	shortcuts.add_theme_constant_override("h_separation", 6)
	shortcuts.add_theme_constant_override("v_separation", 6)
	_body.add_child(shortcuts)
	_idle = hud._button(shortcuts, "", _select_engineers)
	_army = hud._button(shortcuts, "", func(): _select(Plan.army(_player())))
	_damaged = hud._button(shortcuts, "", func(): _select(Plan.damaged_units(_player())))
	_damaged.name = "SelectLowHealth"
	_damaged.tooltip_text = (
		"Select combat and support units below 50% health. Selection keeps their orders. "
		+ "Use Recover health for a manual retreat, or review their program safe points."
	)
	if _collapsed:
		_toggle_body()
	# Restore key shown in place of a hidden card: it docks under the briefing and
	# takes no more room than one console key.
	_restore = hud._button(self, "Battle plan", set_dismissed.bind(false))
	_restore.name = "ShowBattlePlan"
	_restore.icon = BattleTheme.icon("plan")
	_restore.add_theme_constant_override("icon_max_width", 16)
	_restore.custom_minimum_size.y = 34
	_restore.tooltip_text = "Show battle plan"
	_restore.accessibility_name = tr("Show battle plan")
	_apply_dismissed(not Globals.options.show_battle_plan)
	refresh()


func _label(parent, font_size):
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = HudLayout.COLUMN_WIDTH - 36
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _process(delta):
	var command = hud.get_child(0)
	position = Vector2(0, command.position.y + command.size.y + 8)
	visible = not hud.get_parent().finished and not hud.map_assignment_active()
	# Settings can change the preference while a battle is paused.
	if _dismissed == Globals.options.show_battle_plan:
		_apply_dismissed(not Globals.options.show_battle_plan)
	if _dismissed:
		return
	var minimap = hud.get_parent().get_node_or_null("HUD/MarginContainer/Minimap")
	var bottom = get_viewport_rect().size.y - 16
	if is_instance_valid(minimap):
		bottom = minimap.global_position.y
	var heading = _toggle.get_parent()
	var available = (
		bottom
		- position.y
		- 12
		- get_theme_stylebox("panel").get_minimum_size().y
		- heading.size.y
		- 8
	)
	var height = minf(_body.get_combined_minimum_size().y, maxf(40, available))
	if _scroll.custom_minimum_size.y != height:
		_scroll.custom_minimum_size.y = height
		size.y = 0
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()


func is_dismissed() -> bool:
	return _dismissed


## Hides the whole card behind a compact restore key, or brings it back. The choice
## is saved with the player's settings, so later skirmishes open the same way.
func set_dismissed(dismissed: bool):
	if dismissed == _dismissed:
		return
	var had_focus = (
		get_viewport().gui_get_focus_owner() in [_dismiss, _restore] if is_inside_tree() else false
	)
	Globals.options.show_battle_plan = not dismissed
	# The card still follows the choice when the settings file cannot be written.
	Globals.options.persist(options_path)
	_apply_dismissed(dismissed)
	if not dismissed:
		refresh()
	# Keyboard users land on the key that undoes what they just did.
	if had_focus:
		(_restore if dismissed else _dismiss).grab_focus()


func _apply_dismissed(dismissed: bool):
	_dismissed = dismissed
	_content.visible = not dismissed
	_restore.visible = dismissed
	var compact = StyleBoxEmpty.new()
	# The restore key keeps the column's inset from the screen edge.
	compact.content_margin_left = 8
	add_theme_stylebox_override("panel", compact if dismissed else _plate)
	custom_minimum_size.x = 0 if dismissed else HudLayout.COLUMN_WIDTH
	size = Vector2.ZERO


func _player():
	return hud.get_parent()._get_human_player()


func refresh():
	var player = _player()
	var issues = Plan.program_issues(player).size()
	_programs.text = "Program issues · %d" % issues
	_programs.accessibility_description = _programs.text + ". " + _programs.tooltip_text
	_programs.visible = issues > 0
	_programs.disabled = issues == 0
	var step = Plan.next_step(player)
	_title.text = step.title
	_title.tooltip_text = step.description
	_title.accessibility_description = step.description
	_description.text = step.description
	_action.text = step.action
	_action.tooltip_text = step.get("action_tooltip", "")
	_action.accessibility_description = _action.tooltip_text
	_action.disabled = step.units.is_empty() and not step.get("open_technology", false)
	var support = Plan.support_step(player)
	var show_support = not support.is_empty() and support.id != step.id
	if show_support:
		_support.text = support.support_label
		_support.tooltip_text = support.support_tooltip
		_support.accessibility_description = "Repair support. " + support.support_tooltip
		_support.disabled = support.units.is_empty()
	if _support.visible != show_support:
		_support.visible = show_support
		size.y = 0
	var endangered = Plan.endangered_workers(player)
	var idle = Plan.idle_workers(player).size()
	var army = Plan.army(player).size()
	_idle.text = "Idle engineers · %d" % idle
	_idle.disabled = idle == 0
	_idle.tooltip_text = "Select engineers waiting for an assignment."
	if not endangered.is_empty():
		_idle.text = "Engineers at risk · %d" % endangered.size()
		_idle.disabled = false
		_idle.tooltip_text = (
			"Select engineers near visible threats or recently hit by enemy fire. "
			+ "Move them behind your defenses. Selection keeps their current orders."
		)
	_idle.accessibility_description = _idle.text + ". " + _idle.tooltip_text
	_army.text = "Army · %d" % army
	_army.disabled = army == 0
	var damaged = Plan.damaged_units(player).size()
	_damaged.text = "Low health · %d" % damaged
	_damaged.accessibility_description = _damaged.text + ". " + _damaged.tooltip_text
	# Shortcuts appear only while they have something to select that the primary
	# action does not already select.
	var idle_targets = endangered if not endangered.is_empty() else Plan.idle_workers(player)
	var shown = [
		not _idle.disabled and not _same_units(idle_targets, step.units),
		army > 0 and not _same_units(Plan.army(player), step.units),
		damaged > 0,
	]
	var chips = [_idle, _army, _damaged]
	for index in chips.size():
		if chips[index].visible != shown[index]:
			chips[index].visible = shown[index]
			size.y = 0


static func _same_units(a, b):
	return a.size() == b.size() and a.all(func(unit): return unit in b)


func _select_engineers():
	var player = _player()
	var endangered = Plan.endangered_workers(player)
	_select(endangered if not endangered.is_empty() else Plan.idle_workers(player))


func _toggle_body():
	_body.visible = not _body.visible
	_scroll.visible = _body.visible
	_toggle.text = "Battle plan  ▾" if _body.visible else "Battle plan  ▸"
	_collapsed = not _body.visible
	size.y = 0


func _select_step():
	var step = Plan.next_step(_player())
	if step.get("open_technology", false):
		hud.open_technology()
	else:
		_select(step.units, step.get("focus_position"))


func _select(units, focus = null):
	if units.is_empty():
		refresh()
		return false
	return hud.select_units(units, focus)


func _select_program_issues():
	if not _select(Plan.program_issues(_player())):
		return
	var menus = hud.get_parent().find_child("UnitMenus")
	var panel = menus._program_panel
	if is_instance_valid(panel):
		menus._pages.current_tab = panel.get_parent().get_index()
	# Selection creates the controls immediately; scrolling needs their layout.
	await get_tree().process_frame
	await get_tree().process_frame
	if (
		is_instance_valid(menus)
		and is_instance_valid(panel)
		and menus._program_panel == panel
		and hud._overlay == null
		and not is_instance_valid(hud.program_editor)
	):
		menus._scroll.scroll_vertical = int(
			panel.global_position.y - menus._content.global_position.y
		)


func _select_support():
	var step = Plan.support_step(_player())
	if step.is_empty():
		refresh()
		return
	_select(step.units)
