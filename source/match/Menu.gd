extends CanvasLayer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")


func _ready():
	hide()
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.name = "PauseArtwork"
	backdrop.dim = .28
	backdrop.motion = false
	add_child(backdrop)
	move_child(backdrop, 1)
	var panel = find_child("PanelContainer")
	if panel != null:
		BattleTheme.apply(panel, 20, 16)
	var resume = find_child("ResumeButton")
	if resume != null:
		resume.theme = BattleTheme.create()
		resume.theme_type_variation = "BattlePrimaryButton"
		resume.custom_minimum_size.y = 40
		resume.focus_mode = Control.FOCUS_ALL
	var exit_btn = find_child("ExitButton")
	if exit_btn != null:
		exit_btn.theme = BattleTheme.create()
		exit_btn.custom_minimum_size.y = 40
		exit_btn.focus_mode = Control.FOCUS_ALL


func _unhandled_input(event):
	if (
		event.is_action_pressed("toggle_match_menu", false, true)
		and ((not visible and not get_tree().paused) or (visible and get_tree().paused))
	):
		_toggle()


func _toggle():
	visible = not visible
	get_tree().paused = visible
	if visible:
		find_child("ResumeButton").grab_focus()


func _on_resume_button_pressed():
	_toggle()


func _on_exit_button_pressed():
	MatchSignals.match_aborted.emit()
	await get_tree().create_timer(1.74).timeout  # Give voice narrator some time to finish.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
