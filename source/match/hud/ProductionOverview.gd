extends PanelContainer

## Production overview, docked under the system plate whatever is selected: one key
## per building with paid jobs or construction in progress. A key shows the current
## job's portrait and progress and how many jobs the building holds; pressing it
## selects that building and centres the camera on it.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const KEY_SIZE = Vector2(46, 46)
const SEPARATION = 5
const REFRESH_SECONDS = 0.2

var hud
var _flow: HFlowContainer
## Keys in display order; each holds its building in the "building" meta.
var _keys = []
var _elapsed = 0.0


func _ready():
	name = "ProductionOverview"
	theme = BattleTheme.create()
	add_theme_stylebox_override("panel", BattleTheme.strip(10, 6))
	_flow = HFlowContainer.new()
	_flow.name = "Jobs"
	_flow.alignment = FlowContainer.ALIGNMENT_END
	_flow.add_theme_constant_override("h_separation", SEPARATION)
	_flow.add_theme_constant_override("v_separation", SEPARATION)
	add_child(_flow)
	refresh()


func _process(delta):
	_elapsed += delta
	if _elapsed >= REFRESH_SECONDS:
		_elapsed = 0.0
		refresh()
	var viewport = get_viewport_rect().size
	position = Vector2(viewport.x - size.x, maxf(HudLayout.TOP_PLATE, hud.system_plate.size.y) + 6)


## Every building of the human player that is producing or under construction, in a
## stable order: producers first, then construction sites, each by building type.
func entries() -> Array:
	var player = hud.get_parent()._get_human_player()
	if player == null:
		return []
	var result = []
	for unit in player.get_children():
		if not unit is Structure or unit.is_queued_for_deletion() or not unit.is_in_group("units"):
			continue
		if unit.is_under_construction():
			(
				result
				. append(
					{
						"building": unit,
						"role": unit.type,
						"progress": unit.construction_progress(),
						"jobs": 0,
						"construction": true,
						"blocked": "",
					}
				)
			)
			continue
		var queue = unit.production_queue
		if queue == null or queue.size() == 0:
			continue
		var job = queue.get_elements()[0]
		(
			result
			. append(
				{
					"building": unit,
					"role": Catalog.type_from_path(job.unit_prototype.resource_path),
					"progress": job.progress(),
					"jobs": queue.size(),
					"construction": false,
					"blocked": queue.blocked_reason(),
				}
			)
		)
	result.sort_custom(_before)
	return result


func _before(a, b):
	if a.construction != b.construction:
		return not a.construction
	var rank_a = Catalog.STRUCTURES.find(a.building.type)
	var rank_b = Catalog.STRUCTURES.find(b.building.type)
	if rank_a != rank_b:
		return rank_a < rank_b
	return a.building.get_instance_id() < b.building.get_instance_id()


func keys() -> Array:
	return _keys.duplicate()


func refresh():
	var items = entries() if not hud.get_parent().finished else []
	var buildings = items.map(func(item): return item.building)
	if buildings != _keys.map(func(key): return key.get_meta("building")):
		_rebuild(items)
	for index in items.size():
		_update(_keys[index], items[index])
	visible = not items.is_empty()
	# Wrap within the system plate's width so the strip never reaches the top-left plates.
	var room = maxf(KEY_SIZE.x * 4, hud.system_plate.size.x - 20)
	var per_row = maxi(1, floori((room + SEPARATION) / (KEY_SIZE.x + SEPARATION)))
	var columns = mini(items.size(), per_row)
	var width = columns * (KEY_SIZE.x + SEPARATION) - SEPARATION
	if _flow.custom_minimum_size.x != width:
		_flow.custom_minimum_size.x = maxf(0, width)
		size = Vector2.ZERO


func _rebuild(items):
	var focused = get_viewport().gui_get_focus_owner()
	var focused_building = (
		focused.get_meta("building") if focused in _keys and is_instance_valid(focused) else null
	)
	for key in _keys:
		_flow.remove_child(key)
		key.queue_free()
	_keys.clear()
	for item in items:
		var key = _key(item.building)
		_flow.add_child(key)
		_keys.append(key)
		# Keyboard focus stays with its building when keys come and go.
		if item.building == focused_building:
			key.grab_focus.call_deferred()
	size = Vector2.ZERO


func _key(building):
	var key = Button.new()
	key.name = "Job%d" % building.get_instance_id()
	key.set_meta("building", building)
	key.theme_type_variation = "HudSlotButton"
	key.custom_minimum_size = KEY_SIZE
	key.expand_icon = true
	key.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	key.pressed.connect(_select.bind(key))
	var count = Label.new()
	count.name = "Count"
	count.add_theme_font_override("font", BattleTheme.numeral_font())
	count.add_theme_font_size_override("font_size", 13)
	count.add_theme_constant_override("outline_size", 4)
	count.add_theme_color_override("font_outline_color", Color("050607"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	count.offset_left = -26
	count.offset_right = -5
	count.offset_top = 1
	count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(count)
	var bar = ProgressBar.new()
	bar.name = "Progress"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", BattleTheme.bar_track())
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 5
	bar.offset_right = -5
	bar.offset_top = -10
	bar.offset_bottom = -5
	key.add_child(bar)
	return key


func _update(key, item):
	var faction = item.building.player.faction
	if key.get_meta("role", "") != item.role:
		key.set_meta("role", item.role)
		key.icon = Factions.portrait(faction, item.role)
	var count = key.get_node("Count")
	count.text = str(item.jobs) if item.jobs > 1 else ""
	var bar = key.get_node("Progress")
	bar.value = item.progress
	var tint = (
		BattleTheme.SIGNAL_WARN
		if not item.blocked.is_empty()
		else (BattleTheme.SIGNAL_OK if item.construction else BattleTheme.accent())
	)
	if key.get_meta("tint", Color.TRANSPARENT) != tint:
		key.set_meta("tint", tint)
		bar.add_theme_stylebox_override("fill", BattleTheme.bar_fill(tint))
	var percent = int(item.progress * 100.0)
	var title = tr(Factions.title(faction, item.role))
	var lines = []
	if item.construction:
		lines.append(tr("%s · under construction %d%%") % [title, percent])
	else:
		lines.append(tr("%s · %d%%") % [title, percent])
		lines.append(tr("Producer: %s") % tr(Factions.title(faction, item.building.type)))
		if item.jobs > 1:
			lines.append(tr("%d jobs queued") % item.jobs)
		if not item.blocked.is_empty():
			lines.append(tr(item.blocked))
	lines.append(tr("Select to view the building."))
	key.tooltip_text = "\n".join(lines)
	key.accessibility_name = lines[0]
	key.accessibility_description = "\n".join(lines.slice(1))


func _select(key):
	var building = key.get_meta("building")
	if is_instance_valid(building) and not building.is_queued_for_deletion():
		hud.select_units([building])
