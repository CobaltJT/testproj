extends SceneTree
const STATE = preload("res://scripts/ore_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ore: ", message)
	else:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var ore = STATE.new()
	ore.interact(1, Vector2(238, 216))
	check(ore.available == 8 and ore.carriers.is_empty(), "Cannot pick up through the floor")
	ore.interact(1, STATE.SUPPLY)
	ore.interact(1, STATE.SUPPLY)
	check(ore.available == 7 and ore.carriers == [1], "Carry at most one piece")
	ore.interact(1, Vector2(310, 288))
	check(ore.deposited == 0 and ore.carriers == [1], "Cannot deposit from another floor")
	ore.interact(1, STATE.BIN)
	ore.interact(1, STATE.BIN)
	check(ore.deposited == 1 and ore.carriers.is_empty(), "Deposit exactly once")
	ore.available = 1
	ore.interact(2, STATE.SUPPLY)
	ore.interact(3, STATE.SUPPLY)
	check(ore.available == 0 and ore.carriers == [2], "Only one contender receives the last piece")
	ore.release_carrier(2)
	ore.release_carrier(2)
	check(ore.available == 1 and ore.carriers.is_empty(), "Disconnect returns carried ore exactly once")
	ore.interact(4, STATE.SUPPLY)
	var copy = STATE.new()
	copy.restore(ore.snapshot())
	ore.release_carrier(4)
	check(copy.available == 0 and copy.carriers == [4] and copy.deposited == 1, "Snapshot preserves inventory without aliasing")
	print("ORE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
