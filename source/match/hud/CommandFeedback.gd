extends Control

## Cosmetic command feedback uses the same contextual rules as right-click orders.
## Destinations are snapshots: feedback never follows a target into hidden terrain.
const Controller = preload("res://source/match/players/human/UnitActionsController.gd")
const ThemeKit = preload("res://source/match/hud/BattleTheme.gd")
const GroundFeedback = preload("res://source/match/effects/TerrainFeedback.gd")
const TITLES = {
	"move": "Move",
	"approach": "Move",
	"attack": "Attack target",
	"force_attack": "Force attack",
	"attack_move": "Attack move",
	"patrol": "Patrol",
	"gather": "Gather",
	"scavenge": "Scavenge",
	"repair": "Repair",
	"recover": "Recover health",
	"construct": "Build",
	"garrison": "Enter building",
	"follow": "Follow",
	"guard": "Guard",
	"rally": "Set rally point",
}
const PATHS = {
	"move": "M1 8h14m-5-5 5 5-5 5",
	"attack": "M1 5V1h4m6 0h4v4m0 6v4h-4m-6 0H1v-4M8 4v8M4 8h8",
	"gather": "M3 2q7-3 12 4M8 3 2 15",
	"repair":
	"M9.8 4.2l2 2 2.5-2.5a4 4 0 0 1-5.3 5.3l-4.6 4.6a2 2 0 0 1-2.8-2.8L6.2 6.2a4 4 0 0 1 5.3-5.3z",
	"construct": "M2 5 6 1l9 9-4 4zM7 8l-6 7",
	"garrison": "M2 15V1h12v14M9 5l4 3-4 3M0 8h12",
	"follow": "M1 5h9m-3-3 3 3-3 3M5 12h10m-3-3 3 3-3 3",
	"guard": "M8 1 14 4v5l-6 6-6-6V4z",
	"rally": "M3 16V1h11l-3 4 3 4H3",
}
const FACTION_STYLE = {
	"bastion":
	{
		"primary": Color("f2be54"),
		"highlight": Color("fff4d1"),
		"attack": Color("ff5c42"),
		"attack_hi": Color("ffd7c4"),
		"rally": Color("f5c55a"),
		"utility": Color("76d4be"),
		"reject": Color("e5a365"),
		"ink": Color(0.05, 0.08, 0.11, 0.74),
		"cursor_hex": "#f2be54",
		"attack_hex": "#ff5c42",
	},
	"helix":
	{
		"primary": Color("5ce8fa"),
		"highlight": Color("ebfeff"),
		"attack": Color("ff4f8b"),
		"attack_hi": Color("ffd9e8"),
		"rally": Color("6ef2ff"),
		"utility": Color("68f0c8"),
		"reject": Color("e8a8c4"),
		"ink": Color(0.03, 0.09, 0.13, 0.74),
		"cursor_hex": "#5ce8fa",
		"attack_hex": "#ff4f8b",
	},
	"frontier":
	{
		"primary": Color("ff9238"),
		"highlight": Color("ffeed8"),
		"attack": Color("ff4726"),
		"attack_hi": Color("ffd082"),
		"rally": Color("ff9c3b"),
		"utility": Color("a6d65e"),
		"reject": Color("e5b378"),
		"ink": Color(0.08, 0.07, 0.05, 0.76),
		"cursor_hex": "#ff9238",
		"attack_hex": "#ff4726",
	},
}
const MAX_MARKERS = 6
var hud
var context = ""
var markers = []
var _selection = []
var _batch = {}
var _elapsed = 0.0
var _cursors = {}
var _cursor_faction = ""
var _cursor_kind = ""
var _pointer = Vector2.ZERO
var _panel: StyleBoxFlat


func _ready():
	name = "CommandFeedback"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = ThemeKit.surface(Color("121b24ee"), 8, 5)
	_panel.set_corner_radius_all(4)
	_rebuild_cursors(_human_faction())

	MatchSignals.unit_selected.connect(_selection_changed)
	MatchSignals.unit_deselected.connect(_selection_changed)
	MatchSignals.deselect_all_units.connect(_selection_changed)
	MatchSignals.order_feedback.connect(_on_order)
	_selection_changed()


