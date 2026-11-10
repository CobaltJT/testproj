extends Node
## ENet LAN session. Only the host simulates physics; clients send controls.
const MAP = preload("res://scripts/map_layout.gd")
var overview_camera: Camera2D
const WORKSHOP_STATE = preload("res://scripts/workshop_state.gd")
const STATION_JOB = preload("res://scripts/station_job.gd")
const STATION_SCENE = preload("res://scenes/workstation.tscn")
const STATION_VIEW = preload("res://scripts/station_view.gd")
var workshop = WORKSHOP_STATE.new()
var station_nodes: Dictionary = {}
var build_ghost: Sprite2D
var catalog: PanelContainer
var build_button: Button
const MERCHANT_STATE = preload("res://scripts/merchant_state.gd")
var merchant = MERCHANT_STATE.new()
var merchant_node: Node2D
var merchant_label: Label
var customer_nodes: Dictionary = {}
var recipe_label: Label
const EXTRA_TEXTURES = {
	"horseshoe": preload("res://assets/textures/horseshoe.svg"),
	"sword": preload("res://assets/textures/sword.svg"),
	"axe": preload("res://assets/textures/axe.svg"),
	"wood": preload("res://assets/textures/wood.svg"),
	"dull_sword": preload("res://assets/textures/dull_sword.svg"),
	"axe_head": preload("res://assets/textures/axe_head.svg"),
	"shaft": preload("res://assets/textures/shaft.svg"),
	"ingot": preload("res://assets/textures/ingot.svg")
}
const MINING_STATE = preload("res://scripts/mining_state.gd")
const MINE_POSITION := Vector2(390, 288)
const MINE_OUTPUT := Vector2(344, 276)
var mining = MINING_STATE.new()
var mining_station: Node2D
const CUSTOMER_STATE = preload("res://scripts/customer_state.gd")
var orders = CUSTOMER_STATE.new()
var order_label: Label
const PLAYER = preload("res://scenes/player.tscn")
const WORLD = preload("res://scenes/smithy.tscn")
const ORE_STATE = preload("res://scripts/ore_state.gd")
const ORE_BODY = preload("res://scenes/ore_piece.tscn")
const ORE_TEXTURE = preload("res://assets/textures/ore.svg")
var work_held: Dictionary = {}
var ore = ORE_STATE.new()
var ore_bodies: Dictionary = {}
var throw_grace: Dictionary = {}
var hit_cooldowns: Dictionary = {}
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
	overview_camera = Camera2D.new()
	overview_camera.name = "OverviewCamera"
	overview_camera.top_level = true
	world.add_child(overview_camera)
	get_viewport().size_changed.connect(update_overview)
	update_overview()
	overview_camera.make_current()
	mining_station = preload("res://scenes/mining_station.tscn").instantiate()
	world.add_child(mining_station)
	merchant_node = preload("res://scenes/merchant.tscn").instantiate()
	world.add_child(merchant_node)
	reset_ore(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 88)
	layer.add_child(panel)
	hint = Label.new()
	hint.position = Vector2(24, 642)
	hint.add_theme_font_size_override("font_size", 14)
	layer.add_child(hint)
	order_label = Label.new()
	order_label.position = Vector2(505, 12)
	order_label.add_theme_font_size_override("font_size", 12)
	layer.add_child(order_label)
	merchant_label = Label.new()
	merchant_label.position = Vector2(24, 686)
	merchant_label.add_theme_font_size_override("font_size", 13)
	layer.add_child(merchant_label)
	recipe_label = Label.new()
	recipe_label.position = Vector2(24, 664)
	recipe_label.add_theme_font_size_override("font_size", 13)
	layer.add_child(recipe_label)
	refresh_orders()
	refresh_merchant()
	init_build_ui(layer)
	refresh_workshop()
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
	broadcast_state("spawn_player", [id, Vector2(210 + (players.size() % 6) * 22, 216)], true)
	receive_ore.rpc_id(id, ore.snapshot())
	receive_ore_motion.rpc_id(id, ore_motion())
	receive_workshop.rpc_id(id, workshop.snapshot())
	receive_orders.rpc_id(id, orders.snapshot())
	receive_mining.rpc_id(id, mining.snapshot())
	receive_merchant.rpc_id(id, merchant.snapshot())

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
	dwarf.set_camera_active(local)
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
	if Input.is_action_just_pressed("accept_order") or Input.is_action_just_pressed("reject_order"):
		if not orders.queue.is_empty():
			var order_id: int = orders.queue[0].id
			var accept := Input.is_action_just_pressed("accept_order")
			if multiplayer.is_server():
				decide_order_for(1, order_id, accept)
			else:
				request_order_decision.rpc_id(1, order_id, accept)
	for choice in STATION_JOB.ANVIL_RECIPES:
		if Input.is_action_just_pressed("recipe_" + choice):
			if multiplayer.is_server():
				choose_recipe(1, choice)
			else:
				request_recipe.rpc_id(1, choice)
	if Input.is_action_just_pressed("build_menu"):
		catalog.visible = not catalog.visible
	if Input.is_action_just_pressed("cancel_build"):
		catalog.hide()
		if multiplayer.is_server():
			cancel_build_for(1)
		else:
			request_cancel_build.rpc_id(1)
	if Input.is_action_just_pressed("pack_station"):
		if multiplayer.is_server():
			pack_for(1)
		else:
			request_pack.rpc_id(1)
	if Input.is_action_just_pressed("buy_wood"):
		if multiplayer.is_server():
			buy_wood_for(1)
		else:
			request_wood.rpc_id(1)
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
		step_workstations(delta)
		step_mining(delta)
		if workshop.opened:
			orders.step(delta)
			merchant.step(delta)
		refresh_orders()
		refresh_merchant()
		tick += 1
		if tick % 3 == 0:
			var state: Array = []
			for id in players:
				var dwarf = players[id]
				state.append([id, dwarf.position, dwarf.velocity, dwarf.climbing, dwarf.sprite.flip_h])
			broadcast_state("receive_state", [state], false)
			broadcast_state("receive_ore_motion", [ore_motion()], false)
			broadcast_state("receive_workshop", [workshop.snapshot()], false)
			broadcast_state("receive_orders", [orders.snapshot()], false)
			broadcast_state("receive_mining", [mining.snapshot()], false)
			broadcast_state("receive_merchant", [merchant.snapshot()], false)
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
		workshop.cancel(id, orders)
		sync_build()
		workshop.cancel(id, orders)
		broadcast_state("receive_workshop", [workshop.snapshot()])
		broadcast_state("receive_orders", [orders.snapshot()])
		release_ore(id, true)
		broadcast_state("remove_player", [id], true)
		broadcast_state("receive_ore", [ore.snapshot()], true)

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
	overview_camera.make_current()
	update_overview()
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


