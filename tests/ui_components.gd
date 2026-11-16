extends SceneTree
## The extracted UI scenes can render and emit intent without a game session.
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS UI components: ", message)
	else:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog = preload("res://scenes/ui/workshop_catalog.tscn").instantiate()
	root.add_child(catalog)
	var progression = preload("res://scripts/progression_state.gd").new()
	progression.add(1)
	progression.dwarfs[1].points = 1
	var transport = preload("res://scripts/transport_state.gd").new()
	catalog.refresh_progression(1, progression)
	catalog.refresh_transport(1, progression, transport, 0)
	catalog.show()
	await frames(3)
	check(catalog.tabs.get_tab_count() == 3 and catalog.station_buttons.size() == 12, "Catalog renders all tabs and purchase choices independently")
	check(catalog.transport_buttons[1].disabled and not catalog.skill_buttons.walking.disabled, "Catalog reflects locked mine and available skill point")
	var requested: Array = []
	catalog.station_requested.connect(func(kind): requested.append(["station", kind]))
	catalog.skill_requested.connect(func(skill): requested.append(["skill", skill]))
	catalog.mobile_bin_requested.connect(func(): requested.append(["bin"]))
	catalog.transport_requested.connect(func(kind, level): requested.append(["transport", kind, level]))
	catalog.station_buttons.anvil.pressed.emit()
	catalog.skill_buttons.walking.pressed.emit()
	catalog.mobile_bin_button.pressed.emit()
	catalog.transport_buttons.rail.pressed.emit()
	check(requested == [["station", "anvil"], ["skill", "walking"], ["bin"], ["transport", "rail", 0]], "Catalog signals preserve action parameters")
	check(progression.rank(1, "walking") == 0 and progression.dwarfs[1].points == 1 and transport.pending.is_empty(), "Catalog intent cannot mutate gameplay state")
	catalog.hide()
	var expansions = preload("res://scenes/ui/expansion_indicators.tscn").instantiate()
	root.add_child(expansions)
	var rooms = preload("res://scripts/room_state.gd").new()
	expansions.refresh(Vector2(320, 216), rooms, progression, 1, 100)
	var obstacles: Array[Rect2] = []
	expansions.project(Transform2D.IDENTITY, Rect2(0, 0, 1280, 720), obstacles, true)
	var purchase: Array = []
	expansions.room_requested.connect(func(mine, cell): purchase.append([mine, cell]))
	var button: Button = expansions.buttons[Vector3i(1, 1, 0)]
	button.pressed.emit()
	check(purchase == [[false, Vector2i(1, 1)]] and rooms.building.size() == 2, "Expansion button emits intent without buying a room")
	expansions.refresh(Vector2(320, 216), rooms, progression, 1, 0)
	check(expansions.buttons[Vector3i(1, 1, 0)] == button and button.disabled, "Affordability updates preserve marker controls")
	expansions.refresh(Vector2(390, 328), rooms, progression, 1, 100)
	check(expansions.buttons.is_empty(), "Room context changes remove irrelevant markers")
	var summary = preload("res://scenes/ui/day_summary.tscn").instantiate()
	root.add_child(summary)
	var day = preload("res://scripts/day_state.gd").new()
	var orders = preload("res://scripts/customer_state.gd").new()
	var merchant = preload("res://scripts/merchant_state.gd").new()
	summary.refresh(false, day)
	check(not summary.modal.visible and not summary.blackout.visible, "Inactive day UI hides modal and fade")
	day.phase = "evening"
	day.step(0, orders, merchant)
	summary.refresh(true, day)
	check(summary.modal.visible and "Customers: 0" in summary.report.text, "Day report renders its supplied totals")
	var advances: Array = []
	summary.advance_requested.connect(func(): advances.append(true))
	summary.next_day_button.pressed.emit()
	check(advances.size() == 1 and day.phase == "summary", "Summary button emits intent without advancing the simulation")
	day.advance(day.day)
	day.step(0.3, orders, merchant)
	summary.refresh(true, day)
	check(is_equal_approx(summary.blackout.color.a, 0.5), "Transition fade follows synchronized day progress")
	day.step(0.3, orders, merchant)
	summary.refresh(true, day)
	await frames(45)
	check(summary.blackout.color.a < 0.01 and not summary.modal.visible, "Morning fade completes inside the owning component")
	summary.refresh(false, day)
	check(not summary.blackout.visible and summary.blackout.color.a == 0, "Disconnect resets presentation without changing the day model")
	print("UI COMPONENTS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
