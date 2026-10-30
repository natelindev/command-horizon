# gdlint: disable=max-returns
extends PanelContainer

## Dynamic Ability Tray: displays quick-access modular blocks for Commander Support,
## Faction Signatures, and active Tactical Unit Abilities at the top of the battle HUD.
## Ensures abilities are instantly accessible in combat without diving through menus.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const Bindings = preload("res://source/input/KeyBindings.gd")
const CommandCard = preload("res://source/match/hud/CommandCard.gd")
const CommanderPanel = preload("res://source/match/hud/CommanderPanel.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const AbilityBlock = preload("res://source/match/hud/AbilityBlock.gd")

var hud: CanvasLayer
var _box: HBoxContainer
var _blocks: Array = []
var _refresh_timer: float = 0.0


func _init():
	name = "AbilityTray"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate = BattleTheme.strip(10, 2)
	plate.content_margin_left = 6
	plate.content_margin_right = 6
	plate.content_margin_top = 4
	plate.content_margin_bottom = 4
	add_theme_stylebox_override("panel", plate)

	_box = HBoxContainer.new()
	_box.name = "BlockContainer"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	visible = false


func _ready():
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_refresh(0.0)


func _on_viewport_size_changed():
	if is_instance_valid(hud):
		_update_position(hud)


func _process(delta: float):
	_refresh_timer += delta
	if _refresh_timer >= 0.1:
		_refresh_timer = 0.0
		_refresh(delta)


func _refresh(_delta: float):
	if not is_instance_valid(hud):
		return
	var game = hud.get_parent()
	if game == null or not game.has_method("_get_human_player"):
		visible = false
		return
	var player = game._get_human_player()
	if player == null or not is_instance_valid(player):
		visible = false
		return

	var entries = []
	_gather_commander_support(game, player, entries)
	_gather_faction_signature(hud, player, entries)
	_gather_unit_abilities(hud, entries)
	_gather_campaign_hero(game, entries)

	if entries.is_empty():
		visible = false
		return

	visible = true

	# Allocate / update block nodes
	while _blocks.size() < entries.size():
		var block = AbilityBlock.new()
		_box.add_child(block)
		_blocks.append(block)

	for i in range(_blocks.size()):
		var block = _blocks[i]
		if i < entries.size():
			block.visible = true
			block.update_data(entries[i])
		else:
			block.visible = false

	_update_position(hud)


func _gather_commander_support(game, player, entries: Array):
	if game.commander_support == null:
		return
	var power = game.commander_support.power_for(player)
	var state = game.commander_support.state(player)
	var lab_started = player.has_completed_structure("CommandLab") or state.get("started", false)
	if not lab_started:
		return

	var cost = game.commander_support.cost_for(player)
	var issue = game.commander_support.disabled_reason(player)
	var cooldown = 0.0
	if not state.get("started", false) or state.get("left", 0.0) > 0.0:
		cooldown = state.get("left", 0.0)

	var glyph_name = {"barrage": "attack", "emp": "tech", "airdrop": "cargo"}.get(power, "attack")
	var hotkey_lbl = Bindings.label("commander_support")
	var armed = is_instance_valid(hud.direct_orders) and hud.direct_orders.kind == "commander"

	entries.append(
		{
			"id": "commander_" + power,
			"kind": "commander",
			"name": game.commander_support.TITLES.get(power, "Commander Support"),
			"description": CommanderPanel.DESCRIPTIONS.get(power, ""),
			"glyph": BattleTheme.icon(glyph_name),
			"hotkey": hotkey_lbl,
			"cost_text": "%dM/%dE" % [cost.resource_a, cost.resource_b],
			"cooldown_left": cooldown,
			"cooldown_total": game.commander_support.COOLDOWNS.get(power, 120.0),
			"is_armed": armed,
			"is_active": false,
			"is_ready": issue.is_empty(),
			"issue": issue,
			"action": func(): _trigger_commander()
		}
	)


func _trigger_commander():
	if is_instance_valid(hud.direct_orders):
		hud.direct_orders.arm_commander()


func _gather_faction_signature(hud_ref, player, entries: Array):
	if not player.coordination_unlocked or player.signatures == null:
		return

	var sig_title = Factions.signature_title(player.faction)
	var armed = hud_ref._assignment_kind == "signature"
	var controlled = hud_ref.get_tree().get_nodes_in_group("controlled_units")
	var members = controlled.filter(
		func(u):
			return is_instance_valid(u) and u.player == player and player.signatures.eligible(u)
	)

	var recharge = INF
	var active_left = 0.0
	for u in controlled:
		if is_instance_valid(u) and u.player == player and u.signature != null and u.hp > 0:
			var left = u.signature.cooldown
			for group in player.signatures.groups:
				if u in group.members:
					left = maxf(left, group.left)
			if left > 0 and u.signature.kind != "anchor":
				recharge = minf(recharge, left)
			if u.signature.kind == "maneuver" and u.signature.window_left > 0:
				active_left = maxf(active_left, u.signature.window_left)
			elif u.signature.kind == "precision" and u.signature.window_left > 0:
				active_left = maxf(active_left, u.signature.window_left)

	var glyph_name = (
		"plan"
		if player.faction == "bastion"
		else ("move" if player.faction == "frontier" else "tech")
	)
	var ready = not members.is_empty() and (is_inf(recharge) or recharge <= 0.0)
	var issue_text = ""
	if members.is_empty():
		issue_text = "Needs ready units"
	elif not is_inf(recharge) and recharge > 0.0:
		issue_text = "Recharging"

	entries.append(
		{
			"id": "signature_" + player.faction,
			"kind": "signature",
			"name": sig_title,
			"description": Factions.signature_title(player.faction),
			"glyph": BattleTheme.icon(glyph_name),
			"hotkey": "Z",
			"cost_text": "",
			"cooldown_left": 0.0 if is_inf(recharge) else recharge,
			"cooldown_total": 25.0,
			"is_armed": armed,
			"is_active": active_left > 0.0,
			"is_ready": ready,
			"issue": issue_text,
			"action": func(): _trigger_signature(player, members)
		}
	)


func _trigger_signature(player, eligible_members: Array):
	var selected = hud.get_tree().get_nodes_in_group("selected_units").filter(
		func(u):
			return is_instance_valid(u) and u.player == player and player.signatures.eligible(u)
	)
	var units_to_use = selected if not selected.is_empty() else eligible_members
	if units_to_use.is_empty():
		hud.show_notice("No ready units for faction signature.")
		return
	if player.faction == "bastion":
		hud.arm_signature_sector(units_to_use)
	else:
		var count = player.signatures.activate(units_to_use)
		var msg = (
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
		hud.show_notice(msg)


func _gather_unit_abilities(hud_ref, entries: Array):
	if not is_instance_valid(hud_ref.direct_orders):
		return
	var candidates = hud_ref.direct_orders.ability_units()
	var seen_ids = []
	for unit in candidates:
		if not is_instance_valid(unit) or unit.abilities == null:
			continue
		for ability in unit.abilities.abilities:
			if ability.id in seen_ids:
				continue
			seen_ids.append(ability.id)
			var units_with_ability = candidates.filter(
				func(u):
					return (
						is_instance_valid(u)
						and u.abilities != null
						and u.abilities.get_ability(ability.id) != null
					)
			)
			var issues = []
			for u in units_with_ability:
				issues.append(u.abilities.availability_issue(ability.id))
			var any_ready = issues.any(func(iss): return iss.is_empty())
			var any_active = units_with_ability.any(
				func(u): return u.abilities.get_ability(ability.id).is_active
			)
			var min_cd = INF
			for u in units_with_ability:
				var ab = u.abilities.get_ability(ability.id)
				min_cd = minf(min_cd, ab.cooldown_left)
			if ability.id == "field_barricade":
				min_cd = INF
				for u in units_with_ability:
					if u.type == "Worker" and u.player.faction == "bastion":
						min_cd = minf(min_cd, u._match.engineering.cooldown_left(u))
			var cost_desc = ""
			if ability.id == "field_barricade":
				cost_desc = "10M"
			elif ability.id == "scrap_mine":
				cost_desc = "8M"

			var armed = (
				hud_ref.direct_orders.kind == "ability"
				and hud_ref.direct_orders.ability_id == ability.id
			)
			var glyph_id = CommandCard.ABILITY_GLYPHS.get(ability.id, "attack")
			var extra_str = ""
			if ability.range > 0 and ability.range < 1000:
				extra_str = "Range: %.1f m · Radius: %.1f m" % [ability.range, ability.radius]

			entries.append(
				{
					"id": "unit_" + ability.id,
					"kind": "unit",
					"name": ability.name,
					"description": ability.description,
					"glyph": BattleTheme.icon(glyph_id),
					"hotkey": ability.key,
					"cost_text": cost_desc,
					"cooldown_left": 0.0 if is_inf(min_cd) else min_cd,
					"cooldown_total": ability.cooldown,
					"is_armed": armed,
					"is_active": any_active,
					"is_ready": any_ready,
					"issue": issues[0] if not issues.is_empty() else "",
					"extra": extra_str,
					"action": func(): hud_ref.direct_orders.activate_ability(ability.id)
				}
			)


func _gather_campaign_hero(game, entries: Array):
	if game.campaign_hero == null or not game.campaign_hero.alive():
		return
	var hero = game.campaign_hero
	var ready = hero.cooldown <= 0.0 and not get_tree().paused
	entries.append(
		{
			"id": "campaign_hero_ability",
			"kind": "hero",
			"name": "Hero Ability",
			"description": "Activate campaign hero tactical ability.",
			"glyph": BattleTheme.icon("attack"),
			"hotkey": "H",
			"cost_text": "",
			"cooldown_left": hero.cooldown,
			"cooldown_total": 30.0,
			"is_armed": false,
			"is_active": false,
			"is_ready": ready,
			"issue": "Cooling down" if hero.cooldown > 0.0 else "",
			"action": func(): hero.activate()
		}
	)


func _update_position(hud_ref: CanvasLayer):
	var viewport = get_viewport().get_visible_rect().size
	var tray_size = get_combined_minimum_size()
	if custom_minimum_size != tray_size:
		custom_minimum_size = tray_size
	if size != tray_size:
		size = tray_size

	var res_node = hud_ref.get_node_or_null("HUD/MarginContainer2/Resources")
	if res_node == null:
		res_node = hud_ref.get_parent().get_node_or_null("HUD/MarginContainer2/Resources")
	var res_end_x = (
		res_node.get_global_rect().end.x
		if is_instance_valid(res_node) and res_node.is_visible_in_tree()
		else 0.0
	)

	var sys_pos_x = (
		hud_ref.system_plate.get_global_rect().position.x
		if is_instance_valid(hud_ref.system_plate)
		else viewport.x
	)
	var available_span = sys_pos_x - res_end_x

	var target_pos: Vector2
	if available_span >= tray_size.x + 24.0:
		# Centered neatly in the top rail
		target_pos = Vector2(res_end_x + (available_span - tray_size.x) / 2.0, HudLayout.TOP_RAIL)
	else:
		# Dropped safely below top plates when horizontal space is narrow
		var top_limit = HudLayout.TOP_PLATE + 4.0
		if is_instance_valid(hud_ref.system_plate):
			top_limit = maxf(top_limit, hud_ref.system_plate.get_global_rect().end.y + 4.0)
		target_pos = Vector2(maxf(12.0, (viewport.x - tray_size.x) / 2.0), top_limit)
	if position != target_pos:
		position = target_pos