func _human_faction() -> String:
	if is_instance_valid(hud) and is_instance_valid(hud.get_parent()):
		var human = hud.get_parent()._get_human_player()
		if is_instance_valid(human) and FACTION_STYLE.has(human.faction):
			return human.faction
	return "bastion"


func _rebuild_cursors(faction: String):
	if faction == _cursor_faction and not _cursors.is_empty():
		return
	_cursor_faction = faction
	var style = FACTION_STYLE.get(faction, FACTION_STYLE["bastion"])
	var badge_shape = (
		'<polygon points="2,-2 14,-2 18,2 18,14 14,18 2,18 -2,14 -2,2" '
		+ 'fill="#0d141c" stroke="%s" stroke-width="1.4"/>'
	)
	if faction == "helix":
		badge_shape = (
			'<polygon points="8,-3 19,8 8,19 -3,8" '
			+ 'fill="#081620" stroke="%s" stroke-width="1.4"/>'
		)
	elif faction == "frontier":
		badge_shape = (
			'<rect x="-2" y="-2" width="20" height="20" rx="3" '
			+ 'fill="#17130f" stroke="%s" stroke-width="1.5"/>'
		)
	for kind in PATHS:
		var stroke = style.attack_hex if kind == "attack" else style.cursor_hex
		var glyph = (
			(
				'<path d="%s" fill="none" stroke="%s" stroke-width="2" '
				+ 'stroke-linecap="round" stroke-linejoin="round"/>'
			)
			% [PATHS[kind], stroke]
		)
		var svg = (
			'<svg xmlns="http://www.w3.org/2000/svg" width="42" height="42">'
			+ '<path d="M2 2v23l6-5.5 4 9.5 4.5-2-4-9.5h9.5z" fill="#f7f9fb" '
			+ 'stroke="#0d141c" stroke-width="2" stroke-linejoin="round"/>'
			+ '<g transform="translate(21 21)">%s%s</g></svg>' % [badge_shape % stroke, glyph]
		)
		var cursor_image = Image.new()
		cursor_image.load_svg_from_string(svg)
		_cursors[kind] = ImageTexture.create_from_image(cursor_image)


func _selection_changed(_unit = null):
	_selection = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)
	_elapsed = .08


func _process(delta):
	var had_content = not markers.is_empty()
	_pointer = get_viewport().get_mouse_position()
	_elapsed += delta
	if _elapsed >= .08:
		_elapsed = 0.0
		_rebuild_cursors(_human_faction())
		context = _context_at(_pointer)
		_set_cursor(_glyph_kind(context))
	var reduced = Globals.options.reduced_flashes
	for index in range(markers.size() - 1, -1, -1):
		var marker = markers[index]
		marker.age += delta
		marker.node.visible = not hud.direct_orders._blocked()
		if marker.accepted and (not reduced or not marker.get("posed", false)):
			_pose_marker(marker)
			marker.posed = reduced
		var fade_in = 1.0 if reduced else clampf(marker.age / 0.045, 0.0, 1.0)
		var fade_out = minf(1.0, (marker.lifetime - marker.age) * 3.6)
		marker.node.fade(fade_in * fade_out)
		if marker.age >= marker.lifetime:
			marker.node.queue_free()
			markers.remove_at(index)
	if had_content or not markers.is_empty():
		queue_redraw()


func _context_at(point):
	if (
		hud.direct_orders._blocked()
		or not get_viewport_rect().has_point(point)
		or get_viewport().gui_get_hovered_control() != null
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		return ""
	var placement = hud.get_parent()._get_human_player().get_node("StructurePlacementHandler")
	if placement._structure_placement_started() or hud._assignment_kind != "":
		return ""
	if not hud.direct_orders.kind.is_empty():
		return hud.direct_orders.kind
	var target = hud._pick_unit(point)
	return contextual_kind(target)


func contextual_kind(target):
	var result = ""
	for unit in _selection:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		var kind = ""
		if is_instance_valid(target):
			kind = Controller.context_kind(unit, target)
		elif unit.movement_speed > 0:
			kind = "move"
		elif unit.find_child("RallyPoint") != null:
			kind = "rally"
		if (
			kind
			in ["gather", "scavenge", "repair", "construct", "garrison", "attack", "force_attack"]
		):
			return kind
		if result.is_empty():
			result = kind
	return result


func _glyph_kind(kind):
	return (
		{
			"ability": "attack",
			"attack_move": "attack",
			"force_attack": "attack",
			"approach": "move",
			"recover": "repair",
			"scavenge": "gather",
			"patrol": "move"
		}
		. get(kind, kind)
	)


func _set_cursor(kind):
	if kind == _cursor_kind:
		return
	_cursor_kind = kind
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(_cursors.get(kind), Input.CURSOR_ARROW, Vector2(2, 2))


func _exit_tree():
	for marker in markers:
		if is_instance_valid(marker.node):
			marker.node.queue_free()
	if not _cursor_kind.is_empty() and DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null)


