extends Node
const INTERACTION_CONTEXT = preload("res://scripts/interaction/context.gd")
const INTERACTION_ROUTER = preload("res://scripts/interaction/router.gd")
const MOVABLE_OBJECTS = preload("res://scripts/controllers/movable_objects.gd")
const PLACEABLES = preload("res://scripts/controllers/placeables.gd")
const NPCS = preload("res://scripts/controllers/npcs.gd")
var interaction_router = INTERACTION_ROUTER.new()
var movable_objects = MOVABLE_OBJECTS.new()
var placeables = PLACEABLES.new()
var npcs = NPCS.new()
const NEEDS = preload("res://scripts/needs_state.gd")
var needs = NEEDS.new()
var supplies = preload("res://scripts/merchant_state.gd").new()
const CATALOG_VIEW = preload("res://scripts/ui/workshop_catalog.gd")
const DAY_VIEW = preload("res://scripts/ui/day_summary.gd")
const EXPANSION_VIEW = preload("res://scripts/ui/expansion_indicators.gd")
const CATALOG_SCENE = preload("res://scenes/ui/workshop_catalog.tscn")
const DAY_UI_SCENE = preload("res://scenes/ui/day_summary.tscn")
const EXPANSION_SCENE = preload("res://scenes/ui/expansion_indicators.tscn")
var workshop_ui: CATALOG_VIEW
var day_ui: DAY_VIEW
var expansion_ui: EXPANSION_VIEW
const HUD = preload("res://scripts/hud.gd")
var hud: HUD
## ENet LAN session. Only the host simulates physics; clients send controls.
const PROGRESSION = preload("res://scripts/progression_state.gd")
var progression = PROGRESSION.new()
const DAY_STATE = preload("res://scripts/day_state.gd")
var cycle = DAY_STATE.new()
var day_tick := 0
const TRANSPORT = preload("res://scripts/transport_state.gd")
var transport = TRANSPORT.new()
var rail_nodes: Array = []
var shown_tracks: Array = []
var shaft_nodes: Array = []
var lift_node: Node2D
var lift_riders: Dictionary = {}
const ROOMS = preload("res://scripts/room_state.gd")
var rooms = ROOMS.new()
const MAP = preload("res://scripts/map_layout.gd")
var overview_camera: Camera2D
const WORKSHOP_STATE = preload("res://scripts/workshop_state.gd")
const STATION_JOB = preload("res://scripts/station_job.gd")
const STATION_SCENE = preload("res://scenes/workstation.tscn")
const STATION_VIEW = preload("res://scripts/station_view.gd")
var workshop = WORKSHOP_STATE.new()
var station_nodes: Dictionary = {}
var build_ghost: Sprite2D
const MERCHANT_STATE = preload("res://scripts/merchant_state.gd")
var merchant = MERCHANT_STATE.new()
var merchant_node: Node2D
var customer_nodes: Dictionary = {}
var recipe_label: Label
const MINING_STATE = preload("res://scripts/mining_state.gd")
const MINE_POSITION := Vector2(320, 448)
const MINE_OUTPUT := Vector2(274, 436)
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
var work_held: Dictionary = {}
var ore = ORE_STATE.new()
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
	init_interactions()
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
	merchant_node = preload("res://scenes/merchant.tscn").instantiate()
	world.add_child(merchant_node)
	init_transport_world()
	reset_game_state(false)
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
	recipe_label = Label.new()
	recipe_label.position = Vector2(24, 664)
	recipe_label.add_theme_font_size_override("font_size", 13)
	layer.add_child(recipe_label)
	refresh_orders()
	refresh_merchant()
	init_ui(layer)
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
	hud = HUD.new()
	hud.setup(self, layer, panel)
	layer.move_child(expansion_ui, 0)
	hud.workshop_requested.connect(workshop_ui.toggle)
	hud.day_advance_requested.connect(advance_day)
	refresh_day()
	refresh_progression()
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
	reset_game_state(true)
	spawn_player(1, Vector2(220, 216))
	if hud != null: hud.reset_events()
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
	receive_rooms.rpc_id(id, rooms.snapshot())
	receive_ore.rpc_id(id, ore.snapshot())
	receive_ore_motion.rpc_id(id, movable_objects.motion_snapshot())
	receive_workshop.rpc_id(id, workshop.snapshot())
	receive_orders.rpc_id(id, orders.snapshot())
	receive_mining.rpc_id(id, mining_snapshot())
	receive_merchant.rpc_id(id, merchant.snapshot())
	receive_progression.rpc_id(id, progression.snapshot())
	receive_needs.rpc_id(id, needs.snapshot())
	receive_supplies.rpc_id(id, supplies.snapshot())
	receive_day.rpc_id(id, cycle.snapshot())
	receive_transport.rpc_id(id, transport.snapshot())
	initialize_hud_events.rpc_id(id)

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
	dwarf.set_ladders(rooms.ladders())
	dwarf.mine_ladder_top = TRANSPORT.STOPS[transport.upgrades]
	configure_camera(dwarf.get_node("FollowCamera"))
	players[id] = dwarf
	progression.add(id)
	needs.add(id)
	active = true
	refresh_progression()
	movable_objects.refresh()
	update_status()

