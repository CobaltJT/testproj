extends Node
## ENet LAN session. Only the host simulates physics; clients send controls.
const PROGRESSION = preload("res://scripts/progression_state.gd")
var progression = PROGRESSION.new()
var progression_label: Label
var skill_summary: Label
var skill_buttons: Dictionary = {}
var station_buttons: Dictionary = {}
var catalog_tabs: TabContainer
const DAY_STATE = preload("res://scripts/day_state.gd")
var cycle = DAY_STATE.new()
var day_label: Label
var open_button: Button
var day_popup: PanelContainer
var day_summary: Label
var next_day_button: Button
var blackout: ColorRect
var last_day_phase := "morning"
var fade_tween: Tween
var day_tick := 0
const TRANSPORT = preload("res://scripts/transport_state.gd")
var transport = TRANSPORT.new()
var cart_nodes: Dictionary = {}
var rail_nodes: Array = []
var shown_tracks: Array = []
var shaft_nodes: Array = []
var lift_node: Node2D
var lift_riders: Dictionary = {}
var transport_buttons: Dictionary = {}
var transport_info: Label
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
	"ingot": preload("res://assets/textures/ingot.svg"),
	"ore_bin": preload("res://assets/textures/ore_bin.svg")
}
const MINING_STATE = preload("res://scripts/mining_state.gd")
const MINE_POSITION := Vector2(240, 368)
const MINE_OUTPUT := Vector2(194, 356)
var mine_veins: Dictionary = {}
var vein_nodes: Dictionary = {}
var mining = MINING_STATE.new()
var mining_station: Node2D
const CUSTOMER_STATE = preload("res://scripts/customer_state.gd")
var orders = CUSTOMER_STATE.new()
var order_label: Label
const PLAYER = preload("res://scenes/player.tscn")
const WORLD = preload("res://scenes/smithy.tscn")
const ORE_STATE = preload("res://scripts/ore_state.gd")
const BIN_BODY = preload("res://scenes/ore_bin.tscn")
var mobile_bin_button: Button
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
	for vein in range(MAP.VEINS.size()):
		var view := preload("res://scenes/mining_station.tscn").instantiate()
		view.position = MAP.VEINS[vein] - Vector2(390, 288)
		world.add_child(view)
		vein_nodes[vein] = view
	mining_station = vein_nodes[0]
	reset_mining()
	merchant_node = preload("res://scenes/merchant.tscn").instantiate()
	world.add_child(merchant_node)
	init_transport_world()
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
	progression_label = Label.new()
	progression_label.position = Vector2(24, 608)
	progression_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(progression_label)
	init_build_ui(layer)
	init_day_ui(layer)
	refresh_progression()
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
	receive_mining.rpc_id(id, mining_snapshot())
	receive_merchant.rpc_id(id, merchant.snapshot())
	receive_progression.rpc_id(id, progression.snapshot())
	receive_day.rpc_id(id, cycle.snapshot())
	receive_transport.rpc_id(id, transport.snapshot())

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
	dwarf.collision_mask = 17
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
	progression.add(id)
	active = true
	refresh_progression()
	refresh_ore()
	update_status()

func _physics_process(delta: float) -> void:
	if not active or not players.has(multiplayer.get_unique_id()):
		return
	if multiplayer.is_server():
		var previous_phase: String = cycle.phase
		cycle.step(delta, orders, merchant)
		if previous_phase != cycle.phase:
			broadcast_state("receive_orders", [orders.snapshot()])
			broadcast_state("receive_merchant", [merchant.snapshot()])
			refresh_orders()
			refresh_merchant()
			refresh_mining()
		day_tick += 1
		if day_tick % 3 == 0:
			broadcast_state("receive_day", [cycle.snapshot()])
	refresh_day()
	if cycle.phase in ["summary", "transition"]:
		if multiplayer.is_server():
			for id in players:
				apply_controls(id, Vector2.ZERO, false, false)
				work_held[id] = false
		return
	if Input.is_action_just_pressed("push_cart"):
		if multiplayer.is_server(): toggle_cart_for(1)
		else: request_cart_toggle.rpc_id(1)
	if Input.is_action_just_pressed("climb_up") or Input.is_action_just_pressed("climb_down"):
		var direction := -1 if Input.is_action_just_pressed("climb_up") else 1
		if multiplayer.is_server(): lift_for(1, direction)
		else: request_lift.rpc_id(1, direction)
	if Input.is_action_just_pressed("take_bin_ore"):
		if multiplayer.is_server(): take_bin_for(1)
		else: request_take_bin.rpc_id(1)
	if Input.is_action_just_pressed("cycle_storage"):
		if multiplayer.is_server():
			cycle_storage_for(1)
		else:
			request_storage_cycle.rpc_id(1)
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
			transport.cancel(1, orders)
			sync_transport()
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
		step_transport(delta)
		step_workstations(delta)
		step_mining(delta)
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
			broadcast_state("receive_mining", [mining_snapshot()], false)
			broadcast_state("receive_transport", [transport.snapshot()])
			broadcast_state("receive_merchant", [merchant.snapshot()], false)
	else:
		send_controls.rpc_id(1, axis, jump, climb, Input.is_action_pressed("interact"))

