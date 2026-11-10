extends RefCounted
## Session-local, host-owned dwarf progression. Each rank costs one point.
const SKILLS := {
	"walking": {"title": "Sure-footed", "branch": "Craft", "parent": "", "max": 3, "effect": "+10% walking speed per rank"},
	"smithing": {"title": "Metalworker", "branch": "Craft", "parent": "walking", "max": 3, "effect": "+20% anvil, grinder and forge speed per rank"},
	"mining": {"title": "Prospector", "branch": "Craft", "parent": "walking", "max": 3, "effect": "+20% mining speed per rank"},
	"woodworking": {"title": "Woodworker", "branch": "Craft", "parent": "walking", "max": 3, "effect": "+20% woodbench speed per rank"},
	"purchasing": {"title": "Bargainer", "branch": "Trade", "parent": "", "max": 3, "effect": "-10% workstation and wood prices per rank"},
	"sales": {"title": "Salesperson", "branch": "Trade", "parent": "purchasing", "max": 3, "effect": "+10% delivery prices per rank"},
	"diplomacy": {"title": "Diplomat", "branch": "Trade", "parent": "purchasing", "max": 2, "effect": "-1 reputation lost per explicit rejection per rank"}
}
const TASK_EXP := {"mining": 2, "crafting": 3, "delivery": 5}
var dwarfs: Dictionary = {}

func add(player: int) -> void:
	if player > 0 and not dwarfs.has(player):
		dwarfs[player] = {"level": 1, "exp": 0, "points": 0, "skills": {}}

func required(level: int) -> int:
	return 10 + (level - 1) * 5

func award(player: int, task: String) -> bool:
	if not dwarfs.has(player) or task not in TASK_EXP:
		return false
	var dwarf: Dictionary = dwarfs[player]
	dwarf.exp += TASK_EXP[task]
	var leveled := false
	while dwarf.exp >= required(dwarf.level):
		dwarf.exp -= required(dwarf.level)
		dwarf.level += 1
		dwarf.points += 1
		leveled = true
	return leveled

func rank(player: int, skill: String) -> int:
	return dwarfs[player].skills.get(skill, 0) if dwarfs.has(player) else 0

func can_buy(player: int, skill: String) -> bool:
	if not dwarfs.has(player) or skill not in SKILLS or dwarfs[player].points <= 0:
		return false
	var definition: Dictionary = SKILLS[skill]
	return rank(player, skill) < definition.max and (definition.parent == "" or rank(player, definition.parent) > 0)

func buy(player: int, skill: String) -> bool:
	if not can_buy(player, skill):
		return false
	dwarfs[player].points -= 1
	dwarfs[player].skills[skill] = rank(player, skill) + 1
	return true

func speed(player: int, skill: String) -> float:
	return 1.0 + rank(player, skill) * (0.1 if skill == "walking" else 0.2)

func purchase_price(player: int, base: int) -> int:
	return maxi(1, ceili(base * (1.0 - 0.1 * rank(player, "purchasing")) - 0.000001))

func sale_price(player: int, base: int) -> int:
	return ceili(base * (1.0 + 0.1 * rank(player, "sales")) - 0.000001)

func reject_cost(player: int) -> int:
	return 3 - rank(player, "diplomacy")

func snapshot() -> Dictionary:
	return dwarfs.duplicate(true)

func restore(state: Dictionary) -> void:
	dwarfs = state.duplicate(true)