func _physics_process(delta: float) -> void:
	if not active or not players.has(multiplayer.get_unique_id()):
		return
	if multiplayer.is_server():
		if npcs.step(delta):
			broadcast_state("receive_orders", [orders.snapshot()])
			broadcast_state("receive_merchant", [merchant.snapshot()])
			broadcast_state("receive_supplies", [supplies.snapshot()])
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
	if Input.is_action_just_pressed("cycle_storage"):
		if multiplayer.is_server():
			cycle_storage_for(1)
		else:
			request_storage_cycle.rpc_id(1)
	if Input.is_action_just_pressed("build_menu"):
		workshop_ui.toggle()
	if Input.is_action_just_pressed("cancel_build"):
		workshop_ui.hide()
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
		movable_objects.step_loose()
		work_held[1] = Input.is_action_pressed("interact")
		apply_controls(1, axis, jump, climb)
		for id in last_input:
			if Time.get_ticks_msec() - last_input[id] > 500 and players.has(id):
				apply_controls(id, Vector2.ZERO, false, false)
				work_held[id] = false
		step_transport(delta)
		needs.step(delta)
		placeables.step_care(delta)
		placeables.step_workstations(delta)
		placeables.step_mining(delta)
		refresh_workshop()
		refresh_mining()
		refresh_walking()
		refresh_orders()
		refresh_merchant()
		tick += 1
		if tick % 3 == 0:
			var state: Array = []
			for id in players:
				var dwarf = players[id]
				state.append([id, dwarf.position, dwarf.velocity, dwarf.climbing, dwarf.sprite.flip_h])
			broadcast_state("receive_state", [state], false)
			broadcast_state("receive_ore_motion", [movable_objects.motion_snapshot()], false)
			broadcast_state("receive_workshop", [workshop.snapshot()], false)
			broadcast_state("receive_orders", [orders.snapshot()], false)
			broadcast_state("receive_mining", [mining_snapshot()], false)
			broadcast_state("receive_transport", [transport.snapshot()])
			broadcast_state("receive_merchant", [merchant.snapshot()], false)
			broadcast_state("receive_supplies", [supplies.snapshot()])
			broadcast_state("receive_needs", [needs.snapshot()])
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
		movable_objects.forget_actor(id)
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
	movable_objects.forget_actor(id)
	if players.has(id):
		players[id].free()
		players.erase(id)
	progression.dwarfs.erase(id)
	needs.dwarfs.erase(id)
	placeables.forget_actor(id)
	refresh_progression()
	last_input.erase(id)
	work_held.erase(id)
	last_interaction.erase(id)
	update_status()

func update_status() -> void:
	status.text = "%s · UDP %s · %s player%s" % ["Hosting" if multiplayer.is_server() else "Connected", int(port.value), players.size(), "" if players.size() == 1 else "s"]

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
	reset_game_state(false)
	hint.text = ""
	if hud != null:
		hud.last_message = ""
		hud.notice_until = 0
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
	movable_objects.refresh()