func apply_controls(id: int, axis: Vector2, jump: bool, climb: bool) -> void:
	players[id].controls = axis
	players[id].jump_held = jump
	players[id].climb_held = climb

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_controls(axis: Vector2, jump: bool, climb: bool, work: bool) -> void:
	if not multiplayer.is_server() or not axis.is_finite() or cycle.phase in ["summary", "transition"]:
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
		transport.cancel(id, orders)
		for cart in transport.carts.values():
			if cart.driver == id: cart.driver = 0
		lift_riders.erase(id)
		sync_transport()
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
	progression.dwarfs.erase(id)
	refresh_progression()
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
	if multiplayer.is_server() and cycle.phase not in ["summary", "transition"]:
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
	var bin: bool = ore.pieces[piece_id].kind == "ore_bin"
	var at: Vector2 = dwarf.position + Vector2(direction * 2, (-22 if not drop else -13) if bin else (-18 if not drop else -7))
	if bin: at.x = clampf(at.x, 70, MAP.RIGHT_WALL - 20)
	var motion := Vector2(direction * 280, -180) if not drop else Vector2(direction * 25, 0)
	position_ore(body, at, motion)
	body.angular_velocity = direction * 6 if not drop and not bin else 0
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
		if ore.pieces[piece_id].kind == "ore" and body.linear_velocity.y >= 0:
			for cart in cart_nodes:
				if cart_nodes[cart].get_node("Catch").overlaps_body(body):
					stored = transport.store(cart, piece_id, ore)
					if stored:
						collected = true
						break
		if stored: continue
		if ore.pieces[piece_id].kind in ORE_STATE.BIN_PRODUCTS and body.linear_velocity.y >= 0:
			for bin in ore_bodies:
				if ore.pieces[bin].kind == "ore_bin" and ore.is_loose(bin) and ore_bodies[bin].get_node("Catch").overlaps_body(body):
					stored = ore.store_in_bin(bin, piece_id)
					if stored:
						collected = true
						break
		if stored: continue
		if body.linear_velocity.y >= 0:
			for station_id in workshop.stations:
				var entry: Dictionary = workshop.stations[station_id]
				if entry.kind in WORKSHOP_STATE.STORAGE and WORKSHOP_STATE.STORAGE[entry.kind].group == "intermediate" and station_nodes.has(station_id) and station_nodes[station_id].get_node("PartsCatch").overlaps_body(body):
					stored = workshop.catch_intermediate(station_id, piece_id, ore)
					if stored:
						collected = true
						break
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
		sync_transport()
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
		show_customer(order.id, Vector2(at, 216), "%s: %s %s/%s · %ss" % ["DELIVER" if order.accepted else ("DECIDE" if i == 0 else "WAIT"), order.kind.to_upper(), order.get("delivered", 0), order.get("quantity", 1), ceili(order.remaining)], false)
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
			text += "\n%s #%s: %s %s/%s · %s · %ss · %sg each" % ["FRONT" if i == 0 else "QUEUED", order.id, order.kind.capitalize(), order.get("delivered", 0), order.get("quantity", 1), phase, ceili(order.remaining), progression.sale_price(multiplayer.get_unique_id(), CUSTOMER_STATE.PRICES[order.kind])]
		text += "\nNext arrival: %ss · E serves FRONT only" % ceili(orders.until_arrival) if cycle.phase == "shop" else "\nShop closed to new arrivals · E serves FRONT only"
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
	var body: RigidBody2D = (BIN_BODY if ore.pieces[id].kind == "ore_bin" else ORE_BODY).instantiate()
	body.name = "Ore_%s" % id
	world.add_child(body)
	body.global_position = world.to_global(at)
	body.freeze = not simulate
	body.collision_layer = 4 if simulate else 0
	body.collision_mask = 29 if simulate else 0
	ore_bodies[id] = body
	return body

func vein_at(at: Vector2) -> int:
	for vein in range(MAP.VEINS.size()):
		var target: Vector2 = MAP.VEINS[vein]
		if absf(at.x - target.x) <= 20 and absf(at.y - target.y) <= 6: return vein
	return -1

func near_mine(dwarf: CharacterBody2D) -> bool:
	return vein_at(dwarf.position) != -1

func reset_mining() -> void:
	mine_veins.clear()
	for vein in range(MAP.VEINS.size()): mine_veins[vein] = MINING_STATE.new()
	mining = mine_veins[0]

func mining_snapshot() -> Dictionary:
	var state: Dictionary = {}
	for vein in mine_veins: state[vein] = mine_veins[vein].snapshot()
	return state

func step_mining(delta: float) -> void:
	for vein in mine_veins:
		var job = mine_veins[vein]
		var eligible: Array[int] = []
		if cycle.phase == "shop":
			for id in players:
				var dwarf = players[id]
				if not workshop.pending.has(id) and work_held.get(id, false) and vein_at(dwarf.position) == vein and not dwarf.transport_locked and dwarf.is_on_floor() and not dwarf.climbing and dwarf.hit_stun == 0 and dwarf.controls.is_zero_approx() and not dwarf.jump_held and ore.carried_by(id) == -1:
					eligible.append(id)
		eligible.sort()
		var worker: int = job.worker if job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		if job.step(delta * progression.speed(worker, "mining"), eligible):
			award_exp(worker, "mining")
			var piece_id: int = ore.add_mined_ore()
			var output: Vector2 = MAP.VEINS[vein] + Vector2(-46, -12)
			var body := create_ore_body(piece_id, true, output)
			position_ore(body, output, Vector2(0, 20))
			broadcast_state("receive_ore", [ore.snapshot()], true)
			broadcast_state("receive_ore_motion", [ore_motion()], false)
			broadcast_state("receive_mining", [mining_snapshot()], false)
	refresh_mining()

@rpc("authority", "call_remote", "reliable")
func receive_mining(state: Dictionary) -> void:
	for vein in mine_veins:
		mine_veins[vein].restore(state[vein])
	refresh_mining()

