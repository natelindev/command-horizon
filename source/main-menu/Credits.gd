extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const MenuChrome = preload("res://source/main-menu/MenuChrome.gd")

@onready var _rich_text_label = find_child("RichTextLabel")
@onready var _button = find_child("Button")


func _ready():
	theme = ArtTheme.create()
	var backdrop = find_child("Background")
	if is_instance_valid(backdrop) and "dim" in backdrop:
		backdrop.dim = 0.52
		if "left_focus" in backdrop:
			backdrop.left_focus = 0.35

	var panel = find_child("PanelContainer")
	if is_instance_valid(panel):
		panel.theme_type_variation = "HudHousing"
		panel.add_theme_stylebox_override("panel", ArtTheme.housing(22, 18))

	var vbox = find_child("VBoxContainer")
	if is_instance_valid(vbox):
		var header_box = VBoxContainer.new()
		header_box.add_theme_constant_override("separation", 6)

		var title_row = HBoxContainer.new()
		title_row.alignment = BoxContainer.ALIGNMENT_CENTER
		title_row.add_theme_constant_override("separation", 10)
		header_box.add_child(title_row)

		var crest = MenuChrome.TacticalCrest.new(28.0)
		crest.accent = ArtTheme.accent()
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(crest)

		var title_lbl = Label.new()
		title_lbl.text = tr("CREDITS")
		title_lbl.add_theme_font_override("font", ArtTheme.heading_font())
		title_lbl.add_theme_font_size_override("font_size", 24)
		title_lbl.add_theme_color_override("font_color", ArtTheme.IVORY)
		title_row.add_child(title_lbl)

		header_box.add_child(MenuChrome.stripe_bar(3.0))

		vbox.add_child(header_box)
		vbox.move_child(header_box, 1)

	if is_instance_valid(panel):
		for sub_panel in panel.find_children("*", "PanelContainer", true, false):
			if sub_panel != panel:
				sub_panel.theme_type_variation = "HudSocket"
				sub_panel.add_theme_stylebox_override("panel", ArtTheme.socket(16, 12))

	if is_instance_valid(_button):
		_button.text = tr("BACK")
		_button.custom_minimum_size = Vector2(160, 40)
		_button.grab_focus()

	if is_instance_valid(_rich_text_label):
		_rich_text_label.text = (
			_rich_text_label
			. text
			. replace("CORE_CONTRIBUTORS", tr("CORE_CONTRIBUTORS"))
			. replace("ASSETS", tr("ASSETS"))
		)

		_rich_text_label.text += "\n\n" + _music_credits() + "\n\n" + _voice_credits() + "[/center]"
		_rich_text_label.meta_clicked.connect(_on_credit_link)


func _music_credits():
	return (
		"[u]"
		+ tr("Music")
		+ "[/u]\n"
		+ "[url=https://opengameart.org/content/nebulous]Nebulous[/url]\n"
		+ "music by Joe Baxter-Webb (BossLevel VGM) · CC BY 3.0\n\n"
		+ "[url=https://opengameart.org/content/rock-war-music-marching-industrial]"
		+ "Rock of War[/url] — p0ss · CC BY-SA 3.0\n\n"
		+ "[url=https://opengameart.org/content/perpetual-tension]Perpetual Tension[/url]\n"
		+ "[url=https://opengameart.org/content/the-recon-mission]The Recon Mission[/url]\n"
		+ "Zander Noriega · CC BY 3.0\n\n"
		+ "[url=https://creativecommons.org/licenses/by/3.0/]CC BY 3.0[/url] · "
		+ "[url=https://creativecommons.org/licenses/by-sa/3.0/]CC BY-SA 3.0[/url]\n"
		+ tr("Music edits: adaptive stems, volume, fades and Ogg encoding.")
	)


func _voice_credits():
	return (
		"[u]"
		+ tr("Synthetic battle voices")
		+ "[/u]\n"
		+ "[url=https://huggingface.co/hexgrad/Kokoro-82M]Kokoro-82M[/url] · hexgrad\n"
		+ tr("Male voice styles · Apache 2.0 model")
		+ "\n"
		+ "[url=https://github.com/thewh1teagle/kokoro-onnx]kokoro-onnx[/url] · MIT\n"
		+ "[url=https://github.com/resemble-ai/chatterbox]Chatterbox TTS[/url] · Resemble AI · MIT\n"
		+ "[url=https://huggingface.co/kyutai/tts-voices]Unmute voice donations[/url] · "
		+ "Kyutai · CC0\n"
		+ "Christophe Veaux, Junichi Yamagishi, Kirsten MacDonald · CSTR, Edinburgh\n"
		+ "[url=https://doi.org/10.7488/ds/2645]VCTK 0.92[/url] · "
		+ "[url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url]\n"
		+ tr("Original dialogue, unit and robot voices, equalization and Ogg encoding.")
	)


func _on_credit_link(meta):
	OS.shell_open(str(meta))


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_button_pressed()


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
