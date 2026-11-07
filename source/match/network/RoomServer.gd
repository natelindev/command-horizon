extends Node

## The directory owns waiting rooms. Each active match owns its own scene tree,
## simulation clock and ENet port in an ordinary headless dedicated host.
const Link = preload("res://source/match/network/RoomLink.gd")
const Session = preload("res://source/match/network/NetworkSession.gd")
const MAX_NAME = 32
var port = Session.PORT
var max_rooms = 4
var link = Link.new()
var rooms = {}
var browsers = {}
var _next_id = 1
var _next_port_offset = 0
var _next_worker_check = 0
var _worker_pack = ""


func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--max-rooms="):
			max_rooms = arg.trim_prefix("--max-rooms=").to_int()
		elif arg.begins_with("--room-pack="):
			_worker_pack = arg.trim_prefix("--room-pack=")
	if port < 1024 or max_rooms < 1 or max_rooms > 16 or port + max_rooms > 65535:
		push_error("Choose 1–16 rooms and a port with space for all room ports.")
		get_tree().quit(1)
		return
	add_child(link)
	link.received.connect(_request)
	link.departed.connect(_disconnect)
	if not link.listen(port):
		push_error("Room server could not bind UDP port %d." % port)
		get_tree().quit(1)
		return
	print(
		"Room server listening on UDP %d (battle ports %d–%d)" % [port, port + 1, port + max_rooms]
	)


func _request(sender: int, packet: Dictionary):
	if packet.type == "worker":
		_worker_ready(sender, packet)
		return
	if packet.type == "browse":
		browsers[sender] = true
		_snapshot(sender)
		return
	if not browsers.has(sender):
		return
	var room = _membership(sender)
	match packet.type:
		"create":
			_create(sender, room, packet)
		"join":
			if not packet.get("id") is int:
				return
			var target = rooms.get(packet.get("id"))
			if (
				room != null
				or target == null
				or target.state != "Waiting"
				or target.members.size() >= target.capacity
			):
				_error(sender, "This room is unavailable.")
				return
			target.members.append(sender)
			_publish()
		"leave":
			if room != null and room.state != "In battle":
				_leave(sender, room)
		"start":
			if (
				room == null
				or room.state != "Waiting"
				or room.members[0] != sender
				or room.members.size() != room.capacity
			):
				_error(sender, "Only the room owner can start a full room.")
				return
			_launch(room)


func _create(sender: int, current, packet: Dictionary):
	if current != null or rooms.size() >= max_rooms:
		_error(sender, "Cannot create another room.")
		return
	if not packet.get("name") is String or packet.get("capacity") not in [2, 4]:
		_error(sender, "Choose a room name and battle format.")
		return
	var title = packet.name.strip_edges()
	if title.is_empty() or title.length() > MAX_NAME or _has_control(title):
		_error(sender, "Choose a room name of 1 to 32 characters.")
		return
	var id = _next_id
	_next_id += 1
	rooms[id] = {
		"id": id,
		"name": title,
		"capacity": packet.capacity,
		"members": [sender],
		"state": "Waiting",
		"pid": -1,
		"port": 0,
		"key": "",
		"deadline": 0
	}
	_publish()


func _has_control(title: String) -> bool:
	for i in title.length():
		if title.unicode_at(i) < 32 or title.unicode_at(i) == 127:
			return true
	return false


func _membership(sender: int):
	for room in rooms.values():
		if room.state != "In battle" and sender in room.members:
			return room
	return null


func _snapshot(sender: int):
	var listing = []
	var mine = 0
	var owner = false
	for room in rooms.values():
		listing.append(
			{
				"id": room.id,
				"name": room.name,
				"capacity": room.capacity,
				"count": room.members.size(),
				"state": room.state
			}
		)
		if room.state != "In battle" and sender in room.members:
			mine = room.id
			owner = room.members[0] == sender
	link.send(sender, {"type": "rooms", "rooms": listing, "mine": mine, "owner": owner})


func _publish():
	for id in browsers:
		_snapshot(id)


func _error(id: int, reason: String):
	link.send(id, {"type": "error", "reason": reason})


func _leave(sender: int, room: Dictionary):
	if room.state == "Starting":
		_stop_worker(room)
	room.members.erase(sender)
	if room.members.is_empty():
		rooms.erase(room.id)
	_publish()


func _disconnect(id: int):
	browsers.erase(id)
	var room = _membership(id)
	if room != null:
		_leave(id, room)


func _launch(room: Dictionary):
	var used = rooms.values().map(func(other): return other.port)
	for _index in max_rooms:
		var candidate = port + 1 + _next_port_offset
		_next_port_offset = (_next_port_offset + 1) % max_rooms
		if candidate not in used:
			room.port = candidate
			break
	room.key = Crypto.new().generate_random_bytes(32).hex_encode()
	room.state = "Starting"
	room.deadline = Time.get_ticks_msec() + 30000
	var args = PackedStringArray(
		[
			"--headless",
			"--max-fps",
			"60",
			"--log-file",
			ProjectSettings.globalize_path("user://logs/battle-port-%d.log" % room.port)
		]
	)
	if not _worker_pack.is_empty():
		args.append_array(["--main-pack", _worker_pack])
	elif OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(
		[
			"--",
			"--dedicated-server",
			"--port=%d" % room.port,
			"--mode=" + ("2v2" if room.capacity == 4 else "1v1"),
			"--timeout=90",
			"--room-lobby=%d" % port,
			"--room-key=" + room.key
		]
	)
	for arg in OS.get_cmdline_user_args():
		if (
			arg
			in [
				"--enable-native-kernels",
				"--disable-native-kernels",
				"--native-unit-state",
				"--native-crowd-runtime"
			]
		):
			args.append(arg)
	room.pid = OS.create_process(OS.get_executable_path(), args)
	if room.pid < 0:
		_worker_failed(room)
	else:
		_publish()


func _worker_ready(sender: int, packet: Dictionary):
	for room in rooms.values():
		if room.state != "Starting" or packet.get("key") != room.key:
			continue
		link.peer.get_peer(sender).set_timeout(32, 60000, 120000)
		print("Room %d launching on UDP %d" % [room.id, room.port])
		room.state = "In battle"
		for slot in room.members.size():
			link.send(
				room.members[slot],
				{"type": "battle", "port": room.port, "ticket": Session.room_ticket(room.key, slot)}
			)
		room.key = ""
		_publish()
		return


func _process(_delta):
	var now = Time.get_ticks_msec()
	if now < _next_worker_check:
		return
	_next_worker_check = now + 250
	for room in rooms.values():
		if room.pid < 0:
			continue
		if not OS.is_process_running(room.pid):
			print("Room %d worker exited (code %d)" % [room.id, OS.get_process_exit_code(room.pid)])
			room.pid = -1
			if room.state == "Starting":
				_worker_failed(room)
			else:
				rooms.erase(room.id)
				_publish()
		elif room.state == "Starting" and now > room.deadline:
			_worker_failed(room)


func _worker_failed(room: Dictionary):
	_stop_worker(room)
	_publish()
	for member in room.members:
		_error(member, "Battle server failed to start. Try again.")


func _stop_worker(room: Dictionary):
	if room.pid > 0 and OS.is_process_running(room.pid):
		OS.kill(room.pid)
	room.pid = -1
	room.port = 0
	room.key = ""
	room.state = "Waiting"


func _exit_tree():
	for room in rooms.values():
		_stop_worker(room)