@rpc("authority", "call_remote", "reliable")
func interaction_feedback(message: String) -> void:
	hint.text = message
	if hud != null: hud.notify(message)



@rpc("any_peer", "call_remote", "reliable")
func request_throw(drop: bool) -> void:
	if multiplayer.is_server() and cycle.phase not in ["summary", "transition"]:
		release_ore(multiplayer.get_remote_sender_id(), drop)

func release_ore(id: int, drop: bool) -> void:
	if not multiplayer.is_server() or not players.has(id): return
	movable_objects.release(id, drop)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_ore_motion(state: Array) -> void:
	movable_objects.apply_motion(state)

@rpc("authority", "call_remote", "reliable")
func receive_orders(state: Dictionary) -> void:
	orders.restore(state)
	refresh_orders()

func refresh_orders() -> void:
	refresh_expansions()
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
		order_label.visible = false
		var text := "No customers"
		if not orders.queue.is_empty():
			var order: Dictionary = orders.queue[0]
			text = "%s · %s/%s\n%s · %ss\n%s coins each · %s waiting" % [order.kind.capitalize(), order.get("delivered", 0), order.get("quantity", 1), "Accepted" if order.accepted else "Awaiting decision", ceili(order.remaining), progression.sale_price(multiplayer.get_unique_id(), CUSTOMER_STATE.PRICES[order.kind]), orders.queue.size() - 1]

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

func vein_at(at: Vector2) -> int:
	for vein in mine_veins:
		var target: Vector2 = MAP.VEINS[vein]
		if absf(at.x - target.x) <= 20 and absf(at.y - target.y) <= 6: return vein
	return -1

func near_mine(dwarf: CharacterBody2D) -> bool:
	return vein_at(dwarf.position) != -1

func reset_mining() -> void:
	mine_veins.clear()
	sync_veins()

func sync_veins() -> void:
	for vein in range(MAP.VEINS.size()):
		var enabled: bool = rooms.contains_floor(MAP.VEINS[vein], true)
		if enabled:
			if not mine_veins.has(vein): mine_veins[vein] = MINING_STATE.new()
			if not vein_nodes.has(vein):
				var view := preload("res://scenes/mining_station.tscn").instantiate()
				view.position = MAP.VEINS[vein] - Vector2(390, 288)
				world.add_child(view)
				vein_nodes[vein] = view
		else:
			mine_veins.erase(vein)
			if vein_nodes.has(vein):
				vein_nodes[vein].free()
				vein_nodes.erase(vein)
	mining = mine_veins.get(0, MINING_STATE.new())
	mining_station = vein_nodes.get(0)

func mining_snapshot() -> Dictionary:
	var state: Dictionary = {}
	for vein in mine_veins: state[vein] = mine_veins[vein].snapshot()
	return state

@rpc("authority", "call_remote", "reliable")
func receive_mining(state: Dictionary) -> void:
	for vein in mine_veins:
		if state.has(vein): mine_veins[vein].restore(state[vein])
	refresh_mining()

func refresh_mining() -> void:
	for vein in vein_nodes:
		if not mine_veins.has(vein): continue
		var job = mine_veins[vein]
		var view: Node2D = vein_nodes[vein]
		view.get_node("Progress").value = job.progress
		view.get_node("Progress").visible = job.progress > 0
		view.get_node("WorkLabel").text = ""
		view.get_node("WorkLabel").hide()

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
	npcs.buy_wood(id, players[id].position)

@rpc("authority", "call_remote", "reliable")
func receive_merchant(state: Dictionary) -> void:
	merchant.restore(state)
	refresh_merchant()

func refresh_merchant() -> void:
	var visiting = visiting_merchant()
	merchant_node.visible = active and visiting.remaining > 0
	merchant_node.modulate = {"wood": Color.WHITE, "ore": Color(0.65, 0.9, 1), "food": Color(0.7, 1, 0.65)}[visiting.kind]

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
	return movable_objects.material_texture(kind)