@rpc("authority", "call_local", "reliable")
func receive_ore(state: Dictionary) -> void:
	ore.restore(state)
	refresh_ore()

@rpc("authority", "call_remote", "reliable")
func interaction_feedback(message: String) -> void:
	hint.text = message



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
	broadcast_state("receive_ore", [ore.snapshot()], true)
	broadcast_state("receive_ore_motion", [ore_motion()], false)

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
	var collected := false
	for piece_id in ore_bodies:
		if not ore.is_loose(piece_id):
			continue
		var body: RigidBody2D = ore_bodies[piece_id]
		var stored := false
		if body.linear_velocity.y >= 0:
			for station_id in workshop.stations:
				var entry: Dictionary = workshop.stations[station_id]
				if entry.kind == "forge" and station_nodes.has(station_id) and station_nodes[station_id].get_node("BinCatch").overlaps_body(body):
					stored = entry.job.store_ore(piece_id, ore)
					if stored:
						collected = true
						break
		if stored:
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

	if collected:
		broadcast_state("receive_ore", [ore.snapshot()], true)
		broadcast_state("receive_workshop", [workshop.snapshot()])
		refresh_workshop()

func position_ore(body: RigidBody2D, at: Vector2, motion: Vector2) -> void:
	body.freeze = false
	body.sleeping = false
	body.rotation = 0
	body.global_position = world.to_global(at)
	body.linear_velocity = motion
	# Update the physics transform as well when releasing a formerly frozen body.
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, motion)






