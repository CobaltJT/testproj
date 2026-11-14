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
	if ok: print("PASS rooms net [", role, "]: ", message)
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
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.get_slice("=", 1)
	call_deferred("run")
func run() -> void:
	sync = Sync.new()
	sync.name = "RoomsTestSync"
	root.add_child(sync)
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	check(await until(func(): return session.players.size() == 3), "Three peers connect")
	if role == "host": await host()
	else: await client()
	print("MULTIPLAYER RESULT ", role, ": ", failures, " failures")
	quit(1 if failures else 0)
func host() -> void:
	check(session.rooms.building.size() == 2 and session.mine_veins.is_empty(), "Host starts with two rooms")
	sync.begin.rpc("initial")
	check(await until(func(): return reports("initial")), "Both clients confirm initial layout before purchases")
	sync.begin.rpc("basement")
	check(await until(func(): return reports("basement")), "Concurrent basement purchases finish")
	check(session.rooms.building.size() == 3 and session.orders.coins == 85 and session.orders.spent == 15, "Concurrent requests charge for basement only once")
	sync.begin.rpc("entrance")
	check(await until(func(): return reports("entrance")), "Concurrent mine purchases finish")
	check(session.rooms.mine_open and session.mine_veins.size() == 1 and session.orders.coins == 55 and session.orders.spent == 45, "Entrance unlocks one chamber and charges once")
	sync.begin.rpc("deeper")
	check(await until(func(): return reports("deeper")), "Concurrent deeper purchases finish")
	check(session.rooms.depth() == 2 and session.mine_veins.size() == 2 and session.orders.coins == 15 and session.orders.spent == 85, "Depth unlock and price replicate exactly once")
	sync.begin.rpc("rejoin")
	check(await until(func(): return reports("rejoin")), "Rejoining clients receive expanded layout")
	check(session.rooms.depth() == 2 and session.orders.coins == 15, "Reconnect preserves shared rooms and economy")
	sync.begin.rpc("finished")
	await frames(10)
	session.disconnect_game("Done")
	await frames(10)
func client() -> void:
	await stage("initial")
	check(session.rooms.building.size() == 2 and session.vein_nodes.is_empty(), "Client initially receives two-room world")
	done("initial")
	await stage("basement")
	session.request_room.rpc_id(1, false, Vector2i(4, -2))
	if role == "client1": session.room_buttons[Vector3i(1, 1, 0)].pressed.emit()
	else: session.request_room.rpc_id(1, false, Vector2i(1, 1))
	session.request_room.rpc_id(1, false, Vector2i(1, 1))
	check(await until(func(): return session.rooms.building.size() == 3), "Purchased basement and ladder appear remotely")
	check(session.entrance_button != null and session.world.entrance.visible, "Basement signpost and purchase indicator appear on clients")
	check(session.players[multiplayer_id()].ladders.size() == 1, "Local dwarf receives new building ladder")
	await frames(10)
	done("basement")
	await stage("entrance")
	session.request_room.rpc_id(1, true, Vector2i(1, 0))
	check(await until(func(): return session.rooms.mine_open and session.mine_veins.size() == 1), "Remote entrance creates first chamber and vein")
	await frames(10)
	done("entrance")
	await stage("deeper")
	session.request_room.rpc_id(1, true, Vector2i(1, 3))
	session.request_room.rpc_id(1, true, Vector2i(1, 2))
	check(await until(func(): return session.rooms.depth() == 2 and session.mine_veins.size() == 2), "Only next depth opens; skip request rejected")
	check(session.players[multiplayer_id()].mine_ladder_bottom == 528, "Mine ladder ends at purchased depth on client")
	await frames(10)
	done("deeper")
	await stage("rejoin")
	if role == "client2":
		session.disconnect_game("Rejoining")
		await frames(20)
		session.join_game()
		check(await until(func(): return session.active and session.players.size() == 3 and session.rooms.depth() == 2), "Late join restores room ownership")
		check(session.rooms.building.size() == 3 and session.vein_nodes.size() == 2 and session.players[multiplayer_id()].ladders.size() == 2, "Late join rebuilds collision, ladders and veins")
		check(session.orders.coins == 15, "Late join restores expansion spending")
	done("rejoin")
	await stage("finished")
	check(await until(func(): return not session.active), "Host shutdown returns client to menu")
func multiplayer_id() -> int: return session.multiplayer.get_unique_id()