func _on_order(unit, kind, point, accepted, queued, reason):
	if not is_instance_valid(unit) or not unit.is_in_group("controlled_units"):
		return
	var faction = unit.player.faction if is_instance_valid(unit.player) else _human_faction()
	var key = [kind, accepted, queued, reason, faction]
	if _batch.is_empty():
		_flush_feedback.call_deferred()
	if not _batch.has(key):
		_batch[key] = {"point": Vector3.ZERO, "count": 0}
	_batch[key].point += point
	_batch[key].count += 1


func _flush_feedback():
	var accepted_any = false
	var primary_kind = "move"
	var primary_faction = _human_faction()
	for key in _batch:
		var entry = _batch[key]
		var label = tr(TITLES.get(key[0], "Move")) if key[1] else tr(key[3])
		if key[2] and key[1]:
			label += " · " + tr("Queued")
		_add_marker(entry.point / entry.count, key[0], label, key[1], key[4])
		if key[1]:
			accepted_any = true
			primary_kind = key[0]
			primary_faction = key[4]
	_batch.clear()
	UIAudio.play_order(primary_kind, primary_faction, accepted_any)


func reject(message):
	var camera = get_viewport().get_camera_3d()
	var point = camera.get_ray_intersection(get_viewport().get_mouse_position())
	if point is Vector3:
		var faction = _human_faction()
		_add_marker(point, "", tr(message), false, faction)
		UIAudio.play_order("", faction, false)


func _add_marker(point, kind, label, accepted, faction = ""):
	while markers.size() >= MAX_MARKERS:
		markers.pop_front().node.queue_free()
	var resolved_faction = faction if FACTION_STYLE.has(faction) else _human_faction()
	var heading := Vector3.FORWARD
	if not _selection.is_empty() and is_instance_valid(_selection[0]):
		heading = ((point - _selection[0].global_position) * Vector3(1, 0, 1)).normalized()
	if heading.is_zero_approx():
		heading = Vector3.FORWARD
	var node = GroundFeedback.new()
	node.name = "CommandRing"
	node.map = hud.get_parent().map
	hud.get_parent().add_child(node)
	# Preserve spoken command/rejection feedback after removing accepted cards.
	accessibility_name = label
	var life = 1.15 if kind == "rally" and accepted else (0.98 if accepted else 2.4)
	(
		markers
		. append(
			{
				"point": point,
				"heading": heading,
				"node": node,
				"kind": kind,
				"faction": resolved_faction,
				"text": label,
				"accepted": accepted,
				"age": 0.0,
				"lifetime": life,
			}
		)
	)
	_pose_marker(markers.back())
	queue_redraw()


