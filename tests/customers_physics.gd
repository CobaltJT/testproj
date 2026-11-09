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
	session.orders.step(8)
	session.orders.step(2)
	session.refresh_orders()
	check(session.customer_nodes.has(1) and session.customer_nodes[1].position == Vector2(120, 216), "Waiting customer appears beside counter")
	session.ore.pieces[0].kind = "hammer"
	session.ore.pickup(1, 0)
	session.refresh_ore()
	var dwarf = session.players[1]
	dwarf.position = Vector2(166, 216)
	await frames(5)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(5)
	check(session.orders.coins == 30 and session.orders.completed == 1 and session.ore.carried_by(1) == -1, "Real E action serves customer and awards shared coins")
	check(not session.ore_bodies[0].visible and not dwarf.get_node("CarriedOre").visible, "Sold hammer disappears from world and hands")
	check("Coins: 30" in session.order_label.text, "Order UI displays shared reward")
	await frames(130)
	check(not session.customer_nodes.has(1) and session.orders.queue.is_empty(), "Served customer departs")
	session.disconnect_game("Done")
	check(session.orders.coins == 20 and session.orders.completed == 0 and not session.order_label.visible, "New session resets orders and earnings")
	print("ORDER INTERACTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
