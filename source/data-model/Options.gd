extends Resource

enum Screen { FULL = 0, WINDOW = 1 }

const Bindings = preload("res://source/input/KeyBindings.gd")
const DEFAULTS = {
	"screen": Screen.FULL,
	"mouse_restricted": false,
	"master_volume": 0.8,
	"voice_volume": 0.8,
	"effects_volume": 0.75,
	"ambience_volume": 0.55,
	"music_volume": 0.5,
	"language": "en",
	"subtitles": false,
	"ownership_symbols": true,
	"subtitle_size": 22,
	"interface_scale": 1.0,
	"camera_speed": 1.0,
	"zoom_speed": 1.0,
	"edge_scrolling": true,
	"reduced_flashes": false,
	"key_bindings": {},
	"graphics_shadows": true,
	"graphics_ao": true,
	"graphics_glow": true,
	"graphics_fog": true,
	"graphics_dof": false,
	"graphics_msaa": 1,
	"graphics_ground_detail": true,
	"battlefield_wear": true,
	"area_lighting": false,
	"hud_motion": true,
	"hdr_output": false,
	"hdr_peak_nits": 0.0,
	"hdr_paper_white": 0.0,
	"time_of_day": 0,
	"day_cycle": true,
	"weather": 0,
	"weather_particles": true,
	"living_world": true,
	"menu_motion": true
}
@export var screen: Screen = Screen.FULL
@export var mouse_restricted = false
@export var master_volume = 0.8
@export var voice_volume = 0.8
@export var effects_volume = 0.75
@export var ambience_volume = 0.55
@export var music_volume = 0.5
@export var language = "zh_CN" if OS.get_locale_language() == "zh" else "en"
@export var subtitles = false
@export var ownership_symbols = true
@export var subtitle_size = 22
@export var interface_scale = 1.0
@export var camera_speed = 1.0
@export var zoom_speed = 1.0
@export var edge_scrolling = true
@export var reduced_flashes = false
@export var key_bindings = {}
@export var graphics_shadows = true
@export var graphics_ao = true
@export var graphics_glow = true
@export var graphics_fog = true
@export var graphics_dof = false
@export var graphics_msaa = 1
@export var graphics_ground_detail = true
@export var battlefield_wear = true
@export var area_lighting = false
@export var hud_motion = true
@export var hdr_output = false
@export var hdr_peak_nits = 0.0
@export var hdr_paper_white = 0.0
@export var time_of_day = 0
@export var day_cycle = true
@export var weather = 0
@export var weather_particles = true
@export var living_world = true
@export var menu_motion = true
var _display_target = DisplayServer.WINDOW_MODE_WINDOWED
var _display_until = 0
var _display_next = 0


func capture():
	var result = {}
	for key in DEFAULTS:
		result[key] = get(key).duplicate(true) if get(key) is Dictionary else get(key)
	return result


func restore(values):
	for key in DEFAULTS:
		var value = values.get(key, DEFAULTS[key])
		if typeof(value) == typeof(DEFAULTS[key]) or (value is int and DEFAULTS[key] is float):
			set(key, value.duplicate(true) if value is Dictionary else value)
		else:
			set(key, DEFAULTS[key])
	apply()


func apply():
	if language not in ["en", "zh_CN"]:
		language = "en"
	if TranslationServer.get_locale() != language:
		TranslationServer.set_locale(language)
	hdr_peak_nits = _bounded(hdr_peak_nits, 0, 2000, 0)
	hdr_paper_white = _bounded(hdr_paper_white, 0, 400, 0)
	apply_hdr()
	graphics_msaa = clampi(graphics_msaa, 0, 2)
	time_of_day = clampi(time_of_day, 0, 3)
	weather = clampi(weather, 0, 4)
	key_bindings = Bindings.normalize(key_bindings)
	Bindings.apply(key_bindings)
	if screen not in [Screen.FULL, Screen.WINDOW]:
		screen = Screen.FULL
	master_volume = _bounded(master_volume, 0, 1, 0.8)
	voice_volume = _bounded(voice_volume, 0, 1, 0.8)
	effects_volume = _bounded(effects_volume, 0, 1, 0.75)
	ambience_volume = _bounded(ambience_volume, 0, 1, 0.55)
	music_volume = _bounded(music_volume, 0, 1, 0.5)
	if subtitle_size not in [18, 22, 26]:
		subtitle_size = 22
	if interface_scale not in [1.0, 1.25, 1.5]:
		interface_scale = 1.0
	camera_speed = _bounded(camera_speed, 0.5, 2.0, 1.0)
	zoom_speed = _bounded(zoom_speed, 0.5, 3.0, 1.0)
	var mode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if screen == Screen.FULL
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	request_display(mode)
	Input.set_mouse_mode(
		Input.MOUSE_MODE_CONFINED if mouse_restricted else Input.MOUSE_MODE_VISIBLE
	)
	var voice = _audio_bus("Voice")
	var effects = _audio_bus("Effects")
	var ambience = _audio_bus("Ambience")
	var music = _audio_bus("Music")
	_volume(AudioServer.get_bus_index("Master"), master_volume)
	_volume(voice, voice_volume)
	_volume(effects, effects_volume)
	_volume(ambience, ambience_volume)
	_volume(music, music_volume)
	_limiter(ambience, -9.0)
	_limiter(effects, -4.0)
	_speech_clarity(voice)
	_limiter(AudioServer.get_bus_index("Master"), -1.0)
	emit_changed()


