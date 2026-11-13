extends SceneTree
var session: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS mine levels: ", message)
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
	var dwarf = session.players[1]
	check(session.mine_veins.size() == 6 and session.vein_nodes.size() == 6, "Two independently mineable veins on each of three levels")
	check(session.vein_at(Vector2(390, 288)) == -1 and session.world.has_node("MineEntrance"), "Old mining spot is now an entrance, not an ore source")
	dwarf.position = Vector2(390, 288)
	dwarf.velocity = Vector2.ZERO
	Input.action_press("climb_down")
	await frames(280)
	Input.action_release("climb_down")
	check(absf(dwarf.position.y - 528) < 2 and dwarf.climbing, "One continuous ladder traverses all three mine levels without floor obstruction")
	check(root.get_camera_2d().get_screen_center_position().y > 800, "Local camera follows dwarf into deepest mine level")
	Input.action_press("climb_up")
	await frames(280)
	Input.action_release("climb_up")
	check(absf(dwarf.position.y - 288) < 2, "Continuous ladder returns to building entrance")
	for level in session.MAP.MINE_FLOORS:
		dwarf.position = Vector2(390, level - 0.25)
		dwarf.velocity = Vector2.ZERO
		dwarf.climbing = true
		dwarf.active_ladder = 2
		Input.action_press("move_right")
		await frames(30)
		Input.action_release("move_right")
		await frames(10)
		check(dwarf.is_on_floor() and absf(dwarf.position.y - level) < 1 and dwarf.position.x > 412, "Can leave ladder onto mine floor " + str(level))
	# Each vein produces at its own level and retains independent pause progress.
	for vein in session.mine_veins:
		dwarf.position = session.MAP.VEINS[vein]
		dwarf.velocity = Vector2.ZERO
		dwarf.climbing = false
		await frames(5)
		Input.action_press("interact")
		await frames(185)
		Input.action_release("interact")
		await frames(10)
		check(session.mine_veins[vein].extracted == 1, "Mine physical ore at vein " + str(vein))
	check(session.ore.pieces.size() == 14 and session.progression.dwarfs[1].level == 2, "All levels use shared ore identities and normal mining EXP")
	var copy: Dictionary = session.mining_snapshot()
	session.mine_veins[3].progress = 1.25
	check(copy[3].progress != session.mine_veins[3].progress, "Mining snapshot keeps vein states independent")
	session.cycle.phase = "evening"
	Input.action_press("interact")
	await frames(30)
	Input.action_release("interact")
	check(session.mine_veins[5].extracted == 1, "Evening closes underground mining")
	session.disconnect_game("Done")
	check(session.mine_veins.size() == 6 and session.mine_veins[5].extracted == 0, "New session resets every vein")
	print("MINE LEVELS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
