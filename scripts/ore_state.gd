extends RefCounted
## Host-owned identity ledger; physics transforms live in the ore bodies.
const INITIAL_ORE := 8
const BIN_CAPACITY := 10
const BIN_PRICE := 15
var pieces: Dictionary = {}

func _init() -> void:
	for id in range(INITIAL_ORE):
		pieces[id] = {"owner": 0, "processing": false, "kind": "ore", "delivered": false, "consumed": false}

var available: int:
	get:
		var count := 0
		for id in pieces:
			if is_loose(id):
				count += 1
		return count
var carriers: Array[int]:
	get:
		var result: Array[int] = []
		for piece in pieces.values():
			if piece.owner != 0:
				result.append(piece.owner)
		return result

func carried_by(player: int) -> int:
	for id in pieces:
		if pieces[id].owner == player:
			return id
	return -1

func is_loose(id: int) -> bool:
	return pieces.has(id) and pieces[id].owner == 0 and not pieces[id].processing and not pieces[id].delivered and not pieces[id].consumed

func pickup(player: int, id: int) -> bool:
	if player <= 0 or carried_by(player) != -1 or not is_loose(id):
		return false
	pieces[id].owner = player
	return true

func release_carrier(player: int) -> int:
	var id := carried_by(player)
	if id != -1:
		pieces[id].owner = 0
	return id

func snapshot() -> Dictionary:
	return pieces.duplicate(true)

func restore(state: Dictionary) -> void:
	pieces = state.duplicate(true)

func add_mined_ore() -> int:
	return add_material("ore")

func add_material(kind: String) -> int:
	var id := 0
	for existing in pieces:
		id = maxi(id, existing + 1)
	pieces[id] = {"owner": 0, "processing": false, "kind": kind, "delivered": false, "consumed": false}
	if kind == "ore_bin": pieces[id]["contents"] = []
	return id

func store_in_bin(bin: int, piece: int) -> bool:
	if not is_loose(bin) or pieces[bin].kind != "ore_bin" or not is_loose(piece) or pieces[piece].kind != "ore" or pieces[bin].contents.size() >= BIN_CAPACITY:
		return false
	pieces[piece].processing = true
	pieces[bin].contents.append(piece)
	return true

func deposit_in_bin(player: int, bin: int) -> bool:
	var piece := carried_by(player)
	if player <= 0 or piece == -1 or not is_loose(bin) or pieces[bin].kind != "ore_bin" or pieces[piece].kind != "ore" or pieces[bin].contents.size() >= BIN_CAPACITY:
		return false
	release_carrier(player)
	return store_in_bin(bin, piece)

func take_from_bin(player: int, bin: int) -> bool:
	if player <= 0 or carried_by(player) != -1 or not is_loose(bin) or pieces[bin].kind != "ore_bin" or pieces[bin].contents.is_empty():
		return false
	var piece: int = pieces[bin].contents.pop_front()
	pieces[piece].processing = false
	return pickup(player, piece)
