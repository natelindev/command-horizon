extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	create_timer(180).timeout.connect(func(): quit(1))
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "menu_motion": false, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	var artwork = load("res://source/main-menu/ArtworkCatalog.gd")
	# Opening a menu must not alter deterministic gameplay randomness.
	seed(1729)
	var expected = randi()
	seed(1729)
	var previous = artwork.next_background()
	_check(randi() == expected, "Menu art consumed simulation randomness")
	var seen = {}
	for index in 250:
		var chosen = artwork.next_background()
		_check(chosen != previous, "Consecutive menu artworks repeated")
		_check(load(chosen) is Texture2D, "Missing background: " + chosen)
		seen[chosen] = true
		previous = chosen
	_check(seen.size() == artwork.BACKGROUNDS.size(), "Gallery omitted a background")
	for speaker in artwork.SPEAKERS:
		_check(load(artwork.portrait_path(speaker)) is Texture2D, "Missing portrait: " + speaker)
	var factions = load("res://source/match/FactionCatalog.gd")
	for faction in artwork.COMMANDERS:
		_check(
			factions.portrait(faction, "Hero") == artwork.commander(faction),
			"Hero selection retained different art: " + faction
		)
	var narration = load("res://source/match/campaign/CampaignNarration.gd")
	for cue in narration.lines():
		for line in narration.scene(cue):
			if narration.single_narrator(cue):
				continue
			var portrait = line.get("portrait", "")
			_check(
				portrait.contains("/portraits/") and portrait.ends_with(".png"),
				"Dialogue retained missing or placeholder art: " + line.id
			)
			_check(ResourceLoader.exists(portrait), "Missing dialogue art: " + portrait)
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	root.add_child(backdrop)
	var first = backdrop.artwork_path
	await _frames(3)
	_check(backdrop.artwork_path == first, "Art changed while menu stayed open")
	backdrop.hide()
	backdrop.show()
	_check(backdrop.artwork_path != first, "Reopened menu did not choose new art")
	backdrop.queue_free()
	await _frames(2)
	await _skirmish("bastion")
	var unit = _units(game._get_human_player(), "Tank")[0]
	unit.get_node("Selection").select()
	var hud = game.hud
	for already_paused in [false, true]:
		paused = already_paused
		hud._open_menu()
		var picture = hud._overlay.find_child("PauseArtwork", true, false)
		_check(picture != null and paused, "Pause menu has no art or did not pause")
		first = picture.artwork_path
		await _frames(5)
		_check(picture.artwork_path == first, "Pause art changed while visible")
		hud._close_menu()
		_check(paused == already_paused, "Closing pause menu changed prior pause state")
		_check(unit.is_in_group("selected_units"), "Pause menu lost selected unit")
		hud._open_menu()
		picture = hud._overlay.find_child("PauseArtwork", true, false)
		_check(picture.artwork_path != first, "Reopening pause repeated artwork")
		hud._close_menu()
	paused = false
	game.queue_free()
	await _frames(4)
	# Older match scenes use the separate CanvasLayer menu.
	var legacy = load("res://source/match/Menu.tscn").instantiate()
	root.add_child(legacy)
	legacy._toggle()
	first = legacy.get_node("PauseArtwork").artwork_path
	legacy._on_resume_button_pressed()
	_check(not paused and not legacy.visible, "Legacy resume failed")
	legacy._toggle()
	_check(legacy.get_node("PauseArtwork").artwork_path != first, "Legacy art did not refresh")
	legacy._on_resume_button_pressed()
	legacy.queue_free()
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Menu artwork regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