@rpc("authority", "call_remote", "reliable")
func receive_orders(state: Dictionary) -> void:
	orders.restore(state)
	refresh_orders()

func refresh_orders() -> void:
	var live: Dictionary = {}
	for i in range(orders.queue.size()):
		var order: Dictionary = orders.queue[i]
		var target := 120.0 - i * 20
		var at := lerpf(70, target, minf(1, order.age / CUSTOMER_STATE.WALK_TIME))
		show_customer(order.id, Vector2(at, 216), "%s: %s %ss" % ["DELIVER" if order.accepted else ("DECIDE" if i == 0 else "WAIT"), order.kind.to_upper(), ceili(order.remaining)], false)
		live[order.id] = true
	for departure in orders.departures:
		var at := lerpf(70, departure.x, departure.remaining / CUSTOMER_STATE.WALK_TIME)
		show_customer(departure.id, Vector2(at, 216), {"fulfilled": "THANKS!", "rejected": "DECLINED", "unanswered": "NO ANSWER", "failed": "TOO LATE!"}.get(departure.reason, "BYE!"), true)
		live[departure.id] = true
	for id in customer_nodes.keys():
		if not live.has(id):
			customer_nodes[id].free()
			customer_nodes.erase(id)
	if order_label != null:
		order_label.visible = active
		var text := "Coins: %s · Reputation: %s · Served: %s · Failed: %s · Declined: %s" % [orders.coins, orders.reputation, orders.completed, orders.missed, orders.rejected]
		for i in range(orders.queue.size()):
			var order: Dictionary = orders.queue[i]
			var phase := "DELIVER" if order.accepted else ("Y accept / N reject" if i == 0 else "waiting for counter")
			text += "\n%s #%s: %s · %s · %ss · %sg" % ["FRONT" if i == 0 else "QUEUED", order.id, order.kind.capitalize(), phase, ceili(order.remaining), CUSTOMER_STATE.PRICES[order.kind]]
		text += "\nNext arrival: %ss · E serves FRONT only" % ceili(orders.until_arrival) if workshop.opened else "\nPlace an anvil to open the workshop. Tab: build catalog"
		order_label.text = text

func show_customer(id: int, at: Vector2, request: String, leaving: bool) -> void:
	if not customer_nodes.has(id):
		var node := preload("res://scenes/customer.tscn").instantiate()
		world.add_child(node)
		customer_nodes[id] = node
	var node: Node2D = customer_nodes[id]
	node.visible = active
	node.position = at
	node.get_node("Sprite2D").flip_h = leaving
	node.get_node("Request").text = request

func create_ore_body(id: int, simulate: bool, at: Vector2) -> RigidBody2D:
	var body: RigidBody2D = ORE_BODY.instantiate()
	body.name = "Ore_%s" % id
	world.add_child(body)
	body.global_position = world.to_global(at)
	body.freeze = not simulate
	body.collision_layer = 4 if simulate else 0
	body.collision_mask = 13 if simulate else 0
	ore_bodies[id] = body
	return body

func near_mine(dwarf: CharacterBody2D) -> bool:
	return absf(dwarf.position.x - MINE_POSITION.x) <= 20 and absf(dwarf.position.y - MINE_POSITION.y) <= 6

