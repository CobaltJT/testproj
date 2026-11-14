extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS room world: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func click(button: Button) -> void:
	await frames(3)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)
		await frames(2)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	await frames(10)
	var dwarf = session.players[1]
	check(session.rooms.building.size() == 2 and session.station_nodes.is_empty() and session.vein_nodes.is_empty() and dwarf.ladders.is_empty(), "Fresh game contains only two ground rooms, counter and door")
	check(session.ore_bodies.values().all(func(body): return session.rooms.contains_floor(Vector2(session.world.to_local(body.global_position).x, 216))), "Starting ore stays inside the owned ground floor")
	check(not session.workshop.can_place(Vector2(512, 216)) and not session.workshop.can_place(Vector2(256, 136)), "Station placement rejects unpurchased space")
	dwarf.position = Vector2(410, 216)
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	check(dwarf.position.x < 455 and dwarf.is_on_floor(), "Exterior room wall contains player")
	session.catalog.show()
	session.catalog_tabs.current_tab = 3
	await click(session.room_buttons[Vector3i(2, 0, 0)])
	check(session.rooms.building.has(Vector2i(2, 0)) and session.orders.coins == 75, "Rooms tab mouse button buys ground expansion")
	session.catalog.hide()
	Input.action_press("move_right")
	await frames(50)
	Input.action_release("move_right")
	check(dwarf.position.x > 470 and dwarf.is_on_floor(), "Purchased room removes former wall and adds walkable floor")
	check(session.workshop.can_place(Vector2(512, 216)), "Purchased floor supports furniture")
	session.purchase_room_for(1, false, Vector2i(1, 1))
	session.purchase_room_for(1, true, Vector2i(1, 0))
	await frames(5)
	check(session.orders.coins == 30 and session.mine_veins.size() == 1 and session.rooms.depth() == 1, "Basement and mine entrance unlock one chamber and vein")
	check(session.vein_at(Vector2(528, 368)) == -1 and session.vein_at(Vector2(320, 448)) == -1, "Locked chambers cannot be mined")
	dwarf.position = Vector2(320, 216)
	dwarf.velocity = Vector2.ZERO
	Input.action_press("climb_down")
	await frames(100)
	Input.action_release("climb_down")
	check(absf(dwarf.position.y - 288) < 1 and dwarf.climbing, "New basement ladder connects ground floor")
	dwarf.position = Vector2(390, 288)
	dwarf.velocity = Vector2.ZERO
	dwarf.climbing = false
	Input.action_press("climb_down")
	await frames(100)
	Input.action_release("climb_down")
	check(absf(dwarf.position.y - 368) < 1 and dwarf.climbing, "Entrance ladder reaches first chamber and stops at its floor")
	session.buy_transport_for(1, "lift", 2)
	check(session.transport.upgrades == 0 and session.orders.coins == 30, "Elevator cannot upgrade into unpurchased depth")
	session.orders.coins = 200
	session.purchase_room_for(1, true, Vector2i(1, 2))
	check(dwarf.climbing and absf(dwarf.position.y - 368) < 1, "Expansion preserves ladder attachment and position")
	Input.action_press("climb_down")
	await frames(100)
	Input.action_release("climb_down")
	check(absf(dwarf.position.y - 448) < 1 and session.mine_veins.size() == 2, "New shaft segment opens deeper floor and vein")
	# New vertical access must not destroy or overlap an existing workstation.
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(320, 216)) # Existing ladder: blocked.
	check(session.workshop.stations.is_empty(), "Furniture cannot block existing ladders")
	session.place_for(1, Vector2(624, 216))
	var before: int = session.orders.coins
	session.purchase_room_for(1, false, Vector2i(2, -1))
	check(not session.rooms.owned(false, Vector2i(2, -1)) and session.orders.coins == before, "Room purchase refuses a new ladder through furniture without charging")
	session.cycle.phase = "summary"
	session.purchase_room_for(1, false, Vector2i(0, 1))
	check(not session.rooms.owned(false, Vector2i(0, 1)), "Daily summary blocks room purchases")
	var owned: Dictionary = session.rooms.snapshot()
	session.cycle.phase = "evening"
	session.cycle.step(0, session.orders, session.merchant)
	session.advance_day()
	await frames(50)
	check(session.cycle.day == 2 and session.cycle.phase == "morning" and session.rooms.snapshot() == owned, "Next morning preserves rooms")
	session.disconnect_game("Done")
	check(session.rooms.building.size() == 2 and not session.rooms.mine_open and session.vein_nodes.is_empty(), "New session resets owned rooms, ladder geometry and veins")
	print("ROOM WORLD RESULT: ", failures, " failures")
	quit(1 if failures else 0)
