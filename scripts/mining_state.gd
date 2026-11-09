extends RefCounted
## One shared three-second extraction cycle, advanced once per host tick.
const DURATION := 3.0
var progress := 0.0
var worker := 0
var extracted := 0

func step(delta: float, eligible: Array[int]) -> bool:
	if worker not in eligible:
		worker = eligible[0] if not eligible.is_empty() else 0
	if worker == 0:
		return false
	progress = minf(DURATION, progress + delta)
	if progress >= DURATION - 0.00001:
		progress = 0.0
		worker = 0
		extracted += 1
		return true
	return false

func snapshot() -> Dictionary:
	return {"progress": progress, "worker": worker, "extracted": extracted}

func restore(state: Dictionary) -> void:
	progress = state.progress
	worker = state.worker
	extracted = state.extracted
