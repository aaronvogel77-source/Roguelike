class_name BattleUnit
extends RefCounted
## A figure or enemy as it exists during one battle.
## Battles work on copies, so the run state is never changed by a fight.

var uid: int
var def_id: String
var side: int  # BattleSimulator.PLAYER or BattleSimulator.ENEMY
var attack: int
var health: int
var max_health: int


static func from_definition(definition: Dictionary, unit_side: int, unit_uid: int) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.uid = unit_uid
	unit.def_id = definition["id"]
	unit.side = unit_side
	unit.attack = int(definition["attack"])
	unit.health = int(definition["health"])
	unit.max_health = unit.health
	return unit


func is_alive() -> bool:
	return health > 0


func snapshot() -> Dictionary:
	return {
		"uid": uid, "def_id": def_id, "side": side,
		"attack": attack, "health": health, "max_health": max_health,
	}
