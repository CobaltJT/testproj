extends SceneTree
const STATE = preload("res://scripts/progression_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS progression: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var state = STATE.new()
	state.add(1)
	state.add(2)
	check(not state.buy(1, "walking") and not state.award(3, "delivery"), "Cannot spend unearned points or award absent player")
	state.award(1, "delivery")
	state.award(1, "delivery")
	check(state.dwarfs[1].level == 2 and state.dwarfs[1].points == 1 and state.dwarfs[1].exp == 0 and state.required(2) == 15, "Ten EXP grants first level and next costs fifteen")
	check(not state.buy(1, "smithing") and not state.buy(1, "unknown"), "Prerequisites and unknown skills validated")
	check(state.buy(1, "walking") and is_equal_approx(state.speed(1, "walking"), 1.1), "Root skill consumes point and increases speed")
	for i in range(3): state.award(1, "delivery")
	check(state.dwarfs[1].level == 3 and state.dwarfs[1].points == 1 and state.required(3) == 20, "Second level requires fifteen additional EXP")
	check(state.buy(1, "smithing") and is_equal_approx(state.speed(1, "smithing"), 1.2), "Root unlocks specialized crafting")
	for i in range(60): state.award(1, "delivery")
	for key in STATE.SKILLS:
		while state.can_buy(1, key): state.buy(1, key)
	# Earn enough for all ranks independently of progression curve.
	for i in range(300): state.award(1, "delivery")
	for key in STATE.SKILLS:
		while state.can_buy(1, key): state.buy(1, key)
	var points: int = state.dwarfs[1].points
	check(state.rank(1, "walking") == 3 and not state.buy(1, "walking") and state.dwarfs[1].points == points, "Repeatable ranks stop at cap without consuming points")
	check(state.purchase_price(1, 25) == 18 and state.purchase_price(1, 5) == 4 and state.sale_price(1, 15) == 20 and state.reject_cost(1) == 1, "Trade bonuses round coins up and rejection stops at one")
	check(state.dwarfs[2].level == 1 and state.rank(2, "walking") == 0, "Progress and skills are personal")
	var copy = STATE.new()
	copy.restore(state.snapshot())
	copy.dwarfs[1].skills.walking = 0
	check(state.rank(1, "walking") == 3, "Snapshot is independent and includes ranks")
	print("PROGRESSION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
