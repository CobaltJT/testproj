extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS loose physics: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	preload("res://tests/world_fixture.gd").prepare(session)
	await frames(150)
	var resting := true
	for body in session.ore_bodies.values():
		var at: Vector2 = session.world.to_local(body.global_position)
		resting = resting and at.y > 278 and at.y < 288 and body.linear_velocity.length() < 10
	check(resting, "Loose ore settles on floor in an empty workshop")
	check(session.workshop.stations.is_empty() and session.station_nodes.is_empty() and session.orders.number == 0, "No free stations or customer clock before opening")
	var dwarf = session.players[1]
	dwarf.position = Vector2(240, 288)
	session.interact_for(1)
	var piece: int = session.ore.carried_by(1)
	check(piece != -1, "Loose ore can be picked up")
	if piece == -1:
		quit(1)
		return
	session.release_ore(1, true)
	await frames(90)
	check(session.ore.is_loose(piece) and session.ore_bodies[piece].visible, "Dropped ore persists")
	session.ore.pickup(1, piece)
	session.refresh_ore()
	dwarf.position = Vector2(180, 216)
	dwarf.velocity = Vector2.ZERO
	dwarf.sprite.flip_h = false
	session.spawn_player(2, Vector2(212, 216))
	session.release_ore(1, false)
	await frames(30)
	check(session.players[2].position.x > 217, "Thrown ore knocks another dwarf back")
	check(session.ore.is_loose(piece), "Thrown ore remains a recoverable physics object")
	session.ore.pickup(2, 5)
	session.refresh_ore()
	session.peer_left(2)
	await frames(30)
	check(session.ore.is_loose(5), "Disconnect drops carried material")
	session.disconnect_game("Done")
	print("LOOSE PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