func refresh_mining() -> void:
	for vein in vein_nodes:
		if not mine_veins.has(vein): continue
		var job = mine_veins[vein]
		var view: Node2D = vein_nodes[vein]
		view.get_node("Progress").value = job.progress
		var duration: float = MINING_STATE.DURATION / progression.speed(job.worker if job.worker != 0 else multiplayer.get_unique_id(), "mining")
		var text := "HOLD E: MINE · %.1fs" % duration
		if cycle.phase != "shop": text = "VEIN CLOSED"
		elif job.progress > 0:
			text = "%s %s%% · %.1fs per ore" % ["MINING" if job.worker != 0 else "PAUSED", roundi(job.progress / MINING_STATE.DURATION * 100), duration]
		view.get_node("WorkLabel").text = text

@rpc("any_peer", "call_remote", "reliable")
func request_recipe(choice: String) -> void:
	if multiplayer.is_server():
		choose_recipe(multiplayer.get_remote_sender_id(), choice)


@rpc("any_peer", "call_remote", "reliable")
func request_wood() -> void:
	if multiplayer.is_server():
		buy_wood_for(multiplayer.get_remote_sender_id())

func buy_wood_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase != "shop":
		return
	var piece_id: int = merchant.buy(id, players[id].position, orders, ore, progression.purchase_price(id, MERCHANT_STATE.WOOD_PRICE))
	if piece_id == -1:
		var message := "B buys wood: stand by the merchant with empty hands, %s coins and stock available." % progression.purchase_price(id, MERCHANT_STATE.WOOD_PRICE)
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
		if cycle.phase != "shop":
			merchant_label.text = "Merchant visits during shop hours."
			return
		merchant_label.text = "Merchant: B buys wood for %s coins · Stock: %s · Leaves in %ss" % [progression.purchase_price(multiplayer.get_unique_id(), MERCHANT_STATE.WOOD_PRICE), merchant.stock, ceili(merchant.remaining)] if merchant.remaining > 0 else "Merchant returns in %ss · Wood costs %s coins (B nearby)" % [ceili(merchant.until_visit), progression.purchase_price(multiplayer.get_unique_id(), MERCHANT_STATE.WOOD_PRICE)]

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
	if not multiplayer.is_server() or not players.has(id) or workshop.pending.has(id) or cycle.phase in ["summary", "transition"]:
		return
	var now := Time.get_ticks_msec()
	if now - last_interaction.get(id, -1000) < 150:
		return
	last_interaction[id] = now
	var dwarf = players[id]
	var carried: int = ore.carried_by(id)
	var message := "E: pick up/load · Hold E: work · Tab: build · R: pack idle station"
	var object: int = nearest_loose(dwarf.position)
	var bin: int = nearest_mobile_bin(dwarf.position)
	var cart: int = nearest_cart(dwarf.position)
	if carried == -1 and object != -1 and ore.pickup(id, object):
		message = "Picked up %s. F: throw · Q: drop" % ("movable parts bin" if ore.pieces[object].kind == "ore_bin" else ore.pieces[object].kind.replace("_", " "))
	elif carried == -1 and cart != -1:
		message = "Took one ore from cart." if transport.take(cart, id, ore) else "Cart is empty. C: push cart."
		sync_transport()
	elif carried != -1 and cart != -1 and transport.deposit(cart, id, ore):
		message = "Ore loaded into cart. E: take ore with empty hands · C: push cart."
		sync_transport()
	elif carried != -1 and bin != -1 and ore.deposit_in_bin(id, bin):
		message = "Intermediate product stored. G: take one out with empty hands."
	elif near_mine(dwarf):
		message = "Mine closed until shop hours." if cycle.phase != "shop" else "Hold E with empty hands to mine ore. Prospector speeds up extraction."
	elif absf(dwarf.position.x - 166) <= 30 and absf(dwarf.position.y - 216) <= 6 and not orders.queue.is_empty() and carried != -1:
		var request: Dictionary = orders.queue[0]
		var product: String = request.kind
		var completed_before: int = orders.completed
		var sold: bool = orders.deliver(id, dwarf.position, ore, 1.0 + 0.1 * progression.rank(id, "sales"))
		if sold:
			var result := "Order complete! +2 reputation." if orders.completed > completed_before else "%s more needed." % (request.get("quantity", 1) - request.delivered)
			message = "%s delivered! +%s coins. %s" % [product.capitalize(), progression.sale_price(id, CUSTOMER_STATE.PRICES[product]), result]
		else:
			message = "Y: accept or N: reject this request first." if not request.accepted else "Front customer needs a %s." % product
		if sold:
			award_exp(id, "delivery")
		broadcast_state("receive_orders", [orders.snapshot()])
		refresh_orders()
	else:
		var station_id: int = workshop.nearest(dwarf.position)
		if station_id != -1 and workshop.stations[station_id].kind in WORKSHOP_STATE.STORAGE:
			var transferred: bool = workshop.storage_transfer(id, dwarf.position, ore)
			message = "Stored item." if transferred and carried != -1 else ("Retrieved item. T: select another stored product." if transferred else "Storage: check category, capacity and selected product. T: cycle products.")
			broadcast_state("receive_workshop", [workshop.snapshot()])
			refresh_workshop()
		elif carried != -1 and station_id != -1:
			var job = workshop.stations[station_id].job
			message = "Ingredient loaded. Hold E with empty hands to work." if job.load_material(id, ore) else ("Throw ore into the attached forge bin, then hold E to smelt." if job.kind == "forge" else "Wrong or duplicate ingredient for this station recipe.")
			broadcast_state("receive_workshop", [workshop.snapshot()])
			refresh_workshop()

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
		body.collision_mask = 29 if loose and multiplayer.is_server() else 0
		if ore.pieces[piece_id].kind == "ore_bin":
			body.get_node("Catch").monitoring = loose and multiplayer.is_server()
			body.get_node("Count").text = "PARTS %s/10 · G: take" % ore.pieces[piece_id].contents.size()
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
	transport = TRANSPORT.new()
	lift_riders.clear()
	refresh_transport()
	progression = PROGRESSION.new()
	refresh_progression()
	workshop = WORKSHOP_STATE.new()
	refresh_workshop()
	reset_mining()
	refresh_mining()
	orders = CUSTOMER_STATE.new()
	cycle = DAY_STATE.new()
	refresh_day()
	merchant = MERCHANT_STATE.new()
	refresh_orders()
	refresh_merchant()
	work_held.clear()
	for id in ore.pieces:
		create_ore_body(id, simulate, Vector2(210 + id * 8, 281 - (id % 2) * 3))
	refresh_ore()

