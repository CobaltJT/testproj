extends SceneTree
const ORE = preload("res://scripts/ore_state.gd")
const FORGE = preload("res://scripts/forge_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS forge: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var ore = ORE.new()
	var forge = FORGE.new()
	var helpers: Array[int] = [1, 2]
	var nobody: Array[int] = []
	var second: Array[int] = [2]
	forge.step(1, helpers, ore)
	check(forge.piece == -1 and forge.progress == 0, "Empty bin cannot start a job")
	ore.store(0)
	ore.store(1)
	forge.step(2, helpers, ore)
	check(forge.piece == 0 and ore.deposited == 1 and ore.pieces[0].processing and forge.progress == 2, "Two workers reserve one ore and advance at single speed")
	forge.step(30, nobody, ore)
	check(forge.progress == 2 and forge.worker == 0 and ore.deposited == 1, "Release pauses work without consuming more ore")
	forge.step(2.9, second, ore)
	check(forge.worker == 2 and is_equal_approx(forge.progress, 4.9) and ore.pieces[0].kind == "ore", "Another player resumes; 4.9 seconds does not finish")
	var result: Dictionary = forge.step(0.1, second, ore)
	check(result.finished == 0 and ore.pieces[0].kind == "ingot" and ore.is_loose(0) and forge.piece == -1, "Exactly five seconds produces one physical output identity")
	check(not ore.store(0), "Finished ingots cannot be fed back into the ore bin")
	check(ore.pieces.size() == 8 and ore.deposited == 1, "Conversion preserves material identity and remaining stock")
	forge.step(1, second, ore)
	var copy = FORGE.new()
	copy.restore(forge.snapshot())
	check(copy.piece == 1 and copy.progress == 1 and copy.worker == 2, "Snapshot preserves active job for late joiners")
	print("FORGE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
