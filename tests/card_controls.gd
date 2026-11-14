extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS card controls: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(3)
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
	session.players[1].position = Vector2(166, 216)
	session.cycle.phase = "shop"
	session.orders.until_arrival = 100
	session.orders.queue = [{"id": 501, "kind": "horseshoe", "age": 2.0, "remaining": 10.0, "accepted": false, "quantity": 1, "delivered": 0}, {"id": 502, "kind": "sword", "age": 2.0, "remaining": 10.0, "accepted": false, "quantity": 2, "delivered": 0}]
	session.refresh_orders()
	await frames(8)
	check(not InputMap.has_action("accept_order") and not InputMap.has_action("reject_order") and not InputMap.has_action("buy_wood"), "Order and merchant keyboard shortcuts removed")
	await click(session.hud.order_cards[502].accept_button)
	check(not session.orders.queue[0].accepted and session.orders.queue[1].accepted, "Real mouse click accepts second queued customer's order")
	check(not session.hud.order_cards[502].accept_button.visible and session.hud.order_cards[502].reject_button.visible, "Accepted order retains red failure button")
	await click(session.hud.order_cards[502].reject_button)
	check(session.orders.queue.size() == 1 and session.orders.queue[0].id == 501 and session.orders.missed == 1 and session.orders.reputation == -6, "Red button fails already accepted queued order for six reputation")
	await click(session.hud.order_cards[501].reject_button)
	check(session.orders.rejected == 1 and session.orders.reputation == -9, "Red button declines unaccepted order for three reputation")
	session.merchant.step(12)
	session.refresh_merchant()
	await frames(4)
	check(session.hud.merchant_card.buy_button.visible and session.hud.merchant_card.buy_button.disabled, "Merchant buy button requires proximity")
	await click(session.hud.merchant_card.buy_button)
	session.buy_wood_for(1)
	check(session.orders.coins == 100 and session.merchant.stock == 4, "Disabled button and host validation prevent remote purchase")
	session.players[1].position = Vector2(212, 216)
	session.players[1].velocity = Vector2.ZERO
	await frames(5)
	check(not session.hud.merchant_card.buy_button.disabled, "Merchant buy button enables in range with empty hands")
	await click(session.hud.merchant_card.buy_button)
	check(session.orders.coins == 95 and session.merchant.stock == 3, "Real buy-icon click purchases exactly one wood")
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(456, 216))
	var anvil: int = session.workshop.nearest(Vector2(456, 216))
	session.players[1].position = Vector2(456, 216)
	session.players[1].velocity = Vector2.ZERO
	await frames(5)
	check(not InputMap.has_action("recipe_blade") and not InputMap.has_action("take_bin_ore"), "Number recipe keys and G binding removed")
	for recipe in ["blade", "head", "axe", "horseshoe"]:
		await press("cycle_storage")
		check(session.workshop.stations[anvil].job.recipe == recipe, "T cycles anvil recipe to " + recipe)
	session.ore.pieces[0].kind = "ingot"
	session.ore.pickup(1, 0)
	session.workshop.stations[anvil].job.load_material(1, session.ore)
	await press("cycle_storage")
	check(session.workshop.stations[anvil].job.recipe == "horseshoe", "Loaded anvil recipe remains locked")
	session.disconnect_game("Done")
	print("CARD CONTROLS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
