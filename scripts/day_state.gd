extends RefCounted
const SHOP_DURATION := 120.0
const FADE_DURATION := 0.6
var day := 1
var phase := "morning"
var remaining := SHOP_DURATION
var fade := 0.0
var baseline := {"customers": 0, "served": 0, "failed": 0, "rejected": 0, "earned": 0, "spent": 0, "refunds": 0}
var summary: Dictionary = {}

func totals(orders: RefCounted) -> Dictionary:
	return {"customers": orders.number, "served": orders.completed, "failed": orders.missed, "rejected": orders.rejected, "earned": orders.earned, "spent": orders.spent, "refunds": orders.refunds}

func advance(expected_day: int) -> bool:
	if expected_day != day:
		return false
	if phase == "morning":
		phase = "shop"
		return true
	if phase == "summary":
		phase = "transition"
		fade = 0
		return true
	return false

func step(delta: float, orders: RefCounted, merchant: RefCounted) -> void:
	if phase == "shop":
		var elapsed := minf(delta, remaining)
		orders.step(elapsed)
		merchant.step(elapsed)
		remaining = maxf(0, remaining - elapsed)
		if remaining <= 0.000001:
			phase = "evening"
			merchant.remaining = 0
			orders.step(delta - elapsed, false)
	elif phase == "evening":
		orders.step(delta, false)
	elif phase == "transition":
		fade += delta
		if fade >= FADE_DURATION:
			day += 1
			phase = "morning"
			remaining = SHOP_DURATION
			baseline = totals(orders)
			summary.clear()
			orders.reset_arrival()
			merchant.until_visit = merchant.FIRST_VISIT
			merchant.remaining = 0
			merchant.stock = 0
	if phase == "evening" and orders.queue.is_empty() and orders.departures.is_empty():
		summary = totals(orders)
		for key in summary:
			summary[key] -= baseline[key]
		phase = "summary"

func snapshot() -> Dictionary:
	return {"day": day, "phase": phase, "remaining": remaining, "fade": fade, "baseline": baseline.duplicate(), "summary": summary.duplicate()}

func restore(state: Dictionary) -> void:
	day = state.day
	phase = state.phase
	remaining = state.remaining
	fade = state.fade
	baseline = state.baseline.duplicate()
	summary = state.summary.duplicate()
