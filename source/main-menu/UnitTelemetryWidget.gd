extends PanelContainer

const SHADER = preload("res://source/shaders/tactical_chamfer.gdshader")

var _turntable: Node3D
var _viewport: SubViewport
var _camera: Camera3D
var _model_instance: Node3D
var _unit_name_label: Label
var _unit_class_label: Label
var _unit_armor_label: Label
var _unit_weapon_label: Label
var _azimuth_label: Label
var _bg: ColorRect
var _material: ShaderMaterial

const UNITS = {
	"walker": {
		"name": "BASTION B-44 COMBAT WALKER",
		"class": "HEAVY ASSAULT // BIPEDAL PLATFORM",
		"armor": "COMPOSITE CHOBHAM // 94% INTEGRITY",
		"weapon": "TWIN 120mm HYPER-VELOCITY CANNON",
		"model": "res://assets/models/bastion/demo/CombatRobot.glb",
		"cam_pos": Vector3(0, 2.0, 4.0),
		"cam_target": Vector3(0, 1.1, 0),
		"scale": Vector3(1.15, 1.15, 1.15),
	},
	"tank": {
		"name": "BASTION MBT-09 CRUSADER",
		"class": "MAIN BATTLE TANK // TRACKED",
		"armor": "REACTIVE STEEL SLABS // 98% INTEGRITY",
		"weapon": "140mm SMOOTHBORE RAIL-ASSIST",
		"model": "res://assets/models/bastion/demo/Tank.glb",
		"cam_pos": Vector3(0, 2.2, 5.0),
		"cam_target": Vector3(0, 0.7, 0),
		"scale": Vector3(0.68, 0.68, 0.68),
	},
	"helicopter": {
		"name": "FRONTIER AH-7 VIPER GUNSHIP",
		"class": "TACTICAL CLOSE AIR SUPPORT // VTOL",
		"armor": "LIGHT TITANIUM HULL // 78% INTEGRITY",
		"weapon": "QUAD HIGH-EXPLOSIVE HYDRA PODS",
		"model": "res://assets/models/bastion/demo/Helicopter.glb",
		"cam_pos": Vector3(0, 1.6, 4.0),
		"cam_target": Vector3(0, 0.6, 0),
		"scale": Vector3(0.9, 0.9, 0.9),
	}
}

var _current_key = "walker"


func _ready():
	custom_minimum_size = Vector2(440, 480)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Empty stylebox
	var empty = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty)
	
	# Background chamfered panel
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("cut_size", 16.0)
	_material.set_shader_parameter("cut_top_right", false)
	_material.set_shader_parameter("cut_bottom_left", false)
	_material.set_shader_parameter("cut_top_left", true)
	_material.set_shader_parameter("cut_bottom_right", true)
	_material.set_shader_parameter("left_accent_width", 0.0)
	_material.set_shader_parameter("border_width", 1.2)
	_material.set_shader_parameter("border_color", Color("1d2c36e8"))
	_material.set_shader_parameter("bg_color", Color("0c1419fa"))
	
	_bg = ColorRect.new()
	_bg.material = _material
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Header bar
	var header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = tr("RECON FEED // UNIT TELEMETRY")
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("d8a846"))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	_azimuth_label = Label.new()
	_azimuth_label.text = tr("AZIMUTH: %03d°") % 0
	_azimuth_label.add_theme_font_size_override("font_size", 10)
	_azimuth_label.add_theme_color_override("font_color", Color("7b929e"))
	header.add_child(_azimuth_label)
	
	# Viewport container
	var vp_container = SubViewportContainer.new()
	vp_container.custom_minimum_size = Vector2(408, 240)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(vp_container)
	
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(408, 240)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	vp_container.add_child(_viewport)
	
	_setup_3d_scene()
	
	# HUD overlay lines over viewport
	var hud_overlay = Control.new()
	hud_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp_container.add_child(hud_overlay)
	hud_overlay.draw.connect(_draw_viewport_hud.bind(hud_overlay))
	
	# Specifications card
	var spec_panel = VBoxContainer.new()
	spec_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spec_panel.add_theme_constant_override("separation", 5)
	vbox.add_child(spec_panel)
	
	_unit_name_label = Label.new()
	_unit_name_label.text = tr(UNITS[_current_key]["name"])
	_unit_name_label.add_theme_font_size_override("font_size", 15)
	_unit_name_label.add_theme_color_override("font_color", Color("f1eee4"))
	spec_panel.add_child(_unit_name_label)
	
	_unit_class_label = _spec_line(spec_panel, "CLASS:", tr(UNITS[_current_key]["class"]))
	_unit_armor_label = _spec_line(spec_panel, "ARMOR:", tr(UNITS[_current_key]["armor"]))
	_unit_weapon_label = _spec_line(spec_panel, "PRIMARY:", tr(UNITS[_current_key]["weapon"]))
	
	# Tactical telemetry meters
	var meter_box = VBoxContainer.new()
	meter_box.add_theme_constant_override("separation", 3)
	spec_panel.add_child(meter_box)
	_add_stat_bar(meter_box, tr("FIREPOWER"), 0.88, Color("d8a846"))
	_add_stat_bar(meter_box, tr("ARMOR INTEGRITY"), 0.94, Color("4da8cc"))
	_add_stat_bar(meter_box, tr("MOBILITY"), 0.65, Color("7b929e"))
	
	resized.connect(_on_resized)
	_on_resized()
	set_process(true)


