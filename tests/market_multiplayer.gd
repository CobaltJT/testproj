extends SceneTree
# Test-only coordination; all purchases, recipe choices, loads, work and deliveries
# use production inputs/RPCs. The host positions fixtures to isolate each rule.
class TestSync extends Node:
	var stage := ""
	var seen: Dictionary = {}
	var reports: Dictionary = {}
	@rpc("authority", "call_local", "reliable")
	func begin(value: String) -> void:
		stage = value
		seen[value] = true
	@rpc("any_peer", "call_remote", "reliable")
	func report(key: String) -> void:
		reports[key] = true

var session: Node
var sync: TestSync
var role := ""
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS market [", role, "]: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func until(condition: Callable, limit: int = 600) -> bool:
	for i in range(limit):
		if condition.call():
			return true
		await frames(1)
	return false
func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(12)
func stage(value: String) -> void:
	check(await until(func(): return sync.seen.has(value)), "Stage " + value)
func done(value: String) -> void:
	if role == "host":
		sync.reports[role + ":" + value] = true
	else:
		sync.report.rpc_id(1, role + ":" + value)
func reports(value: String) -> bool:
	return sync.reports.has("client1:" + value) and sync.reports.has("client2:" + value)
func fixtures(at: Vector2) -> void:
	for dwarf in session.players.values():
		dwarf.position = at
		dwarf.velocity = Vector2.ZERO
func broadcast() -> void:
	session.receive_ore.rpc(session.ore.snapshot())
	session.receive_ore_motion.rpc(session.ore_motion())
	session.receive_orders.rpc(session.orders.snapshot())
	session.receive_merchant.rpc(session.merchant.snapshot())
	session.receive_anvil.rpc(session.anvil.snapshot())
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.get_slice("=", 1)
	call_deferred("run")
func run() -> void:
	sync = TestSync.new()
	sync.name = "TestSync"
	root.add_child(sync)
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	if not await until(func(): return session.players.size() == 3):
		check(false, "Three peers connect")
		quit(1)
		return
	if role == "host":
		await host_scenarios()
	else:
		await client_scenarios()
	print("MARKET RESULT ", role, ": ", failures, " failures")
	quit(1 if failures else 0)

func host_scenarios() -> void:
	fixtures(Vector2(212, 216))
	session.merchant.step(12)
	session.merchant.stock = 1
	session.orders.coins = 5
	broadcast()
	await frames(10)
	sync.begin.rpc("buy")
	check(await until(func(): return reports("buy")), "Both clients attempted last-stock purchase")
	check(session.orders.coins == 0 and session.merchant.stock == 0 and session.ore.pieces.size() == 9, "Competing purchases create one wood and charge once")
	var ids: Array = session.players.keys()
	ids.erase(1)
	ids.sort()
	# Identify roles through test reports sent during registration.
	var c1 := 0
	var c2 := 0
	for id in ids:
		if sync.reports.has("role-client1-%s" % id):
			c1 = id
		else:
			c2 = id
	session.ore.pickup(c1, 8)
	session.ore.pieces[0].kind = "ingot"
	session.ore.pickup(c2, 0)
	fixtures(Vector2(260, 216))
	broadcast()
	await frames(10)
	sync.begin.rpc("selectaxe")
	check(await until(func(): return session.anvil.recipe == "axe"), "Client selects axe recipe")
	sync.begin.rpc("loadaxe")
	check(await until(func(): return session.anvil.piece == 0 and session.anvil.wood_piece == 8), "Separate clients load ingot and purchased wood")
	sync.begin.rpc("workaxe")
	await frames(240)
	check(session.ore.pieces[0].kind == "ingot", "Two workers cannot finish axe in four seconds")
	check(await until(func(): return session.ore.pieces[0].kind == "axe"), "Axe finishes with shared work")
	check(session.ore.pieces[8].consumed and not session.ore_bodies[8].visible, "Wood consumed once and hidden")
	check(await until(func(): return reports("axe")), "Clients see axe output")
	sync.begin.rpc("selectsword")
	check(await until(func(): return session.anvil.recipe == "sword"), "Client selects sword")
	session.ore.pieces[1].kind = "ingot"
	session.ore.pickup(c2, 1)
	broadcast()
	await frames(10)
	sync.begin.rpc("loadsword")
	check(await until(func(): return session.anvil.piece == 1), "Sword loads one ingot")
	sync.begin.rpc("worksword")
	check(await until(func(): return session.ore.pieces[1].kind == "sword"), "Sword completes without wood")
	check(await until(func(): return reports("sword")), "Clients see sword output")
	session.ore.pickup(c1, 0)
	session.ore.pickup(c2, 1)
	fixtures(Vector2(166, 216))
	session.orders.queue = [{"id": 101, "kind": "sword", "remaining": 30.0, "age": 2.0}, {"id": 102, "kind": "axe", "remaining": 30.0, "age": 2.0}]
	session.orders.number = 102
	session.orders.until_arrival = 20
	session.orders.completed = 0
	session.orders.missed = 0
	session.orders.reputation = 0
	session.orders.coins = 0
	broadcast()
	await frames(10)
	sync.begin.rpc("wrongdelivery")
	check(await until(func(): return reports("wrongdelivery")), "Clients observe front-only rejection")
	check(session.orders.completed == 0 and session.ore.carried_by(c1) == 0, "Queued axe cannot skip front sword")
	sync.begin.rpc("deliversword")
	check(await until(func(): return session.orders.completed == 1), "Front sword delivered")
	sync.begin.rpc("deliveraxe")
	check(await until(func(): return session.orders.completed == 2), "Next axe delivered after queue advances")
	check(session.orders.coins == 40 and session.orders.reputation == 2, "Specific-item prices and reputation awarded exactly once")
	session.orders.queue = [{"id": 103, "kind": "hammer", "remaining": 0.25, "age": 29.75}, {"id": 104, "kind": "axe", "remaining": 1.0, "age": 29.0}]
	session.orders.step(1)
	broadcast()
	sync.begin.rpc("expired")
	check(await until(func(): return reports("expired")), "All clients see expired orders and reputation loss")
	check(session.orders.missed == 2 and session.orders.reputation == 0 and session.orders.coins == 40, "Each expired customer costs one reputation without changing coins")
	sync.begin.rpc("rejoin")
	check(await until(func(): return reports("rejoin")), "Late rejoin restores economy, recipes, material kinds and consumed wood")
	sync.begin.rpc("finished")
	await frames(5)
	session.disconnect_game("Market test complete")
	await frames(10)

