extends CanvasLayer

@onready var _container: MarginContainer = $MarginContainer
@onready var _fps_label = find_child("FPSLabel")


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visibility_changed.connect(func(): set_physics_process(visible))
	hide()
	set_physics_process(false)


func _unhandled_input(event):
	if event.is_action_pressed("toggle_diagnostic_mode", false, true):
		visible = not visible


func _physics_process(_delta):
	_update_layout()
	_fps_label.text = (
		"{0} FPS \n".format(["%0.1f" % (Performance.get_monitor(Performance.TIME_FPS))])
		+ str(OS.get_processor_name())
		+ " \n"
		+ str(OS.get_processor_count())
		+ " CPU Cores \n"
		+ str(OS.get_static_memory_usage() / (1024 * 1024))
		+ " MiB Memory Used \n"
		+ str(RenderingServer.get_video_adapter_name())
		+ " "
		+ str(RenderingServer.get_video_adapter_vendor())
		+ " \n"
		+ "Using "
		+ str(OS.get_name())
		+ " Operating System"
	)


func _update_layout():
	if not is_instance_valid(_container):
		return
	var top_margin := 78
	var match_node = get_parent().get_parent() if get_parent() != null else null
	if is_instance_valid(match_node) and "hud" in match_node and is_instance_valid(match_node.hud):
		var hud = match_node.hud
		if "system_plate" in hud and is_instance_valid(hud.system_plate):
			top_margin = maxi(top_margin, ceili(hud.system_plate.size.y) + 8)
		if (
			"production_overview" in hud
			and is_instance_valid(hud.production_overview)
			and hud.production_overview.visible
		):
			top_margin = maxi(
				top_margin, ceili(hud.production_overview.get_global_rect().end.y) + 6
			)
	if _container.get_theme_constant("margin_top") != top_margin:
		_container.add_theme_constant_override("margin_top", top_margin)
