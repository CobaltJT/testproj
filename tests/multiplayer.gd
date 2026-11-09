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
	if role == "client1":
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
