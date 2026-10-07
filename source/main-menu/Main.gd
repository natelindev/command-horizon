extends Control


func _ready():
	get_node("/root/SaveManager").autosaves_enabled = true
	var buttons = find_child("VBoxContainer")
	var demo_button = Button.new()
	demo_button.text = "BASTION DEMO"
	demo_button.pressed.connect(
		func(): get_tree().change_scene_to_file("res://source/match/BastionDemo.tscn")
	)
	buttons.add_child(demo_button)
	buttons.move_child(demo_button, 0)
	var skirmish_button = buttons.get_node("Button")
	skirmish_button.text = "SKIRMISH"
	buttons.move_child(skirmish_button, 0)
	skirmish_button.grab_focus()
	var campaign_button = Button.new()
	campaign_button.text = "CAMPAIGN"
	campaign_button.pressed.connect(
		func(): get_tree().change_scene_to_file("res://source/main-menu/Campaign.tscn")
	)
	buttons.add_child(campaign_button)
	buttons.move_child(campaign_button, 1)
	var load_button = Button.new()
	load_button.text = "LOAD BATTLE"
	load_button.pressed.connect(func(): get_node("/root/SaveManager").open_dialog())
	buttons.add_child(load_button)
	buttons.move_child(load_button, 2)
	var helix_button = Button.new()
	helix_button.text = "HELIX MODEL REVIEW"
	helix_button.pressed.connect(
		func(): get_tree().change_scene_to_file("res://source/showcase/HelixShowcase.tscn")
	)
	buttons.add_child(helix_button)
	buttons.move_child(helix_button, 4)


func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Play.tscn")


func _on_options_button_pressed():
	Globals.open_settings()


func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Credits.tscn")


func _on_quit_button_pressed():
	get_tree().quit()