func interact_for(id: int) -> void:
	if not transport_allowed(id) or workshop.pending.has(id): return
	var now := Time.get_ticks_msec()
	if now - last_interaction.get(id, -1000) < 150: return
	last_interaction[id] = now
	if not route_interaction(id, &"interact"):
		feedback_for(id, "E: pick up/load · Hold E: work · Tab: build · R: pack idle station")

func feedback_for(id: int, message: String) -> void:
	if id == 1:
		interaction_feedback(message)
	else:
		interaction_feedback.rpc_id(id, message)

func reset_game_state(simulate: bool) -> void:
	movable_objects.clear()
	rooms = ROOMS.new()
	ore = ORE_STATE.new()
	transport = TRANSPORT.new()
	transport.room_layout = rooms
	movable_objects.bind(world, players, ore, transport, simulate and active and multiplayer.is_server())
	lift_riders.clear()
	refresh_transport()
	progression = PROGRESSION.new()
	refresh_progression()
	workshop = WORKSHOP_STATE.new()
	workshop.room_layout = rooms
	apply_room_layout()
	refresh_workshop()
	reset_mining()
	refresh_mining()
	orders = CUSTOMER_STATE.new()
	cycle = DAY_STATE.new()
	refresh_day()
	merchant = MERCHANT_STATE.new()
	supplies = MERCHANT_STATE.new()
	supplies.configure_supplies()
	needs = NEEDS.new()
	work_held.clear()
	movable_objects.spawn_initial_items()
	bind_interaction_state()
	refresh_orders()
	refresh_merchant()

func choose_recipe(id: int, choice: String) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	var station_id: int = workshop.nearest(players[id].position)
	if station_id != -1 and workshop.stations[station_id].job.select(choice):
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
		recipe_label.visible = false
		recipe_label.text = ""

func _process(_delta: float) -> void:
	if build_ghost == null:
		return
	var id := multiplayer.get_unique_id()
	var carrying_kit: bool = active and cycle.phase not in ["summary", "transition"] and workshop.pending.has(id)
	build_ghost.visible = carrying_kit
	if carrying_kit:
		workshop_ui.hide()
		var at: Vector2 = workshop.snap(world.get_local_mouse_position())
		build_ghost.position = at + Vector2(8, -16)
		build_ghost.texture = STATION_VIEW.TEXTURES[workshop.pending[id].kind]
		build_ghost.modulate = Color(0.4, 1, 0.5, 0.7) if workshop.can_place(at) else Color(1, 0.3, 0.3, 0.7)
	if active and transport.pending.has(id) and cycle.phase not in ["summary", "transition"]:
		workshop_ui.hide()
		var at: Vector2 = transport.snap_rail(world.get_local_mouse_position())
		build_ghost.visible = true
		build_ghost.texture = preload("res://assets/textures/rail.svg")
		build_ghost.position = at - Vector2(0, 2)
		build_ghost.modulate = Color(0.4, 1, 0.5, 0.7) if transport.can_rail(at) else Color(1, 0.3, 0.3, 0.7)
	if not active:
		workshop_ui.hide()
	refresh_expansions()

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

func configure_camera(camera: Camera2D) -> void:
	var bounds: Rect2 = rooms.bounds().grow(32)
	if bounds.size.y < MAP.CAMERA_HEIGHT:
		bounds = bounds.grow_individual(0, MAP.CAMERA_HEIGHT - bounds.size.y, 0, 0)
	camera.limit_left = floori(bounds.position.x * MAP.SCALE)
	camera.limit_top = floori(bounds.position.y * MAP.SCALE)
	camera.limit_right = ceili(bounds.end.x * MAP.SCALE)
	camera.limit_bottom = ceili(bounds.end.y * MAP.SCALE)

func update_overview() -> void:
	var size := get_viewport().get_visible_rect().size
	var bounds: Rect2 = rooms.bounds().grow(32)
	var factor := minf(size.x / (bounds.size.x * MAP.SCALE), (size.y - 80) / (bounds.size.y * MAP.SCALE))
	overview_camera.zoom = Vector2.ONE * maxf(factor, 0.01)
	overview_camera.global_position = bounds.get_center() * MAP.SCALE
	if not active: overview_camera.force_update_scroll()

