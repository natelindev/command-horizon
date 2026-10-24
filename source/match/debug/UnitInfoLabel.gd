extends Label3D

## Unit status text belongs to the explicit F1 diagnostic overlay, even in debug builds.
signal refresh_requested

var content_visible = true:
	set(value):
		content_visible = value
		_update_visibility()
var _diagnostics: CanvasLayer


func _init():
	hide()


func _ready():
	hide()
	var ancestor = get_parent()
	while ancestor != null:
		_diagnostics = ancestor.get_node_or_null("Debug/DiagnosticHUD")
		if _diagnostics != null:
			break
		ancestor = ancestor.get_parent()
	if _diagnostics != null:
		_diagnostics.visibility_changed.connect(_diagnostics_changed)
	_diagnostics_changed()


func diagnostics_enabled() -> bool:
	return is_instance_valid(_diagnostics) and _diagnostics.visible


func _diagnostics_changed():
	if diagnostics_enabled():
		# Owners read live gameplay state only when the overlay becomes visible.
		refresh_requested.emit()
	_update_visibility()


func _update_visibility():
	visible = content_visible and diagnostics_enabled()
