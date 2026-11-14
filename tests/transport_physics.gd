extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS transport physics: ", message)
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
	await frames(5)
	check(session.transport_buttons[2].disabled and not session.transport_buttons[1].disabled, "Transport UI only offers next elevator segment")
	session.buy_transport_for(1, "lift", 2)
	check(session.transport.upgrades == 0 and session.orders.coins == 100, "Host rejects skipped upgrade")
	session.transport_buttons[1].pressed.emit()
	check(session.transport.upgrades == 1 and session.lift_node.visible and session.players[1].mine_ladder_top == 448, "Purchase replaces top ladder segment with elevator")
	session.transport_buy("rail", 0)
	session.place_rail_for(1, Vector2(326, 288))
	var dwarf = session.players[1]
	dwarf.position = Vector2(358, 288)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	session.transport_buy("cart", 0)
	check(session.transport.carts.size() == 1 and session.cart_nodes.size() == 1, "Purchase spawns cart on rails")
	var piece: int = session.ore.add_material("ore")
	session.refresh_ore()
	session.position_ore(session.ore_bodies[piece], Vector2(358, 250), Vector2(0, 100))
	await frames(80)
	check(session.transport.carts[1].items == [piece] and not session.ore_bodies[piece].visible, "Cart catches physical ore")
	check(not InputMap.has_action("take_bin_ore"), "Obsolete G binding is removed")
	await press("interact")
	check(session.ore.carried_by(1) == piece and session.transport.carts[1].items.is_empty(), "E withdraws exact ore identity with empty hands")
	await press("interact")
	check(session.ore.carried_by(1) == -1 and session.transport.carts[1].items == [piece], "E deposits carried ore back into cart")
	var player_before: Vector2 = dwarf.position
	var cart_before: Vector2 = session.transport.carts[1].at
	await press("push_cart")
	check(session.transport.carts[1].driver == 1, "C couples player to cart")
	check(dwarf.position.distance_to(player_before) < 0.1 and session.transport.carts[1].at == cart_before, "Coupling preserves both positions")
	Input.action_press("move_right")
	await frames(10)
	check(absf(dwarf.position.x - player_before.x) < 0.1 and session.transport.carts[1].at.x > cart_before.x + 10, "Cart initially moves while player stays in place")
	await frames(17)
	Input.action_release("move_right")
	check(absf(dwarf.position.x - (session.transport.carts[1].at.x - 20)) < 0.1, "Far edge carries player only after reaching them")
	check(session.transport.carts[1].at.x > 386 and session.transport.carts[1].at.x < 392, "A/D pushes cart along rails onto elevator")
	await press("push_cart")
	dwarf.position = Vector2(390, 288)
	dwarf.velocity = Vector2.ZERO
	await frames(3)
	await press("climb_down")
	await frames(125)
	check(session.transport.lift_y == 448 and absf(dwarf.position.y - 448) < 2 and session.transport.carts[1].at.y == 448, "Elevator carries dwarf and loaded cart to first mine floor")
	check(session.ore.pieces[piece].processing and session.transport.carts[1].items == [piece], "Ore remains stored during elevator travel")
	dwarf.position = Vector2(390, 528)
	dwarf.velocity = Vector2.ZERO
	dwarf.climbing = false
	Input.action_press("climb_up")
	await frames(105)
	Input.action_release("climb_up")
	check(absf(dwarf.position.y - 448) < 2, "Remaining ladder can reach the lowest upgraded platform from below")
	session.buy_transport_for(1, "lift", 2)
	check(session.transport.upgrades == 2 and session.players[1].mine_ladder_top == 528, "Second upgrade extends elevator in required order")
	session.cycle.phase = "summary"
	session.cycle.summary = session.cycle.totals(session.orders)
	session.buy_transport_for(1, "rail", 0)
	check(not session.transport.pending.has(1), "Summary blocks transport purchases")
	session.disconnect_game("Done")
	check(session.transport.upgrades == 0 and session.transport.carts.is_empty(), "New session resets transport")
	print("TRANSPORT PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