func choose_recipe(id: int, choice: String) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	var station_id: int = workshop.nearest(players[id].position)
	if station_id != -1 and workshop.stations[station_id].job.select(choice):
		broadcast_state("receive_workshop", [workshop.snapshot()])
		refresh_workshop()

func step_workstations(delta: float) -> void:
	var changed := false
	for station_id in workshop.stations:
		var entry: Dictionary = workshop.stations[station_id]
		if entry.kind in WORKSHOP_STATE.STORAGE:
			continue
		var eligible: Array[int] = []
		for id in players:
			var dwarf = players[id]
			if work_held.get(id, false) and workshop.nearest(dwarf.position) == station_id and not workshop.pending.has(id) and not dwarf.transport_locked and dwarf.is_on_floor() and not dwarf.climbing and dwarf.hit_stun == 0 and dwarf.controls.is_zero_approx() and not dwarf.jump_held and ore.carried_by(id) == -1:
				eligible.append(id)
		eligible.sort()
		var worker: int = entry.job.worker if entry.job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		var specialty := "woodworking" if entry.kind == "woodbench" else "smithing"
		var output: int = entry.job.step(delta * progression.speed(worker, specialty), eligible, ore)
		if output != -1:
			award_exp(worker, "crafting")
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
		station_nodes[id].update_view(workshop.stations[id], ore)
	if recipe_label != null:
		recipe_label.visible = active
		recipe_label.text = "Tab: build / skills · R: pack idle station · Anvil: 1 Horseshoe  2 Blade  3 Axe head  4 Assemble axe"
	if build_button != null:
		build_button.visible = active

func init_build_ui(layer: CanvasLayer) -> void:
	build_ghost = Sprite2D.new()
	build_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(build_ghost)
	build_ghost.hide()
	build_button = Button.new()
	build_button.text = "Build / Skills [Tab]"
	build_button.position = Vector2(820, 642)
	build_button.pressed.connect(func(): catalog.visible = not catalog.visible)
	build_button.focus_mode = Control.FOCUS_NONE
	layer.add_child(build_button)
	catalog = PanelContainer.new()
	catalog.position = Vector2(500, 160)
	catalog.custom_minimum_size = Vector2(730, 430)
	layer.add_child(catalog)
	catalog_tabs = TabContainer.new()
	catalog.add_child(catalog_tabs)
	var column := VBoxContainer.new()
	column.name = "Build"
	catalog_tabs.add_child(column)
	var title := Label.new()
	title.text = "Buy stations or storage (empty hands)"
	column.add_child(title)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 24)
	column.add_child(choices)
	var stations_column := VBoxContainer.new()
	var storage_column := VBoxContainer.new()
	choices.add_child(stations_column)
	choices.add_child(storage_column)
	for kind in WORKSHOP_STATE.PRICES:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): buy_station(kind))
		(storage_column if kind in WORKSHOP_STATE.STORAGE else stations_column).add_child(button)
		station_buttons[kind] = button
	mobile_bin_button = Button.new()
	mobile_bin_button.focus_mode = Control.FOCUS_NONE
	mobile_bin_button.pressed.connect(buy_mobile_bin)
	storage_column.add_child(mobile_bin_button)
	var help := Label.new()
	help.text = "After buying: click a green floor preview.\nRed: blocked. Esc: cancel/refund kit.\nR beside an empty station: pack/move.\nTAB closes this menu; the game continues while it is open."
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)
	var skills := VBoxContainer.new()
	skills.name = "Skills"
	catalog_tabs.add_child(skills)
	skill_summary = Label.new()
	skills.add_child(skill_summary)
	var branches := HBoxContainer.new()
	branches.add_theme_constant_override("separation", 16)
	skills.add_child(branches)
	for branch in ["Craft", "Trade"]:
		var path := VBoxContainer.new()
		path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branches.add_child(path)
		var heading := Label.new()
		heading.text = branch + " · each rank costs 1 skill point"
		path.add_child(heading)
		for key in PROGRESSION.SKILLS:
			var definition: Dictionary = PROGRESSION.SKILLS[key]
			if definition.branch != branch:
				continue
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func(): buy_skill(key))
			path.add_child(button)
			skill_buttons[key] = button
			var detail := Label.new()
			detail.text = definition.effect.replace("anvil, grinder and forge", "metalwork")
			detail.add_theme_font_size_override("font_size", 12)
			path.add_child(detail)
	var help_skills := Label.new()
	help_skills.text = "Complete mining: +2 EXP · Station work: +3 EXP · Delivery: +5 EXP\nEXP goes to the completing worker. Progress lasts for this session.\nPurchase prices round up to whole coins. Unanswered requests still cost 3 reputation."
	help_skills.add_theme_font_size_override("font_size", 12)
	skills.add_child(help_skills)
	init_transport_ui()
	catalog.hide()

