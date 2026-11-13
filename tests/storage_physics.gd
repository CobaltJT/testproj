extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS storage interaction: ", message)
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
	await press("build_menu")
	check(session.station_buttons.size() == 10 and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(session.catalog.get_global_rect()), "Build catalog includes all six storage options and fits viewport")
	session.station_buttons.finished_small.pressed.emit()
	await frames(5)
	check(session.build_ghost.visible and session.build_ghost.texture == session.STATION_VIEW.TEXTURES.finished_small, "Storage purchase uses its own image texture preview")
	session.place_for(1, Vector2(456, 216))
	var id: int = session.workshop.nearest(Vector2(456, 216))
	session.players[1].position = Vector2(456, 216)
	await frames(5)
	session.ore.pieces[0].kind = "horseshoe"
	session.ore.pickup(1, 0)
	session.refresh_ore()
	await press("interact")
	check(session.workshop.stations[id].items == [0] and not session.ore_bodies[0].visible and session.ore.carried_by(1) == -1, "E stores product and hides physical item and carried sprite")
	check("1/5" in session.station_nodes[id].get_node("Label").text and not session.station_nodes[id].get_node("Progress").visible, "Container shows capacity instead of work progress")
	await press("pack_station")
	check(session.workshop.stations.has(id), "R cannot pack a filled container")
	session.ore.pieces[1].kind = "ingot"
	session.ore.pickup(1, 1)
	session.refresh_ore()
	await press("interact")
	check(session.ore.carried_by(1) == 1 and session.workshop.stations[id].items == [0], "Finished storage refuses intermediate product")
	session.ore.release_carrier(1)
	session.ore.pieces[2].kind = "sword"
	session.ore.pickup(1, 2)
	session.refresh_ore()
	await press("interact")
	await press("cycle_storage")
	check(session.workshop.stations[id].selected == "sword", "T selects another mixed stored product")
	await press("interact")
	check(session.ore.carried_by(1) == 2 and session.workshop.stations[id].items == [0], "E retrieves selected identity directly into hands")
	await press("drop_ore")
	check(session.ore.is_loose(2) and session.ore_bodies[2].visible, "Retrieved item becomes ordinary physical object when dropped")
	session.disconnect_game("Done")
	check(session.workshop.stations.is_empty() and session.ore.pieces[0].kind == "ore", "New session resets containers and stored product ledger")
	print("STORAGE INTERACTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
