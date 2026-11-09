extends Node
## ENet LAN session. Only the host simulates physics; clients send controls.
const PLAYER = preload("res://scenes/player.tscn")
const WORLD = preload("res://scenes/smithy.tscn")
const ORE_STATE = preload("res://scripts/ore_state.gd")
const ORE_BODY = preload("res://scenes/ore_piece.tscn")
const FORGE_STATE = preload("res://scripts/forge_state.gd")
const ORE_TEXTURE = preload("res://assets/textures/ore.svg")
const INGOT_TEXTURE = preload("res://assets/textures/ingot.svg")
const FORGE_POSITION := Vector2(393, 216)
const OUTPUT_POSITION := Vector2(342, 197)
var forge = FORGE_STATE.new()
var forge_station: Node2D
var work_held: Dictionary = {}
var ore = ORE_STATE.new()
var ore_bodies: Dictionary = {}
var throw_grace: Dictionary = {}
var hit_cooldowns: Dictionary = {}
var stations: Node2D
var hint: Label
var last_interaction: Dictionary = {}
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
	stations = preload("res://scenes/ore_stations.tscn").instantiate()
	world.add_child(stations)
	forge_station = preload("res://scenes/forge_station.tscn").instantiate()
	world.add_child(forge_station)
	reset_ore(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 88)
	layer.add_child(panel)
	hint = Label.new()
	hint.position = Vector2(48, 574)
	hint.add_theme_font_size_override("font_size", 14)
	layer.add_child(hint)
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
	reset_ore(true)
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
	receive_ore.rpc_id(id, ore.snapshot())
	receive_ore_motion.rpc_id(id, ore_motion())
	receive_forge.rpc_id(id, forge.snapshot())

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
	refresh_ore()
	update_status()

func _physics_process(delta: float) -> void:
	if not active or not players.has(multiplayer.get_unique_id()):
		return
	if Input.is_action_just_pressed("throw_ore") or Input.is_action_just_pressed("drop_ore"):
		var drop := Input.is_action_just_pressed("drop_ore")
		if multiplayer.is_server():
			release_ore(1, drop)
		else:
			request_throw.rpc_id(1, drop)
	if Input.is_action_just_pressed("interact"):
		if multiplayer.is_server():
			interact_for(1)
		else:
			request_interaction.rpc_id(1)
	var axis := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("climb_up", "climb_down"))
	var jump := Input.is_action_pressed("jump")
	var climb := Input.is_action_pressed("climb_up") or Input.is_action_pressed("climb_down")
	if multiplayer.is_server():
		step_ore()
		work_held[1] = Input.is_action_pressed("interact")
		apply_controls(1, axis, jump, climb)
		for id in last_input:
			if Time.get_ticks_msec() - last_input[id] > 500 and players.has(id):
				apply_controls(id, Vector2.ZERO, false, false)
				work_held[id] = false
		step_forge(delta)
		tick += 1
		if tick % 3 == 0:
			var state: Array = []
			for id in players:
				var dwarf = players[id]
				state.append([id, dwarf.position, dwarf.velocity, dwarf.climbing, dwarf.sprite.flip_h])
			receive_state.rpc(state)
			receive_ore_motion.rpc(ore_motion())
			receive_forge.rpc(forge.snapshot())
	else:
		send_controls.rpc_id(1, axis, jump, climb, Input.is_action_pressed("interact"))

func apply_controls(id: int, axis: Vector2, jump: bool, climb: bool) -> void:
	players[id].controls = axis
	players[id].jump_held = jump
	players[id].climb_held = climb

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_controls(axis: Vector2, jump: bool, climb: bool, work: bool) -> void:
	if not multiplayer.is_server() or not axis.is_finite():
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	apply_controls(id, axis.clamp(Vector2(-1, -1), Vector2.ONE), jump, climb)
	last_input[id] = Time.get_ticks_msec()
	work_held[id] = work

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
		release_ore(id, true)
		remove_player.rpc(id)
		receive_ore.rpc(ore.snapshot())

@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	if players.has(id):
		players[id].free()
		players.erase(id)
	last_input.erase(id)
	work_held.erase(id)
	last_interaction.erase(id)
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
	last_interaction.clear()
	reset_ore(false)
	hint.text = ""
	menu.show()
	leave_button.hide()
	status.text = message

