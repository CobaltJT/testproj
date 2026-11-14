extends SceneTree
const ROUTER = preload("res://scripts/interaction/router.gd")
const CONTEXT = preload("res://scripts/interaction/context.gd")
class Probe extends RefCounted:
	var label: String
	var calls: Array
	func _init(name: String, log: Array) -> void:
		label = name
		calls = log
	func decline(_context) -> bool:
		calls.append(label + ":decline")
		return false
	func consume(_context) -> bool:
		calls.append(label + ":consume")
		return true
class StationQuery extends RefCounted:
	var stations: Dictionary = {}
	var searches := 0
	func nearest(_at: Vector2) -> int:
		searches += 1
		return -1
class CountingWorkshop extends "res://scripts/workshop_state.gd":
	var searches := 0
	func nearest(at: Vector2) -> int:
		searches += 1
		return super.nearest(at)
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS router: ", message)
	else:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var router = ROUTER.new()
	var context = CONTEXT.new(1, &"interact", Vector2(256, 216))
	check(not router.route(context), "An empty route leaves input unhandled")
	var calls: Array = []
	var a = Probe.new("A", calls)
	var b = Probe.new("B", calls)
	router.handlers.assign([a.decline, b.consume, a.consume])
	check(router.route(context) and calls == ["A:decline", "B:consume"], "Functions from different controllers follow list order and stop at true")
	calls.clear()
	router.handlers.assign([a.consume, b.consume])
	check(router.route(context) and calls == ["A:consume"], "Priorities can change without changing controller boundaries")
	calls.clear()
	router.handlers.assign([a.decline, b.decline])
	check(not router.route(context) and calls.size() == 2, "All false results allow propagation and leave the input unhandled")
	# Replacing registration during a callback must not change the current traversal.
	var replace := func(_context):
		calls.append("replace")
		router.handlers.assign([a.consume])
		return false
	calls.clear()
	router.handlers.assign([replace, b.consume])
	check(router.route(context) and calls == ["replace", "B:consume"], "The dispatch list stays stable during an interaction")
	calls.clear()
	check(router.route(context) and calls == ["A:consume"], "Registration changes take effect on the next interaction")
	# Multiple placeable functions share one proximity lookup, with no preflight.
	var placeables = preload("res://scripts/controllers/placeables.gd").new()
	var stations = StationQuery.new()
	var items = preload("res://scripts/ore_state.gd").new()
	var needs = preload("res://scripts/needs_state.gd").new()
	needs.add(1)
	placeables.bind(stations, items, needs, preload("res://scripts/day_state.gd").new(), stations.nearest)
	router.handlers.assign([placeables.try_storage, placeables.try_care, placeables.try_load])
	var before: Dictionary = items.snapshot()
	check(not router.route(CONTEXT.new(1, &"interact", Vector2.ZERO, 0)) and stations.searches == 1 and items.snapshot() == before, "Declining handlers share a cached query and do not change gameplay state")
	check(not router.route(CONTEXT.new(1, &"push_cart", Vector2.ZERO)) and stations.searches == 1, "Unrelated actions decline before querying the world")
	var storage = CountingWorkshop.new()
	var economy = preload("res://scripts/customer_state.gd").new()
	storage.purchase(1, "intermediate_small", economy, items)
	var id: int = storage.place(1, Vector2(256, 136))
	items.pieces[0].kind = "ingot"
	items.pickup(1, 0)
	placeables.bind(storage, items, needs, preload("res://scripts/day_state.gd").new(), stations.nearest)
	check(router.route(CONTEXT.new(1, &"interact", Vector2(256, 136), 0)) and storage.searches == 1 and storage.stations[id].items == [0], "Successful storage reuses its discovered target instead of searching twice")
	check(not storage.storage_transfer(1, Vector2(500, 136), items, id) and items.carried_by(1) == -1, "Reusing discovery still validates the target's range")
	router.handlers.clear()
	print("ROUTER RESULT: ", failures, " failures")
	quit(1 if failures else 0)
