extends RefCounted

const PATH = "res://assets/audio/campaign/narration.json"
const Campaigns = preload("res://source/match/campaign/CampaignCatalog.gd")
const BRIEFINGS = "res://assets/audio/campaign/briefings.json"
const CONVERSATIONS = "res://assets/audio/campaign/conversations.json"
const Cache = preload("res://source/utils/RuntimeCache.gd")
const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")


static func lines():
	var cache = Cache.bucket("campaign_narration")
	if not cache.has("lines"):
		cache.narrators = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		cache.lines = cache.narrators.duplicate(true)
		if FileAccess.file_exists(CONVERSATIONS):
			cache.lines.merge(JSON.parse_string(FileAccess.get_file_as_string(CONVERSATIONS)), true)
		if FileAccess.file_exists(BRIEFINGS):
			var briefings = JSON.parse_string(FileAccess.get_file_as_string(BRIEFINGS))
			for mission in briefings:
				var faction = Campaigns.operations()[mission].faction
				var speaker = {
					"bastion": {"en": "Field Marshal Aegis", "zh_CN": "元帅埃吉斯"},
					"helix": {"en": "Spectre Nyx", "zh_CN": "幽灵尼克斯"},
					"frontier": {"en": "Pathfinder Rook", "zh_CN": "探路者鲁克"}
				}[faction]
				var dialogue = []
				for segment in briefings[mission].segments:
					dialogue.append(
						{
							"id": segment.id,
							"speaker": speaker,
							"en": segment.en,
							"zh_CN": segment.zh,
							"voice": segment.stream,
							"duration": segment.duration,
							"portrait": Artwork.portrait_path(Artwork.COMMANDERS[faction])
						}
					)
				cache.lines[mission + ".briefing"] = {"dialogue": dialogue}
	return cache.lines


static func ids(mission):
	return lines().keys().filter(
		func(key): return key.begins_with(mission + ".") or key.begins_with("common.")
	)


static func _narrator_record(id, language = "en"):
	if not single_narrator(id):
		return {}
	var locale = "zh_CN" if language == "zh_CN" else "en"
	var path = "res://assets/audio/campaign/%s_en.wav" % id.replace(".", "_")
	return {
		"id": id,
		"speaker": "堡垒指挥部" if locale == "zh_CN" else "Bastion Command",
		"text": Cache.bucket("campaign_narration").narrators[id][locale],
		"stream": path
	}


# A cue either has a single Bastion Command narrator or an ordered dialogue array.
# Dialogue voices are English in both locales; captions and speaker names localize.
static func scene(id, language = "en"):
	if not lines().has(id):
		return []
	var entry = lines()[id]
	if not entry.has("dialogue"):
		return [_narrator_record(id, language)]
	var locale = "zh_CN" if language == "zh_CN" else "en"
	var result = []
	for line in entry.dialogue:
		result.append(
			{
				"id": line.id,
				"speaker": line.speaker[locale],
				"text": line[locale],
				"stream": line.voice,
				"portrait": line.get("portrait", ""),
				"duration": line.get("duration", -1.0)
			}
		)
	return result


static func record(id, language = "en"):
	for cue in lines():
		for line in scene(cue, language):
			if line.id == id:
				return line
	return _narrator_record(id, language) if single_narrator(id) else {}


static func single_narrator(id):
	lines()
	return Cache.bucket("campaign_narration").narrators.has(id)


static func missions():
	return Campaigns.operations().keys().filter(func(id): return lines().has(id + ".intro"))


static func valid_state(data, mission):
	if not data is Dictionary or not data.get("seen") is Array:
		return false
	var allowed = ids(mission)
	var heard = []
	for cue in data.seen:
		if cue not in allowed or cue in heard:
			return false
		heard.append(cue)
	if data.size() != 3 or not data.get("pending") is Array or not data.get("active") is Dictionary:
		return false
	var queued = []
	for cue in data.pending:
		if cue not in heard or cue in queued:
			return false
		queued.append(cue)
	var active = data.active
	if active.is_empty():
		return true
	if active.size() != 4 or active.get("cue") not in heard or active.cue in queued:
		return false
	var sequence = scene(active.cue)
	if (
		not active.get("line") is String
		or (
			active.line not in sequence.map(func(line): return line.id)
			and not (active.line == active.cue and single_narrator(active.line))
		)
	):
		return false
	for key in ["remaining", "position"]:
		var value = active.get(key)
		if (
			not (value is int or value is float)
			or not is_finite(value)
			or value < 0
			or value > 3600
		):
			return false
	return true