func _pose_marker(marker):
	var node = marker.node
	var point: Vector3 = marker.point
	var heading: Vector3 = marker.heading
	var faction: String = marker.get("faction", "bastion")
	var style = FACTION_STYLE.get(faction, FACTION_STYLE["bastion"])
	var reduced = Globals.options.reduced_flashes
	var progress = 1.0 if reduced else clampf(marker.age / 0.34, 0.0, 1.0)
	var ease_out = 1.0 - pow(1.0 - progress, 3.0)
	var spin = 0.0 if reduced else marker.age
	var pulse = 0.0 if reduced else clampf(marker.age / 0.62, 0.0, 1.0)
	var kind: String = marker.kind
	var is_attack = kind in ["attack", "attack_move", "force_attack"]
	var is_rally = kind == "rally"
	var is_utility = (
		kind in ["gather", "scavenge", "repair", "recover", "construct", "garrison", "guard"]
	)

	node.begin()
	if not marker.accepted:
		_draw_rejected(node, point, style)
		node.finish()
		return

	var base_color: Color = style.primary
	var hi_color: Color = style.highlight
	if is_attack:
		base_color = style.attack
		hi_color = style.attack_hi
	elif is_rally:
		base_color = style.rally
	elif is_utility:
		base_color = style.utility

	var ctx = {
		"point": point,
		"heading": heading,
		"kind": kind,
		"is_attack": is_attack,
		"is_rally": is_rally,
		"color": base_color,
		"hi": hi_color,
		"ink": style.ink,
		"ease_out": ease_out,
		"pulse": pulse,
		"spin": spin,
		"reduced": reduced,
	}
	match faction:
		"helix":
			_pose_helix(node, ctx)
		"frontier":
			_pose_frontier(node, ctx)
		_:
			_pose_bastion(node, ctx)
	node.finish()


func _draw_rejected(node, point: Vector3, style: Dictionary):
	var ink: Color = style.ink
	var c: Color = style.reject
	node.polygon_ring(point, 0.56, 0.16, 8, PI * 0.125, ink, 0.0)
	node.polygon_ring(point, 0.56, 0.08, 8, PI * 0.125, c, 0.015)
	for angle in [PI * 0.25, -PI * 0.25]:
		var d = Vector3(cos(angle), 0, sin(angle)) * 0.28
		node.line(point - d, point + d, 0.15, ink, 0.005)
		node.line(point - d, point + d, 0.075, c, 0.02)