func client_scenarios() -> void:
	var id: int = session.multiplayer.get_unique_id()
	sync.report.rpc_id(1, "role-%s-%s" % [role, id])
	await stage("buy")
	await press("buy_wood")
	await frames(20)
	check(session.orders.coins == 0 and session.ore.pieces.has(8) and session.ore.pieces[8].kind == "wood", "Purchased wood and charge replicate")
	done("buy")
	await stage("selectaxe")
	if role == "client1":
		await press("recipe_axe")
	await stage("loadaxe")
	await press("interact")
	await stage("workaxe")
	Input.action_press("interact")
	check(await until(func(): return session.ore.pieces[0].kind == "axe"), "Client sees crafted axe")
	Input.action_release("interact")
	await frames(10)
	check(session.ore.pieces[8].consumed and session.ore_bodies[0].get_node("Sprite2D").texture == session.EXTRA_TEXTURES.axe, "Axe image and consumed wood replicate")
	done("axe")
	await stage("selectsword")
	if role == "client2":
		await press("recipe_sword")
	await stage("loadsword")
	if role == "client2":
		await press("interact")
	await stage("worksword")
	if role == "client2":
		Input.action_press("interact")
	check(await until(func(): return session.ore.pieces[1].kind == "sword"), "Client sees sword recipe output")
	Input.action_release("interact")
	done("sword")
	await stage("wrongdelivery")
	if role == "client1":
		await press("interact")
	await frames(20)
	check(session.orders.completed == 0 and session.orders.queue.size() == 2, "Front-only queue rule replicated")
	done("wrongdelivery")
	await stage("deliversword")
	if role == "client2":
		await press("interact")
	await stage("deliveraxe")
	if role == "client1":
		await press("interact")
	await stage("expired")
	check(session.orders.coins == 40 and session.orders.reputation == 0 and session.orders.missed == 2, "Shared rewards and expiry penalties replicate")
	done("expired")
	await stage("rejoin")
	if role == "client2":
		session.disconnect_game("Test reconnect")
		await frames(10)
		session.join_game()
		check(await until(func(): return session.players.size() == 3 and session.orders.coins == 40 and session.ore.pieces.has(8) and session.ore.pieces[8].consumed), "Rejoining client receives complete expanded state")
		check(session.anvil.recipe == "sword" and session.orders.reputation == 0, "Rejoin restores selected recipe and reputation")
	done("rejoin")
	await stage("finished")
	check(await until(func(): return not session.active), "Host shutdown returns client to menu")
