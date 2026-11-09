extends RefCounted
## Host clock and transaction ledger. One patient customer requests one hammer.
const FIRST_VISIT := 8.0
const BETWEEN_VISITS := 15.0
const WALK_TIME := 2.0
const REWARD := 10
var phase := "away"
var timer := FIRST_VISIT
var number := 0
var completed := 0
var coins := 0

func step(delta: float) -> void:
	if phase == "waiting":
		return
	timer = maxf(0, timer - delta)
	if timer > 0:
		return
	match phase:
		"away":
			number += 1
			phase = "arriving"
			timer = WALK_TIME
		"arriving":
			phase = "waiting"
		"leaving":
			phase = "away"
			timer = BETWEEN_VISITS

func deliver(player: int, at: Vector2, materials: RefCounted) -> bool:
	if phase != "waiting" or absf(at.x - 166) > 30 or absf(at.y - 216) > 6:
		return false
	var piece: int = materials.carried_by(player)
	if player <= 0 or piece == -1 or materials.pieces[piece].kind != "hammer":
		return false
	materials.release_carrier(player)
	materials.pieces[piece].delivered = true
	completed += 1
	coins += REWARD
	phase = "leaving"
	timer = WALK_TIME
	return true

func snapshot() -> Dictionary:
	return {"phase": phase, "timer": timer, "number": number, "completed": completed, "coins": coins}

func restore(state: Dictionary) -> void:
	phase = state.phase
	timer = state.timer
	number = state.number
	completed = state.completed
	coins = state.coins
