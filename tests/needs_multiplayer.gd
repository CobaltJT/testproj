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
	if ok: print("PASS needs net [", role, "]: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func until(test: Callable) -> bool:
	for i in range(900):
		if test.call(): return true
		await frames(1)
	return false
func stage(value: String) -> void: check(await until(func(): return sync.stage == value), "Stage " + value)
func reports(value: String) -> bool: return sync.reports.has("client1" + value) and sync.reports.has("client2" + value)
func done(value: String) -> void: sync.report.rpc_id(1, role, value)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.get_slice("=", 1)
	call_deferred("run")
func run() -> void:
	sync = Sync.new()
	sync.name = "NeedsTestSync"
	root.add_child(sync)
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	check(await until(func(): return session.players.size() == 3), "Three peers connect")
	if role == "host": await host()
	else: await client()
	print("MULTIPLAYER RESULT ", role, ": ", failures, " failures")
	quit(1 if failures else 0)
func host() -> void:
	preload("res://tests/world_fixture.gd").prepare(session)
	session.orders.coins = 1000
	for entry in [["bed", Vector2(160, 136)], ["dining", Vector2(256, 136)]]:
		session.purchase_for(1, entry[0])
		session.place_for(1, entry[1])
	# Clients report their role/id before their needs are configured.
	sync.begin.rpc("identify")
	check(await until(func(): return reports("identify")), "Clients identify")
	var ids: Array = session.players.keys().filter(func(id): return id != 1)
	var c1 := 0
	# Role identity is encoded by an additional RPC report key.
	for key in sync.reports:
		if str(key).begins_with("client1id_"): c1 = int(str(key).get_slice("_", 1))
	var c2: int = ids[0] if ids[0] != c1 else ids[1]
	session.needs.dwarfs[c1] = {"energy": 5.0, "food": 50.0}
	session.needs.dwarfs[c2] = {"energy": 50.0, "food": 0.0}
	session.players[c1].position = Vector2(160, 136)
	session.players[c2].position = Vector2(256, 136)
	for id in [c1, c2]: session.players[id].velocity = Vector2.ZERO
	var meal: int = session.ore.add_material("food")
	session.ore.pickup(c2, meal)
	session.broadcast_state("receive_ore", [session.ore.snapshot()], true)
	session.broadcast_state("receive_needs", [session.needs.snapshot()])
	await frames(10)
	sync.begin.rpc("low")
	check(await until(func(): return reports("low")), "Low and empty needs replicate")
	sync.begin.rpc("recover")
	check(await until(func(): return reports("recover")), "Bed and meal recovery finish remotely")
	check(session.needs.dwarfs[c1].energy > 40 and session.needs.dwarfs[c2].food > 30 and session.ore.pieces[meal].consumed, "Host owns recovery and consumes exactly one meal")
	session.cycle.phase = "shop"
	session.orders.until_arrival = 1000
	session.merchant.remaining = 0
	session.merchant.until_visit = 1000
	for id in [c1, c2]:
		session.players[id].position = Vector2(212, 216)
		session.players[id].velocity = Vector2.ZERO
	for kind in ["food", "ore"]:
		session.supplies.kind = kind
		session.supplies.stock = 1
		session.supplies.remaining = 15
		session.supplies.until_visit = 100
		session.broadcast_state("receive_supplies", [session.supplies.snapshot()])
		session.broadcast_state("receive_day", [session.cycle.snapshot()])
		await frames(10)
		sync.begin.rpc(kind)
		check(await until(func(): return reports(kind)), "Concurrent remote " + kind + " purchases finish")
		check(session.supplies.stock == 0 and session.orders.coins == (966 if kind == "food" else 963), "Last stock charges once: " + kind)
	# Pause a loaded meal for the host and verify it and personal needs on late join.
	session.needs.dwarfs[1].energy = 3
	session.needs.dwarfs[1].food = 0
	var food: int = session.ore.add_material("food")
	session.ore.pickup(1, food)
	var table: int = session.workshop.nearest(Vector2(256, 136))
	session.workshop.stations[table].job.load_material(1, session.ore)
	session.broadcast_state("receive_ore", [session.ore.snapshot()], true)
	session.sync_build()
	sync.begin.rpc("rejoin")
	check(await until(func(): return reports("rejoin")), "Late join restores needs, trader and paused meal")
	sync.begin.rpc("finished")
	await frames(10)
	session.disconnect_game("Done")
	await frames(10)
func client() -> void:
	await stage("identify")
	var id: int = session.multiplayer.get_unique_id()
	sync.report.rpc_id(1, role, "id_" + str(id))
	done("identify")
	await stage("low")
	check(session.needs.dwarfs[id].energy < 10 if role == "client1" else session.needs.dwarfs[id].food == 0, "Personal low/empty meter arrives")
	check(is_equal_approx(session.players[id].walking_multiplier, 0.7 if role == "client1" else 0.4), "Personal movement penalty is replicated")
	check(session.hud.energy_bar.max_value == 100 and session.hud.food_bar.max_value == 100, "HUD displays both percentage meters")
	done("low")
	await stage("recover")
	Input.action_press("interact")
	await frames(340)
	Input.action_release("interact")
	await frames(10)
	check(session.needs.dwarfs[id].energy > 40 if role == "client1" else session.needs.dwarfs[id].food > 30, "Remote hold E recovers the correct need")
	check(is_equal_approx(session.players[id].walking_multiplier, 1), "Movement returns to normal after recovery")
	done("recover")
	for kind in ["food", "ore"]:
		await stage(kind)
		check(session.visiting_merchant().kind == kind and session.hud.merchant_card.visible, "Visitor card shows " + kind)
		if kind == "ore": session.request_goods.rpc_id(1, "food") # Stale request must be ignored.
		session.hud.merchant_card.buy_button.pressed.emit()
		check(await until(func(): return session.supplies.stock == 0), "Shared final stock removed")
		check(session.orders.coins == (966 if kind == "food" else 963), "Shared coins replicated")
		done(kind)
	await stage("rejoin")
	if role == "client2":
		session.disconnect_game("Rejoin")
		await frames(15)
		session.join_game()
		check(await until(func(): return session.active and session.players.size() == 3 and session.needs.dwarfs.has(1) and session.needs.dwarfs[1].food == 0), "Late join receives exhausted host needs")
		check(session.needs.dwarfs[session.multiplayer.get_unique_id()].energy > 99, "Rejoining dwarf starts with fresh personal needs")
		var table: int = session.workshop.nearest(Vector2(256, 136))
		check(session.workshop.stations[table].job.diner == 1 and session.workshop.stations[table].job.slots.has("food"), "Late join restores reserved meal owner and food")
		check(session.supplies.kind == "ore" and session.supplies.stock == 0, "Late join restores current trader stock")
	done("rejoin")
	await stage("finished")
	check(await until(func(): return not session.active), "Host shutdown handled")