func step_mining(delta: float) -> void:
	var eligible: Array[int] = []
	for id in players:
		var dwarf = players[id]
		if not workshop.pending.has(id) and work_held.get(id, false) and near_mine(dwarf) and dwarf.is_on_floor() and not dwarf.climbing and dwarf.hit_stun == 0 and dwarf.controls.is_zero_approx() and not dwarf.jump_held and ore.carried_by(id) == -1:
			eligible.append(id)
	eligible.sort()
	if mining.step(delta, eligible):
		var piece_id: int = ore.add_mined_ore()
		var body := create_ore_body(piece_id, true, MINE_OUTPUT)
		position_ore(body, MINE_OUTPUT, Vector2(0, 20))
		broadcast_state("receive_ore", [ore.snapshot()], true)
		broadcast_state("receive_ore_motion", [ore_motion()], false)
		broadcast_state("receive_mining", [mining.snapshot()], false)
	refresh_mining()

@rpc("authority", "call_remote", "reliable")
func receive_mining(state: Dictionary) -> void:
	mining.restore(state)
	refresh_mining()

func refresh_mining() -> void:
	mining_station.get_node("Progress").value = mining.progress
	var text := "HOLD E: MINE · 3s"
	if mining.progress > 0:
		text = "%s %.1f/3s" % ["MINING" if mining.worker != 0 else "PAUSED", mining.progress]
	mining_station.get_node("WorkLabel").text = text

@rpc("any_peer", "call_remote", "reliable")
func request_recipe(choice: String) -> void:
	if multiplayer.is_server():
		choose_recipe(multiplayer.get_remote_sender_id(), choice)


@rpc("any_peer", "call_remote", "reliable")
func request_wood() -> void:
	if multiplayer.is_server():
		buy_wood_for(multiplayer.get_remote_sender_id())

func buy_wood_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var piece_id: int = merchant.buy(id, players[id].position, orders, ore)
	if piece_id == -1:
		var message := "B buys wood: stand by the merchant with empty hands, 5 coins and stock available."
		if id == 1:
			interaction_feedback(message)
		else:
			interaction_feedback.rpc_id(id, message)
		return
	var body := create_ore_body(piece_id, true, Vector2(222, 202))
	position_ore(body, Vector2(222, 202), Vector2(0, 20))
	broadcast_state("receive_ore", [ore.snapshot()], true)
	broadcast_state("receive_ore_motion", [ore_motion()], false)
	broadcast_state("receive_orders", [orders.snapshot()], false)
	broadcast_state("receive_merchant", [merchant.snapshot()], false)
	refresh_orders()
	refresh_merchant()

@rpc("authority", "call_remote", "reliable")
func receive_merchant(state: Dictionary) -> void:
	merchant.restore(state)
	refresh_merchant()

func refresh_merchant() -> void:
	merchant_node.visible = active and merchant.remaining > 0
	if merchant_label != null:
		merchant_label.visible = active
		merchant_label.text = "Merchant: B buys wood for 5 coins · Stock: %s · Leaves in %ss" % [merchant.stock, ceili(merchant.remaining)] if merchant.remaining > 0 else "Merchant returns in %ss · Wood costs 5 coins (B nearby)" % ceili(merchant.until_visit)

func broadcast_state(method: String, arguments: Array, apply_local: bool = false) -> void:
	if apply_local:
		callv(method, arguments)
	# ENet may still list a closing peer while its channels have been released.
	# Preserve local transactions and send only to peers with a live connection.
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport == null:
		return
	for id in multiplayer.get_peers():
		var peer: ENetPacketPeer = transport.get_peer(id)
		if peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED and peer.get_channels() > 0:
			callv("rpc_id", [id, method] + arguments)

func material_texture(kind: String) -> Texture2D:
	return EXTRA_TEXTURES.get(kind, ORE_TEXTURE)

