extends SceneTree
class TestSync extends Node:
	var seen: Dictionary = {}
	var reports: Dictionary = {}
	@rpc("authority", "call_local", "reliable")
	func begin(value: String) -> void: seen[value] = true
	@rpc("any_peer", "call_remote", "reliable")
	func report(key: String) -> void: reports[key] = true
var session: Node
var sync: TestSync
var role := ""
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS coop [", role, "]: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func until(condition: Callable, limit: int = 900) -> bool:
	for i in range(limit):
		if condition.call(): return true
		await frames(1)
	return false
func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(12)
func stage(value: String) -> void:
	check(await until(func(): return sync.seen.has(value)), "Stage " + value)
func done(value: String) -> void: sync.report.rpc_id(1, role + ":" + value)
func reports(value: String) -> bool: return sync.reports.has("client1:" + value) and sync.reports.has("client2:" + value)
func sid(kind: String) -> int:
	for id in session.workshop.stations:
		if session.workshop.stations[id].kind == kind: return id
	return -1
func job(kind: String) -> RefCounted: return session.workshop.stations[sid(kind)].job
func move_peer(id: int, at: Vector2) -> void:
	var dwarf = session.players[id]
	dwarf.position = at
	dwarf.velocity = Vector2.ZERO
func carry(id: int, piece: int) -> void:
	check(session.ore.pickup(id, piece), "Fixture transfers available physical item")
func broadcast() -> void:
	session.broadcast_state("receive_ore", [session.ore.snapshot()], true)
	session.broadcast_state("receive_ore_motion", [session.ore_motion()])
	session.sync_build()
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.get_slice("=", 1)
	call_deferred("run")
func run() -> void:
	sync = TestSync.new()
	sync.name = "TestSync"
	root.add_child(sync)
	session = load("res://scenes/session.tscn").instantiate()
	root.add_child(session)
	if not await until(func(): return session.players.size() == 3):
		check(false, "Host and two clients connect")
		quit(1)
		return
	var own_id: int = session.multiplayer.get_unique_id()
	var own_camera: Camera2D = session.players[own_id].get_node("FollowCamera")
	check(root.get_camera_2d() == own_camera and own_camera.enabled, "Each instance activates only its own dwarf camera")
	for peer_id in session.players:
		if peer_id != own_id:
			check(not session.players[peer_id].get_node("FollowCamera").enabled, "Remote dwarf cannot take over viewport")
	await frames(10)
	var before: Vector2 = own_camera.get_screen_center_position()
	var start_x: float = session.players[own_id].position.x
	var direction := "move_left" if role == "host" else "move_right"
	Input.action_press(direction)
	await frames(30)
	Input.action_release(direction)
	await frames(10)
	var camera_x: float = own_camera.get_screen_center_position().x
	check(absf(session.players[own_id].position.x - start_x) > 20 and (camera_x < before.x - 20 if role == "host" else camera_x > before.x + 20), "Local camera follows real independently networked movement")
	if role == "host": await host_scenarios()
	else: await client_scenarios()
	print("MULTIPLAYER RESULT ", role, ": ", failures, " failures")
	quit(1 if failures else 0)
