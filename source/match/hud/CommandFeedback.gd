extends Control

## Cosmetic command feedback uses the same contextual rules as right-click orders.
## Destinations are snapshots: feedback never follows a target into hidden terrain.
const Controller = preload("res://source/match/players/human/UnitActionsController.gd")
const ThemeKit = preload("res://source/match/hud/BattleTheme.gd")
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
	"attack": "M1 5V1h4m6 0h4v4m0 6v4h-4m-6 0H1v-4",
	"gather": "M3 2q7-3 12 4M8 3 2 15",
	"repair":
	"M9.8 4.2l2 2 2.5-2.5a4 4 0 0 1-5.3 5.3l-4.6 4.6a2 2 0 0 1-2.8-2.8L6.2 6.2a4 4 0 0 1 5.3-5.3z",
	"construct": "M2 5 6 1l9 9-4 4zM7 8l-6 7",
	"garrison": "M2 15V1h12v14M9 5l4 3-4 3M0 8h12",
	"follow": "M1 5h9m-3-3 3 3-3 3M5 12h10m-3-3 3 3-3 3",
	"guard": "M8 1 14 4v5l-6 6-6-6V4z",
	"rally": "M3 16V1h11l-3 4 3 4H3",
}
const GroundFeedback = preload("res://source/match/effects/TerrainFeedback.gd")
const MAX_MARKERS = 6
var hud
var context = ""
var markers = []
var _selection = []
var _batch = {}
var _elapsed = 0.0
var _cursors = {}
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
	for kind in PATHS:
		var glyph = (
			'<path d="%s" fill="none" stroke="white" stroke-width="2" stroke-linejoin="round"/>'
			% PATHS[kind]
		)
		var svg = (
			'<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40">'
			+ '<path d="M2 2v24l6-6 4 10 5-2-4-10h10z" fill="white" '
			+ 'stroke="#101820" stroke-width="2"/><g transform="translate(21 21)">'
			+ '<path d="M-2-2h20v20H-2z" fill="#101820"/>%s</g></svg>' % glyph
		)
		var cursor_image = Image.new()
		cursor_image.load_svg_from_string(svg)
		_cursors[kind] = ImageTexture.create_from_image(cursor_image)

	MatchSignals.unit_selected.connect(_selection_changed)
	MatchSignals.unit_deselected.connect(_selection_changed)
	MatchSignals.deselect_all_units.connect(_selection_changed)
	MatchSignals.order_feedback.connect(_on_order)
	_selection_changed()


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
		context = _context_at(_pointer)
		_set_cursor(_glyph_kind(context))
	for index in range(markers.size() - 1, -1, -1):
		markers[index].age += delta
		var marker = markers[index]
		marker.node.visible = not hud.direct_orders._blocked()
		marker.node.fade(minf(1.0, (marker.lifetime - marker.age) * 4.0))
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
	var key = [kind, accepted, queued, reason]
	if _batch.is_empty():
		_flush_feedback.call_deferred()
	if not _batch.has(key):
		_batch[key] = {"point": Vector3.ZERO, "count": 0}
	_batch[key].point += point
	_batch[key].count += 1


func _flush_feedback():
	var accepted_any = false
	for key in _batch:
		var entry = _batch[key]
		var label = tr(TITLES.get(key[0], "Move")) if key[1] else tr(key[3])
		if key[2] and key[1]:
			label += " · " + tr("Queued")
		_add_marker(entry.point / entry.count, key[0], label, key[1])
		accepted_any = accepted_any or key[1]
	_batch.clear()
	UIAudio.play("confirm" if accepted_any else "adjust")


func reject(message):
	var camera = get_viewport().get_camera_3d()
	var point = camera.get_ray_intersection(get_viewport().get_mouse_position())
	if point is Vector3:
		_add_marker(point, "", tr(message), false)
		UIAudio.play("adjust")


func _add_marker(point, kind, label, accepted):
	while markers.size() >= MAX_MARKERS:
		markers.pop_front().node.queue_free()
	var node = GroundFeedback.new()
	node.name = "CommandRing"
	node.map = hud.get_parent().map
	hud.get_parent().add_child(node)
	node.begin()
	var color = Color("e3eff1") if accepted else Color("e5c38c")
	node.ring(point, .85 if accepted else .5, .09, color)
	if kind in ["attack", "attack_move"]:
		for index in 4:
			var direction = Vector3.RIGHT.rotated(Vector3.UP, index * PI * .5)
			node.line(point + direction * .3, point + direction * 1.2, .1, color)
	elif not accepted:
		node.line(point + Vector3.LEFT * .25, point + Vector3.RIGHT * .25, .1, color)
	node.finish()
	# Preserve spoken command/rejection feedback after removing accepted cards.
	accessibility_name = label
	markers.append(
		{
			"point": point,
			"node": node,
			"kind": kind,
			"text": label,
			"accepted": accepted,
			"age": 0.0,
			"lifetime": .9 if accepted else 2.4
		}
	)
	queue_redraw()


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
