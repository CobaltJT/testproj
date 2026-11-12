extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS mining physics: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	session.advance_day()
	var dwarf = session.players[1]
	dwarf.position = Vector2(390, 216)
	Input.action_press("interact")
	await frames(15)
	Input.action_release("interact")
	check(session.mining.progress == 0, "Cannot mine from another floor")
	dwarf.position = Vector2(390, 288)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press("interact")
	await frames(60)
	Input.action_release("interact")
	await frames(5)
	var paused: float = session.mining.progress
	check(paused > 0.9 and paused < 1.2 and session.ore.pieces.size() == 8, "Real E input starts mining without extracting early")
	await frames(30)
	check(session.mining.progress == paused and session.mining.worker == 0, "E release pauses mining")
	session.spawn_player(2, Vector2(390, 288))
	session.work_held[2] = true
	await frames(60)
	session.peer_left(2)
	await frames(5)
	var after_disconnect: float = session.mining.progress
	check(after_disconnect > paused and session.mining.worker == 0, "Miner disconnect leaves shared progress intact")
	Input.action_press("interact")
	for i in range(120):
		await frames(1)
		if session.mining.extracted == 1:
			break
	Input.action_release("interact")
	await frames(60)
	check(session.mining.extracted == 1 and session.ore.pieces.size() == 9 and session.ore_bodies.has(8), "Handoff produces one new physical ore identity")
	var body: RigidBody2D = session.ore_bodies[8]
	var at: Vector2 = session.world.to_local(body.global_position)
	check(body.visible and not body.freeze and at.y > 280 and at.y < 288 and absf(at.x - 344) < 5, "Extracted ore falls and settles beside mine entrance")
	dwarf.position = Vector2(344, 288)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(session.ore.carried_by(1) == 8, "Mined ore can be picked up with E")
	session.release_ore(1, false)
	await frames(20)
	check(session.ore.is_loose(8) and body.visible, "Mined ore uses existing throw physics")
	session.disconnect_game("Done")
	check(session.mining.extracted == 0 and session.mining.progress == 0 and session.ore.pieces.size() == 8 and not session.ore_bodies.has(8), "New session clears mined bodies and progress")
	print("MINING PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