func interact_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id) or workshop.pending.has(id):
		return
	var now := Time.get_ticks_msec()
	if now - last_interaction.get(id, -1000) < 150:
		return
	last_interaction[id] = now
	var dwarf = players[id]
	var carried: int = ore.carried_by(id)
	var message := "E: pick up/load · Hold E: work · Tab: build · R: pack idle station"
	if near_mine(dwarf):
		message = "Hold E with empty hands to mine ore (3 seconds)."
	elif absf(dwarf.position.x - 166) <= 30 and absf(dwarf.position.y - 216) <= 6 and not orders.queue.is_empty() and carried != -1:
		var product: String = orders.queue[0].kind
		var sold: bool = orders.deliver(id, dwarf.position, ore)
		message = "%s delivered! +%s coins, +2 reputation." % [product.capitalize(), CUSTOMER_STATE.PRICES[product]] if sold else ("Y: accept or N: reject this request first." if not orders.queue[0].accepted else "Front customer needs a %s." % product)
		broadcast_state("receive_orders", [orders.snapshot()])
		refresh_orders()
	else:
		var station_id: int = workshop.nearest(dwarf.position)
		if carried != -1 and station_id != -1:
			var job = workshop.stations[station_id].job
			message = "Ingredient loaded. Hold E with empty hands to work." if job.load_material(id, ore) else ("Throw ore into the attached forge bin, then hold E to smelt." if job.kind == "forge" else "Wrong or duplicate ingredient for this station recipe.")
			broadcast_state("receive_workshop", [workshop.snapshot()])
			refresh_workshop()
		elif carried == -1 and (station_id == -1 or workshop.stations[station_id].job.slots.is_empty() and workshop.stations[station_id].job.ore_queue.is_empty()):
			var nearest := -1
			var distance := 24.0
			for piece_id in ore_bodies:
				if not ore.is_loose(piece_id):
					continue
				var offset: Vector2 = world.to_local(ore_bodies[piece_id].global_position) - (dwarf.position - Vector2(0, 8))
				if absf(offset.y) <= 18 and offset.length() < distance:
					distance = offset.length()
					nearest = piece_id
			if nearest != -1 and ore.pickup(id, nearest):
				message = "Picked up %s. F: throw · Q: drop" % ore.pieces[nearest].kind.replace("_", " ")
	broadcast_state("receive_ore", [ore.snapshot()], true)
	feedback_for(id, message)

func feedback_for(id: int, message: String) -> void:
	if id == 1:
		interaction_feedback(message)
	else:
		interaction_feedback.rpc_id(id, message)

func refresh_ore() -> void:
	for piece_id in ore.pieces:
		if not ore_bodies.has(piece_id):
			create_ore_body(piece_id, false, MINE_OUTPUT)
	for piece_id in ore_bodies:
		var body: RigidBody2D = ore_bodies[piece_id]
		var loose: bool = ore.is_loose(piece_id)
		body.get_node("Sprite2D").texture = material_texture(ore.pieces[piece_id].kind)
		body.visible = loose
		body.freeze = not loose or not (active and multiplayer.is_server())
		body.collision_layer = 4 if loose and multiplayer.is_server() else 0
		body.collision_mask = 13 if loose and multiplayer.is_server() else 0
	for id in players:
		var carried: int = ore.carried_by(id)
		players[id].get_node("CarriedOre").visible = carried != -1
		if carried != -1:
			players[id].get_node("CarriedOre").texture = material_texture(ore.pieces[carried].kind)

func reset_ore(simulate: bool) -> void:
	for body in ore_bodies.values():
		body.free()
	ore_bodies.clear()
	throw_grace.clear()
	hit_cooldowns.clear()
	ore = ORE_STATE.new()
	workshop = WORKSHOP_STATE.new()
	refresh_workshop()
	mining = MINING_STATE.new()
	refresh_mining()
	orders = CUSTOMER_STATE.new()
	merchant = MERCHANT_STATE.new()
	refresh_orders()
	refresh_merchant()
	work_held.clear()
	for id in ore.pieces:
		create_ore_body(id, simulate, Vector2(210 + id * 8, 281 - (id % 2) * 3))
	refresh_ore()