func _pose_bastion(node, ctx: Dictionary):
	var point: Vector3 = ctx.point
	var heading: Vector3 = ctx.heading
	var kind: String = ctx.kind
	var color: Color = ctx.color
	var hi: Color = ctx.hi
	var ink: Color = ctx.ink
	var ease_out: float = ctx.ease_out
	var pulse: float = ctx.pulse
	var spin: float = ctx.spin
	var reduced: bool = ctx.reduced
	# Bastion: armored chamfered octagons, heavy mechanical lock clamps, double chevrons.
	if ctx.is_rally:
		var r = lerpf(1.18, 0.86, ease_out)
		node.polygon_ring(point, r, 0.17, 8, PI * 0.125, ink, 0.0)
		node.polygon_ring(point, r, 0.085, 8, PI * 0.125, color, 0.015)
		node.polygon_ring(point, 0.42, 0.06, 8, PI * 0.125, hi, 0.02)
		for idx in 4:
			var a = idx * PI * 0.5 + PI * 0.25
			var d = Vector3(cos(a), 0, sin(a))
			node.line(point + d * (r - 0.16), point + d * (r + 0.16), 0.14, ink, 0.005)
			node.line(point + d * (r - 0.14), point + d * (r + 0.14), 0.07, hi, 0.02)
		var col_h = lerpf(0.6, 2.25, ease_out)
		node.beacon_pillar(
			point, 0.28, 0.14, col_h, Color(color, 0.48), Color(color, 0.0), 8, PI * 0.125
		)
		var ring_lift = 0.25 + (0.95 if reduced else fposmod(spin * 1.45, 1.4))
		var ring_alpha = 0.72 * (1.0 - clampf((ring_lift - 0.25) / 1.45, 0.0, 0.85))
		node.polygon_ring(point, 0.56, 0.055, 8, PI * 0.125, Color(hi, ring_alpha), ring_lift)
	elif ctx.is_attack:
		var clamp_r = lerpf(1.42, 0.76, ease_out)
		var inner_r = lerpf(0.72, 0.44, ease_out)
		node.polygon_ring(point, inner_r, 0.13, 8, PI * 0.125 + spin * 0.45, ink, 0.0)
		node.polygon_ring(point, inner_r, 0.06, 8, PI * 0.125 + spin * 0.45, hi, 0.015)
		for idx in 4:
			var a = idx * PI * 0.5 + PI * 0.25
			var d = Vector3(cos(a), 0, sin(a))
			var s = Vector3(-d.z, 0, d.x)
			var corner = point + d * clamp_r
			var arm_a = corner - d * 0.34 + s * 0.08
			var arm_b = corner - d * 0.34 - s * 0.08
			node.line(corner - s * 0.28, corner, 0.17, ink, 0.0)
			node.line(corner + s * 0.28, corner, 0.17, ink, 0.0)
			node.line(corner, corner - d * 0.28, 0.17, ink, 0.0)
			node.line(corner - s * 0.25, corner, 0.09, color, 0.018)
			node.line(corner + s * 0.25, corner, 0.09, color, 0.018)
			node.line(corner, corner - d * 0.24, 0.09, hi, 0.022)
			if kind == "force_attack":
				node.line(arm_a, arm_b, 0.05, color, 0.015)
		if kind == "attack_move":
			node.chevron(point + heading * 0.16, heading, 0.68, 0.15, ink, 0.01)
			node.chevron(point + heading * 0.16, heading, 0.64, 0.08, hi, 0.025)
		else:
			var h = lerpf(1.4, 0.65, ease_out)
			node.beacon_pillar(
				point, 0.16, 0.06, h, Color(color, 0.36), Color(color, 0.0), 4, PI * 0.25
			)
	else:
		var r = lerpf(0.46, 0.84, ease_out)
		node.polygon_ring(point, r, 0.16, 8, PI * 0.125, ink, 0.0)
		node.polygon_ring(point, r, 0.075, 8, PI * 0.125, color, 0.015)
		var clamp_r = lerpf(1.26, 0.94, ease_out)
		for idx in 4:
			var a = idx * PI * 0.5 + PI * 0.25
			var d = Vector3(cos(a), 0, sin(a))
			node.line(point + d * (clamp_r - 0.16), point + d * (clamp_r + 0.08), 0.14, ink, 0.005)
			node.line(point + d * (clamp_r - 0.14), point + d * (clamp_r + 0.06), 0.07, hi, 0.02)
		var slide = lerpf(-0.18, 0.10, ease_out)
		node.chevron(point + heading * (slide + 0.18), heading, 0.62, 0.15, ink, 0.01)
		node.chevron(point + heading * (slide + 0.18), heading, 0.58, 0.08, hi, 0.022)
		node.chevron(
			point + heading * (slide - 0.16), heading, 0.46, 0.065, Color(color, 0.85), 0.022
		)
	if not reduced and pulse < 1.0:
		var ripple = Color(color, 0.46 * (1.0 - pulse))
		node.polygon_ring(point, 0.72 + pulse * 0.86, 0.05, 8, PI * 0.125, ripple, 0.01)