func request_display(mode):
	_display_target = mode
	_display_until = Time.get_ticks_msec() + 5000
	_display_next = 0
	settle_display()


func display_mode():
	var current = DisplayServer.window_get_mode()
	if (
		_display_target == DisplayServer.WINDOW_MODE_WINDOWED
		and current == DisplayServer.WINDOW_MODE_MAXIMIZED
	):
		return current
	return _display_target if Time.get_ticks_msec() < _display_until else current


func settle_display():
	# Native fullscreen transitions may ignore a second request until their animation ends.
	var now = Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless" or now > _display_until or now < _display_next:
		return
	_display_next = now + 150
	var current = DisplayServer.window_get_mode()
	var already_windowed = (
		_display_target == DisplayServer.WINDOW_MODE_WINDOWED
		and current in [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED]
	)
	if current != _display_target and not already_windowed:
		DisplayServer.window_set_mode(_display_target)


func persist(path):
	var temporary = path + ".pending.tres"
	var result = ResourceSaver.save(self, temporary)
	if result != OK:
		return result
	result = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if result != OK:
		DirAccess.remove_absolute(temporary)
	return result


func _volume(bus, value):
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(bus, value == 0)


func _bounded(value, low, high, fallback):
	return clampf(value, low, high) if is_finite(value) else fallback


func selection_modifier_pressed():
	return Bindings.held("shift_selecting")


func _audio_bus(title):
	var index = AudioServer.get_bus_index(title)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, title)
		AudioServer.set_bus_send(index, "Master")
	return index


func _limiter(bus, ceiling):
	for index in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, index) is AudioEffectHardLimiter:
			return
	var limiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = ceiling
	AudioServer.add_bus_effect(bus, limiter)


func _speech_clarity(bus):
	# Full-band speech: a radio band-pass muffles words and makes every speaker sound alike.
	# Clips are loudness-matched offline, so the chain only removes rumble and catches peaks.
	if (
		AudioServer.get_bus_effect_count(bus) == 3
		and AudioServer.get_bus_effect(bus, 0) is AudioEffectHighPassFilter
		and AudioServer.get_bus_effect(bus, 1) is AudioEffectCompressor
		and AudioServer.get_bus_effect(bus, 2) is AudioEffectHardLimiter
	):
		return
	while AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.remove_bus_effect(bus, 0)
	var high_pass = AudioEffectHighPassFilter.new()
	high_pass.cutoff_hz = 85.0
	AudioServer.add_bus_effect(bus, high_pass)
	var compressor = AudioEffectCompressor.new()
	compressor.threshold = -14.0
	compressor.ratio = 2.0
	compressor.attack_us = 5000.0
	compressor.release_ms = 120.0
	AudioServer.add_bus_effect(bus, compressor)
	var limiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(bus, limiter)


func hdr_supported():
	return (
		DisplayServer.get_name() != "headless"
		and DisplayServer.has_feature(DisplayServer.FEATURE_HDR_OUTPUT)
		and DisplayServer.window_is_hdr_output_supported()
	)


func apply_hdr():
	if DisplayServer.get_name() == "headless":
		return
	# Request persists when moving between SDR/HDR displays; the engine handles fallback.
	if DisplayServer.has_feature(DisplayServer.FEATURE_HDR_OUTPUT):
		DisplayServer.window_request_hdr_output(hdr_output)
		if OS.get_name() in ["Windows", "macOS"]:
			DisplayServer.window_set_hdr_output_max_luminance(
				hdr_peak_nits if hdr_peak_nits > 0 else -1
			)
		if OS.get_name() == "Windows":
			DisplayServer.window_set_hdr_output_reference_luminance(
				hdr_paper_white if hdr_paper_white > 0 else -1
			)
