extends RefCounted

const Config = preload("res://source/match/programs/llm/ProviderConfig.gd")
var _session = {}


func available():
	return (
		ClassDB.class_exists("RtsCredentialStore")
		and ClassDB.instantiate("RtsCredentialStore").available()
	)


func read_key(config):
	if not Config.validate(config).is_empty():
		return {
			"ok": false, "found": false, "secret": "", "error": "Configure a valid provider first."
		}
	var id = Config.account(config)
	if _session.has(id):
		return {"ok": true, "found": true, "secret": _session[id], "error": ""}
	if not available():
		return {"ok": true, "found": false, "secret": "", "error": ""}
	return ClassDB.instantiate("RtsCredentialStore").read_secret(id)


func set_key(config, secret, remember = false):
	if not Config.validate(config).is_empty():
		return {"ok": false, "error": "Configure a valid provider first."}
	if (
		secret.is_empty()
		or secret.to_utf8_buffer().size() > 4096
		or secret.contains("\n")
		or secret.contains("\r")
		or secret.to_utf8_buffer().has(0)
	):
		return {"ok": false, "error": "Enter a valid API key without line breaks."}
	var id = Config.account(config)
	if remember:
		if not available():
			return {
				"ok": false,
				"error": "Platform credential storage is unavailable. Use a session key."
			}
		var result = ClassDB.instantiate("RtsCredentialStore").write_secret(id, secret)
		if not result.ok:
			return {"ok": false, "error": result.error}
	_session[id] = secret
	return {"ok": true, "error": ""}


func forget(config):
	if not Config.validate(config).is_empty():
		return {"ok": false, "error": "Configure a valid provider first."}
	var id = Config.account(config)
	if available():
		var result = ClassDB.instantiate("RtsCredentialStore").erase_secret(id)
		if not result.ok:
			return {"ok": false, "error": result.error}
	_session.erase(id)
	return {"ok": true, "error": ""}


func clear_session():
	_session.clear()