@rpc("any_peer", "call_remote", "reliable")
func request_interaction() -> void:
	if multiplayer.is_server():
		interact_for(multiplayer.get_remote_sender_id())

func interact_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	# Position and inventory come from host state, never from a client request.
	var now := Time.get_ticks_msec()
	if now - last_interaction.get(id, -1000) < 150:
		return
	last_interaction[id] = now
	var message := "E: pick up · F: throw · Q: drop · Hold E at forge: work"
	if near_forge(players[id]):
		message = "Hold E with empty hands to forge an ingot (5 seconds)."
	if id in ore.carriers:
		message = "F: throw toward the bin · Q: drop"
	elif not near_forge(players[id]):
		var nearest := -1
		var distance := 24.0
		for piece_id in ore_bodies:
			if not ore.is_loose(piece_id):
				continue
			var offset: Vector2 = world.to_local(ore_bodies[piece_id].global_position) - (players[id].position - Vector2(0, 8))
			if absf(offset.y) <= 18 and offset.length() < distance:
				distance = offset.length()
				nearest = piece_id
		if nearest != -1 and ore.pickup(id, nearest):
			message = "Ore picked up. F: throw · Q: drop"

	receive_ore.rpc(ore.snapshot())
	if id == 1:
		interaction_feedback(message)
	else:
		interaction_feedback.rpc_id(id, message)

@rpc("authority", "call_local", "reliable")
func receive_ore(state: Dictionary) -> void:
	ore.restore(state)
	refresh_ore()

@rpc("authority", "call_remote", "reliable")
func interaction_feedback(message: String) -> void:
	hint.text = message

func refresh_ore() -> void:
	refresh_forge()
	stations.get_node("SupplyLabel").text = "E: PICK UP · LOOSE: %s" % ore.available
	stations.get_node("BinLabel").text = "THROW IN: %s" % ore.deposited
	for piece_id in ore_bodies:
		var body: RigidBody2D = ore_bodies[piece_id]
		var loose: bool = ore.is_loose(piece_id)
		body.get_node("Sprite2D").texture = INGOT_TEXTURE if ore.pieces[piece_id].kind == "ingot" else ORE_TEXTURE
		body.visible = loose
		body.freeze = not loose or not (active and multiplayer.is_server())
		body.collision_layer = 4 if loose and multiplayer.is_server() else 0
		body.collision_mask = 13 if loose and multiplayer.is_server() else 0
	for id in players:
		var carried: int = ore.carried_by(id)
		players[id].get_node("CarriedOre").visible = carried != -1
		if carried != -1:
			players[id].get_node("CarriedOre").texture = INGOT_TEXTURE if ore.pieces[carried].kind == "ingot" else ORE_TEXTURE

func reset_ore(simulate: bool) -> void:
	for body in ore_bodies.values():
		body.free()
	ore_bodies.clear()
	throw_grace.clear()
	hit_cooldowns.clear()
	ore = ORE_STATE.new()
	forge = FORGE_STATE.new()
	work_held.clear()
	refresh_forge()
	for id in ore.pieces:
		var body: RigidBody2D = ORE_BODY.instantiate()
		body.name = "Ore_%s" % id
		world.add_child(body)
		body.global_position = world.to_global(Vector2(210 + id * 8, 281 - (id % 2) * 3))
		body.freeze = not simulate
		body.collision_layer = 4 if simulate else 0
		body.collision_mask = 13 if simulate else 0
		ore_bodies[id] = body
	refresh_ore()

@rpc("any_peer", "call_remote", "reliable")
func request_throw(drop: bool) -> void:
	if multiplayer.is_server():
		release_ore(multiplayer.get_remote_sender_id(), drop)

