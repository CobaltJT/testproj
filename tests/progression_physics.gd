extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS progression interaction: ", message)
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
	session.advance_day()
	await frames(5)
	Input.action_press("build_menu")
	await frames(2)
	Input.action_release("build_menu")
	check(session.catalog.visible and session.catalog_tabs.get_tab_count() == 2, "TAB offers Build and Skills")
	session.catalog_tabs.current_tab = 1
	await frames(5)
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(session.catalog.get_global_rect()), "Build and Skills panel fits default viewport")
	check(session.skill_buttons.walking.disabled and session.progression_label.visible, "Skills require points and HUD shows personal progress")
	for i in range(2): session.award_exp(1, "delivery")
	session.skill_buttons.walking.pressed.emit()
	check(session.progression.rank(1, "walking") == 1 and is_equal_approx(session.players[1].walking_multiplier, 1.1), "Skill button spends earned point and changes movement")
	for i in range(3): session.award_exp(1, "delivery")
	session.skill_buttons.mining.pressed.emit()
	var dwarf = session.players[1]
	dwarf.position = Vector2(390, 288)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press("interact")
	await frames(154)
	Input.action_release("interact")
	check(session.mining.extracted == 1 and session.progression.dwarfs[1].exp == 2, "Mining skill completes in 2.5 seconds and grants exactly two EXP")
	# Provide points through normal EXP awards, then exercise every economic route.
	for i in range(40): session.award_exp(1, "delivery")
	for skill in ["purchasing", "sales", "diplomacy", "smithing", "woodworking"]: session.purchase_skill_for(1, skill)
	var coins: int = session.orders.coins
	session.purchase_for(1, "anvil")
	check(session.orders.coins == coins - 18, "Personal discount applies to workstation purchase")
	session.place_for(1, Vector2(256, 216))
	dwarf.position = Vector2(256, 216)
	await frames(5)
	session.pack_for(1)
	session.cancel_build_for(1)
	check(session.orders.coins == coins, "Packed discounted kit refunds original paid price")
	session.merchant.step(12)
	dwarf.position = Vector2(212, 216)
	session.buy_wood_for(1)
	check(session.orders.coins == coins - 5, "Wood discount rounds up to whole coins")
	dwarf.position = Vector2(166, 216)
	session.orders.queue = [{"id": 1, "kind": "horseshoe", "remaining": 10.0, "age": 2.0, "accepted": false}]
	var rep: int = session.orders.reputation
	session.decide_order_for(1, 1, false)
	check(session.orders.reputation == rep - 2, "Diplomat reduces explicit rejection by one")
	session.orders.queue = [{"id": 2, "kind": "horseshoe", "remaining": 30.0, "age": 2.0, "accepted": true}]
	session.ore.pieces[0].kind = "horseshoe"
	session.ore.pickup(1, 0)
	var exp_before: int = session.progression.dwarfs[1].exp
	session.interact_for(1)
	check(session.orders.coins == coins + 6 and session.progression.dwarfs[1].exp == exp_before + 5, "Personal sales bonus and delivery EXP apply once")
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(256, 216))
	dwarf.position = Vector2(256, 216)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	session.ore.pickup(1, 1)
	var anvil: int = session.workshop.nearest(dwarf.position)
	session.workshop.stations[anvil].job.load_material(1, session.ore)
	exp_before = session.progression.dwarfs[1].exp
	Input.action_press("interact")
	await frames(2)
	session.step_workstations(4.2)
	Input.action_release("interact")
	check(session.ore.pieces[1].kind == "horseshoe" and session.progression.dwarfs[1].exp == exp_before + 3, "Smithing speed and completion EXP apply to active worker")
	session.purchase_for(1, "woodbench")
	session.place_for(1, Vector2(248, 288))
	dwarf.position = Vector2(248, 288)
	dwarf.velocity = Vector2.ZERO
	await frames(5)
	var wood: int = session.ore.add_material("wood")
	session.ore.pickup(1, wood)
	session.refresh_ore()
	var bench: int = session.workshop.nearest(dwarf.position)
	session.workshop.stations[bench].job.load_material(1, session.ore)
	Input.action_press("interact")
	await frames(2)
	session.step_workstations(4.2)
	Input.action_release("interact")
	check(session.ore.pieces[wood].kind == "shaft", "Woodworking skill accelerates woodbench separately")
	session.disconnect_game("Done")
	check(session.progression.dwarfs.is_empty() and not session.progression_label.visible, "Leaving resets session progression")
	print("PROGRESSION INTERACTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
