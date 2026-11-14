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
	check(session.catalog_tabs.get_tab_count() == 3, "Building catalog contains no room purchase tab")
	await click(session.room_buttons[Vector3i(2, 0, 0)])
	check(session.rooms.building.has(Vector2i(2, 0)) and session.orders.coins == 75, "World expansion button buys the neighboring ground room")
	session.catalog.hide()
	Input.action_press("move_right")
	await frames(50)
	Input.action_release("move_right")
	check(dwarf.position.x > 470 and dwarf.is_on_floor(), "Purchased room removes former wall and adds walkable floor")
	check(session.workshop.can_place(Vector2(512, 216)), "Purchased floor supports furniture")
	session.purchase_room_for(1, false, Vector2i(1, 1))
	dwarf.position = Vector2(390, 288)
	dwarf.velocity = Vector2.ZERO
	await frames(40)
	check(session.entrance_button != null and session.world.entrance.visible, "Mine signpost and purchase button appear in the basement")
	await click(session.entrance_button)
	check(session.world.entrance.get_child(0).texture == preload("res://assets/textures/mine_entrance.svg"), "Purchased entrance displays a timber mine marker")
	await frames(5)
	check(session.orders.coins == 30 and session.mine_veins.size() == 1 and session.rooms.depth() == 1, "Basement and mine entrance unlock one chamber and vein")
	check(session.vein_at(Vector2(528, 448)) == -1 and session.vein_at(Vector2(320, 528)) == -1, "Locked chambers cannot be mined")
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
	await frames(190)
	Input.action_release("climb_down")
	check(absf(dwarf.position.y - 448) < 1 and dwarf.climbing, "Entrance ladder reaches first chamber and stops at its floor")
	session.buy_transport_for(1, "lift", 2)
	check(session.transport.upgrades == 0 and session.orders.coins == 30, "Elevator cannot upgrade into unpurchased depth")
	session.orders.coins = 200
	session.purchase_room_for(1, true, Vector2i(1, 2))
	check(dwarf.climbing and absf(dwarf.position.y - 448) < 1, "Expansion preserves ladder attachment and position")
	Input.action_press("climb_down")
	await frames(100)
	Input.action_release("climb_down")
	check(absf(dwarf.position.y - 528) < 1 and session.mine_veins.size() == 2, "New shaft segment opens deeper floor and vein")
	check(session.rooms.room_rect(true, Vector2i(1, 1)).position.y - 288 == 80, "Mine begins one floor-height below the basement")
	var space: PhysicsDirectSpaceState2D = session.world.get_world_2d().direct_space_state
	var floors_solid := true
	for y in [216, 288, 448, 528]:
		var query := PhysicsRayQueryParameters2D.create(session.world.to_global(Vector2(280, y - 10)), session.world.to_global(Vector2(280, y + 12)), 1)
		var hit := space.intersect_ray(query)
		floors_solid = floors_solid and not hit.is_empty() and absf(session.world.to_local(hit.position).y - y) < 1
	check(floors_solid, "Ground, basement and mine floors all retain solid collision away from ladders")
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = session.world.to_global(Vector2(350, 328))
	check(not space.intersect_point(query).is_empty(), "Gap contains solid earth beside the mine shaft")
	query.position = session.world.to_global(Vector2(390, 328))
	check(space.intersect_point(query).is_empty(), "Mine shaft remains open through the rock layer")
	var floors_visible := true
	for sprite in session.world.generated.get_children():
		if sprite is Sprite2D and sprite.texture in [session.world.BRICK, session.world.ROCK]:
			floors_visible = floors_visible and sprite.z_index < 0
	check(floors_visible, "Room and rock backgrounds render behind floor and ceiling textures")
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
