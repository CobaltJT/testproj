extends SceneTree
const MATERIALS = preload("res://scripts/ore_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS materials: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var materials = MATERIALS.new()
	check(materials.pickup(1, 0) and not materials.pickup(1, 1), "Hands carry at most one item")
	check(not materials.pickup(2, 0), "Contending players cannot own the same piece")
	check(materials.release_carrier(1) == 0 and materials.release_carrier(1) == -1, "Drop releases identity exactly once")
	materials.pieces[0].processing = true
	check(not materials.pickup(2, 0), "Reserved station input cannot be picked up")
	materials.pieces[0].processing = false
	materials.pieces[0].consumed = true
	check(not materials.pickup(2, 0), "Consumed ingredient cannot be reused")
	materials.pieces[1].delivered = true
	check(not materials.pickup(2, 1), "Delivered product cannot be reused")
	materials.pickup(4, 2)
	var copy = MATERIALS.new()
	copy.restore(materials.snapshot())
	materials.release_carrier(4)
	check(copy.carried_by(4) == 2 and copy.pieces[0].consumed, "Snapshot copies ownership and material states independently")
	var id: int = copy.add_mined_ore()
	check(id == 8 and copy.is_loose(id), "New material IDs do not overlap initial pieces")
	print("MATERIALS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
