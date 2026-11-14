extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS day interaction: ", message)
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
	var dwarf = session.players[1]
	dwarf.position = session.MINE_POSITION
	await frames(5)
	Input.action_press("interact")
	await frames(65)
	Input.action_release("interact")
	check(session.mining.progress == 0 and session.orders.number == 0 and session.open_button.visible, "Morning UI available while mine and arrivals stay closed")
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(256, 216))
	session.purchase_for(1, "grinder")
	session.cancel_build_for(1)
	session.open_button.pressed.emit()
	await frames(3)
	check(session.cycle.phase == "shop" and not session.open_button.visible, "Actual Open shop button advances morning")
	Input.action_press("interact")
	await frames(30)
	Input.action_release("interact")
	check(session.mining.progress > 0, "Mine works during shop hours")
	session.orders.number = 1
	session.orders.queue = [{"id": 1, "kind": "horseshoe", "age": 2.0, "remaining": 30.0, "accepted": true}]
	session.cycle.remaining = 0.02
	await frames(5)
	check(session.cycle.phase == "evening" and not session.day_popup.get_parent().visible, "Evening keeps existing customer and delays report")
	var progress: float = session.mining.progress
	Input.action_press("interact")
	await frames(10)
	Input.action_release("interact")
	check(session.mining.progress == progress, "Evening closes mine without discarding paused progress")
	dwarf.position = Vector2(166, 216)
	dwarf.velocity = Vector2.ZERO
	session.ore.pieces[0].kind = "horseshoe"
	session.ore.pickup(1, 0)
	session.refresh_ore()
	await frames(10)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(130)
	check(session.orders.completed == 1 and session.cycle.phase == "summary" and session.day_popup.get_parent().visible, "Evening E delivery leads to visible summary after departure")
	check(session.cycle.summary.earned == 10 and session.cycle.summary.spent == 45 and session.cycle.summary.refunds == 25, "Popup includes sales, morning spending and refunds")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(session.day_popup.get_global_rect()), "Daily popup fits viewport")
	var coins: int = session.orders.coins
	session.purchase_for(1, "forge")
	check(session.orders.coins == coins and not session.workshop.pending.has(1), "Summary blocks world transactions")
	session.next_day_button.pressed.emit()
	await frames(15)
	check(session.cycle.phase == "transition" and session.blackout.color.a > 0.2, "Close summary starts actual black fade")
	await frames(70)
	check(session.cycle.day == 2 and session.cycle.phase == "morning" and session.blackout.color.a < 0.01, "Fade completes into next morning")
	check(session.workshop.stations.size() == 1 and session.orders.coins == coins and session.progression.dwarfs[1].exp == 5, "New day retains workshop, earnings and personal EXP")
	session.disconnect_game("Done")
	check(session.cycle.day == 1 and session.cycle.phase == "morning" and not session.day_label.visible, "New session resets day and hides day UI")
	print("DAY INTERACTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