func choose_recipe(id: int, choice: String) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var station_id: int = workshop.nearest(players[id].position)
	if station_id != -1 and workshop.stations[station_id].job.select(choice):
		broadcast_state("receive_workshop", [workshop.snapshot()])
		refresh_workshop()

func step_workstations(delta: float) -> void:
	var changed := false
	for station_id in workshop.stations:
		var entry: Dictionary = workshop.stations[station_id]
		var eligible: Array[int] = []
		for id in players:
			var dwarf = players[id]
			if work_held.get(id, false) and workshop.nearest(dwarf.position) == station_id and not workshop.pending.has(id) and dwarf.is_on_floor() and not dwarf.climbing and dwarf.hit_stun == 0 and dwarf.controls.is_zero_approx() and not dwarf.jump_held and ore.carried_by(id) == -1:
				eligible.append(id)
		eligible.sort()
		var output: int = entry.job.step(delta, eligible, ore)
		if output != -1:
			position_ore(ore_bodies[output], entry.at + Vector2(28, -18), Vector2(0, 20))
			ore_bodies[output].angular_velocity = 0
			changed = true
	if changed:
		broadcast_state("receive_ore", [ore.snapshot()], true)
		broadcast_state("receive_ore_motion", [ore_motion()])
		broadcast_state("receive_workshop", [workshop.snapshot()])
	refresh_workshop()

@rpc("authority", "call_remote", "reliable")
func receive_workshop(state: Dictionary) -> void:
	workshop.restore(state)
	refresh_workshop()

func refresh_workshop() -> void:
	for id in station_nodes.keys():
		if not workshop.stations.has(id):
			station_nodes[id].free()
			station_nodes.erase(id)
	for id in workshop.stations:
		if not station_nodes.has(id):
			var view: Node2D = STATION_SCENE.instantiate()
			world.add_child(view)
			station_nodes[id] = view
		station_nodes[id].update_view(workshop.stations[id])
	if recipe_label != null:
		recipe_label.visible = active
		recipe_label.text = "Tab: buy/place · R: pack idle station · Anvil: 1 Horseshoe  2 Blade  3 Axe head  4 Assemble axe"
	if build_button != null:
		build_button.visible = active

func init_build_ui(layer: CanvasLayer) -> void:
	build_ghost = Sprite2D.new()
	build_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(build_ghost)
	build_ghost.hide()
	build_button = Button.new()
	build_button.text = "Build [Tab]"
	build_button.position = Vector2(820, 642)
	build_button.pressed.connect(func(): catalog.visible = not catalog.visible)
	build_button.focus_mode = Control.FOCUS_NONE
	layer.add_child(build_button)
	catalog = PanelContainer.new()
	catalog.position = Vector2(600, 320)
	layer.add_child(catalog)
	var column := VBoxContainer.new()
	catalog.add_child(column)
	var title := Label.new()
	title.text = "Buy a workstation (empty hands)"
	column.add_child(title)
	for kind in WORKSHOP_STATE.PRICES:
		var button := Button.new()
		button.text = "%s · %s coins" % ["Forge + bin" if kind == "forge" else kind.capitalize(), WORKSHOP_STATE.PRICES[kind]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): buy_station(kind))
		column.add_child(button)
	var help := Label.new()
	help.text = "After buying: click a green floor preview.\nRed: blocked. Esc: cancel/refund kit.\nR beside an empty station: pack/move."
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): catalog.hide())
	column.add_child(close)
	catalog.hide()

