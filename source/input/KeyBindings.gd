extends RefCounted

const VERSION = 5
const MODIFIERS = KEY_MASK_SHIFT | KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_META
const MODIFIER_KEYS = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
const RESERVED = [KEY_BACKTAB, KEY_ENTER, KEY_KP_ENTER]
const SPECIAL = [
	KEY_TAB,
	KEY_ESCAPE,
	KEY_SPACE,
	KEY_BACKSPACE,
	KEY_DELETE,
	KEY_INSERT,
	KEY_HOME,
	KEY_END,
	KEY_PAGEUP,
	KEY_PAGEDOWN,
	KEY_LEFT,
	KEY_RIGHT,
	KEY_UP,
	KEY_DOWN,
	KEY_KP_0,
	KEY_KP_1,
	KEY_KP_2,
	KEY_KP_3,
	KEY_KP_4,
	KEY_KP_5,
	KEY_KP_6,
	KEY_KP_7,
	KEY_KP_8,
	KEY_KP_9,
	KEY_KP_ADD,
	KEY_KP_SUBTRACT,
	KEY_KP_MULTIPLY,
	KEY_KP_DIVIDE,
	KEY_KP_PERIOD
]
const CORE = {
	"commander_support": ["Battle", "Commander support", KEY_F6],
	"pause_battle": ["Battle", "Tactical pause", KEY_SPACE],
	"attack_move": ["Battle", "Attack move", KEY_F],
	"move_order": ["Battle", "Move to point", KEY_M],
	"attack_target": ["Battle", "Attack target / attack move", KEY_A],
	"force_attack": ["Battle", "Force attack", KEY_A | KEY_MASK_CTRL],
	"patrol_order": ["Battle", "Patrol", KEY_P],
	"cycle_subgroup": ["Groups", "Cycle selected unit classes", KEY_TAB],
	"toggle_match_menu": ["Battle", "Battle menu / cancel assignment", KEY_ESCAPE],
	"rotate_structure": ["Battle", "Rotate building", KEY_R],
	"quicksave_battle": ["Battle", "Quicksave", KEY_F5],
	"quickload_battle": ["Battle", "Open quickload", KEY_F9],
	"shift_selecting": ["Battle", "Add selection / queue orders (hold)", KEY_SHIFT],
	"move_map_up": ["Camera", "Pan up", KEY_UP],
	"move_map_down": ["Camera", "Pan down", KEY_DOWN],
	"move_map_left": ["Camera", "Pan left", KEY_LEFT],
	"move_map_right": ["Camera", "Pan right", KEY_RIGHT],
	"rotate_map_clockwise": ["Camera", "Rotate clockwise", KEY_Q],
	"rotate_map_counterclockwise": ["Camera", "Rotate counterclockwise", KEY_E]
}


static func definitions():
	var result = CORE.duplicate(true)
	for index in range(1, 10):
		result["unit_groups_set_%d" % index] = [
			"Groups", "Assign group %d" % index, KEY_0 + index | KEY_MASK_CTRL
		]
		result["unit_groups_access_%d" % index] = [
			"Groups", "Select group %d" % index, KEY_0 + index
		]
	return result


static func defaults():
	var keys = {}
	var entries = definitions()
	for action in entries:
		keys[action] = entries[action][2]
	return {"version": VERSION, "keys": keys}


static func normalize(record):
	var fallback = defaults()
	if (
		record is Dictionary
		and typeof(record.get("version")) == TYPE_INT
		and record.get("version") == 4
		and record.get("keys") is Dictionary
	):
		var previous = record.duplicate(true)
		if (
			previous.keys.size() == fallback.keys.size() - 1
			and not previous.keys.has("commander_support")
		):
			var candidates = [KEY_F6, KEY_F7, KEY_F8, KEY_F10, KEY_F11, KEY_F12]
			# Preserve every valid old binding even if all spare function keys are used.
			for key in range(KEY_F1, KEY_F12 + 1):
				for modifier in [
					KEY_MASK_CTRL, KEY_MASK_SHIFT, KEY_MASK_ALT, KEY_MASK_CTRL | KEY_MASK_SHIFT
				]:
					candidates.append(key | modifier)
			for candidate in candidates:
				if (
					candidate not in previous.keys.values()
					and problem("commander_support", candidate, previous.keys).is_empty()
				):
					previous.keys.commander_support = candidate
					previous.version = VERSION
					record = previous
					break
	if (
		not record is Dictionary
		or typeof(record.get("version")) != TYPE_INT
		or record.get("version") != VERSION
		or not record.get("keys") is Dictionary
	):
		return fallback
	# Treat a corrupt or internally conflicting profile atomically. Mixing partial
	# defaults with user keys can silently assign the same key to two commands.
	var keys = record.keys.duplicate(true)
	if keys.size() != fallback.keys.size():
		return fallback
	for action in fallback.keys:
		if not keys.has(action) or not problem(action, keys[action], keys).is_empty():
			return fallback
	return {"version": VERSION, "keys": keys.duplicate(true)}


