extends PanelContainer

## A screen-space explanation stays readable at any camera zoom. The root
## viewport applies the user's interface scale, just as it does for the HUD.
const ThemeKit = preload("res://source/match/hud/BattleTheme.gd")
const WIDTH = 320.0
const FONT_SIZE = 16
var world_position = Vector3.ZERO
var _label: Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	var panel = ThemeKit.surface(Color("121b24f5"), 12, 9)
	panel.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", ThemeKit.BODY_FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", ThemeKit.IVORY)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = WIDTH - 24
	_label.size.x = WIDTH - 24
	add_child(_label)
	clear()


func show_reason(message, point):
	world_position = point
	_label.text = message
	reset_size()
	set_process(true)
	_process(0.0)


func clear():
	hide()
	set_process(false)


func _process(_delta):
	var camera = get_viewport().get_camera_3d()
	visible = (
		camera != null
		and not camera.is_position_behind(world_position)
		and get_viewport().gui_get_hovered_control() == null
	)
	if visible:
		reset_size()
		_place_at(camera.unproject_position(world_position) + Vector2(24, 30))


func _place_at(point):
	var edge = get_viewport_rect().size - size - Vector2(8, 8)
	position = point.clamp(Vector2(8, 8), edge.max(Vector2(8, 8)))
