extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS building interaction: ", message)
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
func click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = session.world.to_global(at)
	session._unhandled_input(event)
	await frames(5)
func station_id(kind: String) -> int:
	for id in session.workshop.stations:
		if session.workshop.stations[id].kind == kind: return id
	return -1
func run_job(at: Vector2) -> void:
	session.players[1].position = at
	session.players[1].velocity = Vector2.ZERO
	await frames(5)
	await press("interact")
	Input.action_press("interact")
	await frames(310)
	Input.action_release("interact")
	await frames(20)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	await frames(5)
	check(session.station_nodes.is_empty() and session.orders.number == 0, "New world has no stations and stays closed")
	await press("build_menu")
	check(session.catalog.visible, "Tab opens build catalog")
	# Exercise the actual catalog button connection, not just the data model.
	session.catalog.get_child(0).get_child(1).pressed.emit()
	await frames(5)
	check(session.orders.coins == 80 and session.build_ghost.visible and not session.catalog.visible, "Catalog purchase gives placement preview and reserves coins")
	await click(Vector2(112, 216))
	check(session.workshop.stations.is_empty() and session.workshop.pending.has(1), "Mouse placement on ladder is rejected without losing kit")
	await click(Vector2(256, 216))
	var anvil := station_id("anvil")
	check(anvil > 0 and session.station_nodes.has(anvil) and not session.build_ghost.visible and session.workshop.opened, "Mouse places a visible anvil and opens shop")
	var dwarf = session.players[1]
	dwarf.position = Vector2(256, 216)
	await frames(5)
	await press("pack_station")
	check(session.station_nodes.is_empty() and session.build_ghost.visible, "R packs idle anvil for moving")
	await click(Vector2(160, 136))
	check(session.workshop.stations[anvil].at == Vector2(160, 136), "Manual placement works on upper floor")
	session.ore.pickup(1, 0)
	session.refresh_ore()
	await run_job(Vector2(160, 136))
	check(session.ore.pieces[0].kind == "horseshoe" and session.ore_bodies[0].visible, "Raw ore becomes physical horseshoe using only placed anvil")
	var at: Vector2 = session.world.to_local(session.ore_bodies[0].global_position)
	check(absf(at.x - 188) < 8 and at.y < 136 and at.y > 120, "Output falls onto station's relocated tray")
	session.purchase_for(1, "grinder")
	await frames(5)
	await press("cancel_build")
	check(session.orders.coins == 80 and not session.workshop.pending.has(1), "Escape refunds unplaced purchase")
	# Work beside the starting ore pile: E must work a loaded job, not grab ore.
	session.purchase_for(1, "woodbench")
	session.place_for(1, Vector2(248, 288))
	var log_id: int = session.ore.add_material("wood")
	session.ore.pickup(1, log_id)
	session.refresh_ore()
	await run_job(Vector2(248, 288))
	check(session.ore.pieces[log_id].kind == "shaft" and session.ore.carried_by(1) == -1, "Loaded work takes priority over picking up loose ore nearby")
	dwarf.position = Vector2(160, 136)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	# Packing a loaded station must preserve ingredients.
	session.ore.pickup(1, 1)
	session.refresh_ore()
	await press("interact")
	await press("pack_station")
	check(session.workshop.stations.has(anvil) and session.workshop.stations[anvil].job.slots.has("ore"), "Loaded station cannot be packed")
	session.disconnect_game("Done")
	check(session.station_nodes.is_empty() and session.workshop.pending.is_empty() and session.orders.coins == 100, "Reset removes placed stations and restores budget")
	print("BUILD INTERACTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
