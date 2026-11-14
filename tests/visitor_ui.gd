extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS visitor UI: ", message)
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
	preload("res://tests/world_fixture.gd").prepare(session)
	await frames(5)
	check(not session.order_label.visible and not session.hud.customer_badge.visible and not session.hud.merchant_badge.visible, "No text customer panel or inactive visitor indicators")
	check(not session.hud.held.visible and session.hud.held.text == "", "No empty-hands or held-item text")
	check(not session.world.get_node("MineEntrance") is Label and session.vein_nodes.values().all(func(view): return view.get_node("WorkLabel").text == "" and not view.get_node("WorkLabel").visible), "Entrance and veins have no text labels")
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(256, 216))
	var id: int = session.workshop.nearest(Vector2(256, 216))
	session.ore.pieces[0].kind = "ingot"
	session.ore.pickup(1, 0)
	session.workshop.stations[id].job.load_material(1, session.ore)
	session.workshop.stations[id].job.progress = 2.5
	session.refresh_workshop()
	await frames(3)
	check(session.station_nodes[id].get_node("Label").text == "" and session.station_nodes[id].get_node("Progress").visible, "Work progress uses a bar without status text")
	check(session.station_nodes[id].get_node("ProductIcon").texture != null, "Recipe is identified with an icon")
	session.cycle.phase = "shop"
	session.orders.until_arrival = 0.05
	session.hud.reset_events()
	await frames(130)
	check(session.hud.customer_badge.visible and session.hud.customer_count.text == "1", "Waiting customer activates icon indicator")
	check(session.hud.notice.text == "Customer arrived", "New customer produces concise notification")
	var order: Dictionary = session.orders.queue[0]
	var card = session.hud.order_cards[order.id]
	check(card.visible and card.product.texture == session.material_texture(order.kind) and card.count.text == "×%s" % order.quantity, "Customer card shows product icon and requested quantity")
	check(card.timer.text.ends_with("s") and card.progress.value > 0, "Customer card shows remaining time")
	var head: Vector2 = session.world.get_global_transform_with_canvas() * (session.customer_nodes[order.id].position + Vector2(0, -26))
	check(card.get_global_rect().end.y <= head.y, "Customer card is tethered above visitor")
	session.players[1].position = Vector2(166, 216)
	session.hud.notice_until = 0
	session.hud.toast_queue.clear()
	var notice_before: String = session.hud.notice.text
	session.decide_order_for(1, order.id, true)
	await frames(3)
	check(session.hud.notice.text == notice_before and session.hud.notice_until == 0 and card.frame.border_color == Color("7db59b"), "Acceptance changes card state without a toast")
	session.orders.step(30, false)
	await frames(3)
	check(not session.hud.customer_badge.visible and session.hud.order_cards.is_empty(), "Leaving customer removes card and indicator")
	check(session.hud.toast_queue.has("Request failed · −6 rep") or session.hud.notice.text == "Request failed · −6 rep", "Failed order produces notification")
	session.hud.notice_until = 0
	await frames(2)
	check(session.hud.notice.text == "Request failed · −6 rep", "Queued failure notification is displayed")
	session.hud.reset_events()
	session.merchant.step(12)
	session.refresh_merchant()
	await frames(3)
	check(session.hud.merchant_badge.visible and session.hud.merchant_card.visible, "Merchant activates indicator and visitor card")
	check(session.hud.merchant_card.product.texture == session.material_texture("wood") and session.hud.merchant_card.count.text == "×4" and session.hud.merchant_card.price.text == "5", "Merchant card shows stock icon, quantity and purchase price")
	check(session.hud.notice.text == "Merchant arrived", "Merchant arrival produces notification")
	session.players[1].position = Vector2(212, 216)
	session.buy_wood_for(1)
	await frames(3)
	check(session.hud.merchant_card.count.text == "×3", "Merchant stock card updates after purchase")
	session.hud.reset_events()
	session.orders.until_arrival = 0.01
	await frames(3)
	session.orders.step(12, false)
	await frames(3)
	check(session.hud.toast_queue.has("Request expired · −3 rep") or session.hud.notice.text == "Request expired · −3 rep", "Unanswered request expiry produces notification")
	session.hud.reset_events()
	await frames(3)
	check(session.hud.toast_queue.is_empty() and session.hud.notice_until == 0, "Initial snapshot baseline does not replay historic events")
	session.disconnect_game("Done")
	await frames(3)
	check(not session.hud.visible, "Visitor UI hides on disconnect")
	print("VISITOR UI RESULT: ", failures, " failures")
	quit(1 if failures else 0)
