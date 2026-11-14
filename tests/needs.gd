extends SceneTree
const NEEDS = preload("res://scripts/needs_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS needs: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var state = NEEDS.new()
	state.add(1)
	state.add(2)
	state.step(10)
	check(is_equal_approx(state.dwarfs[1].energy, 99) and is_equal_approx(state.dwarfs[1].food, 99.2), "Energy and satisfaction decrease with real time")
	state.exert(1, 5)
	check(state.dwarfs[1].energy < state.dwarfs[2].energy and state.dwarfs[1].food < state.dwarfs[2].food, "Only working dwarf pays extra drain")
	state.dwarfs[1] = {"energy": 10.0, "food": 100.0}
	check(state.walking(1) == 1 and state.working(1) == 1, "Exactly ten percent has normal speed")
	for key in ["energy", "food"]:
		state.dwarfs[1] = {"energy": 100.0, "food": 100.0}
		state.dwarfs[1][key] = 9.9
		check(state.walking(1) == 0.7 and state.working(1) == 0.5, "Either low meter slows movement and work: " + key)
		state.dwarfs[1][key] = 0
		check(state.walking(1) == 0.4 and state.working(1) == 0, "Either empty meter stops production: " + key)
	state.change(1, -10000, -10000)
	check(state.dwarfs[1].energy == 0 and state.dwarfs[1].food == 0, "Needs never go negative")
	state.change(1, 10000, 10000)
	check(state.dwarfs[1].energy == 100 and state.dwarfs[1].food == 100, "Recovery caps at one hundred")
	var copy = NEEDS.new()
	copy.restore(state.snapshot())
	copy.change(1, -10, -10)
	check(state.dwarfs[1].energy == 100 and copy.dwarfs[1].energy == 90, "Needs snapshots are independent")
	var trader = preload("res://scripts/merchant_state.gd").new()
	trader.configure_supplies()
	trader.rng.seed = 77
	var seen := {}
	for i in range(100):
		trader.step(trader.until_visit)
		seen[trader.kind] = true
	check(seen.has("ore") and seen.has("food"), "Random supply visits include both ore and food traders")
	var ore = preload("res://scripts/ore_state.gd").new()
	var economy = preload("res://scripts/customer_state.gd").new()
	trader.kind = "food"
	trader.remaining = 10
	trader.stock = 2
	check(trader.buy(1, Vector2(100, 216), economy, ore, 4) == -1, "Trader rejects purchases out of range")
	var food: int = trader.buy(1, trader.POSITION, economy, ore, 4)
	check(food != -1 and ore.pieces[food].kind == "food" and economy.coins == 96 and economy.spent == 4 and trader.stock == 1, "Food purchase creates unique physical-item identity and charges once")
	ore.pickup(1, food)
	check(trader.buy(1, trader.POSITION, economy, ore, 4) == -1, "Trader requires free hands")
	trader.step_supplies(1, true)
	check(trader.remaining == 0, "Supply trader yields the visitor spot to wood merchant")
	print("NEEDS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
