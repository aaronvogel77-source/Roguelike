class_name BattleUnit
extends RefCounted
## A figure or enemy as it exists during one battle.
## Battles work on copies, so the run state is never changed by a fight.

const STATUS_SHIELD := "shield"
const STATUS_BURN := "burn"
const STATUS_CURSE := "curse"
const STATUS_BLEED := "bleed"
## A curse wears off after this many turns (refreshed when re-applied).
const CURSE_DURATION := 3

var uid: int
var def_id: String
var suit: String
## All suits the unit counts as (fusions count for every contained suit).
var suits: Array = []
## The definition shown for this unit (fusions: their built definition).
var display: Dictionary = {}
var side: int  # BattleSimulator.PLAYER or BattleSimulator.ENEMY
var level: int = 1
var attack: int
var health: int
var max_health: int
## Attack multipliers, applied after additive changes: (attack - curse) × product.
var multipliers: Array[float] = []
## Status stacks, e.g. {"shield": 3, "burn": 2}.
var statuses: Dictionary = {}
var curse_turns_left := 0
var abilities: Array = []
## Attacks ignore shields (Ace of Swords).
var pierce := false
## Per-battle bookkeeping for abilities (charges, counters).
var flags: Dictionary = {}


static func from_definition(definition: Dictionary, unit_side: int, unit_uid: int, unit_level: int = 1) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.uid = unit_uid
	unit.def_id = definition["id"]
	unit.suit = definition.get("suit", definition.get("region", ""))
	unit.side = unit_side
	unit.level = clampi(unit_level, 1, 3)
	# Each level above 1 grants +1/+1.
	unit.attack = int(definition["attack"]) + unit.level - 1
	unit.health = int(definition["health"]) + unit.level - 1
	unit.max_health = unit.health
	if definition.has("ability"):
		unit.abilities.append(definition["ability"])
	unit.abilities.append_array(definition.get("extra_abilities", []))
	unit.suits = (definition.get("fusion", {}).get("suits", [unit.suit]) as Array).duplicate()
	if definition.has("fusion"):
		unit.display = definition
	return unit


func has_suit(name: String) -> bool:
	return name == suit or name in suits


## The first ability with this effect, or {} (auras are read this way).
func aura(effect: String) -> Dictionary:
	for ability in abilities:
		if ability["effect"] == effect:
			return ability
	return {}


func is_alive() -> bool:
	return health > 0


func status(name: String) -> int:
	return statuses.get(name, 0)


func add_status(name: String, amount: int) -> void:
	# Salzgolem: burn never sticks to it.
	if name == STATUS_BURN and amount > 0 and not aura("burn_immune").is_empty():
		return
	statuses[name] = maxi(status(name) + amount, 0)
	if statuses[name] == 0:
		statuses.erase(name)
	if name == STATUS_CURSE and amount > 0:
		curse_turns_left = CURSE_DURATION


func total_multiplier() -> float:
	var product := 1.0
	for factor in multipliers:
		product *= factor
	return product


## Damage dealt by a normal attack: (attack - curse) × multipliers, rounded down.
func effective_attack() -> int:
	return int(floor(maxi(attack - status(STATUS_CURSE), 0) * total_multiplier()))


## Value of an ability for this unit's level (values hold one entry per level).
func level_value(ability: Dictionary) -> float:
	var values: Array = ability["values"]
	return float(values[mini(level, values.size()) - 1])


func snapshot() -> Dictionary:
	return {
		"uid": uid, "def_id": def_id, "side": side, "level": level, "suit": suit,
		"attack": attack, "effective_attack": effective_attack(),
		"health": health, "max_health": max_health,
		"multiplier": total_multiplier(), "statuses": statuses.duplicate(),
		"abilities": abilities.duplicate(true), "display": display,
	}