func host_scenarios() -> void:
	session.advance_day()
	check(session.workshop.stations.is_empty() and session.orders.coins == 100, "Host starts with empty workshop")
	# Keep recipe fixtures clear of the loose-pickup radius at the woodbench.
	for piece in session.ore_bodies:
		session.position_ore(session.ore_bodies[piece], Vector2(150, 270), Vector2.ZERO)
	session.purchase_for(1, "anvil")
	session.place_for(1, Vector2(256, 216))
	sync.begin.rpc("build")
	check(await until(func(): return reports("build")), "Clients purchased and placed both new station types")
	check(session.workshop.stations.size() == 3 and session.orders.coins == 30, "Shared station costs charged once")
	var c1 := 0
	var c2 := 0
	for id in session.players:
		if id == 1: continue
		if sync.reports.has("role-client1-%s" % id): c1 = id
		else: c2 = id
	session.merchant.step(12)
	move_peer(c2, Vector2(212, 216))
	broadcast()
	session.broadcast_state("receive_merchant", [session.merchant.snapshot()])
	await frames(10)
	sync.begin.rpc("wood")
	check(await until(func(): return session.ore.carried_by(c2) == 8), "Client purchases and picks up merchant wood")
	check(session.orders.coins == 25, "Wood costs five coins after station purchases")
	# Prepare smelted stock through the forge model for the existing recipe scenarios.
	var stock_forge = session.STATION_JOB.new()
	stock_forge.configure("forge")
	var smelter: Array[int] = [1]
	for piece in [0, 1, 2, 3]:
		check(stock_forge.store_ore(piece, session.ore) and stock_forge.step(5, smelter, session.ore) == piece, "Recipe fixture is smelted iron, not raw ore")
	carry(c1, 0)
	move_peer(c1, Vector2(256, 216))
	move_peer(c2, Vector2(248, 288))
	broadcast()
	await frames(10)
	sync.begin.rpc("parallel")
	check(await until(func(): return job("anvil").progress > 0.8 and job("anvil").worker == 0), "Client pauses horseshoe work")
	move_peer(1, Vector2(256, 216))
	await frames(5)
	Input.action_press("interact")
	check(await until(func(): return session.ore.pieces[0].kind == "horseshoe"), "Host finishes client's shared anvil job")
	Input.action_release("interact")
	check(await until(func(): return session.ore.pieces[8].kind == "shaft"), "Woodbench produces shaft in parallel")
	check(await until(func(): return reports("parallel")), "Clients see outputs at correct placed stations")
	carry(c1, 1)
	move_peer(c1, Vector2(256, 216))
	broadcast()
	await frames(10)
	sync.begin.rpc("blade")
	check(await until(func(): return session.ore.pieces[1].kind == "dull_sword"), "Anvil shapes unfinished blade")
	check(await until(func(): return reports("blade")), "Clients see unfinished blade")
	carry(c1, 1)
	move_peer(c1, Vector2(160, 136))
	broadcast()
	await frames(10)
	sync.begin.rpc("grind")
	check(await until(func(): return session.ore.pieces[1].kind == "sword"), "Purchased grinder sharpens sword")
	check(await until(func(): return reports("grind")), "Clients see sharpened sword")
	carry(c1, 2)
	move_peer(c1, Vector2(256, 216))
	broadcast()
	await frames(10)
	sync.begin.rpc("head")
	check(await until(func(): return session.ore.pieces[2].kind == "axe_head"), "Anvil makes axe head")
	check(await until(func(): return reports("head")), "Clients see axe head")
	carry(c1, 2)
	carry(c2, 8)
	move_peer(c1, Vector2(256, 216))
	move_peer(c2, Vector2(256, 216))
	broadcast()
	await frames(10)
	sync.begin.rpc("assemble")
	check(await until(func(): return job("anvil").ready()), "Two clients supply head and worked shaft")
	await frames(220)
	check(session.ore.pieces[2].kind == "axe_head", "Helpers do not accelerate assembly")
	check(await until(func(): return session.ore.pieces[2].kind == "axe"), "Assembly produces one final axe")
	check(await until(func(): return reports("assemble")), "Axe and consumed shaft replicate")
	check(session.ore.pieces[8].consumed, "Shaft consumed exactly once")
	carry(c1, 1)
	carry(c2, 2)
	move_peer(c1, Vector2(166, 216))
	move_peer(c2, Vector2(166, 216))
	session.orders.queue = [{"id": 101, "kind": "sword", "quantity": 2, "delivered": 0, "remaining": 10.0, "age": 2.0, "accepted": false}, {"id": 102, "kind": "axe", "remaining": 10.0, "age": 2.0, "accepted": false}]
	session.orders.number = 102
	session.orders.until_arrival = 20
	session.orders.reputation = 0
	session.orders.missed = 0
	broadcast()
	await frames(10)
	sync.begin.rpc("wrong")
	check(await until(func(): return reports("wrong")), "Clients observe front-only queue rejection")
	check(session.orders.completed == 0 and session.ore.carried_by(c2) == 2, "Axe cannot skip front sword order")
	sync.begin.rpc("sell_sword")
	check(await until(func(): return not session.orders.queue.is_empty() and session.orders.queue[0].get("delivered", 0) == 1), "First sword partially fills two-item order")
	sync.begin.rpc("partial")
	check(await until(func(): return reports("partial")), "Partial quantity and payment replicate before completion")
	check(session.orders.completed == 0 and session.orders.reputation == 0, "Partial delivery does not complete request or reward reputation")
	session.ore.pieces[5].kind = "sword"
	carry(1, 5)
	move_peer(1, Vector2(166, 216))
	session.refresh_ore()
	session.interact_for(1)
	check(session.orders.completed == 1, "Host completes client's partial order cooperatively")
	sync.begin.rpc("sell_axe")
	check(await until(func(): return session.orders.completed == 2), "Assembled axe sells next")
	check(session.orders.coins == 80 and session.orders.reputation == 4, "Correct item rewards reach shared economy")
	session.orders.queue = [{"id": 103, "kind": "horseshoe", "remaining": 0.5, "age": 29.5, "accepted": true}]
	session.orders.step(0.5)
	broadcast()
	sync.begin.rpc("expire")
	check(await until(func(): return reports("expire")), "Deadline penalty replicates")
	move_peer(c1, Vector2(160, 136))
	await frames(10)
	sync.begin.rpc("move")
	check(await until(func(): return reports("move")), "Client packs, rejects overlap, and relocates grinder")
	check(session.workshop.stations[sid("grinder")].at == Vector2(240, 136), "Relocated transform authoritative")
	move_peer(c1, Vector2(240, 136))
	await frames(10)
	sync.begin.rpc("refund")
	check(await until(func(): return sid("grinder") == -1 and not session.workshop.pending.has(c1)), "Packing then cancelling refunds station")
	check(session.orders.coins == 105, "Refund adds original price exactly once")
	# Add the restored forge with its integral, physical ore bin.
	session.purchase_for(1, "forge")
	session.place_for(1, Vector2(240, 136))
	move_peer(c1, Vector2(240, 136))
	move_peer(c2, Vector2(168, 136))
	session.players[c2].sprite.flip_h = false
	carry(c2, 4)
	broadcast()
	await frames(10)
	sync.begin.rpc("forge_throw")
	check(await until(func(): return job("forge").ore_queue.has(4)), "Client throw is collected by placed forge bin")
	check(await until(func(): return reports("forge_throw")), "Clients see forge bin stock and refuse packing it")
	sync.begin.rpc("forge_work")
	await frames(240)
	check(session.ore.pieces[4].kind == "ore", "Forge cannot smelt before five seconds")
	check(await until(func(): return session.ore.pieces[4].kind == "ingot"), "Client works forge into a physical ingot")
	check(await until(func(): return reports("forge_work")), "Physical ingot and empty bin replicate")
	sync.begin.rpc("forge_move")
	check(await until(func(): return reports("forge_move")), "Client relocates forge and attached bin together")
	check(session.workshop.stations[sid("forge")].at == Vector2(160, 288), "Relocated forge position authoritative")
	check(session.orders.coins == 80, "Forge and bin share one purchase price")
	check(session.progression.dwarfs[c1].level > 1 and session.progression.dwarfs[c2].level > 1, "Completed tasks and deliveries award personal EXP on host")
	for peer in [c1, c2]:
		while session.progression.dwarfs[peer].points < 1: session.award_exp(peer, "delivery")
	session.sync_progression()
	sync.begin.rpc("skills")
	check(await until(func(): return reports("skills")), "Remote skill purchases replicate")
	check(session.progression.rank(c1, "walking") == 1 and session.progression.rank(c2, "walking") == 1 and session.progression.rank(1, "walking") == 0, "Skill RPC applies only to sender; host skills stay independent")
	sync.begin.rpc("storage_build")
	check(await until(func(): return reports("storage_build")), "Client buys and places shared finished-product container")
	check(session.orders.coins == 70 and session.workshop.stations.size() == 4, "Storage charges shared price once")
	session.ore.pieces[6].kind = "horseshoe"
	carry(c1, 6)
	move_peer(c1, Vector2(456, 216))
	broadcast()
	await frames(10)
	sync.begin.rpc("storage_first")
	check(await until(func(): return reports("storage_first")), "First stored identity and visibility replicate")
	session.ore.pieces[7].kind = "sword"
	carry(c2, 7)
	move_peer(c2, Vector2(456, 216))
	broadcast()
	await frames(10)
	sync.begin.rpc("storage_second")
	check(await until(func(): return reports("storage_second")), "Another player adds different product to same container")
	sync.begin.rpc("storage_take")
	check(await until(func(): return reports("storage_take")), "Remote T selects product and E retrieves it")
	check(session.ore.carried_by(c1) == 7 and session.workshop.stations[sid("finished_small")].items == [6], "Storage transfer preserves exact identities on host")
	session.purchase_for(1, "intermediate_small")
	session.place_for(1, Vector2(456, 136))
	var thrown_part: int = session.ore.add_material("ingot")
	carry(c2, thrown_part)
	move_peer(c2, Vector2(406, 136))
	session.players[c2].sprite.flip_h = false
	broadcast()
	await frames(10)
	sync.begin.rpc("parts_throw")
	check(await until(func(): return reports("parts_throw")), "Remote throw is caught by intermediate bin and replicated")
	check(session.workshop.stations[sid("intermediate_small")].items == [thrown_part], "Host records thrown part identity exactly once")
	sync.begin.rpc("mobile_buy")
	check(await until(func(): return reports("mobile_buy")), "Client purchases and drops movable ore bin")
	var mobile := -1
	for piece in session.ore.pieces:
		if session.ore.pieces[piece].kind == "ore_bin": mobile = piece
	check(mobile != -1 and session.orders.coins == 45, "Movable ore bin charges shared price once")
	var raw: int = session.ore.add_material("shaft")
	session.refresh_ore()
	session.position_ore(session.ore_bodies[raw], session.world.to_local(session.ore_bodies[mobile].global_position) + Vector2(0, -35), Vector2(0, 100))
	broadcast()
	sync.begin.rpc("mobile_catch")
	check(await until(func(): return reports("mobile_catch")), "Movable bin catches intermediate products on host and synchronizes contents")
	# Different mine floors must progress independently and survive reconnects.
	session.release_ore(c1, true)
	move_peer(c1, session.MAP.VEINS[2])
	move_peer(c2, session.MAP.VEINS[5])
	broadcast()
	await frames(10)
	sync.begin.rpc("mine_levels")
	check(await until(func(): return reports("mine_levels")), "Clients mine different underground levels concurrently")
	check(session.mine_veins[2].progress > 1.5 and session.mine_veins[5].progress > 1.5 and session.mine_veins[0].progress == 0, "Vein work is independent across levels")
	# Keep a genuinely loaded paused station for reconnect restoration.
	job("anvil").select("horseshoe")
	carry(1, 3)
	job("anvil").load_material(1, session.ore)
	var helper: Array[int] = [1]
	var none: Array[int] = []
	job("anvil").step(1.25, helper, session.ore)
	job("anvil").step(0, none, session.ore)
	broadcast()
	sync.begin.rpc("rejoin")
	check(await until(func(): return reports("rejoin")), "Reconnect restores placed stations, jobs, inputs and economy")
	check(session.orders.coins == 45 and session.workshop.pending.is_empty(), "Disconnect refunds abandoned kit")
	session.orders.queue.clear()
	session.orders.departures.clear()
	session.cycle.remaining = 0.01
	check(await until(func(): return session.cycle.phase == "summary"), "Evening with no customers opens daily summary")
	sync.begin.rpc("day_summary")
	check(await until(func(): return reports("day_summary")), "Daily report replicates to both clients")
	sync.begin.rpc("next_morning")
	check(await until(func(): return session.cycle.day == 2 and session.cycle.phase == "morning"), "Remote close advances shared day once")
	check(await until(func(): return reports("next_morning")), "Both clients fade into next morning")
	check(session.orders.coins == 45 and session.workshop.stations.size() == 5, "New morning preserves money and workshop")
	sync.begin.rpc("finished")
	await frames(5)
	session.disconnect_game("Done")
	await frames(10)
