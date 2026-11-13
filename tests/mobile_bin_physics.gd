extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS mobile physics: ", message)
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
	await frames(5)
	var dwarf = session.players[1]
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(456, 216))
	var station: int = session.workshop.nearest(Vector2(456, 216))
	check(session.world.get_node("Building").z_index < session.station_nodes[station].z_index and session.station_nodes[station].z_index < dwarf.z_index and dwarf.z_index < session.ore_bodies[0].z_index, "Background, placeables, characters and loose objects use ordered draw layers")
	dwarf.position = Vector2(456, 216)
	await frames(5)
	session.ore.pieces[0].kind = "ingot"
	session.ore.pickup(1, 0)
	session.workshop.stations[station].job.load_material(1, session.ore)
	session.refresh_ore()
	session.position_ore(session.ore_bodies[1], Vector2(457, 208), Vector2.ZERO)
	session.interact_for(1)

	check(session.ore.carried_by(1) == 1 and session.workshop.stations[station].job.progress == 0, "Nearby loose object wins over loaded placeable on interact")
	session.ore.release_carrier(1)
	session.position_ore(session.ore_bodies[1], Vector2(150, 270), Vector2.ZERO)
	session.refresh_ore()
	session.mobile_bin_button.pressed.emit()
	await frames(3)
	var bin: int = session.ore.carried_by(1)
	check(bin != -1 and session.ore.pieces[bin].kind == "ore_bin" and session.orders.coins == 65, "Catalog buys movable bin directly into hands")
	await press("drop_ore")
	await frames(40)
	check(session.ore.is_loose(bin) and session.ore_bodies[bin].get_node("Catch").monitoring, "Dropped bin is a live movable physics container")
	var body: RigidBody2D = session.ore_bodies[bin]
	var center: Vector2 = session.world.to_local(body.global_position)
	session.ore.pieces[2].kind = "shaft"
	session.position_ore(session.ore_bodies[2], center + Vector2(0, -35), Vector2(0, 100))
	await frames(60)
	check(session.ore.pieces[bin].contents == [2] and not session.ore_bodies[2].visible, "Falling intermediate product is caught in movable bin")
	dwarf.position = session.world.to_local(body.global_position) + Vector2(0, 11)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	await press("interact")
	check(session.ore.carried_by(1) == bin and session.ore.pieces[bin].contents == [2], "E prioritizes picking up loaded movable bin over anvil")
	await press("throw_ore")
	await frames(40)
	check(session.ore.is_loose(bin) and session.ore.pieces[bin].contents == [2] and not session.ore_bodies[bin].freeze, "Thrown bin remains physical and retains ore")
	center = session.world.to_local(body.global_position)
	dwarf.position = Vector2(center.x, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	await press("take_bin_ore")
	check(session.ore.carried_by(1) == 2 and session.ore.pieces[bin].contents.is_empty(), "G withdraws original intermediate product into empty hands")
	session.disconnect_game("Done")
	check(session.ore.pieces.size() == 8, "Leaving clears movable bins and their contents")
	print("MOBILE BIN PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
