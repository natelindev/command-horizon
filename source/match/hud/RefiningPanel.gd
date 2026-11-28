extends VBoxContainer

## Direct bottom-HUD controls for Risk-the-Batch Refining.
## No nested menus or floating dialogs; every faction exposes one-click batch,
## discharge, or deploy controls with live progress and clear tooltips.

const Profile = preload("res://source/match/economy/RefiningProfile.gd")

var unit = null
var _refining = null
var _status_label: Label = null
var _progress: ProgressBar = null
var _row: HBoxContainer = null
var _buttons: Dictionary = {}
var _refresh_left: float = 0.0


func _ready():
	add_theme_constant_override("separation", 6)
	_refining = unit.get_node_or_null("Refining") if is_instance_valid(unit) else null
	if _refining == null:
		return
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_status_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(140, 16)
	_progress.max_value = 100.0
	_progress.show_percentage = true
	header.add_child(_progress)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)
	_build_buttons()
	_refining.state_changed.connect(refresh)
	if unit.player != null:
		unit.player.changed.connect(refresh)
	refresh()


func _process(delta: float):
	if not is_visible_in_tree() or _refining == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.2
		refresh()


func _add_btn(id: String, label: String, tip: String, handler: Callable):
	var btn = Button.new()
	btn.name = "Refine_" + id
	btn.text = label
	btn.tooltip_text = tip
	btn.accessibility_name = label
	btn.accessibility_description = tip
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(handler)
	_row.add_child(btn)
	_buttons[id] = btn


func _build_buttons():
	match _refining.mode:
		"bastion":
			_add_btn(
				"standard",
				tr("Small 30→12"),
				tr("Standard Smelter batch: 30 Raw -> 12 Refined in 15 s."),
				func(): _refining.set_batch_tier("standard")
			)
			_add_btn(
				"heavy",
				tr("Heavy 60→30"),
				tr("Heavy Smelter batch: 60 Raw -> 30 Refined in 30 s (+25% efficiency)."),
				func(): _refining.set_batch_tier("heavy")
			)
			_add_btn(
				"super_heavy",
				tr("Super 100→60"),
				tr("Requires Pressurized Blast Furnaces: 100 Raw -> 60 Refined in 42 s."),
				func(): _refining.set_batch_tier("super_heavy")
			)
			_add_btn(
				"overpressure",
				tr("Overpressure"),
				tr("+30% smelting speed for +4 Power (15 s cooldown after batch)."),
				func(): _refining.toggle_overpressure()
			)
			_add_btn(
				"auto",
				tr("Auto-Cycle"),
				tr("Automatically begin the next batch when smelting completes."),
				func(): _refining.toggle_auto_cycle()
			)
			_add_btn(
				"abort",
				tr("Abort Dump"),
				tr("Cancel active batch and recover partial Raw (50%, or 80% Pressurized)."),
				func(): _refining.abort_batch()
			)
		"helix":
			for tier in [1, 2, 3, 4]:
				var spec = Profile.helix_tier(tier)
				var tip = (
					tr("Auto-discharge at Tier %d (%d Raw -> %d Refined in %d s).")
					% [tier, int(spec.raw), int(spec.refined), int(spec.time)]
				)
				_add_btn(
					"t%d" % tier,
					tr("Auto T%d") % tier,
					tip,
					func(): _refining.set_target_tier(tier)
				)
			_add_btn(
				"discharge",
				tr("Discharge Now"),
				tr("Immediately bank accrued Refined Cores at the current resonance tier."),
				func(): _refining.discharge_now()
			)
		"frontier":
			_add_btn(
				"deploy",
				tr("Deploy & Distill"),
				tr(
					"Park Crack-Rig (1.5 s) and distill 24 Raw -> 12 Refined (+40% faster in Hot Zones)."
				),
				func(): _refining.deploy()
			)
			_add_btn(
				"pack",
				tr("Pack Up"),
				tr("Abort active distillation (50% Raw refund) and restore mobility."),
				func(): _refining.pack_up()
			)
			_add_btn(
				"fuel",
				tr("Fuel Inject"),
				tr(
					"Requires Total Battlefield Alchemy: spend 12 Refined to boost nearby vehicles +25% for 15 s."
				),
				func(): _refining.inject_fuel()
			)
			_add_btn(
				"assemble",
				tr("Build Outrider"),
				tr(
					"Requires Salvage War Machine: assemble an Outrider on-site (16 Raw / 12 Refined)."
				),
				func(): _refining.assemble_raider()
			)


