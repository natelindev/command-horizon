extends "res://tests/rendered/CampaignBriefingCatalogPreview.gd"


func _review_mission(id: String, locale: String, factor: float, font_size: int):
	# Production/HUD canvas scaling preserves physical pixels while its logical
	# UI viewport remains853x480 at150%. VIEWPORT captures a853x480 render target.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280, 720)
	var deadline := Time.get_ticks_msec() + 5000
	var stable_since := Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1280, 720):
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280, 720)
			stable_since = Time.get_ticks_msec()
		if Time.get_ticks_msec() - stable_since >= 500:
			break
		await process_frame
	_check(root.size == Vector2i(1280, 720), "Physical briefing window did not settle")
	await super._review_mission(id, locale, factor, font_size)


func _check(condition: bool, message: String):
	if message.begins_with("Interface scale did not apply:"):
		# Canvas UI coordinates retain fractional pixels; do not truncate853.333
		# to853 as the viewport-render-target fixture does at150%.
		var factor: float = root.get_node("Globals").options.interface_scale
		condition = root.get_visible_rect().size.is_equal_approx(Vector2(1280, 720) / factor)
	super._check(condition, message)
