extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS forge physics: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(12)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	preload("res://tests/world_fixture.gd").prepare(session)
	check(session.workshop.stations.is_empty(), "Forge is not preinstalled")
	session.purchase_for(1, "forge")
	session.place_for(1, Vector2(256, 216))
	var id: int = session.workshop.stations.keys()[0]
	var forge = session.workshop.stations[id].job
	var view: Node2D = session.station_nodes[id]
	await frames(10)
	check(view.get_node("BinCatch").monitoring and view.get_node("BinWalls").collision_layer == 8, "Included bin has live sensor and physical walls")
	var dwarf = session.players[1]
	session.ore.pickup(1, 0)
	session.refresh_ore()
	dwarf.position = Vector2(184, 216)
	dwarf.velocity = Vector2.ZERO
	dwarf.sprite.flip_h = false
	await press("throw_ore")
	for i in range(120):
		await frames(1)
		if forge.ore_queue.has(0): break
	check(forge.ore_queue == [0] and not session.ore_bodies[0].visible, "Thrown ore lands in attached bin and is stored")
	await frames(20)
	check(forge.ore_queue.size() == 1, "Bin cannot count same piece twice")
	dwarf.position = Vector2(256, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	await press("pack_station")
	check(session.workshop.stations.has(id) and not session.workshop.pending.has(1), "Stocked forge cannot be packed")
	Input.action_press("interact")
	await frames(120)
	Input.action_release("interact")
	await frames(5)
	var paused: float = forge.progress
	check(paused > 1.9 and paused < 2.2 and forge.slots.has("ore"), "Real hold E starts forge work from the bin")
	await frames(30)
	check(forge.progress == paused and forge.worker == 0, "Release pauses physical forge job")
	Input.action_press("interact")
	for i in range(210):
		await frames(1)
		if session.ore.pieces[0].kind == "ingot": break
	Input.action_release("interact")
	await frames(40)
	var body: RigidBody2D = session.ore_bodies[0]
	check(session.ore.pieces[0].kind == "ingot" and body.visible and not body.freeze, "Forge outputs physical ingot")
	var at: Vector2 = session.world.to_local(body.global_position)
	check(absf(at.x - 284) < 8 and at.y > 200 and at.y < 216, "Ingot lands on forge output tray")
	await press("pack_station")
	session.place_for(1, Vector2(160, 136))
	await frames(10)
	view = session.station_nodes[id]
	check(view.get_node("BinCatch/Shape").global_position == session.world.to_global(Vector2(146, 128)), "Relocating forge moves bin sensor and geometry with it")
	check(view.get_node("BinWalls/Left").global_position == session.world.to_global(Vector2(137, 129)), "Attached bin wall relocates with forge")
	session.disconnect_game("Done")
	print("FORGE PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
