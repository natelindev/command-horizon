extends "res://source/match/hud/LuaProgramEditor.gd"

const Rules = preload("res://source/match/programs/VisualRules.gd")
var _cards
var _tabs: TabContainer


func authoring_mode():
	return "visual"


func _starter_titles():
	return Rules.STARTERS


func _build_ui():
	super()
	_heading.text = "UNIT PROGRAM / VISUAL RULES"
	_guide_heading.text = "RULE GUIDE"
	_guide.text = (
		"Read cards from top to bottom. The first matching rule acts; others wait for the next tick.\n\n"
		+ "Needs recovery stays active from the retreat threshold until the recovery threshold.\n\n"
		+ "Choose area, safe point, escort and route on the battlefield. Missing assignments wait.\n\n"
		+ "Defend assigned area engages observed enemies inside 6 m, then returns.\n\n"
		+ "States remember a mode between ticks. A transition applies to the next tick. "
		+ "Resume starts clean.\n\n"
		+ "Copy as Lua makes a separate draft. Freeform code cannot return to rule cards."
	)
	_requirements.disabled = true
	_requirements.tooltip_text = "Equipment requirements are derived from the chosen actions."
	var body = _source.get_parent()
	body.remove_child(_source)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size = Vector2(500, 220)
	body.add_child(_tabs)
	body.move_child(_tabs, 0)
	_cards = load("res://source/match/hud/VisualRuleCards.gd").new()
	_cards.name = "Rules"
	_tabs.add_child(_cards)
	_source.name = "Generated Lua"
	_source.editable = false
	_source.add_theme_color_override("font_readonly_color", Color("bdccd9"))
	_tabs.add_child(_source)
	_cards.changed.connect(_draft_changed)
	var copy = _button(_actions, "Copy as Lua", _copy_as_lua)
	_actions.move_child(copy, 2)


func _focus_editor():
	_cards._add.grab_focus()


func _draft():
	if _cards == null:
		return super()
	var document = _cards.document
	var roles = Record.ROLES.duplicate()
	if _roles.selected == ROLE_TITLES.size():
		roles = _custom_roles.duplicate()
	elif _roles.selected > 0:
		roles = [Record.ROLES[_roles.selected - 1]]
	if _roles.selected == 0:
		var needs = Rules.requirements(document)
		roles = roles.filter(func(role): return Record.meets_requirements(needs, role))
	return Record.visual(_name.text.strip_edges(), 1, document, roles)


func _refresh():
	if _cards == null:
		return
	var draft = _draft()
	var needed = Rules.assignments(_cards.document)
	_guide_heading.text = "ASSIGN: " + ", ".join(needed) if not needed.is_empty() else "RULE GUIDE"
	_guide_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source.text = draft.source
	_requirements.select(
		2 if "repair" in draft.requirements else (1 if "attack" in draft.requirements else 0)
	)
	super()
	_version.text = (
		"%s · v%d · Visual rules" % [_loaded.name, _loaded.version]
		if _matches_loaded(draft)
		else "Unsaved rules · Save a version before applying"
	)
	var problem = Rules.validate(_cards.document)
	if not problem.is_empty():
		_set_notice(problem)
	elif draft.roles.is_empty():
		_set_notice(
			"No unit has both weapons and repair tools. Use separate programs for these roles."
		)


func _matches_loaded(draft):
	return (
		super(draft)
		and Record._canonical(_loaded.get("rules")) == Record._canonical(draft.get("rules"))
	)


func _show_draft(value):
	if value.get("mode") != "visual" or not value.get("rules") is Dictionary:
		_set_notice("Freeform Lua cannot be loaded as visual rules. Choose a visual starter.")
		return
	_cards.set_document(value.rules)
	super(value)


func _use_starter():
	_cards.set_document(Rules.starter(_starter.selected))
	_loaded = {}
	_name.text = Rules.STARTERS[_starter.selected]
	_roles.select(0)
	_set_notice("Starter copied. Adjust the rules, check samples, then save and apply.")
	_trace.text = "Check the draft against sample inputs before applying."
	_refresh()


func _save():
	if _validate_rules():
		super()


func _check_samples():
	if not _validate_rules():
		return
	var draft = _draft()
	var traces = []
	for role in draft.roles:
		var result = DraftCheck.check(draft.source, role)
		if not result.ok:
			_trace.text = "%s: %s" % [role, result.error]
			_set_notice("Sample check failed. Current orders are unchanged.")
			return
		var rows = [role]
		for step in result.steps:
			var action = step.intent.get("status", step.intent.kind.capitalize())
			rows.append("%d · HP %d%% · %s" % [step.index, step.hp, action])
		traces.append("\n".join(rows))
	_trace.text = "\n\n".join(traces)
	_set_notice(
		"Samples passed for %d roles. Battle outcomes are not simulated." % draft.roles.size()
	)


func _validate_rules():
	var problem = Rules.validate(_cards.document)
	if problem.is_empty() and not Record.validate(_draft()):
		problem = "Choose a name and unit roles that support the rules' equipment requirements."
	if not problem.is_empty():
		_set_notice(problem)
		return false
	return true


func _copy_as_lua():
	if not _validate_rules():
		return
	var draft = _draft()
	# This partial record is an unsaved Lua draft, never a saved version or an Apply.
	var copy = {
		"name": draft.name.left(34) + " (Lua)",
		"source": draft.source,
		"roles": draft.roles.duplicate(),
		"requirements": draft.requirements.duplicate()
	}
	_store_draft(
		{
			"draft": draft,
			"loaded": _loaded.duplicate(true),
			"role_index": _roles.selected,
			"requirement_index": _requirements.selected
		}
	)
	var hud = game.hud
	var units = selection.duplicate()
	var path = library_path
	var prior_pause = _was_paused
	_closing = true
	# Keep the pause through the handoff; the new editor owns its eventual release.
	tree_exited.connect(func(): hud.open_lua_copy.call_deferred(units, path, copy, prior_pause))
	queue_free()