func _pose_helix(node, ctx: Dictionary):
	var point: Vector3 = ctx.point
	var heading: Vector3 = ctx.heading
	var kind: String = ctx.kind
	var color: Color = ctx.color
	var hi: Color = ctx.hi
	var ink: Color = ctx.ink
	var ease_out: float = ctx.ease_out
	var pulse: float = ctx.pulse
	var spin: float = ctx.spin
	var reduced: bool = ctx.reduced
	# Helix: luminous counter-rotating hexagonal phase arcs, crystalline diamond pips, prism spire.
	if ctx.is_rally:
		var r = lerpf(1.24, 0.86, ease_out)
		node.polygon_ring(point, r, 0.13, 6, spin * 0.6, ink, 0.0)
		node.polygon_ring(point, r, 0.06, 6, spin * 0.6, color, 0.015)
		node.polygon_ring(point, 0.48, 0.045, 6, -spin * 0.9, hi, 0.02)
		var col_h = lerpf(0.8, 2.55, ease_out)
		node.beacon_pillar(
			point, 0.24, 0.04, col_h, Color(color, 0.55), Color(hi, 0.0), 6, spin * 0.4
		)
		for idx in 2:
			var wave = 0.0 if reduced else sin(spin * 4.0 + idx * PI) * 0.12
			var h = 0.35 + idx * 0.55 + wave
			var rad = 0.56 - idx * 0.16
			var rot_h = spin * (1.1 if idx == 0 else -1.3)
			node.polygon_ring(point, rad, 0.045, 6, rot_h, Color(hi, 0.76 - idx * 0.22), h)
	elif ctx.is_attack:
		var lock_r = lerpf(1.48, 0.78, ease_out)
		var rot = spin * 1.1
		var hex_r = lerpf(0.95, 0.58, ease_out)
		node.polygon_ring(point, hex_r, 0.11, 6, -rot * 0.7, ink, 0.0)
		node.polygon_ring(point, hex_r, 0.05, 6, -rot * 0.7, Color(color, 0.88), 0.015)
		for idx in 3:
			var a = rot + idx * TAU / 3.0
			var d = Vector3(cos(a), 0, sin(a))
			var pos = point + d * lock_r
			node.wedge_pip(pos, -d, 0.54, 0.24, ink, 0.005)
			node.wedge_pip(pos, -d, 0.42, 0.18, color, 0.02)
			node.arc(point, lock_r + 0.12, 0.045, a - 0.32, a + 0.32, Color(hi, 0.85), 8, 0.022)
		if kind == "attack_move":
			node.diamond_pip(point + heading * 0.14, heading, 0.72, 0.26, ink, 0.01)
			node.diamond_pip(point + heading * 0.14, heading, 0.58, 0.19, hi, 0.025)
		else:
			node.filled_polygon(point, 0.19, 4, rot, hi, 0.025)
			var h = lerpf(1.6, 0.85, ease_out)
			node.beacon_pillar(point, 0.14, 0.02, h, Color(color, 0.42), Color(hi, 0.0), 6, -rot)
	else:
		var r = lerpf(0.42, 0.82, ease_out)
		var rot = spin * 0.9
		for idx in 3:
			var a0 = rot + idx * TAU / 3.0
			node.arc(point, r, 0.13, a0, a0 + TAU / 3.0 - 0.38, ink, 10, 0.0)
			node.arc(point, r, 0.06, a0, a0 + TAU / 3.0 - 0.38, color, 10, 0.015)
		node.polygon_ring(point, r * 0.62, 0.04, 6, -rot * 1.2, Color(hi, 0.78), 0.02)
		var slide = lerpf(-0.16, 0.12, ease_out)
		node.diamond_pip(point + heading * slide, heading, 0.66, 0.24, ink, 0.01)
		node.diamond_pip(point + heading * slide, heading, 0.52, 0.17, hi, 0.025)
	if not reduced and pulse < 1.0:
		var a1 = 0.50 * (1.0 - pulse)
		node.polygon_ring(point, 0.62 + pulse * 0.98, 0.042, 6, spin * 0.5, Color(color, a1), 0.01)
		if pulse > 0.18:
			var p2 = clampf((pulse - 0.18) / 0.82, 0.0, 1.0)
			var c2 = Color(hi, 0.36 * (1.0 - p2))
			node.polygon_ring(point, 0.50 + p2 * 0.72, 0.032, 6, -spin * 0.5, c2, 0.015)