@rpc("any_peer", "call_remote", "reliable")
func request_order_decision(order_id: int, accept: bool) -> void:
	if multiplayer.is_server():
		decide_order_for(multiplayer.get_remote_sender_id(), order_id, accept)

func decide_order_for(id: int, order_id: int, accept: bool) -> void:
	if not multiplayer.is_server() or not players.has(id) or cycle.phase in ["summary", "transition"]:
		return
	npcs.decide_order(id, players[id].position, order_id, accept)

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

@rpc("any_peer", "call_remote", "reliable")
func request_storage_cycle() -> void:
	if multiplayer.is_server():
		cycle_storage_for(multiplayer.get_remote_sender_id())

func cycle_storage_for(id: int) -> void:
	route_interaction(id, &"cycle_storage")

func buy_mobile_bin() -> void:
	workshop_ui.hide()
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
	workshop_ui.hide()
	feedback_for(id, "Movable parts bin: Q drops, F throws. Holds 10 intermediate products. E takes a product; C lifts the bin.")


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

@rpc("any_peer", "call_remote", "reliable")
func request_cart_toggle() -> void:
	if multiplayer.is_server(): toggle_cart_for(multiplayer.get_remote_sender_id())

func toggle_cart_for(id: int) -> void:
	route_interaction(id, &"push_cart")

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
	var previous: Dictionary = movable_objects.cart_positions()
	var riders: Dictionary = lift_riders.duplicate()
	transport.step_lift(delta)
	for id in lift_riders:
		if players.has(id):
			players[id].transport_locked = true
			players[id].position = Vector2(players[id].position.x, transport.lift_y)
			players[id].velocity = Vector2.ZERO
	if not transport.moving: lift_riders.clear()
	movable_objects.step_carts(delta, previous, lift_riders, riders)
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
	for id in players: players[id].mine_ladder_top = TRANSPORT.STOPS[transport.upgrades]
	while shaft_nodes.size() < transport.upgrades:
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/textures/shaft_lift.svg")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -9
		var segment := shaft_nodes.size()
		var top: float = TRANSPORT.STOPS[segment]
		var bottom: float = TRANSPORT.STOPS[segment + 1]
		sprite.position = Vector2(390, (top + bottom) / 2)
		sprite.scale.y = (bottom - top) / 80.0
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
	movable_objects.refresh_carts()
	if workshop_ui != null:
		workshop_ui.refresh_transport(multiplayer.get_unique_id(), progression, transport, rooms.depth())

@rpc("authority", "call_remote", "reliable")
func initialize_hud_events() -> void:
	if hud != null: hud.reset_events()

func customer_card_decision(order_id: int, accept: bool) -> void:
	if multiplayer.is_server(): decide_order_for(1, order_id, accept)
	else: request_order_decision.rpc_id(1, order_id, accept)

func merchant_card_buy() -> void:
	var kind: String = visiting_merchant().kind
	if multiplayer.is_server(): buy_goods_for(1, kind)
	else: request_goods.rpc_id(1, kind)

func buy_room(mine: bool, cell: Vector2i) -> void:
	if multiplayer.is_server(): purchase_room_for(1, mine, cell)
	else: request_room.rpc_id(1, mine, cell)

@rpc("any_peer", "call_remote", "reliable")
func request_room(mine: bool, cell: Vector2i) -> void:
	if multiplayer.is_server(): purchase_room_for(multiplayer.get_remote_sender_id(), mine, cell)

