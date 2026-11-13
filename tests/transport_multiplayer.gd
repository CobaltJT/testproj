extends SceneTree
class Sync extends Node:
	var stage := ""
	var reports: Dictionary = {}
	@rpc("authority", "call_local", "reliable")
	func begin(value: String) -> void: stage = value
	@rpc("any_peer", "call_remote", "reliable")
	func report(role: String, value: String) -> void: reports[role + value] = true
var session: Node
var sync: Sync
var role := ""
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS transport net [", role, "]: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func until(test: Callable) -> bool:
	for i in range(600):
		if test.call(): return true
		await frames(1)
	return false
func stage(value: String) -> void: check(await until(func(): return sync.stage == value), "Stage " + value)
func reports(value: String) -> bool: return sync.reports.has("client1" + value) and sync.reports.has("client2" + value)
func done(value: String) -> void: sync.report.rpc_id(1, role, value)
func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(12)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.get_slice("=", 1)
	call_deferred("run")
func run() -> void:
	sync = Sync.new()
	sync.name = "TransportTestSync"
	root.add_child(sync)
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	check(await until(func(): return session.players.size() == 3), "Three peers connect")
	if role == "host": await host()
	else: await client()
	print("MULTIPLAYER RESULT ", role, ": ", failures, " failures")
	quit(1 if failures else 0)
func host() -> void:
	sync.begin.rpc("upgrade")
	check(await until(func(): return reports("upgrade")), "Concurrent purchases settle")
	check(session.transport.upgrades == 1 and session.orders.coins == 70, "Repeated/skipped upgrades charge once and unlock only level one")
	sync.begin.rpc("rail")
	check(await until(func(): return reports("rail")), "Client extends starting rail")
	check(Vector2(326, 288) in session.transport.tracks and Vector2(294, 288) not in session.transport.tracks and session.orders.coins == 65, "Remote rails enforce adjacency and kit ownership")
	for id in session.players:
		if id != 1:
			session.players[id].position = Vector2(358, 288)
			session.players[id].velocity = Vector2.ZERO
	await frames(10)
	sync.begin.rpc("cart")
	check(await until(func(): return reports("cart")), "Client purchases cart")
	check(session.transport.carts.size() == 1 and session.orders.coins == 40, "Cart charged once")
	sync.begin.rpc("push")
	check(await until(func(): return reports("push")), "Cart pushed remotely")
	check(absf(session.transport.carts[1].at.x - 390) < 12, "Cart reaches elevator on rails")
	for id in session.players:
		if id != 1:
			session.players[id].position = Vector2(390, 288)
			session.players[id].velocity = Vector2.ZERO
	await frames(10)
	sync.begin.rpc("lift")
	check(await until(func(): return reports("lift")), "Remote elevator ride completes")
	check(session.transport.lift_y == 368 and session.transport.carts[1].at.y == 368, "Lift carries cart across levels on host")
	for i in range(25):
		var piece: int = session.ore.add_material("ore")
		session.transport.store(1, piece, session.ore)
	session.broadcast_state("receive_ore", [session.ore.snapshot()], true)
	session.sync_transport()
	sync.begin.rpc("inventory")
	check(await until(func(): return reports("inventory")), "Nested cart inventory replicates")
	sync.begin.rpc("rejoin")
	check(await until(func(): return reports("rejoin")), "Reconnect restores full transport state")
	sync.begin.rpc("finished")
	await frames(5)
	session.disconnect_game("Done")
	await frames(10)
func client() -> void:
	await stage("upgrade")
	session.request_transport_buy.rpc_id(1, "lift", 3)
	session.request_transport_buy.rpc_id(1, "lift", 1)
	check(await until(func(): return session.transport.upgrades == 1), "Host upgrade state received")
	await frames(10)
	done("upgrade")
	await stage("rail")
	if role == "client1":
		session.request_transport_buy.rpc_id(1, "rail", 0)
		check(await until(func(): return session.transport.pending.has(session.multiplayer.get_unique_id())), "Owned rail kit received")
		session.request_rail_place.rpc_id(1, Vector2(294, 288))
		await frames(5)
		session.request_rail_place.rpc_id(1, Vector2(326, 288))
	else: session.request_rail_place.rpc_id(1, Vector2(454, 288))
	check(await until(func(): return Vector2(326, 288) in session.transport.tracks), "Rail placement replicated")
	done("rail")
	await stage("cart")
	if role == "client1": session.request_transport_buy.rpc_id(1, "cart", 0)
	check(await until(func(): return session.transport.carts.size() == 1), "Cart appears on client")
	done("cart")
	await stage("push")
	if role == "client1":
		var before: Vector2 = session.players[session.multiplayer.get_unique_id()].position
		var cart_before: Vector2 = session.transport.carts[1].at
		await press("push_cart")
		check(session.players[session.multiplayer.get_unique_id()].position.distance_to(before) < 0.1 and session.transport.carts[1].at == cart_before, "Remote coupling preserves positions")
		Input.action_press("move_right")
		await frames(27)
		Input.action_release("move_right")
		await press("push_cart")
	check(await until(func(): return absf(session.transport.carts[1].at.x - 390) < 12 and session.transport.carts[1].driver == 0), "Cart motion and driver release replicate")
	done("push")
	await stage("lift")
	if role == "client2": await press("climb_down")
	check(await until(func(): return session.transport.lift_y == 368 and not session.transport.moving), "Shared lift arrives")
	var id: int = session.multiplayer.get_unique_id()
	check(await until(func(): return absf(session.players[id].position.y - 368) < 3), "Local dwarf rides lift")
	done("lift")
	await stage("inventory")
	check(await until(func(): return session.transport.carts[1].items.size() == 25), "All 25 ore identities received")
	for piece in session.transport.carts[1].items: check(session.ore.pieces[piece].processing, "Stored ore reserved")
	if role == "client2":
		await press("take_bin_ore")
		check(session.ore.carried_by(session.multiplayer.get_unique_id()) == -1, "Remote G leaves cart inventory unchanged")
		await press("interact")
		check(await until(func(): return session.transport.carts[1].items.size() == 24 and session.ore.carried_by(session.multiplayer.get_unique_id()) != -1), "Remote E withdraws ore")
		await press("interact")
		check(await until(func(): return session.transport.carts[1].items.size() == 25 and session.ore.carried_by(session.multiplayer.get_unique_id()) == -1), "Remote E reloads same ore")
	done("inventory")
	await stage("rejoin")
	if role == "client2":
		session.disconnect_game("Rejoin")
		await frames(15)
		session.join_game()
		check(await until(func(): return session.transport.upgrades == 1 and session.transport.carts.has(1) and session.transport.carts[1].items.size() == 25), "Reconnect restores upgrades, rails and ore cart")
		check(session.transport.lift_y == 368 and session.transport.carts[1].at.y == 368, "Reconnect restores elevator position")
	done("rejoin")
	await stage("finished")
	check(await until(func(): return not session.active), "Host shutdown handled")
