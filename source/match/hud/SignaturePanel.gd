extends HBoxContainer

const Factions = preload("res://source/match/FactionCatalog.gd")
var selection = []
var _activate
var _summary


func _ready():
	add_theme_constant_override("separation", 8)
	_activate = Button.new()
	_activate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_activate.text = (Factions.signature_title(selection[0].player.faction))
	_activate.add_theme_font_size_override("font_size", 13)
	_activate.pressed.connect(_activate_selection)
	add_child(_activate)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.mouse_filter = Control.MOUSE_FILTER_STOP
	_summary.hide()
	add_child(_summary)
	refresh()


func _members():
	return selection.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)


func _activate_selection():
	var units = _members()
	if units.is_empty():
		return
	var player = units[0].player
	if player.faction == "bastion":
		units[0]._match.hud.arm_signature_sector(units)
	else:
		var count = player.signatures.activate(units)
		units[0]._match.hud.show_notice(
			(
				(
					(
						"Maneuver burst · %d unit%s · 6 seconds of faster movement."
						if player.faction == "frontier"
						else "Precision window · %d unit%s · one faster preparation each."
					)
					% [count, "" if count == 1 else "s"]
				)
				if count > 0
				else player.signatures.error
			)
		)
	refresh()


func refresh():
	var units = _members()
	if units.is_empty():
		_activate.disabled = true
		_summary.text = ""
		return
	var player = units[0].player
	var count = units.filter(func(unit): return player.signatures.eligible(unit)).size()
	_activate.disabled = count == 0 or (player.faction == "frontier" and player.logistics < 5.0)
	var state = _feedback(units, player, count)
	_summary.text = state.summary
	var help = _help(player)
	_activate.tooltip_text = state.details + "\n\n" + help
	_summary.tooltip_text = _activate.tooltip_text
	_activate.accessibility_name = tr(Factions.signature_title(player.faction))
	_activate.accessibility_description = _activate.tooltip_text
	_summary.accessibility_name = state.summary
	_summary.accessibility_description = _summary.tooltip_text
	# A locked ability is a research goal, listed in Tech; it needs no space here.
	visible = player.coordination_unlocked


func _feedback(units, player, ready):
	if not player.coordination_unlocked:
		return {
			"summary": tr("Research Coordination"),
			"details": tr("Research Coordination at your lab to unlock this ability.")
		}
	var effects = {}
	var recharge = INF
	for unit in units:
		if unit.signature == null or unit.hp <= 0:
			continue
		var effect = _effect(unit)
		if not effect.is_empty():
			if not effects.has(effect.title):
				effects[effect.title] = {"count": 0, "left": effect.left}
			effects[effect.title].count += 1
			effects[effect.title].left = minf(effects[effect.title].left, effect.left)
		var left = unit.signature.cooldown
		for group in player.signatures.groups:
			if unit in group.members:
				left = maxf(left, group.left)
		# Settled Anchor stays active until movement breaks it.
		if left > 0 and unit.signature.kind != "anchor":
			recharge = minf(recharge, left)
	var summary = []
	if ready > 0:
		summary.append(tr("%d ready · up to 6") % ready)
	for title in effects:
		var effect = effects[title]
		summary.append(
			(
				(tr("%s · %d · %.1f s") % [tr(title), effect.count, effect.left])
				if effect.left > 0
				else tr("%s · %d") % [tr(title), effect.count]
			)
		)
	var lines = summary.duplicate()
	if player.faction == "frontier":
		lines.append(tr("Cost: 5 Logistics"))
		if player.logistics < 5.0:
			lines.append(tr("Requires 5 Logistics."))
	if recharge < INF:
		lines.append(tr("Recharging · %.1f s") % recharge)
	if lines.is_empty():
		lines.append(
			(
				tr("Needs a ready precision shot")
				if player.faction == "helix"
				else tr("Needs ready ground combatants")
			)
		)
	if summary.is_empty():
		summary.append(lines[0])
	return {"summary": "\n".join(summary), "details": "\n".join(lines)}


func _effect(unit):
	var state = unit.signature
	if state.kind == "anchor":
		if state.anchored:
			return {"title": "Anchored", "left": 0.0}
		if (
			unit.global_position_yless.distance_to(state.sector) > state.RADIUS
			or unit.get_node("Movement")._has_destination
		):
			return {"title": "Hold still in Anchor sector", "left": 0.0}
		return {"title": "Setting up", "left": state.setup_left}
	if state.kind == "maneuver" and state.window_left > 0:
		return {"title": "Maneuver active", "left": state.window_left}
	if state.kind == "precision" and state.window_left > 0:
		return {
			"title": "Precision ready" if state.precision_ready else "Precision used",
			"left": state.window_left
		}
	return {}


func _help(player):
	var upgraded = player.technology != null and player.technology.has_doctrine()
	if player.faction == "bastion":
		return (
			tr("Choose a sector for the closest six ready ground combatants.")
			+ "\n"
			+ (
				tr("Hold still for 2 s inside the 6 m sector: %d%% damage reduction.")
				% (25 if upgraded else 15)
			)
			+ "\n"
			+ tr("Moving breaks Anchor. 10 s cooldown. Orders continue.")
		)
	if player.faction == "frontier":
		return (
			tr("Up to six ready ground combatants.")
			+ "\n"
			+ tr("+%d%% movement speed for 6 s.") % (50 if upgraded else 35)
			+ "\n"
			+ tr("25 s cooldown. Orders continue.")
		)
	return (
		tr("Use Lancers in Precision mode or deployed Prism artillery.")
		+ "\n"
		+ tr("Stop moving; wait for reload and a visible legal target.")
		+ "\n"
		+ tr("Up to six units: one preparation %d%% faster within 2 s.") % (50 if upgraded else 20)
		+ "\n"
		+ tr("8 s cooldown. Damage and reload do not change.")
	)