func purchase_room_for(id: int, mine: bool, cell: Vector2i) -> void:
	if not transport_allowed(id): return
	var candidate = ROOMS.new()
	candidate.restore(rooms.snapshot())
	var entrance := mine and cell == Vector2i(1, 0)
	var available: bool = candidate.can_open_mine() if entrance else candidate.can_buy(mine, cell)
	if not available:
		feedback_for(id, "Room unavailable: expand beside owned rooms.")
		return
	if entrance:
		candidate.mine_open = true
		candidate.underground[Vector2i(1, 1)] = true
	else:
		var cells: Dictionary = candidate.underground if mine else candidate.building
		cells[cell] = true
	# Reject newly opened ladder paths through existing furniture before charging.
	for ladder in candidate.ladders():
		var zone := Rect2(ladder.get_center().x - 8, ladder.position.y - 40, 16, ladder.size.y + 40)
		for station in workshop.stations.values():
			if workshop.footprint(station.at).intersects(zone):
				feedback_for(id, "Move the station blocking the new ladder first.")
				return
	var multiplier: float = 1.0 - 0.1 * progression.rank(id, "purchasing")
	var bought: bool = rooms.buy_entrance(orders, multiplier) if entrance else rooms.buy(mine, cell, orders, multiplier)
	if not bought:
		feedback_for(id, "Not enough coins for this expansion.")
		return
	apply_room_layout()
	broadcast_state("receive_rooms", [rooms.snapshot()])
	broadcast_state("receive_mining", [mining_snapshot()])
	broadcast_state("receive_orders", [orders.snapshot()])
	refresh_orders()
	feedback_for(id, "Mine entrance opened." if entrance else "Room purchased.")

func apply_room_layout() -> void:
	world.configure(rooms)
	workshop.room_layout = rooms
	transport.room_layout = rooms
	for dwarf in players.values():
		dwarf.set_ladders(rooms.ladders())
		configure_camera(dwarf.get_node("FollowCamera"))
	sync_veins()
	refresh_mining()
	refresh_expansions()
	refresh_transport()
	update_overview()

@rpc("authority", "call_remote", "reliable")
func receive_rooms(state: Dictionary) -> void:
	rooms.restore(state)
	apply_room_layout()

func refresh_walking() -> void:
	for id in players: players[id].walking_multiplier = progression.speed(id, "walking") * needs.walking(id)

@rpc("authority", "call_remote", "reliable")
func receive_needs(state: Dictionary) -> void:
	needs.restore(state)
	refresh_walking()

func visiting_merchant() -> RefCounted:
	return npcs.visiting_merchant()

@rpc("authority", "call_remote", "reliable")
func receive_supplies(state: Dictionary) -> void:
	supplies.restore(state)
	refresh_merchant()

@rpc("any_peer", "call_remote", "reliable")
func request_goods(kind: String) -> void:
	if multiplayer.is_server(): buy_goods_for(multiplayer.get_remote_sender_id(), kind)

func buy_goods_for(id: int, kind: String) -> void:
	if not transport_allowed(id) or cycle.phase != "shop" or workshop.pending.has(id) or transport.pending.has(id): return
	npcs.buy_goods(id, players[id].position, kind)

func init_ui(layer: CanvasLayer) -> void:
	build_ghost = Sprite2D.new()
	build_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(build_ghost)
	build_ghost.hide()
	workshop_ui = CATALOG_SCENE.instantiate()
	layer.add_child(workshop_ui)
	workshop_ui.station_requested.connect(buy_station)
	workshop_ui.skill_requested.connect(buy_skill)
	workshop_ui.mobile_bin_requested.connect(buy_mobile_bin)
	workshop_ui.transport_requested.connect(transport_buy)
	day_ui = DAY_UI_SCENE.instantiate()
	layer.add_child(day_ui)
	day_ui.advance_requested.connect(advance_day)
	expansion_ui = EXPANSION_SCENE.instantiate()
	layer.add_child(expansion_ui)
	expansion_ui.room_requested.connect(buy_room)
	refresh_transport()
	refresh_day()
	refresh_expansions()

func refresh_progression() -> void:
	refresh_walking()
	if hud != null: hud.refresh_progression()
	if workshop_ui != null: workshop_ui.refresh_progression(multiplayer.get_unique_id(), progression)
	refresh_expansions()

func refresh_day() -> void:
	if hud != null: hud.refresh_day()
	if day_ui != null: day_ui.refresh(active, cycle)
	if workshop_ui != null and cycle.phase in ["summary", "transition"]:
		workshop_ui.hide()
		build_ghost.hide()