func refresh():
	if _refining == null or not is_instance_valid(unit):
		return
	var paused = get_tree().paused
	_status_label.text = tr(_refining.status_summary())
	_progress.value = _refining.progress_ratio() * 100.0
	match _refining.mode:
		"bastion":
			for tier_id in ["standard", "heavy", "super_heavy"]:
				var btn = _buttons[tier_id]
				var unlocked = Profile.bastion_batch_unlocked(unit.player, tier_id)
				btn.visible = unlocked or tier_id != "super_heavy"
				btn.disabled = paused or not unlocked
				btn.text = (
					("* " if _refining.batch_tier == tier_id else "")
					+ {
						"standard": tr("Small 30→12"),
						"heavy": tr("Heavy 60→30"),
						"super_heavy": tr("Super 100→60"),
					}[tier_id]
				)
			var over_btn = _buttons["overpressure"]
			over_btn.text = (
				tr("Overpressure ON")
				if _refining.overpressure_enabled
				else (
					tr("Overpressure %ds") % ceili(_refining.overpressure_cooldown)
					if (
						_refining.overpressure_cooldown > 0.0
						and not Profile.has_tech(unit.player, "iron_blitz")
					)
					else tr("Overpressure")
				)
			)
			over_btn.disabled = (
				paused
				or (
					not _refining.overpressure_enabled
					and _refining.overpressure_cooldown > 0.0
					and not Profile.has_tech(unit.player, "iron_blitz")
				)
			)
			_buttons["auto"].text = tr("Auto: ON") if _refining.auto_cycle else tr("Auto: OFF")
			_buttons["auto"].disabled = paused
			_buttons["abort"].disabled = paused or not _refining.active
		"helix":
			var has_lattice = Profile.has_tech(unit.player, "harmonic_lattice")
			for tier in [1, 2, 3, 4]:
				var btn = _buttons["t%d" % tier]
				btn.visible = tier < 4 or has_lattice
				btn.disabled = paused or (tier == 4 and not has_lattice)
				btn.text = ("* " if _refining.target_tier == tier else "") + (tr("Auto T%d") % tier)
			var ready_yield = Profile.helix_yield_for_charge(
				_refining.charge_seconds, _refining.helix_max_tier()
			)
			_buttons["discharge"].text = (
				tr("Discharge (+%d R)") % ready_yield if ready_yield > 0 else tr("Discharge Now")
			)
			_buttons["discharge"].disabled = paused or ready_yield <= 0
		"frontier":
			_buttons["deploy"].disabled = paused or _refining.deploy_state != "mobile"
			_buttons["pack"].disabled = paused or _refining.deploy_state != "deployed"
			var has_alchemy = Profile.has_tech(unit.player, "battlefield_alchemy")
			_buttons["fuel"].visible = has_alchemy
			_buttons["fuel"].disabled = (
				paused
				or not has_alchemy
				or _refining.deploy_state != "deployed"
				or (
					unit.player.resource_b < Profile.FRONTIER_BATCH_REFINED
					and _refining.ready_batch <= 0
				)
			)
			var has_war = Profile.has_tech(unit.player, "salvage_war_machine")
			_buttons["assemble"].visible = has_war
			_buttons["assemble"].disabled = (
				paused
				or not has_war
				or _refining.deploy_state != "deployed"
				or not unit.player.has_resources({"resource_a": 16, "resource_b": 12})
			)