func _process(_delta: float) -> void:
	if build_ghost == null:
		return
	var id := multiplayer.get_unique_id()
	var carrying_kit: bool = active and cycle.phase not in ["summary", "transition"] and workshop.pending.has(id)
	build_ghost.visible = carrying_kit
	if carrying_kit:
		catalog.hide()
		var at: Vector2 = workshop.snap(world.get_local_mouse_position())
		build_ghost.position = at + Vector2(8, -16)
		build_ghost.texture = STATION_VIEW.TEXTURES[workshop.pending[id].kind]
		build_ghost.modulate = Color(0.4, 1, 0.5, 0.7) if workshop.can_place(at) else Color(1, 0.3, 0.3, 0.7)
	if active and transport.pending.has(id) and cycle.phase not in ["summary", "transition"]:
		catalog.hide()
		var at: Vector2 = transport.snap_rail(world.get_local_mouse_position())
		build_ghost.visible = true
		build_ghost.texture = preload("res://assets/textures/rail.svg")
		build_ghost.position = at - Vector2(0, 2)
		build_ghost.modulate = Color(0.4, 1, 0.5, 0.7) if transport.can_rail(at) else Color(1, 0.3, 0.3, 0.7)
	if not active:
		catalog.hide()

func _unhandled_input(event: InputEvent) -> void:
	if active and build_ghost != null and build_ghost.visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if transport.pending.has(multiplayer.get_unique_id()):
			var rail: Vector2 = transport.snap_rail(world.get_global_transform_with_canvas().affine_inverse() * event.position)
			if multiplayer.is_server(): place_rail_for(1, rail)
			else: request_rail_place.rpc_id(1, rail)
			get_viewport().set_input_as_handled()
			return
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
	if not multiplayer.is_server() or not players.has(id) or transport.pending.has(id) or cycle.phase in ["summary", "transition"]:
		return
	if not workshop.purchase(id, kind, orders, ore, 1.0 - 0.1 * progression.rank(id, "purchasing")):
		feedback_for(id, "Cannot buy: check coins, empty hands, and any unplaced kit.")
	sync_build()

@rpc("any_peer", "call_remote", "reliable")
func request_place(at: Vector2) -> void:
	if multiplayer.is_server():
		place_for(multiplayer.get_remote_sender_id(), at)

func place_for(id: int, at: Vector2) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	if workshop.place(id, at) == -1:
		feedback_for(id, "Blocked placement: keep paths, fixed fixtures, and other stations clear.")
	sync_build()

@rpc("any_peer", "call_remote", "reliable")
func request_cancel_build() -> void:
	if multiplayer.is_server():
		cancel_build_for(multiplayer.get_remote_sender_id())

func cancel_build_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	transport.cancel(id, orders)
	sync_transport()
	workshop.cancel(id, orders)
	sync_build()

@rpc("any_peer", "call_remote", "reliable")
func request_pack() -> void:
	if multiplayer.is_server():
		pack_for(multiplayer.get_remote_sender_id())

func pack_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id) or transport.pending.has(id) or cycle.phase in ["summary", "transition"]:
		return
	if not workshop.pack(id, players[id].position, ore):
		feedback_for(id, "Only empty, idle stations or containers can be packed; keep your hands free.")
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
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	var changed: bool = orders.decide(id, players[id].position, order_id, accept, progression.reject_cost(id))
	var message := "Request accepted: deliver within 30 seconds (+2 reputation)." if accept else "Request rejected: -%s reputation." % progression.reject_cost(id)
	if not changed:
		message = "Decide on the front request at the counter. Already accepted or stale requests cannot be rejected."
	feedback_for(id, message)
	broadcast_state("receive_orders", [orders.snapshot()])
	refresh_orders()

func award_exp(id: int, task: String) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	if progression.award(id, task):
		feedback_for(id, "Level %s! +1 skill point. TAB → Skills" % progression.dwarfs[id].level)
	sync_progression()

func sync_progression() -> void:
	refresh_progression()
	broadcast_state("receive_progression", [progression.snapshot()])

@rpc("authority", "call_remote", "reliable")
func receive_progression(state: Dictionary) -> void:
	progression.restore(state)
	refresh_progression()
	refresh_merchant()
	refresh_mining()

func buy_skill(skill: String) -> void:
	if multiplayer.is_server():
		purchase_skill_for(1, skill)
	else:
		request_skill.rpc_id(1, skill)

@rpc("any_peer", "call_remote", "reliable")
func request_skill(skill: String) -> void:
	if multiplayer.is_server():
		purchase_skill_for(multiplayer.get_remote_sender_id(), skill)

func purchase_skill_for(id: int, skill: String) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	var bought: bool = progression.buy(id, skill)
	feedback_for(id, "Skill upgraded: %s" % PROGRESSION.SKILLS[skill].title if bought else "Cannot upgrade: check points, prerequisites and maximum rank.")
	sync_progression()
	refresh_merchant()
	refresh_orders()
	refresh_mining()

