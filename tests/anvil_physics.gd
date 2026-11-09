extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS anvil physics: ", message)
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
	var dwarf = session.players[1]
	session.ore.store(0)
	session.ore.finish_smelting(session.ore.begin_smelting())
	session.ore.pickup(1, 0)
	session.refresh_ore()
	dwarf.position = Vector2(260, 216)
	await frames(5)
	Input.action_press("interact")
	await frames(120)
	Input.action_release("interact")
	await frames(5)
	check(session.anvil.piece == 0 and session.anvil.progress > 1.9 and session.anvil.progress < 2.2, "E loads ingot and advances anvil work")
	var paused: float = session.anvil.progress
	await frames(30)
	check(session.anvil.progress == paused, "Anvil pauses on E release")
	# An occupied station must not take an additional carried item.
	session.ore.pickup(1, 1)
	session.refresh_ore()
	session.interact_for(1)
	check(session.ore.carried_by(1) == 1 and session.anvil.piece == 0, "Another input cannot overwrite a loaded job")
	session.release_ore(1, true)
	session.spawn_player(2, Vector2(260, 216))
	session.work_held[2] = true
	for i in range(300):
		await frames(1)
		if session.ore.pieces[0].kind == "hammer":
			break
	session.work_held[2] = false
	var body: RigidBody2D = session.ore_bodies[0]
	await frames(60)
	var at: Vector2 = session.world.to_local(body.global_position)
	check(session.ore.pieces[0].kind == "hammer" and body.visible and not body.freeze and absf(at.x - 282) < 8, "Handoff outputs a physical hammer onto tray")
	dwarf.position = Vector2(282, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	session.interact_for(1)
	check(session.ore.carried_by(1) == 0 and dwarf.get_node("CarriedOre").texture == session.HAMMER_TEXTURE, "Hammer can be picked up with correct texture")
	session.release_ore(1, false)
	await frames(30)
	check(session.ore.is_loose(0) and body.visible, "Hammer can be thrown and stays in world")
	session.disconnect_game("Done")
	check(session.anvil.piece == -1 and session.anvil.progress == 0, "Disconnect resets anvil state")
	print("ANVIL PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
