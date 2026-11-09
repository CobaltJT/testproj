extends SceneTree
var session: Node
var role := ""
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS [", role, "]: ", message)
	else:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func until(predicate: Callable, count: int = 600) -> bool:
	for i in range(count):
		if predicate.call():
			return true
		await frames(1)
	return false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.get_slice("=", 1)
	call_deferred("run")

func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	var joined := await until(func(): return session.players.size() == 3)
	check(joined, "Three peers share a roster")
	if not joined:
		quit(1)
		return
	var id := session.multiplayer.get_unique_id()
	var dwarf = session.players[id]
	var starts: Dictionary = {}
	for peer_id in session.players:
		starts[peer_id] = session.players[peer_id].position
	# All three independent game processes use real production input collection.
	var action := "move_left" if role == "client1" else "move_right"
	Input.action_press(action)
	await frames(30)
	Input.action_release(action)
	await frames(10)
	check(absf(dwarf.position.x - starts[id].x) > 20, "Local controls move own dwarf through host simulation")
	var remote_moved := false
	for peer_id in starts:
		if peer_id != id and session.players.has(peer_id):
			remote_moved = remote_moved or absf(session.players[peer_id].position.x - starts[peer_id].x) > 15
	check(remote_moved, "Remote movement is replicated")
	var jump_y: float = dwarf.position.y
	Input.action_press("jump")
	await frames(5)
	Input.action_release("jump")
	await frames(5)
	check(dwarf.position.y < jump_y - 5, "Jump is simulated and replicated")
	await frames(50)
	check(absf(dwarf.position.y - 216) < 1, "Host collision returns dwarf to ground")
	Input.action_press("move_right")
	var reached_ladder := await until(func(): return dwarf.position.x >= 363, 240)
	Input.action_release("move_right")
	await frames(5)
	Input.action_press("climb_up")
	var reached_top := await until(func(): return dwarf.position.y <= 136.5, 180)
	Input.action_release("climb_up")
	check(reached_ladder and reached_top and dwarf.climbing, "Network controls climb to upper floor")
	Input.action_press("climb_down")
	var reached_ground := await until(func(): return dwarf.position.y >= 215.5, 180)
	Input.action_release("climb_down")
	check(reached_ground, "Network controls descend ladder")
	await walk_to(dwarf, 112)
	Input.action_press("climb_down")
	var cellar := await until(func(): return dwarf.position.y >= 287.5, 180)
	Input.action_release("climb_down")
	await walk_to(dwarf, 238)
	await press_interact()
	var carrying := await until(func(): return id in session.ore.carriers)
	check(cellar and carrying and dwarf.get_node("CarriedOre").visible, "Collect basement ore through E and replicate carried texture")
	await press_interact()
	await frames(12)
	check(session.ore.carriers.count(id) == 1, "Repeated pickup cannot carry a second piece")
	await walk_to(dwarf, 112)
	Input.action_press("climb_up")
	var carried_up := await until(func(): return dwarf.position.y <= 215.8, 180)
	Input.action_release("climb_up")
	check(carried_up and id in session.ore.carriers, "Ore stays carried while climbing basement ladder")
	await walk_to(dwarf, 200)
	var turn := 0 if role == "host" else (1 if role == "client1" else 2)
	var ready_to_throw := await until(func(): return session.ore.deposited >= turn, 900)
	await frames(40)
	await walk_to(dwarf, 260)
	Input.action_press("throw_ore")
	await frames(2)
	Input.action_release("throw_ore")
	var released := await until(func(): return id not in session.ore.carriers)
	check(released and not dwarf.get_node("CarriedOre").visible, "F releases carried ore into shared physics")
	var deposited := await until(func(): return session.ore.deposited >= turn + 1, 240)
	check(ready_to_throw and deposited, "Physical throw lands inside the bin")
	await walk_to(dwarf, 200)
	check(session.ore.available + session.ore.deposited + session.ore.carriers.size() == 8, "All peers conserve the shared ore total")
	var shared_total := await until(func(): return session.ore.deposited == 3 and session.ore.carriers.is_empty())
	check(shared_total and session.stations.get_node("BinLabel").text == "THROW IN: 3", "Every peer sees all three deposits and the same bin count")
	await walk_to(dwarf, 400)
	if role == "host":
		await frames(30)
		Input.action_press("interact")
		await frames(120)
		Input.action_release("interact")
		await frames(5)
		check(session.forge.progress > 1.9 and session.forge.progress < 2.2 and session.ore.deposited == 2, "Host starts one five-second job and pauses after two seconds")
		var handed_off := await until(func(): return session.forge.progress >= 4.0 and session.forge.worker == 0)
		check(handed_off and ingot_id() == -1 and session.ore.deposited == 2, "Clients resume at single-worker speed without spending extra ore")
		Input.action_press("interact")
	else:
		var paused := await until(func(): return session.forge.progress > 1.8 and session.forge.worker == 0)
		check(paused, "Paused forge progress replicates to client")
		Input.action_press("interact")
		await frames(130)
		Input.action_release("interact")
		check(ingot_id() == -1 and session.ore.deposited == 2, "Two clients holding E cannot finish early or consume twice")
	var forged := await until(func(): return ingot_id() != -1)
	Input.action_release("interact")
	await frames(30)
	check(forged and session.ore.deposited == 2 and session.forge.piece == -1, "One completed job produces one replicated ingot")
	if forged:
		var output: RigidBody2D = session.ore_bodies[ingot_id()]
		check(output.visible and output.get_node("Sprite2D").texture == session.INGOT_TEXTURE, "Every peer displays physical ingot output")
		check(is_equal_approx(session.forge_station.get_node("Progress").value, session.forge.progress), "Progress bar follows shared forge state")
	if role == "client1":
		await walk_to(dwarf, 342)
		await press_interact()
		var collected := await until(func(): return id in session.ore.carriers)
		check(collected, "Client picks up forge ingot for anvil")
		await walk_to(dwarf, 260)
		await press_interact()
		check(session.anvil.piece != -1 and id not in session.ore.carriers, "Client loads carried ingot into shared anvil")
		Input.action_press("interact")
		await frames(120)
		Input.action_release("interact")
		var resumed := await until(func(): return session.anvil.progress >= 4 and session.anvil.worker == 0)
		check(resumed and hammer_id() == -1, "Other players resume anvil without accelerating recipe")
		Input.action_press("interact")
	else:
		await walk_to(dwarf, 260)
		var paused_anvil := await until(func(): return session.anvil.progress > 1.8 and session.anvil.worker == 0, 900)
		check(paused_anvil, "Loaded and paused anvil state replicates")
		# Keep the pause visible long enough for both independent clients to observe it.
		await frames(30)
		Input.action_press("interact")
		await frames(130)
		Input.action_release("interact")
		check(hammer_id() == -1, "Two anvil workers cannot finish before five seconds")
	var hammered := await until(func(): return hammer_id() != -1)
	Input.action_release("interact")
	await frames(30)
	check(hammered and session.anvil.piece == -1 and session.ore.pieces.size() == 8, "All peers see one hammer and conserved material identity")
	if hammered:
		check(session.ore_bodies[hammer_id()].visible and session.ore_bodies[hammer_id()].get_node("Sprite2D").texture == session.HAMMER_TEXTURE, "Physical hammer image replicates")
	if role == "client1":
		await walk_to(dwarf, 282)
		await press_interact()
		var carrying_product := await until(func(): return id in session.ore.carriers)
		check(carrying_product, "Client collects finished hammer for delivery")
		await walk_to(dwarf, 166)
		await press_interact()
	var served := await until(func(): return session.orders.completed == 1)
	check(served and session.orders.coins == 10, "Customer delivery and shared coins replicate to all peers")
	check(not session.ore_bodies[hammer_id()].visible and session.ore.pieces[hammer_id()].delivered, "Sold hammer is removed on every peer")
	await walk_to(dwarf, 112)
	Input.action_press("climb_down")
	await until(func(): return dwarf.position.y >= 287.5, 180)
	Input.action_release("climb_down")
	await walk_to(dwarf, 390)
	if role == "host":
		await frames(30)
		Input.action_press("interact")
		await frames(60)
		Input.action_release("interact")
		var handed_mine := await until(func(): return session.mining.progress >= 1.9 and session.mining.worker == 0)
		check(handed_mine and session.mining.extracted == 0, "Mining handoff retains progress without accelerating")
		Input.action_press("interact")
	else:
		var mine_paused := await until(func(): return session.mining.progress > 0.8 and session.mining.worker == 0)
		check(mine_paused, "Paused mining state replicates")
		await frames(30)
		Input.action_press("interact")
		await frames(60)
		Input.action_release("interact")
		check(session.mining.extracted == 0, "Two clients cannot extract early")
	var mined := await until(func(): return session.mining.extracted == 1 and session.ore_bodies.has(8))
	Input.action_release("interact")
	await frames(20)
	check(mined and session.ore.pieces.size() == 9 and session.ore_bodies[8].visible, "Every peer receives one new mined ore body")
	if role == "client1":
		await walk_to(dwarf, 344)
		await press_interact()
		var picked_mined := await until(func(): return session.ore.carried_by(id) == 8)
		check(picked_mined, "Client can pick up dynamically mined ore")
		Input.action_press("drop_ore")
		await frames(2)
		Input.action_release("drop_ore")
	await walk_to(dwarf, 112)
	Input.action_press("climb_up")
	await until(func(): return dwarf.position.y <= 215.8, 180)
	Input.action_release("climb_up")
	await walk_to(dwarf, 200)
	if role == "host":
		# Let the last thrower return to the waiting area, then create an impact.
		await frames(90)
		var loose_id := -1
		for piece_id in session.ore.pieces:
			if session.ore.is_loose(piece_id):
				loose_id = piece_id
				break
		session.ore.pickup(1, loose_id)
		session.refresh_ore()
		dwarf.position = Vector2(220, 216)
		dwarf.velocity = Vector2.ZERO
		dwarf.sprite.flip_h = false
		session.release_ore(1, false)
		session.throw_grace.erase(loose_id)
	var saw_knockback := await until(func(): return session.players.has(1) and session.players[1].position.x > 228, 300)
	check(saw_knockback, "Host ore impact displacement replicates to every peer")
	if role == "client1":
		await frames(15)
		session.disconnect_game("Test leave")
		check(session.players.is_empty() and session.menu.visible, "Leave clears scene and restores menu")
	elif role == "host":
		var removed := await until(func(): return session.players.size() == 2)
		check(removed, "Disconnected client removed from host roster")
		await frames(20)
		session.disconnect_game("Test host stop")
	else:
		var disconnected := await until(func(): return not session.active and session.menu.visible)
		check(disconnected and session.players.is_empty(), "Host loss clears roster and restores menu")
	print("MULTIPLAYER RESULT ", role, ": ", failures, " failures")
	quit(1 if failures else 0)

func walk_to(dwarf: CharacterBody2D, x: float) -> void:
	var action := "move_left" if dwarf.position.x > x else "move_right"
	Input.action_press(action)
	var arrived := await until(func(): return dwarf.position.x <= x + 2 if action == "move_left" else dwarf.position.x >= x - 2, 300)
	Input.action_release(action)
	await frames(5)
	check(arrived, "Walk to station/ladder at x=%s" % x)

func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(10)

func ingot_id() -> int:
	for piece_id in session.ore.pieces:
		if session.ore.pieces[piece_id].kind == "ingot":
			return piece_id
	return -1

func hammer_id() -> int:
	for piece_id in session.ore.pieces:
		if session.ore.pieces[piece_id].kind == "hammer":
			return piece_id
	return -1