func refresh_progression() -> void:
	for id in players:
		players[id].walking_multiplier = progression.speed(id, "walking")
	var local := multiplayer.get_unique_id()
	if progression_label == null:
		return
	progression_label.visible = active
	var text := "Level 1 · EXP 0 / 10 · 0 skill points · TAB: Skills"
	if progression.dwarfs.has(local):
		var dwarf: Dictionary = progression.dwarfs[local]
		text = "Level %s · EXP %s / %s · %s skill points · TAB: Skills" % [dwarf.level, dwarf.exp, progression.required(dwarf.level), dwarf.points]
	progression_label.text = text
	if skill_summary != null:
		skill_summary.text = text
	for key in skill_buttons:
		var definition: Dictionary = PROGRESSION.SKILLS[key]
		var prerequisite: String = "" if definition.parent == "" else "← " + PROGRESSION.SKILLS[definition.parent].title + " · "
		skill_buttons[key].text = "%s%s [%s/%s] +" % [prerequisite, definition.title, progression.rank(local, key), definition.max]
		skill_buttons[key].disabled = not progression.can_buy(local, key)
	if mobile_bin_button != null:
		mobile_bin_button.text = "Movable parts bin (10) · %s coins" % progression.purchase_price(local, ORE_STATE.BIN_PRICE)
	for kind in station_buttons:
		station_buttons[kind].text = "%s · %s coins" % [WORKSHOP_STATE.display_name(kind), progression.purchase_price(local, WORKSHOP_STATE.PRICES[kind])]

func init_day_ui(layer: CanvasLayer) -> void:
	day_label = Label.new()
	day_label.position = Vector2(24, 12)
	layer.add_child(day_label)
	open_button = Button.new()
	open_button.position = Vector2(24, 44)
	open_button.text = "Open shop · Start shop hours"
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.pressed.connect(advance_day)
	layer.add_child(open_button)
	# A full-screen blocker makes the shared summary modal.
	var modal := Control.new()
	modal.name = "DayModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(modal)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	day_popup = PanelContainer.new()
	day_popup.position = Vector2(430, 160)
	day_popup.custom_minimum_size = Vector2(420, 350)
	modal.add_child(day_popup)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	day_popup.add_child(column)
	day_summary = Label.new()
	column.add_child(day_summary)
	next_day_button = Button.new()
	next_day_button.text = "Close summary · Next morning"
	next_day_button.focus_mode = Control.FOCUS_NONE
	next_day_button.pressed.connect(advance_day)
	column.add_child(next_day_button)
	blackout = ColorRect.new()
	blackout.color = Color(0, 0, 0, 0)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(blackout)
	refresh_day()

func advance_day() -> void:
	if multiplayer.is_server():
		advance_day_for(1, cycle.day)
	else:
		request_day_advance.rpc_id(1, cycle.day)

@rpc("any_peer", "call_remote", "reliable")
func request_day_advance(expected_day: int) -> void:
	if multiplayer.is_server():
		advance_day_for(multiplayer.get_remote_sender_id(), expected_day)

func advance_day_for(id: int, expected_day: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	if cycle.advance(expected_day):
		broadcast_state("receive_day", [cycle.snapshot()])
		refresh_day()
		refresh_orders()
		refresh_mining()

@rpc("authority", "call_remote", "reliable")
func receive_day(state: Dictionary) -> void:
	cycle.restore(state)
	refresh_day()
	refresh_orders()
	refresh_mining()

func refresh_day() -> void:
	if day_label == null:
		return
	day_label.visible = active
	day_label.text = "Day %s · %s%s" % [cycle.day, cycle.phase.capitalize(), " · %ss until closing" % ceili(cycle.remaining) if cycle.phase == "shop" else ""]
	open_button.visible = active and cycle.phase == "morning"
	day_popup.get_parent().visible = active and cycle.phase == "summary"
	if cycle.phase in ["summary", "transition"]:
		catalog.hide()
		build_ghost.hide()
	if cycle.phase == "summary":
		var report: Dictionary = cycle.summary
		day_summary.text = "Day %s complete\n\nCustomers: %s\nServed requests: %s\nFailed requests: %s\nRejected / unanswered: %s\nMoney gained: %s\nMoney spent: %s\nRefunds: %s" % [cycle.day, report.customers, report.served, report.failed, report.rejected, report.earned, report.spent, report.refunds]
	if cycle.phase == "transition":
		if fade_tween != null:
			fade_tween.kill()
		blackout.color.a = clampf(cycle.fade / DAY_STATE.FADE_DURATION, 0, 1)
	elif cycle.phase == "morning" and last_day_phase == "transition":
		blackout.color.a = 1
		fade_tween = create_tween()
		fade_tween.tween_property(blackout, "color:a", 0.0, DAY_STATE.FADE_DURATION)
	elif not active:
		if fade_tween != null:
			fade_tween.kill()
		blackout.color.a = 0
	blackout.visible = active
	last_day_phase = cycle.phase

@rpc("any_peer", "call_remote", "reliable")
func request_storage_cycle() -> void:
	if multiplayer.is_server():
		cycle_storage_for(multiplayer.get_remote_sender_id())

func cycle_storage_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	if workshop.cycle_storage(id, players[id].position, ore):
		broadcast_state("receive_workshop", [workshop.snapshot()])
		refresh_workshop()

func nearest_loose(at: Vector2) -> int:
	var nearest := -1
	var distance := 24.0
	for piece in ore_bodies:
		if not ore.is_loose(piece): continue
		var offset: Vector2 = world.to_local(ore_bodies[piece].global_position) - (at - Vector2(0, 8))
		if absf(offset.y) <= 18 and offset.length() < distance:
			nearest = piece
			distance = offset.length()
	return nearest

func nearest_mobile_bin(at: Vector2) -> int:
	var nearest := -1
	var distance := 32.0
	for piece in ore_bodies:
		if ore.pieces[piece].kind != "ore_bin" or not ore.is_loose(piece): continue
		var offset: Vector2 = world.to_local(ore_bodies[piece].global_position) - (at - Vector2(0, 8))
		if absf(offset.y) <= 18 and offset.length() < distance:
			nearest = piece
			distance = offset.length()
	return nearest

func buy_mobile_bin() -> void:
	catalog.hide()
	if multiplayer.is_server(): purchase_mobile_bin_for(1)
	else: request_mobile_bin.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_mobile_bin() -> void:
	if multiplayer.is_server(): purchase_mobile_bin_for(multiplayer.get_remote_sender_id())

func purchase_mobile_bin_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"] or workshop.pending.has(id) or transport.pending.has(id) or ore.carried_by(id) != -1: return
	var price: int = progression.purchase_price(id, ORE_STATE.BIN_PRICE)
	if orders.coins < price:
		feedback_for(id, "Not enough coins for a parts bin.")
		return
	orders.coins -= price
	orders.spent += price
	var bin: int = ore.add_material("ore_bin")
	ore.pickup(id, bin)
	broadcast_state("receive_ore", [ore.snapshot()], true)
	broadcast_state("receive_orders", [orders.snapshot()])
	refresh_orders()
	catalog.hide()
	feedback_for(id, "Movable parts bin: Q drops, F throws. Holds 10 intermediate products. G takes one out with empty hands.")

@rpc("any_peer", "call_remote", "reliable")
func request_take_bin() -> void:
	if multiplayer.is_server(): take_bin_for(multiplayer.get_remote_sender_id())

func take_bin_for(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id) or workshop.pending.has(id) or cycle.phase in ["summary", "transition"]: return
	var bin := nearest_mobile_bin(players[id].position)
	if bin != -1 and ore.take_from_bin(id, bin):
		broadcast_state("receive_ore", [ore.snapshot()], true)
		feedback_for(id, "Took one intermediate product from movable bin.")

func init_transport_world() -> void:
	lift_node = Node2D.new()
	lift_node.z_index = 10
	world.add_child(lift_node)
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/textures/elevator.svg")
	sprite.position = Vector2(0, -24)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lift_node.add_child(sprite)
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 2
	lift_node.add_child(body)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(32, 4)
	shape.shape = rectangle
	shape.one_way_collision = true
	shape.one_way_collision_margin = 1.0
	shape.position.y = 2
	body.add_child(shape)

func init_transport_ui() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Transport"
	catalog_tabs.add_child(tab)
	transport_info = Label.new()
	tab.add_child(transport_info)
	for level in range(1, 4):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): transport_buy("lift", level))
		tab.add_child(button)
		transport_buttons[level] = button
	for kind in ["rail", "cart"]:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): transport_buy(kind, 0))
		tab.add_child(button)
		transport_buttons[kind] = button
	var help := Label.new()
	help.text = "Rails: buy, then click a green extension. Esc refunds.\nRails start beside each unlocked elevator landing.\nAt the shaft: W/S calls or rides the lift.\nCart: C couples/releases · A/D pushes · Jump releases.\nE loads/takes ore · Cart capacity: 25 ore."
	help.add_theme_font_size_override("font_size", 12)
	tab.add_child(help)
	refresh_transport()

