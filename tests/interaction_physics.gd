extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS routed interactions: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func press_e() -> void:
	session.last_interaction.erase(1)
	session.interact_for(1)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	preload("res://tests/world_fixture.gd").prepare(session)
	session.set_physics_process(false)
	session.orders.coins = 1000
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(456, 288))
	var station: int = session.workshop.nearest(Vector2(456, 288))
	var job = session.workshop.stations[station].job
	session.ore.pieces[0].kind = "ingot"
	session.ore.pickup(1, 0)
	job.load_material(1, session.ore)
	var bin: int = session.ore.add_material("ore_bin")
	session.movable_objects.refresh()
	session.movable_objects.position_body(session.movable_objects.bodies[bin], Vector2(456, 277), Vector2.ZERO)
	session.players[1].position = Vector2(456, 288)
	session.players[1].velocity = Vector2.ZERO
	await frames(3)
	var fallthrough: Array = []
	session.interaction_router.handlers.append(func(_context):
		fallthrough.append(true)
		return false)
	var notice: String = session.hud.last_message
	press_e()
	check(session.ore.carried_by(1) == -1 and session.ore.is_loose(bin) and fallthrough.is_empty() and session.hud.last_message == notice, "Empty bin consumes E quietly instead of falling through to a loaded anvil")
	session.toggle_cart_for(1)
	check(session.ore.carried_by(1) == bin, "C routes to bin pickup")
	session.toggle_cart_for(1)
	check(session.ore.is_loose(bin), "C routes to bin drop")
	session.ore.pieces[2].kind = "shaft"
	session.ore.store_in_bin(bin, 2)
	session.movable_objects.refresh()
	press_e()
	check(session.ore.carried_by(1) == 2 and job.slots.ingot == 0 and fallthrough.is_empty(), "Stocked bin retrieval wins over a loaded station")
	session.ore.release_carrier(1)
	session.movable_objects.position_body(session.movable_objects.bodies[2], Vector2(150, 270), Vector2.ZERO)
	session.transport.upgrade(1, session.orders)
	session.transport.buy_rail(1, session.orders)
	session.transport.place_rail(1, Vector2(454, 288))
	var cart: int = session.transport.buy_cart(Vector2(454, 288), session.orders)
	session.sync_transport()
	session.ore.pieces[1].kind = "ingot"
	session.ore.pickup(1, 1)
	session.movable_objects.refresh()
	press_e()
	check(session.ore.carried_by(1) == -1 and session.ore.pieces[bin].contents == [1] and session.transport.carts[cart].items.is_empty(), "Cart declines an ingot so a later callable can deposit it in a bin")
	session.transport.store(cart, 3, session.ore)
	press_e()
	check(session.ore.carried_by(1) == 1 and session.transport.carts[cart].items == [3], "Loose bin retrieval retains priority over cart inventory")
	session.ore.release_carrier(1)
	session.movable_objects.position_body(session.movable_objects.bodies[1], Vector2(150, 270), Vector2.ZERO)
	session.movable_objects.position_body(session.movable_objects.bodies[bin], Vector2(150, 270), Vector2.ZERO)
	session.movable_objects.refresh()
	press_e()
	check(session.ore.carried_by(1) == 3 and session.transport.carts[cart].items.is_empty(), "E retrieves the original cart item through the router")
	session.interact_for(1)
	check(session.ore.carried_by(1) == 3, "Host debounce prevents a duplicate request from immediately redepositing it")
	session.ore.release_carrier(1)
	session.movable_objects.position_body(session.movable_objects.bodies[3], Vector2(150, 270), Vector2.ZERO)
	session.movable_objects.refresh()
	press_e()
	check(session.ore.carried_by(1) == -1 and fallthrough.is_empty(), "An empty cart consumes E instead of falling through")
	session.cycle_storage_for(1)
	check(job.recipe == "horseshoe" and fallthrough.is_empty(), "T on a loaded anvil is consumed without changing its recipe")
	job.slots.clear()
	session.ore.pieces[0].processing = false
	session.ore.pieces[0].consumed = true
	session.cycle_storage_for(1)
	check(job.recipe == "blade", "T on an empty anvil routes to recipe cycling")
	var inventory: Dictionary = session.ore.snapshot()
	check(not session.route_interaction(999, &"interact") and inventory == session.ore.snapshot(), "Unknown actors are rejected before routing")
	session.cycle.phase = "summary"
	check(not session.route_interaction(1, &"interact") and inventory == session.ore.snapshot(), "Modal phases reject interaction dispatch")
	session.cycle.phase = "morning"
	session.interaction_router.handlers.pop_back()
	var old_items = session.ore
	session.disconnect_game("Reset")
	var old_snapshot: Dictionary = old_items.snapshot()
	session.host_game()
	session.set_physics_process(false)
	session.movable_objects.position_body(session.movable_objects.bodies[0], Vector2(222, 208), Vector2.ZERO)
	press_e()
	check(session.ore.carried_by(1) == 0 and old_items.snapshot() == old_snapshot and session.movable_objects.items == session.ore and session.placeables.workshop == session.workshop, "New sessions rebind controller dependencies without changing the old inventory")
	session.disconnect_game("Done")
	print("ROUTED INTERACTIONS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