func _process(_delta: float) -> void:
	if build_ghost == null:
		return
	var id := multiplayer.get_unique_id()
	var carrying_kit: bool = active and workshop.pending.has(id)
	build_ghost.visible = carrying_kit
	if carrying_kit:
		catalog.hide()
		var at: Vector2 = workshop.snap(world.get_local_mouse_position())
		build_ghost.position = at + Vector2(8, -16)
		build_ghost.texture = STATION_VIEW.TEXTURES[workshop.pending[id].kind]
		build_ghost.modulate = Color(0.4, 1, 0.5, 0.7) if workshop.can_place(at) else Color(1, 0.3, 0.3, 0.7)
	if not active:
		catalog.hide()

func _unhandled_input(event: InputEvent) -> void:
	if active and build_ghost != null and build_ghost.visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var at: Vector2 = workshop.snap(world.get_global_transform_with_canvas().affine_inverse() * event.position)
		if multiplayer.is_server():
			place_for(1, at)
		else:
			request_place.rpc_id(1, at)
		get_viewport().set_input_as_handled()

func buy_station(kind: String) -> void:
	if multiplayer.is_server():
		purchase_for(1, kind)
	else:
		request_station.rpc_id(1, kind)

@rpc("any_peer", "call_remote", "reliable")
func request_station(kind: String) -> void:
	if multiplayer.is_server():
		purchase_for(multiplayer.get_remote_sender_id(), kind)

func purchase_for(id: int, kind: String) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	if not workshop.purchase(id, kind, orders, ore):
		feedback_for(id, "Cannot buy: check coins, empty hands, and any unplaced kit.")
	sync_build()

@rpc("any_peer", "call_remote", "reliable")
func request_place(at: Vector2) -> void:
	if multiplayer.is_server():
		place_for(multiplayer.get_remote_sender_id(), at)

func place_for(id: int, at: Vector2) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	if workshop.place(id, at) == -1:
		feedback_for(id, "Blocked placement: keep paths, fixed fixtures, and other stations clear.")
	sync_build()

@rpc("any_peer", "call_remote", "reliable")
func request_cancel_build() -> void:
	if multiplayer.is_server():
		cancel_build_for(multiplayer.get_remote_sender_id())

func cancel_build_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	workshop.cancel(id, orders)
	sync_build()

@rpc("any_peer", "call_remote", "reliable")
func request_pack() -> void:
	if multiplayer.is_server():
		pack_for(multiplayer.get_remote_sender_id())

func pack_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	if not workshop.pack(id, players[id].position, ore):
		feedback_for(id, "Only empty, idle stations can be packed; keep your hands free.")
	sync_build()

func sync_build() -> void:
	refresh_workshop()
	refresh_orders()
	broadcast_state("receive_workshop", [workshop.snapshot()])
	broadcast_state("receive_orders", [orders.snapshot()])

func update_overview() -> void:
	var size := get_viewport().get_visible_rect().size
	var factor := minf(size.x / (MAP.WIDTH * MAP.SCALE), (size.y - 80) / (MAP.HEIGHT * MAP.SCALE))
	overview_camera.zoom = Vector2.ONE * maxf(factor, 0.01)
	overview_camera.global_position = Vector2(MAP.WIDTH, MAP.HEIGHT) * MAP.SCALE / 2.0
	if not active:
		overview_camera.force_update_scroll()

@rpc("any_peer", "call_remote", "reliable")
func request_order_decision(order_id: int, accept: bool) -> void:
	if multiplayer.is_server():
		decide_order_for(multiplayer.get_remote_sender_id(), order_id, accept)

func decide_order_for(id: int, order_id: int, accept: bool) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var changed: bool = orders.decide(id, players[id].position, order_id, accept)
	var message := "Request accepted: deliver within 30 seconds (+2 reputation)." if accept else "Request rejected: -3 reputation."
	if not changed:
		message = "Decide on the front request at the counter. Already accepted or stale requests cannot be rejected."
	feedback_for(id, message)
	broadcast_state("receive_orders", [orders.snapshot()])
	refresh_orders()