func release_ore(id: int, drop: bool) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var piece_id: int = ore.release_carrier(id)
	if piece_id == -1:
		return
	var dwarf = players[id]
	var direction := -1.0 if dwarf.sprite.flip_h else 1.0
	var body: RigidBody2D = ore_bodies[piece_id]
	# Release within the dwarf's footprint so a wall cannot swallow the ore.
	var at: Vector2 = dwarf.position + Vector2(direction * 2, -18 if not drop else -7)
	var motion := Vector2(direction * 280, -180) if not drop else Vector2(direction * 25, 0)
	position_ore(body, at, motion)
	body.angular_velocity = direction * 6 if not drop else 0
	throw_grace[piece_id] = [id, Time.get_ticks_msec() + 300]
	receive_ore.rpc(ore.snapshot())
	receive_ore_motion.rpc(ore_motion())

func ore_motion() -> Array:
	var result: Array = []
	for id in ore_bodies:
		if ore.is_loose(id):
			var body: RigidBody2D = ore_bodies[id]
			result.append([id, body.global_position, body.rotation, body.linear_velocity])
	return result

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_ore_motion(state: Array) -> void:
	for item in state:
		if ore_bodies.has(item[0]):
			var body: RigidBody2D = ore_bodies[item[0]]
			body.global_position = item[1]
			body.rotation = item[2]
			body.linear_velocity = item[3]

func step_ore() -> void:
	var changed := false
	var catch_area: Area2D = stations.get_node("BinCatch")
	for piece_id in ore_bodies:
		if not ore.is_loose(piece_id):
			continue
		var body: RigidBody2D = ore_bodies[piece_id]
		if catch_area.overlaps_body(body) and body.linear_velocity.y >= 0:
			changed = ore.store(piece_id) or changed
			continue
		if body.linear_velocity.length() < 110:
			continue
		for id in players:
			var now := Time.get_ticks_msec()
			var grace: Array = throw_grace.get(piece_id, [0, 0])
			if (grace[0] == id and now < grace[1]) or now < hit_cooldowns.get(Vector2i(piece_id, id), 0):
				continue
			var hurtbox := Rect2(players[id].global_position - Vector2(20, 54), Vector2(40, 62))
			if hurtbox.has_point(body.global_position):
				players[id].apply_ore_hit(body.linear_velocity * 0.7)
				hit_cooldowns[Vector2i(piece_id, id)] = now + 400
				body.linear_velocity = Vector2(-body.linear_velocity.x * 0.4, -70)
				break
	if changed:
		receive_ore.rpc(ore.snapshot())

func position_ore(body: RigidBody2D, at: Vector2, motion: Vector2) -> void:
	body.freeze = false
	body.sleeping = false
	body.rotation = 0
	body.global_position = world.to_global(at)
	body.linear_velocity = motion
	# Update the physics transform as well when releasing a formerly frozen body.
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, motion)

func near_forge(dwarf: CharacterBody2D) -> bool:
	return absf(dwarf.position.x - FORGE_POSITION.x) <= 23 and absf(dwarf.position.y - FORGE_POSITION.y) <= 6

func step_forge(delta: float) -> void:
	var eligible: Array[int] = []
	for id in players:
		var dwarf = players[id]
		if work_held.get(id, false) and near_forge(dwarf) and dwarf.is_on_floor() and not dwarf.climbing and dwarf.hit_stun == 0 and dwarf.controls.is_zero_approx() and not dwarf.jump_held and ore.carried_by(id) == -1:
			eligible.append(id)
	eligible.sort()
	var result: Dictionary = forge.step(delta, eligible, ore)
	if result.finished != -1:
		var body: RigidBody2D = ore_bodies[result.finished]
		position_ore(body, OUTPUT_POSITION, Vector2(0, 20))
		body.angular_velocity = 0
	if result.started != -1 or result.finished != -1:
		receive_ore.rpc(ore.snapshot())
		receive_ore_motion.rpc(ore_motion())
		receive_forge.rpc(forge.snapshot())
	refresh_forge()

@rpc("authority", "call_remote", "reliable")
func receive_forge(state: Dictionary) -> void:
	forge.restore(state)
	refresh_forge()

func refresh_forge() -> void:
	forge_station.get_node("Progress").value = forge.progress
	var text := "HOLD E · 5s"
	if forge.piece != -1:
		text = "%s %.1f/5s" % ["WORK" if forge.worker != 0 else "PAUSED", forge.progress]
	elif ore.deposited == 0:
		text = "NEED ORE"
	forge_station.get_node("WorkLabel").text = text