func _on_resized():
	if _material:
		_material.set_shader_parameter("rect_size", size)


func _spec_line(parent: Control, tag: String, val: String) -> Label:
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var t = Label.new()
	t.text = tr(tag)
	t.custom_minimum_size.x = 75
	t.add_theme_font_size_override("font_size", 10)
	t.add_theme_color_override("font_color", Color("5d7582"))
	row.add_child(t)
	var v = Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 11)
	v.add_theme_color_override("font_color", Color("acbcc4"))
	row.add_child(v)
	return v


func _add_stat_bar(parent: Control, tag: String, value: float, col: Color):
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var label = Label.new()
	label.text = tag
	label.custom_minimum_size.x = 100
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("7b929e"))
	row.add_child(label)
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	bar.value = value * 100.0
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color("101a20")
	bar.add_theme_stylebox_override("background", style_bg)
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = col
	bar.add_theme_stylebox_override("fill", style_fill)
	row.add_child(bar)


func _setup_3d_scene():
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a121600")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("38505e")
	env_node.environment = env
	_viewport.add_child(env_node)
	
	# Turntable root
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	
	# Key Light (tactical amber front-left)
	var light_key = DirectionalLight3D.new()
	light_key.light_color = Color("f7e3b5")
	light_key.light_energy = 1.3
	light_key.rotation_degrees = Vector3(-35, 45, 0)
	_viewport.add_child(light_key)
	
	# Rim Light (cool blue-grey rear-right)
	var light_rim = DirectionalLight3D.new()
	light_rim.light_color = Color("7ab5d6")
	light_rim.light_energy = 1.6
	light_rim.rotation_degrees = Vector3(25, -135, 0)
	_viewport.add_child(light_rim)
	
	# Camera
	_camera = Camera3D.new()
	_camera.position = UNITS[_current_key]["cam_pos"]
	_camera.current = true
	_viewport.add_child(_camera)
	_camera.look_at(UNITS[_current_key]["cam_target"])
	
	_load_model(_current_key)


func _load_model(key: String):
	if _model_instance != null:
		_model_instance.queue_free()
		_model_instance = null
	
	var data = UNITS[key]
	var scene = load(data["model"])
	if scene:
		_model_instance = scene.instantiate()
		_model_instance.scale = data["scale"]
		_turntable.add_child(_model_instance)
	if _camera != null:
		_camera.position = data["cam_pos"]
		_camera.look_at(data["cam_target"])


func set_unit(key: String):
	if not UNITS.has(key) or key == _current_key:
		return
	_current_key = key
	var data = UNITS[key]
	_unit_name_label.text = tr(data["name"])
	_unit_class_label.text = tr(data["class"])
	_unit_armor_label.text = tr(data["armor"])
	_unit_weapon_label.text = tr(data["weapon"])
	_load_model(key)


func _process(delta: float):
	if _turntable != null:
		_turntable.rotation.y += delta * 0.35
		var deg = int(rad_to_deg(_turntable.rotation.y)) % 360
		if deg < 0:
			deg += 360
		if _azimuth_label != null:
			_azimuth_label.text = tr("AZIMUTH: %03d°") % deg


func _draw_viewport_hud(overlay: Control):
	var s = overlay.size
	var line_col = Color("2d465488")
	var bl = 10.0
	# 4 Corner brackets around 3D viewport
	overlay.draw_line(Vector2(2, 2), Vector2(2 + bl, 2), line_col, 1.0)
	overlay.draw_line(Vector2(2, 2), Vector2(2, 2 + bl), line_col, 1.0)
	overlay.draw_line(Vector2(s.x - 2, 2), Vector2(s.x - 2 - bl, 2), line_col, 1.0)
	overlay.draw_line(Vector2(s.x - 2, 2), Vector2(s.x - 2, 2 + bl), line_col, 1.0)
	overlay.draw_line(Vector2(2, s.y - 2), Vector2(2 + bl, s.y - 2), line_col, 1.0)
	overlay.draw_line(Vector2(2, s.y - 2), Vector2(2, s.y - 2 - bl), line_col, 1.0)
	overlay.draw_line(Vector2(s.x - 2, s.y - 2), Vector2(s.x - 2 - bl, s.y - 2), line_col, 1.0)
	overlay.draw_line(Vector2(s.x - 2, s.y - 2), Vector2(s.x - 2, s.y - 2 - bl), line_col, 1.0)
	
	# Center crosshair tick
	var c = s * 0.5
	overlay.draw_line(Vector2(c.x - 6, c.y), Vector2(c.x + 6, c.y), Color("d8a84644"), 1.0)
	overlay.draw_line(Vector2(c.x, c.y - 6), Vector2(c.x, c.y + 6), Color("d8a84644"), 1.0)
