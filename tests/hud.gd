extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS HUD: ", message)
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
	await frames(10)
	check(session.hud.visible and not session.hud.help_layer.visible, "Compact HUD is visible and guide is hidden by default")
	check(not session.hud.connection_panel.visible and not session.recipe_label.visible and not session.hint.visible, "Network panel and persistent control hint lines are hidden during play")
	check("Coins: 100" in session.hud.shop.text and "Rep: 0" in session.hud.shop.text and session.hud.held.text == "Empty hands", "HUD reports shop and player inventory")
	for panel in session.hud.panels:
		check(root.get_visible_rect().encloses(panel.get_global_rect()), "HUD card fits the default viewport")
	var old_day: Vector2 = session.day_label.get_global_rect().position
	session.players[1].position = Vector2(500, 528)
	await frames(10)
	check(session.day_label.get_global_rect().position == old_day, "HUD remains fixed while camera travels underground")
	Input.action_press("show_help")
	await frames(5)
	check(session.hud.help_layer.visible and root.get_visible_rect().encloses(session.hud.help_panel.get_global_rect()), "Holding F1 shows viewport-sized guide")
	var grid = session.hud.help_panel.get_child(0).get_child(2)
	for guide in grid.get_children():
		check(guide.get_content_height() <= guide.size.y + 1, "Guide column fits without clipping")
	Input.action_release("show_help")
	await frames(3)
	check(not session.hud.help_layer.visible, "Releasing F1 immediately hides guide")
	session.ore.pickup(1, 0)
	session.refresh_ore()
	await frames(3)
	check(session.hud.held.text == "Ore" and session.hud.held_icon.texture != null, "Held item name and image update")
	for i in range(2): session.award_exp(1, "delivery")
	await frames(3)
	check("+1 skill" in session.progression_label.text, "Level-up leaves visible unspent skill indicator")
	session.purchase_skill_for(1, "walking")
	await frames(3)
	check("+1 skill" not in session.progression_label.text, "Spending skill point clears indicator")
	session.interaction_feedback("E: pick up/load · Hold E: work")
	await frames(3)
	check(not session.hint.visible, "Control feedback does not restore persistent HUD clutter")
	session.interaction_feedback("Not enough coins.")
	await frames(3)
	check(session.hud.notice.visible and session.hud.notice.text == "Not enough coins.", "Action failures remain visible as short notifications")
	check(session.world.get_children().all(func(node): return not node.name.begins_with("Caption")), "Map instructional captions removed")
	var old_size := root.size
	root.size = Vector2i(1440, 900)
	await frames(5)
	check(session.hud.panels.all(func(panel): return root.get_visible_rect().encloses(panel.get_global_rect())), "HUD anchors remain within resized viewport")
	root.size = old_size
	await frames(3)
	session.disconnect_game("Done")
	await frames(3)
	check(not session.hud.visible and session.hud.connection_panel.visible, "Leaving restores LAN menu and hides gameplay HUD")
	print("HUD RESULT: ", failures, " failures")
	quit(1 if failures else 0)
