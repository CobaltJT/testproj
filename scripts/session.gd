extends Node
## ENet LAN session. Only the host simulates physics; clients send controls.
const PLAYER = preload("res://scenes/player.tscn")
const WORLD = preload("res://scenes/smithy.tscn")
const PORT := 24567
var world: Node2D
var players: Dictionary = {}
var last_input: Dictionary = {}
var status: Label
var address: LineEdit
var port: SpinBox
var menu: VBoxContainer
var leave_button: Button
var active := false
var tick := 0

func _ready() -> void:
	world = WORLD.instantiate()
	add_child(world)
	world.get_node("Player").free()
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 88)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status = Label.new()
	status.text = "LAN co-op — host or join a smithy"
	column.add_child(status)
	menu = VBoxContainer.new()
	column.add_child(menu)
	address = LineEdit.new()
	address.placeholder_text = "Host LAN IP (for example 192.168.1.20)"
	address.text = "127.0.0.1"
	address.custom_minimum_size.x = 370
	menu.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = PORT
	menu.add_child(port)
	for entry in [["Host LAN game", host_game], ["Join LAN game", join_game]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		menu.add_child(button)
	leave_button = Button.new()
	leave_button.text = "Leave game"
	leave_button.focus_mode = Control.FOCUS_NONE
	leave_button.visible = false
	leave_button.pressed.connect(func(): disconnect_game("Disconnected"))
	column.add_child(leave_button)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(func(): client_ready.rpc_id(1))
	multiplayer.connection_failed.connect(func(): disconnect_game("Connection failed. Check IP, port and firewall."))
	multiplayer.server_disconnected.connect(func(): disconnect_game("Host disconnected."))
	# The same production entry points are used by the multi-process smoke test.
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--port="):
			port.value = int(arg.get_slice("=", 1))
	if "--host" in args:
		host_game()
	for arg in args:
		if arg.begins_with("--join="):
			address.text = arg.get_slice("=", 1)
			join_game()

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	# No game-design player cap yet; ENet's transport limit is used.
	var error := peer.create_server(int(port.value), 4095)
	if error != OK:
		status.text = "Cannot host on this UDP port (error %s)." % error
		return
	multiplayer.multiplayer_peer = peer
	active = true
	menu.hide()
	leave_button.show()
	spawn_player(1, Vector2(220, 216))
	update_status()

func join_game() -> void:
	if address.text.strip_edges().is_empty():
		status.text = "Enter the host's LAN IP."
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.text.strip_edges(), int(port.value))
	if error != OK:
		status.text = "Cannot connect (error %s)." % error
		return
	multiplayer.multiplayer_peer = peer
	menu.hide()
	leave_button.show()
	status.text = "Connecting…"

@rpc("any_peer", "call_remote", "reliable")
func client_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id not in multiplayer.get_peers() or players.has(id):
		return
	for existing in players:
		spawn_player.rpc_id(id, existing, players[existing].position)
	spawn_player.rpc(id, Vector2(210 + (players.size() % 6) * 22, 216))

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, at: Vector2) -> void:
	if players.has(id):
		return
	var dwarf = PLAYER.instantiate()
	dwarf.name = "Dwarf_%s" % id
	dwarf.position = at
	dwarf.networked = true
	# Dwarfs pass through each other; only the building blocks movement.
	dwarf.collision_layer = 2
	dwarf.collision_mask = 1
	world.add_child(dwarf)
	var local := id == multiplayer.get_unique_id()
	dwarf.get_node("Sprite2D").modulate = Color.WHITE if local else Color.from_hsv(fmod(id * 0.137, 1.0), 0.45, 1.0)
	var tag := Label.new()
	tag.text = "YOU" if local else ("HOST" if id == 1 else "DWARF %s" % id)
	tag.position = Vector2(-14, -35)
	tag.add_theme_font_size_override("font_size", 7)
	dwarf.add_child(tag)
	players[id] = dwarf
	active = true
	update_status()

func _physics_process(_delta: float) -> void:
	if not active or not players.has(multiplayer.get_unique_id()):
		return
	var axis := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("climb_up", "climb_down"))
	var jump := Input.is_action_pressed("jump")
	var climb := Input.is_action_pressed("climb_up") or Input.is_action_pressed("climb_down")
	if multiplayer.is_server():
		apply_controls(1, axis, jump, climb)
		for id in last_input:
			if Time.get_ticks_msec() - last_input[id] > 500 and players.has(id):
				apply_controls(id, Vector2.ZERO, false, false)
		tick += 1
		if tick % 3 == 0:
			var state: Array = []
			for id in players:
				var dwarf = players[id]
				state.append([id, dwarf.position, dwarf.velocity, dwarf.climbing, dwarf.sprite.flip_h])
			receive_state.rpc(state)
	else:
		send_controls.rpc_id(1, axis, jump, climb)

func apply_controls(id: int, axis: Vector2, jump: bool, climb: bool) -> void:
	players[id].controls = axis
	players[id].jump_held = jump
	players[id].climb_held = climb

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_controls(axis: Vector2, jump: bool, climb: bool) -> void:
	if not multiplayer.is_server() or not axis.is_finite():
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	apply_controls(id, axis.clamp(Vector2(-1, -1), Vector2.ONE), jump, climb)
	last_input[id] = Time.get_ticks_msec()

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state(state: Array) -> void:
	for item in state:
		if players.has(item[0]):
			var dwarf = players[item[0]]
			dwarf.position = item[1]
			dwarf.velocity = item[2]
			dwarf.climbing = item[3]
			dwarf.sprite.flip_h = item[4]

func peer_left(id: int) -> void:
	if multiplayer.is_server():
		remove_player.rpc(id)

@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	if players.has(id):
		players[id].free()
		players.erase(id)
	last_input.erase(id)
	update_status()

func update_status() -> void:
	status.text = "%s · UDP %s · %s dwarfs" % ["Hosting" if multiplayer.is_server() else "Connected", int(port.value), players.size()]

func disconnect_game(message: String) -> void:
	active = false
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for dwarf in players.values():
		dwarf.free()
	players.clear()
	last_input.clear()
	menu.show()
	leave_button.hide()
	status.text = message
