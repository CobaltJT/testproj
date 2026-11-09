extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS forge physics: ", message)
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
	session.refresh_ore()
	Input.action_press("interact")
	await frames(10)
	check(session.forge.piece == -1, "Holding E away from forge does not spend ore")
	Input.action_release("interact")
	dwarf.position = Vector2(400, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press("interact")
	await frames(120)
	Input.action_release("interact")
	await frames(3)
	var paused: float = session.forge.progress
	check(paused > 1.9 and paused < 2.2 and session.ore.deposited == 0, "Actual hold E reserves ore and advances in seconds")
	await frames(30)
	check(session.forge.progress == paused and session.forge.worker == 0, "Actual E release pauses progress")
	session.spawn_player(2, Vector2(400, 216))
	await frames(3)
	session.work_held[2] = true
	await frames(190)
	check(session.ore.pieces[0].kind == "ingot" and session.forge.piece == -1, "Another dwarf completes paused job")
	var body: RigidBody2D = session.ore_bodies[0]
	await frames(60)
	var at: Vector2 = session.world.to_local(body.global_position)
	check(body.visible and not body.freeze and absf(at.x - 342) < 5 and at.y > 200 and at.y < 213, "Physical ingot lands on output tray")
	check(body.get_node("Sprite2D").texture == session.INGOT_TEXTURE, "Output uses ingot image texture")
	dwarf.position = Vector2(342, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	session.interact_for(1)
	check(session.ore.carried_by(1) == 0 and dwarf.get_node("CarriedOre").texture == session.INGOT_TEXTURE, "Finished ingot can be picked up")
	session.release_ore(1, true)
	await frames(30)
	check(session.ore.is_loose(0) and body.visible, "Finished ingot can be dropped as a physics object")
	session.disconnect_game("Done")
	check(session.forge.piece == -1 and session.forge.progress == 0 and session.ore.pieces[0].kind == "ore", "New session resets forge and materials")
	print("FORGE PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
