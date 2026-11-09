extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS physics ore: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
		session.step_ore()
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	session.set_physics_process(false)
	await frames(150)
	var dwarf = session.players[1]
	var resting := true
	for body in session.ore_bodies.values():
		resting = resting and session.world.to_local(body.global_position).y < 288 and session.world.to_local(body.global_position).y > 278 and body.linear_velocity.length() < 10
	check(resting, "Loose rigid bodies settle on basement floor")
	dwarf.position = Vector2(240, 288)
	dwarf.velocity = Vector2.ZERO
	session.interact_for(1)
	var piece: int = session.ore.carried_by(1)
	check(piece != -1, "Pick up a nearby physical piece")
	if piece == -1:
		quit(1)
		return
	session.release_ore(1, true)
	await frames(100)
	var body: RigidBody2D = session.ore_bodies[piece]
	check(session.ore.is_loose(piece) and body.visible and not body.freeze and session.world.to_local(body.global_position).y > 278, "Dropped ore remains in world and settles")
	# Place a known piece near the dwarf to isolate throwing from pickup selection.
	session.ore.pickup(1, piece)
	session.refresh_ore()
	dwarf.position = Vector2(260, 216)
	dwarf.velocity = Vector2.ZERO
	dwarf.sprite.flip_h = false
	session.release_ore(1, false)
	check(body.linear_velocity.x > 200 and body.linear_velocity.y < 0, "Throw launches a physical arc")
	await frames(100)
	check(session.ore.deposited == 1 and not body.visible, "Thrown ore enters bin and is stored once")
	await frames(30)
	check(session.ore.deposited == 1, "Resting in bin cannot duplicate a deposit")
	# A missed throw persists rather than vanishing.
	session.ore.pickup(1, 7)
	session.refresh_ore()
	dwarf.position = Vector2(160, 216)
	dwarf.sprite.flip_h = false
	session.release_ore(1, false)
	await frames(100)
	check(session.ore.is_loose(7) and session.ore_bodies[7].visible, "Missed throw stays available on the floor")
	# Throw at another actual player rather than teleporting an active rigid body.
	session.spawn_player(2, Vector2(212, 216))
	var target = session.players[2]
	dwarf.position = Vector2(180, 216)
	dwarf.velocity = Vector2.ZERO
	dwarf.sprite.flip_h = false
	session.ore.pickup(1, 6)
	session.refresh_ore()
	session.release_ore(1, false)
	await frames(24)
	check(target.position.x > 217, "Ore impact knocks a dwarf sideways")
	session.ore.pickup(2, 5)
	session.refresh_ore()
	var disconnect_at: Vector2 = target.position
	session.peer_left(2)
	await frames(60)
	check(session.ore.is_loose(5) and session.ore_bodies[5].visible and absf(session.world.to_local(session.ore_bodies[5].global_position).x - disconnect_at.x) < 30, "Disconnected dwarf drops carried ore where they stood")
	check(session.ore.available + session.ore.carriers.size() + session.ore.deposited == 8, "Physics preserves all eight pieces")
	session.disconnect_game("Test complete")
	print("ORE PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
