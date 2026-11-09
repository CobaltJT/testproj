extends SceneTree
const MINING = preload("res://scripts/mining_state.gd")
const ORE = preload("res://scripts/ore_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS mining: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var mine = MINING.new()
	var both: Array[int] = [1, 2]
	var nobody: Array[int] = []
	var other: Array[int] = [2]
	check(not mine.step(1, both) and mine.progress == 1, "Two miners advance at one-worker speed")
	mine.step(100, nobody)
	check(mine.progress == 1 and mine.worker == 0, "Releasing pauses without losing progress")
	check(not mine.step(1.9, other) and is_equal_approx(mine.progress, 2.9) and mine.worker == 2, "Another miner resumes; 2.9 seconds cannot extract")
	check(mine.step(0.1, other) and mine.extracted == 1 and mine.progress == 0, "Three seconds extracts exactly once")
	check(not mine.step(2, both) and mine.step(1, both) and mine.extracted == 2, "Held work repeats extraction with no finite-stock limit")
	var ore = ORE.new()
	var first: int = ore.add_mined_ore()
	var copy = ORE.new()
	copy.restore(ore.snapshot())
	var second: int = copy.add_mined_ore()
	check(first == 8 and second == 9 and copy.pieces.size() == 10 and copy.is_loose(second), "New ore has unique IDs, including after snapshot restore")
	check(copy.pickup(1, second) and copy.carried_by(1) == second, "Mined ore can enter existing pickup workflow")
	mine.step(1, other)
	var restored = MINING.new()
	restored.restore(mine.snapshot())
	check(restored.progress == mine.progress and restored.worker == 2 and restored.extracted == 2, "Snapshot preserves progress, miner, and extraction count")
	print("MINING RESULT: ", failures, " failures")
	quit(1 if failures else 0)
