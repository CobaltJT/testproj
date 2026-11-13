extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS order interaction: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	session.host_game()
	session.advance_day()
	session.workshop.opened = true
	session.orders.step(session.orders.until_arrival)
	session.orders.queue[0].kind = "horseshoe"
	session.orders.queue[0].quantity = 2
	session.orders.step(2)
	session.refresh_orders()
	check(session.customer_nodes.has(1) and session.customer_nodes[1].position == Vector2(120, 216), "Waiting customer appears beside counter")
	session.ore.pieces[0].kind = "horseshoe"
	session.ore.pickup(1, 0)
	session.refresh_ore()
	var dwarf = session.players[1]
	dwarf.position = Vector2(166, 216)
	await frames(5)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(3)
	check(session.orders.completed == 0 and session.ore.carried_by(1) == 0, "Delivery requires acceptance")
	session.hud.order_cards[1].accept_button.pressed.emit()
	await frames(2)
	await frames(3)
	check(session.orders.queue[0].accepted, "Accept card button accepts front request")
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(5)
	check(session.orders.coins == 110 and session.orders.completed == 0 and session.orders.reputation == 0 and session.ore.carried_by(1) == -1, "Real E action delivers one item without completing whole request")
	check(session.hud.order_cards[1].count.text == "×1" and session.customer_nodes.has(1), "Customer and partial quantity stay visible")
	session.ore.pieces[1].kind = "horseshoe"
	session.ore.pickup(1, 1)
	session.refresh_ore()
	await frames(12)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(5)
	check(session.orders.coins == 120 and session.orders.completed == 1 and session.orders.reputation == 2, "Second item completes request and awards reputation once")
	check(not session.ore_bodies[0].visible and not dwarf.get_node("CarriedOre").visible, "Sold horseshoe disappears from world and hands")
	check("Coins: 120" in session.hud.shop.text, "Order UI displays shared reward")
	await frames(130)
	check(not session.customer_nodes.has(1) and session.orders.queue.is_empty(), "Served customer departs")
	session.orders.step(session.orders.until_arrival + 2)
	session.refresh_orders()
	await frames(3)
	session.hud.order_cards[2].reject_button.pressed.emit()
	await frames(2)
	await frames(3)
	check(session.orders.rejected == 1 and session.orders.reputation == -1, "Reject card button declines request for three reputation")
	session.disconnect_game("Done")
	check(session.orders.coins == 100 and session.orders.completed == 0 and not session.order_label.visible, "New session resets orders and earnings")
	print("ORDER INTERACTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
