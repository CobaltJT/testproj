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
	check(ore.pickup(1, 0) and not ore.pickup(1, 1), "Carry at most one identified piece")
	check(not ore.pickup(2, 0), "Only one contender can pick up a piece")
	check(not ore.store(0), "Carried ore cannot be deposited by interaction")
	check(ore.release_carrier(1) == 0 and ore.release_carrier(1) == -1, "Release a carried piece exactly once")
	check(ore.store(0) and not ore.store(0) and not ore.pickup(3, 0), "Bin captures a loose piece exactly once")
	ore.pickup(4, 1)
	var copy = STATE.new()
	copy.restore(ore.snapshot())
	ore.release_carrier(4)
	check(copy.carried_by(4) == 1 and copy.deposited == 1, "Snapshot preserves identity without aliasing")
	check(ore.available + ore.deposited + ore.carriers.size() == 8, "Loose, carried and stored pieces conserve total")
	print("ORE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