func refresh_expansions() -> void:
	if expansion_ui == null: return
	var local := multiplayer.get_unique_id()
	var at: Vector2 = players[local].position if players.has(local) else Vector2(INF, INF)
	expansion_ui.refresh(at, rooms, progression, local, orders.coins)
	var obstacles: Array[Rect2] = []
	if hud != null:
		for panel in hud.panels:
			if panel.is_visible_in_tree(): obstacles.append(panel.get_global_rect())
	var shown: bool = active and cycle.phase not in ["summary", "transition"] and not workshop_ui.visible and not build_ghost.visible and not Input.is_physical_key_pressed(KEY_F1)
	expansion_ui.project(world.get_global_transform_with_canvas(), get_viewport().get_visible_rect(), obstacles, shown)

func init_interactions() -> void:
	# Priority is independent of controller boundaries. Only true consumes input.
	interaction_router.handlers.assign([
		movable_objects.try_pickup,
		movable_objects.try_cart_inventory,
		movable_objects.try_bin_deposit,
		placeables.try_mine,
		npcs.try_deliver,
		placeables.try_storage,
		placeables.try_care,
		placeables.try_load,
		movable_objects.try_carry,
		placeables.try_cycle,
	])
	for controller in [movable_objects, placeables, npcs]:
		controller.items_changed.connect(sync_interaction_items)
		controller.feedback_requested.connect(feedback_for)
	movable_objects.transport_changed.connect(sync_transport)
	movable_objects.motion_changed.connect(sync_movable_motion)
	movable_objects.catch_stationary = placeables.catch_item
	placeables.workshop_changed.connect(sync_interaction_workshop)
	npcs.orders_changed.connect(sync_interaction_orders)
	npcs.experience_requested.connect(award_exp)
	npcs.output_ready.connect(place_work_output)
	npcs.purchase_completed.connect(sync_visitor_purchase)
	placeables.experience_requested.connect(award_exp)
	placeables.output_ready.connect(place_work_output)
	placeables.production_completed.connect(sync_production)
	placeables.mining_completed.connect(sync_mining)

func bind_interaction_state() -> void:
	# New sessions replace models; refresh explicit dependencies instead of capturing
	# the old models in closures. The router's ordered method references stay valid.
	movable_objects.bind(world, players, ore, transport, active and multiplayer.is_server())
	placeables.bind(workshop, ore, needs, cycle, vein_at, station_nodes)
	placeables.bind_workers(players, work_held, progression, mine_veins, active and multiplayer.is_server())
	npcs.bind(ore, orders, progression)
	npcs.bind_visitors(cycle, merchant, supplies, active and multiplayer.is_server())

func route_interaction(id: int, action: StringName) -> bool:
	if not transport_allowed(id): return false
	var context = INTERACTION_CONTEXT.new(id, action, players[id].position, ore.carried_by(id))
	return interaction_router.route(context)

func sync_interaction_items() -> void:
	broadcast_state("receive_ore", [ore.snapshot()], true)

func sync_interaction_workshop() -> void:
	broadcast_state("receive_workshop", [workshop.snapshot()])
	refresh_workshop()

func sync_interaction_orders() -> void:
	broadcast_state("receive_orders", [orders.snapshot()])
	refresh_orders()

func sync_movable_motion() -> void:
	broadcast_state("receive_ore_motion", [movable_objects.motion_snapshot()], false)

func place_work_output(piece: int, at: Vector2) -> void:
	var body: RigidBody2D = movable_objects.bodies.get(piece)
	if body == null: body = movable_objects.create_body(piece, true, at)
	movable_objects.position_body(body, at, Vector2(0, 20))
	body.angular_velocity = 0

func sync_production() -> void:
	sync_interaction_items()
	sync_movable_motion()
	broadcast_state("receive_workshop", [workshop.snapshot()])

func sync_mining() -> void:
	sync_interaction_items()
	sync_movable_motion()
	broadcast_state("receive_mining", [mining_snapshot()], false)

func sync_visitor_purchase() -> void:
	sync_interaction_items()
	sync_movable_motion()
	sync_interaction_orders()
	broadcast_state("receive_merchant", [merchant.snapshot()])
	broadcast_state("receive_supplies", [supplies.snapshot()])
	refresh_merchant()