func transport_buy(kind: String, level: int) -> void:
	if multiplayer.is_server(): buy_transport_for(1, kind, level)
	else: request_transport_buy.rpc_id(1, kind, level)

@rpc("any_peer", "call_remote", "reliable")
func request_transport_buy(kind: String, level: int) -> void:
	if multiplayer.is_server(): buy_transport_for(multiplayer.get_remote_sender_id(), kind, level)

func buy_transport_for(id: int, kind: String, level: int) -> void:
	if not transport_allowed(id) or ore.carried_by(id) != -1 or workshop.pending.has(id) or transport.pending.has(id): return
	var ok := false
	if kind == "lift": ok = transport.upgrade(level, orders, progression.purchase_price(id, TRANSPORT.UPGRADE_PRICE))
	elif kind == "rail": ok = transport.buy_rail(id, orders, progression.purchase_price(id, TRANSPORT.RAIL_PRICE))
	elif kind == "cart":
		var at: Vector2 = players[id].position
		for rail in transport.tracks:
			if absf(rail.y - at.y) < 6 and absf(rail.x - at.x) < 24:
				ok = transport.buy_cart(rail, orders, progression.purchase_price(id, TRANSPORT.CART_PRICE)) != -1
				break
	feedback_for(id, "Transport purchased." if ok else "Cannot buy: check coins, empty hands, upgrade order, and nearby rails for a cart.")
	sync_transport()

func transport_allowed(id: int) -> bool:
	return multiplayer.is_server() and players.has(id) and cycle.phase not in ["summary", "transition"]

@rpc("any_peer", "call_remote", "reliable")
func request_rail_place(at: Vector2) -> void:
	if multiplayer.is_server(): place_rail_for(multiplayer.get_remote_sender_id(), at)

func place_rail_for(id: int, at: Vector2) -> void:
	if transport_allowed(id):
		transport.place_rail(id, at)
		sync_transport()

func nearest_cart(at: Vector2) -> int:
	var nearest := -1
	var distance := 36.0
	for id in transport.carts:
		var offset: Vector2 = transport.carts[id].at - at
		if absf(offset.y) <= 8 and offset.length() < distance:
			nearest = id
			distance = offset.length()
	return nearest

@rpc("any_peer", "call_remote", "reliable")
func request_cart_toggle() -> void:
	if multiplayer.is_server(): toggle_cart_for(multiplayer.get_remote_sender_id())

func toggle_cart_for(id: int) -> void:
	if not transport_allowed(id): return
	for cart in transport.carts.values():
		if cart.driver == id:
			cart.driver = 0
			players[id].transport_locked = false
			sync_transport()
			return
	var cart := nearest_cart(players[id].position)
	if cart != -1 and ore.carried_by(id) == -1 and transport.carts[cart].driver == 0 and not transport.moving:
		transport.carts[cart].driver = id
		sync_transport()

