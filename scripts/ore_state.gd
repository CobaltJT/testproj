extends RefCounted
## Host-owned identity ledger; physics transforms live in the ore bodies.
const INITIAL_ORE := 8
var pieces: Dictionary = {}

func _init() -> void:
	for id in range(INITIAL_ORE):
		pieces[id] = {"owner": 0, "stored": false}

var available: int:
	get:
		return INITIAL_ORE - deposited - carriers.size()
var deposited: int:
	get:
		var count := 0
		for piece in pieces.values():
			if piece.stored:
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
	return pieces.has(id) and pieces[id].owner == 0 and not pieces[id].stored

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

func store(id: int) -> bool:
	if not is_loose(id):
		return false
	pieces[id].stored = true
	return true

func snapshot() -> Dictionary:
	return pieces.duplicate(true)

func restore(state: Dictionary) -> void:
	pieces = state.duplicate(true)
