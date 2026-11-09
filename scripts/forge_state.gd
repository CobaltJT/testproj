extends RefCounted
## One shared job. Work time advances once per host tick, regardless of helpers.
const DURATION := 5.0
var piece := -1
var progress := 0.0
var worker := 0

func step(delta: float, eligible: Array[int], ore: RefCounted) -> Dictionary:
	var result := {"started": -1, "finished": -1}
	if worker not in eligible:
		worker = eligible[0] if not eligible.is_empty() else 0
	if worker == 0:
		return result
	if piece == -1:
		piece = ore.begin_smelting()
		if piece == -1:
			worker = 0
			return result
		result.started = piece
	if piece != -1:
		progress = minf(DURATION, progress + delta)
		if progress >= DURATION - 0.00001:
			result.finished = piece
			ore.finish_smelting(piece)
			piece = -1
			progress = 0.0
			worker = 0
	return result

func snapshot() -> Dictionary:
	return {"piece": piece, "progress": progress, "worker": worker}

func restore(state: Dictionary) -> void:
	piece = state.piece
	progress = state.progress
	worker = state.worker