static func problem(action, code, keys):
	if not action in definitions() or not code is int:
		return "Invalid key binding."
	var key = code & ~MODIFIERS
	if (
		code < 0
		or (
			key not in SPECIAL
			and key not in MODIFIER_KEYS
			and not (key >= KEY_F1 and key <= KEY_F12)
			and not (key >= 32 and key <= 96)
		)
	):
		return "Choose a letter, number, function key or navigation key."
	if key in MODIFIER_KEYS and (action != "shift_selecting" or code != key):
		return "Use a key with the modifier, such as Ctrl+K."
	if (
		key in RESERVED
		or (key == KEY_TAB and action != "cycle_subgroup")
		or (key == KEY_ESCAPE and action != "toggle_match_menu")
	):
		return "This key is reserved for navigating or closing dialogs."
	if (
		(code & KEY_MASK_META and key in [KEY_Q, KEY_W, KEY_M, KEY_H])
		or (code & KEY_MASK_ALT and key == KEY_F4)
	):
		return "This shortcut is reserved by the operating system."
	for reserved_action in [
		"toggle_god_mode",
		"toggle_diagnostic_mode",
		"toggle_frame_incrementer",
		"god_mode_delete_units"
	]:
		for event in InputMap.action_get_events(reserved_action):
			if event is InputEventKey and from_event(event) == code:
				return "This key is reserved for debug controls."
	for other in definitions():
		if other != action and keys.get(other) is int and keys.get(other) == code:
			return "Already used by %s. Change that binding first." % definitions()[other][1]
	return ""


static func from_event(event):
	var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key in MODIFIER_KEYS:
		return key
	return (
		key
		| (KEY_MASK_CTRL if event.ctrl_pressed else 0)
		| (KEY_MASK_SHIFT if event.shift_pressed else 0)
		| (KEY_MASK_ALT if event.alt_pressed else 0)
		| (KEY_MASK_META if event.meta_pressed else 0)
	)


static func event_for(code):
	var event = InputEventKey.new()
	event.physical_keycode = code & ~MODIFIERS
	event.ctrl_pressed = bool(code & KEY_MASK_CTRL)
	event.shift_pressed = bool(code & KEY_MASK_SHIFT)
	event.alt_pressed = bool(code & KEY_MASK_ALT)
	event.meta_pressed = bool(code & KEY_MASK_META)
	return event


static func apply(record):
	for action in record.keys:
		var code = record.keys[action]
		var current = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		if current.size() == 1 and current[0] is InputEventKey and from_event(current[0]) == code:
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		# A held old key must not leave a camera/action latched after editing.
		Input.action_release(action)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event_for(code))


static func label(action):
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return describe(from_event(events[0]))


static func describe(code):
	var result = ""
	for pair in [
		[KEY_MASK_CTRL, "Ctrl+"],
		[KEY_MASK_ALT, "Alt+"],
		[KEY_MASK_SHIFT, "Shift+"],
		[KEY_MASK_META, "Cmd+" if OS.get_name() == "macOS" else "Meta+"]
	]:
		if code & pair[0]:
			result += pair[1]
	var physical = code & ~MODIFIERS
	var localized = (
		DisplayServer.keyboard_get_keycode_from_physical(physical)
		if DisplayServer.get_name() != "headless"
		else physical
	)
	return result + OS.get_keycode_string(localized if localized != 0 else physical)


static func hint(title, action):
	return "%s [%s]" % [title, label(action)]


static func pressed(event, action):
	if event.is_action_pressed(action, false, true):
		return true
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	return _queue_chord_matches(from_event(event), action)


static func _queue_chord_matches(code, action):
	if not held("shift_selecting"):
		return false
	# An explicitly assigned chord always wins over the queue modifier fallback.
	for other in definitions():
		if from_event(InputMap.action_get_events(other)[0]) == code:
			return false
	var queue_code = from_event(InputMap.action_get_events("shift_selecting")[0])
	var mask = queue_code & MODIFIERS
	for pair in [
		[KEY_SHIFT, KEY_MASK_SHIFT],
		[KEY_CTRL, KEY_MASK_CTRL],
		[KEY_ALT, KEY_MASK_ALT],
		[KEY_META, KEY_MASK_META]
	]:
		if queue_code == pair[0]:
			mask = pair[1]
	var wanted = from_event(InputMap.action_get_events(action)[0])
	# Keep modifiers required by the command itself.
	return mask != 0 and (code & ~(mask & ~wanted)) == wanted


static func held(action):
	var code = from_event(InputMap.action_get_events(action)[0])
	var key = code & ~MODIFIERS
	if not Input.is_physical_key_pressed(key):
		return false
	# Poll physical modifiers too: InputMap retains the modifiers from key-down
	# when Ctrl/Shift is pressed or released later while that key remains held.
	if action == "shift_selecting" and key in MODIFIER_KEYS:
		return true
	var actual = key
	for pair in [
		[KEY_SHIFT, KEY_MASK_SHIFT],
		[KEY_CTRL, KEY_MASK_CTRL],
		[KEY_ALT, KEY_MASK_ALT],
		[KEY_META, KEY_MASK_META]
	]:
		if Input.is_physical_key_pressed(pair[0]):
			actual |= pair[1]
	if action == "shift_selecting":
		return (actual & code) == code
	return actual == code or _queue_chord_matches(actual, action)


static func axis(negative, positive):
	return float(held(positive)) - float(held(negative))
