extends Node

## Separate reliable ENet channel for the room directory. Battle traffic stays on NetworkSession.
signal received(sender: int, packet: Dictionary)
signal departed(id: int)
signal lost
signal connected

const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
const MAX_PACKET = 8192
var peer: ENetMultiplayerPeer
var _deadline = 0
var _server = false
var _budgets = {}


func listen(port: int) -> bool:
	_server = true
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(port, 128, 1) != OK:
		close()
		return false
	peer.peer_disconnected.connect(_departed)
	return true


func dial(address: String, port: int) -> bool:
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(address, port, 1) != OK:
		close()
		return false
	_deadline = Time.get_ticks_msec() + 8000
	return true


func send(id: int, packet: Dictionary):
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(id)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.put_packet(JSON.stringify(packet).to_utf8_buffer())


func _departed(id: int):
	_budgets.erase(id)
	departed.emit(id)


func _process(_delta):
	if peer == null:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.poll()
	if peer == null:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		if (
			peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
			or Time.get_ticks_msec() >= _deadline
		):
			close()
			lost.emit()
		return
	if not _server and _deadline > 0:
		_deadline = 0
		connected.emit()
	for _index in 128:
		if peer == null or peer.get_available_packet_count() == 0:
			break
		var sender = peer.get_packet_peer()
		var bytes = peer.get_packet()
		if bytes.size() > MAX_PACKET or (not _server and sender != 1):
			continue
		if _server:
			var second = Time.get_ticks_msec() / 1000
			var budget = _budgets.get(sender, [second, 0])
			if budget[0] != second:
				budget = [second, 0]
			budget[1] += 1
			_budgets[sender] = budget
			if budget[1] > 16:
				continue
		var packet = Protocol.new().decode(bytes)
		if packet is Dictionary and packet.get("type") is String:
			received.emit(sender, packet)


func close():
	if peer != null:
		peer.close()
		peer = null


func _exit_tree():
	close()