func _pose_frontier(node, ctx: Dictionary):
	var point: Vector3 = ctx.point
	var heading: Vector3 = ctx.heading
	var kind: String = ctx.kind
	var color: Color = ctx.color
	var hi: Color = ctx.hi
	var ink: Color = ctx.ink
	var ease_out: float = ctx.ease_out
	var pulse: float = ctx.pulse
	var spin: float = ctx.spin
	var reduced: bool = ctx.reduced
	# Frontier: bold 3-arc field-stencil rings, radial compass ticks, X-strike brackets, flare plume.
	if ctx.is_rally:
		var r = lerpf(1.20, 0.88, ease_out)
		for idx in 4:
			var a0 = idx * PI * 0.5 + 0.18
			var a1 = (idx + 1) * PI * 0.5 - 0.18
			node.arc(point, r, 0.17, a0, a1, ink, 8, 0.0)
			node.arc(point, r, 0.09, a0, a1, color, 8, 0.015)
			var tick_a = idx * PI * 0.5
			var d = Vector3(cos(tick_a), 0, sin(tick_a))
			node.line(point + d * (r - 0.22), point + d * (r + 0.22), 0.15, ink, 0.005)
			node.line(point + d * (r - 0.18), point + d * (r + 0.18), 0.075, hi, 0.02)
		var col_h = lerpf(0.7, 2.35, ease_out)
		node.beacon_pillar(point, 0.24, 0.18, col_h, Color(color, 0.50), Color(hi, 0.0), 6, 0.0)
		var lift = 0.20 + (0.85 if reduced else fposmod(spin * 1.65, 1.5))
		var ra = 0.75 * (1.0 - clampf((lift - 0.20) / 1.5, 0.0, 0.88))
		node.ring(point, 0.44 + lift * 0.12, 0.06, Color(hi, ra), 24, lift)
	elif ctx.is_attack:
		var r = lerpf(0.92, 0.62, ease_out)
		for idx in 4:
			var a0 = idx * PI * 0.5 + 0.22
			var a1 = (idx + 1) * PI * 0.5 - 0.22
			node.arc(point, r, 0.14, a0, a1, ink, 8, 0.0)
			node.arc(point, r, 0.07, a0, a1, color, 8, 0.015)
		var arm = lerpf(1.38, 0.74, ease_out)
		for idx in 4:
			var a = idx * PI * 0.5 + PI * 0.25
			var d = Vector3(cos(a), 0, sin(a))
			node.line(point + d * (arm - 0.36), point + d * arm, 0.19, ink, 0.005)
			node.line(point + d * (arm - 0.34), point + d * (arm - 0.02), 0.10, hi, 0.022)
		if kind == "attack_move":
			node.wedge_pip(point + heading * 0.16, heading, 0.74, 0.34, ink, 0.01)
			node.wedge_pip(point + heading * 0.16, heading, 0.58, 0.25, hi, 0.025)
		else:
			var h = lerpf(1.35, 0.6, ease_out)
			node.beacon_pillar(point, 0.18, 0.08, h, Color(color, 0.38), Color(hi, 0.0), 6, 0.0)
	else:
		var r = lerpf(0.48, 0.86, ease_out)
		for idx in 3:
			var a0 = idx * TAU / 3.0 + 0.24
			var a1 = (idx + 1) * TAU / 3.0 - 0.24
			node.arc(point, r, 0.17, a0, a1, ink, 10, 0.0)
			node.arc(point, r, 0.085, a0, a1, color, 10, 0.015)
		for idx in 4:
			var a = idx * PI * 0.5
			var d = Vector3(cos(a), 0, sin(a))
			node.line(point + d * (r + 0.06), point + d * (r + 0.22), 0.13, ink, 0.005)
			node.line(point + d * (r + 0.07), point + d * (r + 0.20), 0.065, hi, 0.02)
		var slide = lerpf(-0.18, 0.12, ease_out)
		node.wedge_pip(point + heading * slide, heading, 0.68, 0.30, ink, 0.01)
		node.wedge_pip(point + heading * slide, heading, 0.54, 0.22, hi, 0.025)
	if not reduced and pulse < 1.0:
		var ripple = Color(color, 0.48 * (1.0 - pulse))
		node.ring(point, 0.70 + pulse * 0.88, 0.055, ripple, 32, 0.01)


func _draw():
	if not is_instance_valid(hud) or hud.direct_orders._blocked():
		return
	var camera = get_viewport().get_camera_3d()
	for marker in markers:
		if camera.is_position_behind(marker.point):
			continue
		var point = camera.unproject_position(marker.point)
		var alpha = minf(1.0, (marker.lifetime - marker.age) * 4)
		if not marker.accepted:
			_label_at(point + Vector2(18, 20), marker.text, alpha)


func _label_at(point, text_value, alpha):
	var font = ThemeKit.BODY_FONT
	var width = minf(300, font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var text_size = font.get_multiline_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, width, 13)
	var rect = Rect2(point, Vector2(width + 16, text_size.y + 10))
	rect.position = rect.position.clamp(
		Vector2(8, 8), get_viewport_rect().size - rect.size - Vector2(8, 8)
	)
	_panel.bg_color.a = .93 * alpha
	draw_style_box(_panel, rect)
	draw_multiline_string(
		font,
		rect.position + Vector2(8, 5 + font.get_ascent(13)),
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		13,
		-1,
		Color(1, 1, 1, alpha)
	)
