extends SceneTree
const ORE = preload("res://scripts/ore_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS mobile bin: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var ore = ORE.new()
	var bin: int = ore.add_material("ore_bin")
	check(ore.store_in_bin(bin, 0) and not ore.store_in_bin(bin, 0), "Ore stored once by identity")
	var ingot: int = ore.add_material("ingot")
	check(not ore.store_in_bin(bin, ingot) and ore.is_loose(ingot), "Only raw ore enters movable bin")
	for i in range(9):
		var piece: int = ore.add_material("ore")
		check(ore.store_in_bin(bin, piece), "Fill movable bin")
	var extra: int = ore.add_material("ore")
	check(not ore.store_in_bin(bin, extra) and ore.is_loose(extra), "Ten-slot capacity leaves overflow loose")
	check(ore.pickup(1, bin) and ore.pieces[bin].contents.size() == 10 and not ore.is_loose(0), "Loaded bin can be carried while contents remain reserved")
	check(not ore.take_from_bin(2, bin) and not ore.store_in_bin(bin, extra), "Carried bin cannot be accessed as a loose object")
	ore.release_carrier(1)
	var copy = ORE.new()
	copy.restore(ore.snapshot())
	check(copy.pieces[bin].contents == ore.pieces[bin].contents, "Snapshot retains loaded container contents")
	check(copy.take_from_bin(2, bin) and copy.carried_by(2) == 0 and copy.pieces[bin].contents.size() == 9, "Withdraw exact original identity")
	check(ore.pieces[bin].contents.size() == 10, "Snapshot contents are independent")
	ore.pickup(1, extra)
	check(not ore.deposit_in_bin(1, bin) and ore.carried_by(1) == extra, "Manual deposit into full bin preserves hands")
	ore.take_from_bin(2, bin)
	check(ore.deposit_in_bin(1, bin) and ore.carried_by(1) == -1, "Manual deposit fills vacated slot")
	print("MOBILE BIN RESULT: ", failures, " failures")
	quit(1 if failures else 0)