@rpc("any_peer", "call_remote", "reliable")
func request_lift(direction: int) -> void:
	if multiplayer.is_server(): lift_for(multiplayer.get_remote_sender_id(), direction)

func lift_for(id: int, direction: int) -> void:
	if not transport_allowed(id) or direction not in [-1, 1] or absf(players[id].position.x - 390) > 30: return
	var stop := -1
	for i in range(transport.upgrades + 1):
		if absf(players[id].position.y - TRANSPORT.STOPS[i]) < 6: stop = i
	if stop == -1: return
	var aboard: bool = absf(players[id].position.x - 390) <= 16
	for cart in transport.carts.values():
		if cart.driver == id and absf(cart.at.x - 390) <= 16: aboard = true
	if absf(transport.lift_y - TRANSPORT.STOPS[stop]) <= 2 and not aboard: return
	var destination := stop if absf(transport.lift_y - TRANSPORT.STOPS[stop]) > 2 else stop + direction
	var old: float = transport.lift_y
	if transport.start_lift(destination):
		lift_riders.clear()
		for peer in players:
			if absf(players[peer].position.x - 390) <= 16 and absf(players[peer].position.y - old) < 6:
				lift_riders[peer] = true
				players[peer].climbing = false
				players[peer].transport_locked = true
		sync_transport()

func step_transport(delta: float) -> void:
	for id in players: players[id].transport_locked = false
	var previous: Dictionary = {}
	for id in transport.carts: previous[id] = transport.carts[id].at
	var riders: Dictionary = lift_riders.duplicate()
	transport.step_lift(delta)
	for id in lift_riders:
		if players.has(id):
			players[id].transport_locked = true
			players[id].position = Vector2(players[id].position.x, transport.lift_y)
			players[id].velocity = Vector2.ZERO
	if not transport.moving: lift_riders.clear()
	for cart in transport.carts.values():
		var driver: int = cart.driver
		if not players.has(driver) or players[driver].jump_held or ore.carried_by(driver) != -1:
			cart.driver = 0
			continue
		var id: int = transport.carts.find_key(cart)
		if not lift_riders.has(driver): transport.move_cart(id, players[driver].controls.x * 70 * delta)
		players[driver].transport_locked = true
		players[driver].position.x = TRANSPORT.follow_cart_x(players[driver].position.x, previous[id].x, cart.at.x)
		if not riders.has(driver): players[driver].position.y += cart.at.y - previous[id].y
		players[driver].velocity = Vector2.ZERO
	refresh_transport()

func sync_transport() -> void:
	refresh_transport()
	broadcast_state("receive_transport", [transport.snapshot()])
	broadcast_state("receive_orders", [orders.snapshot()])
	refresh_orders()

@rpc("authority", "call_remote", "reliable")
func receive_transport(state: Dictionary) -> void:
	transport.restore(state)
	refresh_transport()

func refresh_transport() -> void:
	if lift_node == null: return
	lift_node.visible = transport.upgrades > 0
	lift_node.position = Vector2(390, transport.lift_y)
	lift_node.get_child(1).collision_layer = 16 if transport.upgrades > 0 else 0
	for id in players: players[id].mine_ladder_top = 288.0 + transport.upgrades * 80
	while shaft_nodes.size() < transport.upgrades:
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/textures/shaft_lift.svg")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -9
		sprite.position = Vector2(390, 328 + shaft_nodes.size() * 80)
		world.add_child(sprite)
		shaft_nodes.append(sprite)
	for i in range(shaft_nodes.size()): shaft_nodes[i].visible = i < transport.upgrades
	if shown_tracks != transport.tracks:
		shown_tracks = transport.tracks.duplicate()
		for node in rail_nodes: node.free()
		rail_nodes.clear()
		for at in transport.tracks:
			var sprite := Sprite2D.new()
			sprite.texture = preload("res://assets/textures/rail.svg")
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = at - Vector2(0, 2)
			sprite.z_index = 10
			world.add_child(sprite)
			rail_nodes.append(sprite)
	for id in cart_nodes.keys():
		if not transport.carts.has(id):
			cart_nodes[id].free()
			cart_nodes.erase(id)
	for id in transport.carts:
		if not cart_nodes.has(id):
			cart_nodes[id] = preload("res://scenes/mine_cart.tscn").instantiate()
			world.add_child(cart_nodes[id])
		cart_nodes[id].position = transport.carts[id].at
		cart_nodes[id].get_node("Catch").monitoring = active and multiplayer.is_server()
		cart_nodes[id].get_node("Count").text = "ORE %s/25 · C: push · E: load/take" % transport.carts[id].items.size()
	if transport_info != null:
		transport_info.text = "Elevator: %s/3 segments · Rails: %s · Carts: %s" % [transport.upgrades, transport.tracks.size(), transport.carts.size()]
		var id := multiplayer.get_unique_id()
		for level in range(1, 4):
			transport_buttons[level].text = "Upgrade elevator to mine level %s · %s coins" % [level, progression.purchase_price(id, TRANSPORT.UPGRADE_PRICE)]
			transport_buttons[level].disabled = level != transport.upgrades + 1
		transport_buttons.rail.text = "Buy rail section · %s coins" % progression.purchase_price(id, TRANSPORT.RAIL_PRICE)
		transport_buttons.cart.text = "Buy mine cart · %s coins (stand beside rails)" % progression.purchase_price(id, TRANSPORT.CART_PRICE)
