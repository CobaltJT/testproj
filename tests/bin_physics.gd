extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS bins: ", message)
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
	for size in ["small", "medium", "large"]:
		var kind: String = "intermediate_" + size
		session.purchase_for(1, kind)
		session.place_for(1, Vector2(256, 216))
		var id: int = session.workshop.nearest(Vector2(256, 216))
		var view: Node2D = session.station_nodes[id]
		await frames(5)
		check(view.get_node("PartsCatch").monitoring and view.get_node("PartsWalls").collision_layer == 8, "Open " + size + " bin has live catch sensor and physical sides")
		var piece: int = session.ore.add_material("ingot")
		session.refresh_ore()
		if size == "small":
			session.ore.pickup(1, piece)
			session.refresh_ore()
			session.players[1].position = Vector2(206, 216)
			session.players[1].velocity = Vector2.ZERO
			session.players[1].sprite.flip_h = false
			await frames(5)
			Input.action_press("throw_ore")
			await frames(2)
			Input.action_release("throw_ore")
		else:
			session.position_ore(session.ore_bodies[piece], Vector2(264, 170), Vector2(0, 100))
		await frames(80)
		check(session.workshop.stations[id].items == [piece] and not session.ore_bodies[piece].visible, "Thrown ingot is caught once by " + size + " bin")
		session.players[1].position = Vector2(256, 216)
		session.players[1].velocity = Vector2.ZERO
		await frames(5)
		session.interact_for(1)
		check(session.ore.carried_by(1) == piece, "Caught identity can be retrieved manually")
		session.ore.release_carrier(1)
		session.position_ore(session.ore_bodies[piece], Vector2(300, 270), Vector2.ZERO)
		session.refresh_ore()
		session.pack_for(1)
		session.place_for(1, Vector2(456, 216))
		await frames(5)
		view = session.station_nodes[id]
		check(view.get_node("PartsCatch").global_position == session.world.to_global(Vector2(464, -view.get_node("Sprite").texture.get_height() / 2.0 + 216)), "Bin sensor relocates with " + size + " container")
		session.players[1].position = Vector2(456, 216)
		session.pack_for(1)
		session.cancel_build_for(1)
	# Fill small bin through normal state operations, then test physical overflow and wrong goods.
	session.purchase_for(1, "intermediate_small")
	session.place_for(1, Vector2(256, 216))
	var id: int = session.workshop.nearest(Vector2(256, 216))
	for i in range(5):
		var piece: int = session.ore.add_material("shaft")
		check(session.workshop.catch_intermediate(id, piece, session.ore), "Bin reserves compatible identity")
	var overflow: int = session.ore.add_material("ingot")
	var wrong: int = session.ore.add_material("sword")
	session.refresh_ore()
	session.position_ore(session.ore_bodies[overflow], Vector2(264, 170), Vector2(0, 100))
	session.position_ore(session.ore_bodies[wrong], Vector2(264, 165), Vector2(0, 100))
	await frames(80)
	check(session.ore.is_loose(overflow) and session.ore.is_loose(wrong) and session.workshop.stations[id].items.size() == 5, "Full or incompatible bin leaves thrown items as recoverable physics objects")
	session.purchase_for(1, "finished_small")
	session.place_for(1, Vector2(456, 216))
	var shelf: int = session.workshop.nearest(Vector2(456, 216))
	var product: int = session.ore.add_material("horseshoe")
	session.refresh_ore()
	session.position_ore(session.ore_bodies[product], Vector2(464, 165), Vector2(0, 100))
	await frames(80)
	check(not session.station_nodes[shelf].get_node("PartsCatch").monitoring and session.workshop.stations[shelf].items.is_empty() and session.ore.is_loose(product), "Shelf never catches thrown finished goods")
	session.disconnect_game("Done")
	print("BIN PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
