extends Control
## Owns the daily report, input blocker, and presentation-only fade tween.
signal advance_requested
const DAY = preload("res://scripts/day_state.gd")
var last_phase := "morning"
var fade_tween: Tween
@onready var modal: Control = $Modal
@onready var popup: PanelContainer = $Modal/Popup
@onready var report: Label = $Modal/Popup/Column/Report
@onready var next_day_button: Button = $Modal/Popup/Column/NextDay
@onready var blackout: ColorRect = $Blackout

func _ready() -> void:
	next_day_button.pressed.connect(func(): advance_requested.emit())

func refresh(active: bool, cycle: RefCounted) -> void:
	modal.visible = active and cycle.phase == "summary"
	if cycle.phase == "summary":
		var totals: Dictionary = cycle.summary
		report.text = "Day %s complete\n\nCustomers: %s\nServed requests: %s\nFailed requests: %s\nRejected / unanswered: %s\nMoney gained: %s\nMoney spent: %s\nRefunds: %s" % [cycle.day, totals.customers, totals.served, totals.failed, totals.rejected, totals.earned, totals.spent, totals.refunds]
	if cycle.phase == "transition":
		if fade_tween != null: fade_tween.kill()
		blackout.color.a = clampf(cycle.fade / DAY.FADE_DURATION, 0, 1)
	elif cycle.phase == "morning" and last_phase == "transition":
		blackout.color.a = 1
		fade_tween = create_tween()
		fade_tween.tween_property(blackout, "color:a", 0.0, DAY.FADE_DURATION)
	elif not active:
		if fade_tween != null: fade_tween.kill()
		blackout.color.a = 0
	blackout.visible = active
	last_phase = cycle.phase