func client_scenarios() -> void:
	var id: int = session.multiplayer.get_unique_id()
	sync.report.rpc_id(1, "role-%s-%s" % [role, id])
	await stage("build")
	var kind := "grinder" if role == "client1" else "woodbench"
	session.request_station.rpc_id(1, kind)
	check(await until(func(): return session.workshop.pending.has(id)), "Purchase replicates unplaced kit")
	session.request_place.rpc_id(1, Vector2(256, 216) if role == "client1" else Vector2(390, 288))
	await frames(15)
	check(session.workshop.pending.has(id), "Invalid overlap or mine placement keeps kit")
	session.request_place.rpc_id(1, Vector2(160, 136) if role == "client1" else Vector2(248, 288))
	check(await until(func(): return sid(kind) != -1 and not session.workshop.pending.has(id)), "Client manually places kit on chosen floor")
	check(session.station_nodes.has(sid(kind)), "Placed station scene appears")
	done("build")
	await stage("wood")
	if role == "client2":
		await press("buy_wood")
		await frames(30)
		await press("interact")
	await stage("parallel")
	await press("interact")
	Input.action_press("interact")
	if role == "client1":
		await frames(60)
		Input.action_release("interact")
		check(await until(func(): return session.ore.pieces[0].kind == "horseshoe"), "Host resumes client's horseshoe")
	else:
		check(await until(func(): return session.ore.pieces[8].kind == "shaft"), "Woodbench outputs worked shaft")
	Input.action_release("interact")
	done("parallel")
	for phase in ["blade", "grind", "head"]:
		await stage(phase)
		if role == "client1":
			if phase != "grind": await press("recipe_" + phase)
			await press("interact")
			Input.action_press("interact")
		var piece := 2 if phase == "head" else 1
		var output := "axe_head" if phase == "head" else ("sword" if phase == "grind" else "dull_sword")
		check(await until(func(): return session.ore.pieces[piece].kind == output), "Replicated output " + output)
		Input.action_release("interact")
		done(phase)
	await stage("assemble")
	if role == "client1": await press("recipe_axe")
	await frames(20)
	await press("interact")
	Input.action_press("interact")
	check(await until(func(): return session.ore.pieces[2].kind == "axe"), "Shared anvil assembly outputs axe")
	Input.action_release("interact")
	check(session.ore.pieces[8].consumed, "Worked shaft consumed on clients")
	done("assemble")
	await stage("wrong")
	if role == "client2": await press("interact")
	await frames(20)
	check(session.orders.completed == 0, "Front-only order enforced")
	done("wrong")
	await stage("sell_sword")
	if role == "client1":
		await press("accept_order")
		check(await until(func(): return not session.orders.queue.is_empty() and session.orders.queue[0].accepted), "Remote acceptance replicated")
		await press("interact")
	await stage("partial")
	check(await until(func(): return not session.orders.queue.is_empty() and session.orders.queue[0].get("quantity", 1) == 2 and session.orders.queue[0].get("delivered", 0) == 1 and session.orders.coins == 40), "Client observes exact partial delivery and per-item earnings")
	check("1/2" in session.order_label.text, "HUD shows delivered and requested quantities")
	done("partial")
	await stage("sell_axe")
	if role == "client2":
		await press("accept_order")
		check(await until(func(): return not session.orders.queue.is_empty() and session.orders.queue[0].accepted), "Next remote acceptance replicated")
		await press("interact")
	await stage("expire")
	check(session.orders.coins == 80 and session.orders.reputation == -2, "Shared rewards and expiry penalty replicated")
	done("expire")
	await stage("move")
	if role == "client1":
		await press("pack_station")
		check(await until(func(): return session.workshop.pending.has(id)), "R packs idle grinder")
		session.request_place.rpc_id(1, Vector2(256, 216))
		await frames(15)
		check(session.workshop.pending.has(id), "Moving onto occupied anvil rejected")
		session.request_place.rpc_id(1, Vector2(240, 136))
		check(await until(func(): return sid("grinder") != -1 and session.workshop.stations[sid("grinder")].at == Vector2(240, 136)), "Grinder relocated and replicated")
	done("move")
	await stage("refund")
	if role == "client1":
		await press("pack_station")
		await press("cancel_build")
	await stage("forge_throw")
	if role == "client2": await press("throw_ore")
	check(await until(func(): return sid("forge") != -1 and job("forge").ore_queue.has(4)), "Placed forge bin stock replicates after thrown ore")
	if role == "client1":
		await press("pack_station")
		check(sid("forge") != -1 and not session.workshop.pending.has(id), "Stocked forge cannot be packed")
	done("forge_throw")
	await stage("forge_work")
	if role == "client1": Input.action_press("interact")
	check(await until(func(): return session.ore.pieces[4].kind == "ingot"), "Forge produces replicated ingot")
	Input.action_release("interact")
	check(session.ore_bodies[4].visible and job("forge").ore_queue.is_empty(), "Forge output is physical and bin is empty")
	done("forge_work")
	await stage("forge_move")
	if role == "client1":
		await press("pack_station")
		session.request_place.rpc_id(1, Vector2(160, 288))
	check(await until(func(): return sid("forge") != -1 and session.workshop.stations[sid("forge")].at == Vector2(160, 288)), "Forge relocation replicates")
	check(session.station_nodes[sid("forge")].get_node("BinCatch/Shape").global_position == session.world.to_global(Vector2(146, 280)), "Attached bin moves with forge on every peer")
	done("forge_move")
	await stage("skills")
	check(await until(func(): return session.progression.dwarfs.has(id) and session.progression.dwarfs[id].points >= 1), "Personal earned EXP and points received")
	await press("build_menu")
	session.catalog_tabs.current_tab = 1
	session.skill_buttons.walking.pressed.emit()
	check(await until(func(): return session.progression.rank(id, "walking") == 1), "Real Skills button sends validated purchase")
	check(is_equal_approx(session.players[id].walking_multiplier, 1.1), "Purchased speed replicated")
	session.request_skill.rpc_id(1, "unknown")
	await frames(5)
	check(session.progression.rank(id, "unknown") == 0, "Unknown skill request cannot alter progression")
	done("skills")
	await stage("storage_build")
	if role == "client1":
		session.catalog_tabs.current_tab = 0
		session.station_buttons.finished_small.pressed.emit()
		check(await until(func(): return session.workshop.pending.has(id)), "Storage catalog purchase gives client placement kit")
		session.request_place.rpc_id(1, Vector2(456, 216))
	check(await until(func(): return sid("finished_small") != -1), "Placed storage arrives on both clients")
	done("storage_build")
	await stage("storage_first")
	if role == "client1": await press("interact")
	check(await until(func(): return session.workshop.stations[sid("finished_small")].items == [6] and session.ore.pieces[6].processing), "Stored horseshoe identity replicated")
	check(not session.ore_bodies[6].visible, "Stored item disappears from physical world")
	done("storage_first")
	await stage("storage_second")
	if role == "client2": await press("interact")
	check(await until(func(): return session.workshop.stations[sid("finished_small")].items.size() == 2), "Mixed products share capacity")
	done("storage_second")
	await stage("storage_take")
	if role == "client1":
		await press("cycle_storage")
		check(await until(func(): return session.workshop.stations[sid("finished_small")].selected == "sword"), "Remote T selects sword")
		await press("interact")
	check(await until(func(): return session.workshop.stations[sid("finished_small")].items == [6] and session.ore.pieces[7].owner > 0 and not session.ore.pieces[7].processing), "Selected identity transfers to player hands without duplication")
	done("storage_take")
	await stage("parts_throw")
	if role == "client2": await press("throw_ore")
	check(await until(func(): return sid("intermediate_small") != -1 and session.workshop.stations[sid("intermediate_small")].items.size() == 1), "Thrown ingot enters shared intermediate bin")
	var part: int = session.workshop.stations[sid("intermediate_small")].items[0]
	check(await until(func(): return session.ore.pieces[part].processing and not session.ore_bodies[part].visible), "Caught part is hidden on both clients")
	done("parts_throw")
	await stage("mobile_buy")
	if role == "client2":
		session.mobile_bin_button.pressed.emit()
		check(await until(func(): return session.ore.carried_by(id) != -1 and session.ore.pieces[session.ore.carried_by(id)].kind == "ore_bin"), "Client buys physical ore bin into hands")
		await press("drop_ore")
	await frames(45)
	var mobile := -1
	for piece in session.ore.pieces:
		if session.ore.pieces[piece].kind == "ore_bin": mobile = piece
	check(mobile != -1 and session.ore.is_loose(mobile) and session.ore_bodies[mobile].z_index > session.players[id].z_index, "Loose movable bin renders above characters on clients")
	done("mobile_buy")
	await stage("mobile_catch")
	check(await until(func(): return session.ore.pieces[mobile].contents.size() == 1), "Nested ore contents replicate")
	var raw: int = session.ore.pieces[mobile].contents[0]
	check(session.ore.pieces[raw].processing and not session.ore_bodies[raw].visible, "Stored ore identity hidden on clients")
	done("mobile_catch")
	await stage("mine_levels")
	Input.action_press("interact")
	await frames(100)
	Input.action_release("interact")
	await frames(10)
	check(await until(func(): return session.mine_veins[2].progress > 1.5 and session.mine_veins[5].progress > 1.5 and session.mine_veins[2].worker == 0 and session.mine_veins[5].worker == 0), "Two mining jobs synchronize independent paused progress")
	check(root.get_camera_2d().get_screen_center_position().y > 700, "Each client's camera follows its dwarf underground")
	done("mine_levels")
	await stage("rejoin")
	if role == "client2":
		session.request_station.rpc_id(1, "grinder")
		check(await until(func(): return session.workshop.pending.has(id)), "New unplaced kit reserved before disconnect")
		session.disconnect_game("Reconnect")
		await frames(15)
		session.join_game()
		check(await until(func(): return session.players.size() == 3 and session.workshop.stations.size() == 5 and session.orders.coins == 45), "Reconnect receives layout and abandoned-kit refund")
		check(root.get_camera_2d() == session.players[session.multiplayer.get_unique_id()].get_node("FollowCamera"), "Reconnect attaches camera to new local dwarf")
		check(await until(func(): return session.progression.dwarfs.size() == 3), "Late join receives progression snapshot")
		check(session.progression.dwarfs[session.multiplayer.get_unique_id()].level == 1, "New connection starts its own session dwarf progression")
		check(session.workshop.stations[sid("finished_small")].items == [6] and session.ore.pieces[6].processing and not session.ore_bodies[6].visible, "Late join receives container contents and hidden stored identities")
		check(session.workshop.stations[sid("intermediate_small")].items.size() == 1, "Reconnect preserves caught intermediate products")
		check(session.ore.pieces[mobile].contents.size() == 1 and not session.ore_bodies[session.ore.pieces[mobile].contents[0]].visible, "Reconnect preserves movable bin inventory")
		check(session.mine_veins.size() == 6 and session.mine_veins[2].progress > 1.5 and session.mine_veins[5].progress > 1.5, "Reconnect restores every underground vein and paused work")
		check(job("anvil").slots.has("ingot") and is_equal_approx(job("anvil").progress, 1.25) and session.ore.pieces[8].consumed, "Reconnect preserves paused station ingredients and physical material states")
	done("rejoin")
	await stage("day_summary")
	check(await until(func(): return session.cycle.phase == "summary" and session.day_popup.get_parent().visible), "Shared daily popup appears")
	check(session.cycle.summary.earned == 55 and session.cycle.summary.served == 2, "Daily report includes actual shared deliveries")
	done("day_summary")
	await stage("next_morning")
	if role == "client1": session.next_day_button.pressed.emit()
	check(await until(func(): return session.cycle.day == 2 and session.cycle.phase == "morning"), "Shared fade leads to morning")
	check(session.open_button.visible and not session.day_popup.get_parent().visible, "Morning controls replace summary")
	check(session.ore.pieces[mobile].contents.size() == 1, "Loaded movable bin persists into next day")
	check(session.workshop.stations[sid("finished_small")].items == [6], "Stored contents persist into next day")
	done("next_morning")
	await stage("finished")
	check(await until(func(): return not session.active), "Host shutdown returns to menu")
