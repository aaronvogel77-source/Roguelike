extends GutTest
## M5a: equipment, relics, tarot, packs, legendary aces, inserting.

var _db: ContentDb


func before_all() -> void:
	_db = ContentDb.load_default()


func _planning_run(seed_value := 3) -> RunState:
	var run := RunState.new_run(_db, seed_value)
	run.choose_enemy(0)
	return run


func _fig(def_id: String, xp := 0) -> Dictionary:
	return {"uid": randi(), "def_id": def_id, "xp": xp}


# --- Equipment -------------------------------------------------------------------

func test_equipment_affix_count_follows_rarity() -> void:
	var rng := RngStreams.new(1).stream("t")
	for i in 200:
		var item := Items.roll_equipment(_db, 2, rng)
		assert_eq(item["affixes"].size(), Items.AFFIX_COUNT[item["rarity"]])
		assert_eq(not item["drawback"].is_empty(), item["rarity"] == Items.RARITY_CURSED)


func test_multiplier_affix_only_from_rare() -> void:
	var rng := RngStreams.new(2).stream("t")
	for i in 300:
		var item := Items.roll_equipment(_db, 3, rng)
		for affix in item["affixes"]:
			if affix["id"] == "multiplier":
				assert_gte(item["rarity"], Items.RARITY_RARE)


func test_equipment_changes_battle_stats() -> void:
	var run := _planning_run()
	run.row[0] = _fig("coin_squire")
	run.row[0]["equipment"] = {"base": "blade", "rarity": 1, "affixes": [{"id": "plus_health", "value": 3}], "drawback": {}}
	var entry: Dictionary = run.player_battle_team()[0]
	assert_eq(entry["bonus_attack"], 2)
	assert_eq(entry["bonus_health"], 3)


func test_cursed_gold_drain_reduces_income() -> void:
	var run := _planning_run()
	run.row[0] = _fig("the_judge")
	run.row[0]["equipment"] = {"base": "amulet", "rarity": 3, "affixes": [], "drawback": {"id": "gold_drain", "value": -1}}
	run.apply_battle_result({"victory": true, "gold_after": 0})
	assert_eq(run.last_income["extra"], -1)


func test_death_gold_affix_pays_on_death() -> void:
	var dies := {"def": _db.figures["coin_squire"], "level": 1, "abilities": [
		{"trigger": "on_death", "target": "self", "effect": "gain_gold", "values": [2, 2, 2]}]}
	var result := BattleSimulator.simulate([dies], [{"def": _db.enemies["greedy_dragon"], "level": 3}], 5)
	assert_eq(result["gold_after"], 7)


# --- Relics ------------------------------------------------------------------------

func test_war_chest_and_vanguard_banner() -> void:
	var run := _planning_run()
	run.row[0] = _fig("coin_squire")
	run.row[1] = _fig("the_judge")
	run.relics = ["war_chest", "vanguard_banner"]
	var team := run.player_battle_team()
	assert_eq(team[0]["bonus_attack"], 1, "coin figure +1")
	assert_eq(team[1]["bonus_attack"], 0)
	assert_eq(team[0]["multipliers"], [1.5], "front figure ×1.5")


func test_eternal_ember_adds_a_burn_stack() -> void:
	var spark := {"def": _db.figures["spark_bearer"], "level": 1, "bonus_health": 10}
	var result := BattleSimulator.simulate([spark], [{"def": _db.enemies["vault_warden"], "level": 1}], 0,
		{"status_bonus": {"burn": {"all": 1}}})
	var burned := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["side"] == 1 and e["unit"]["statuses"].get("burn", 0) >= 2:
			burned = true
	assert_true(burned, "burn 1 + 1 bonus")


func test_royal_court_counts_queens_kings_and_aces() -> void:
	var run := _planning_run()
	run.row[0] = _fig("the_judge")
	run.row[1] = _fig("golden_scales")
	run.row[2] = _fig("ace_of_coins")
	run.relics = ["royal_court"]
	for entry in run.player_battle_team():
		assert_eq(entry["bonus_health"], 3)


func test_beggars_bowl_pays_after_wins() -> void:
	var run := _planning_run()
	run.relics = ["beggars_bowl"]
	run.row[0] = _fig("the_judge")
	run.apply_battle_result({"victory": true, "gold_after": 0})
	assert_eq(run.last_income["extra"], 2)


# --- Tarot ---------------------------------------------------------------------------

func test_tarot_cards() -> void:
	var run := _planning_run()
	run.row[0] = _fig("coin_squire")
	run.row[0]["xp"] = RunState.XP_FOR_LEVEL[2]  # level 3: two object slots
	run.tarots = ["strength", "sun"]
	assert_true(run.use_tarot(0, 0))
	assert_eq(run.row[0]["bonus_attack"], 2)
	assert_true(run.use_tarot(0, 0))
	assert_eq(run.row[0]["blessing"], "sun")
	assert_eq(run.tarots.size(), 0)
	run.tarots = ["wheel_of_fortune"]
	run.use_tarot(0, 0)
	assert_ne(run.figure_suit(run.row[0]), "coins")
	run.tarots = ["hanged_man"]
	var before := run.gold
	run.use_tarot(0, 0)
	assert_null(run.row[0])
	assert_eq(run.gold, before + 3)


func test_tarot_needs_a_figure() -> void:
	var run := _planning_run()
	run.tarots = ["magician"]
	assert_false(run.use_tarot(0, 2), "empty slot")


# --- Packs ---------------------------------------------------------------------------

func test_shop_has_two_packs_and_buying_opens_one() -> void:
	var run := _planning_run()
	assert_eq(run.packs.size(), 2)
	run.gold = 50
	assert_true(run.buy_pack(0))
	assert_false(run.open_pack.is_empty())
	assert_eq(run.open_pack["items"].size(), Items.pack_choice_count(_db, run.open_pack["pack"]))


func test_pack_contents_match_type() -> void:
	var rng := RngStreams.new(4).stream("t")
	var kinds := {"equipment": "equipment", "arcana": "tarot", "relic": "relic"}
	for type in kinds:
		for size in ["normal", "jumbo", "mega"]:
			var items := Items.pack_contents(_db, {"type": type, "size": size}, 1, rng)
			assert_gt(items.size(), 0)
			for item in items:
				# Arcana packs may (rarely) contain a legendary figure instead.
				assert_true(item["kind"] == kinds[type] or (type == "arcana" and item["kind"] == "figure"))


func test_taking_items_from_a_pack() -> void:
	var run := _planning_run()
	run.open_pack = {"pack": {"type": "arcana", "size": "normal"}, "picks_left": 1,
		"items": [{"kind": "tarot", "id": "star"}, {"kind": "tarot", "id": "sun"}]}
	assert_true(run.take_pack_item(1))
	assert_eq(run.tarots, ["sun"])
	assert_true(run.open_pack.is_empty(), "single pick closes the pack")


func test_equipment_from_pack_needs_a_figure() -> void:
	var run := _planning_run()
	var blade := {"base": "blade", "rarity": 0, "affixes": [], "drawback": {}}
	run.open_pack = {"pack": {"type": "equipment", "size": "normal"}, "picks_left": 1,
		"items": [{"kind": "equipment", "item": blade}]}
	assert_false(run.take_pack_item(0, 2), "slot 2 is empty")
	assert_true(run.take_pack_item(0, 0))
	assert_eq(run.row[0]["equipment"]["base"], "blade")


func test_relic_slots_are_limited() -> void:
	var run := _planning_run()
	run.relics = ["war_chest", "whetstone", "death_bell"]
	run.open_pack = {"pack": {"type": "relic", "size": "normal"}, "picks_left": 1,
		"items": [{"kind": "relic", "id": "beggars_bowl"}]}
	assert_false(run.can_take_pack_item(0))


func test_debug_legend_pack_contains_an_ace() -> void:
	var run := _planning_run()
	run.debug_legend_pack()
	assert_eq(_db.figures[run.open_pack["items"][0]["def_id"]]["rank"], "legend")


func test_legends_never_appear_in_the_normal_shop() -> void:
	for seed_value in range(1, 60):
		var run := _planning_run(seed_value)
		for def_id in run.shop:
			assert_ne(_db.figures[def_id]["rank"], "legend")


# --- Legendary abilities -------------------------------------------------------------

func test_ace_of_swords_pierces_shields() -> void:
	var ace := {"def": _db.figures["ace_of_swords"], "level": 1}
	var result := BattleSimulator.simulate([ace], [{"def": _db.enemies["vault_warden"], "level": 1}])
	var hits: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "damage" and e["uid"] == 2)
	assert_eq(hits[0]["amount"], 7, "full damage through 3 shield")


func test_ace_of_cups_revives_twice() -> void:
	var team := [{"def": _db.figures["coin_squire"], "level": 1}, {"def": _db.figures["altar_server"], "level": 1},
		{"def": _db.figures["ace_of_cups"], "level": 1}]
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["greedy_dragon"], "level": 3}])
	var revives: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["type"] == "revive")
	assert_lte(revives.size(), 2)
	assert_gt(revives.size(), 0)


func test_ace_of_coins_shields_by_interest() -> void:
	var team := [{"def": _db.figures["ace_of_coins"], "level": 1}, {"def": _db.figures["the_judge"], "level": 1}]
	var result := BattleSimulator.simulate(team, [{"def": _db.enemies["beggar_ghost"], "level": 1}], 23)
	var shielded := false
	for e in result["events"]:
		if e["type"] == "update" and e["unit"]["uid"] == 2 and e["unit"]["statuses"].get("shield", 0) == 8:
			shielded = true
	assert_true(shielded, "23 gold -> interest 4 -> shield 8")


# --- Inserting -------------------------------------------------------------------------

func test_insert_between_shifts_figures() -> void:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("the_judge"), _fig("executioner")]
	var moving: String = run.row[2]["def_id"]
	assert_true(run.insert_between(2, 0), "behind the front figure")
	assert_eq(run.row.map(func(f): return f["def_id"]), ["coin_squire", moving, "the_judge"])
	assert_true(run.insert_between(1, -1), "to the very front")
	assert_eq(run.row[0]["def_id"], moving)


func test_legendary_figures_come_only_from_arcana_packs() -> void:
	var rng := RngStreams.new(9).stream("t")
	var legends := 0
	for i in 2000:
		for item in Items.pack_contents(_db, {"type": "arcana", "size": "normal"}, 1, rng):
			if item["kind"] == "figure":
				legends += 1
				assert_eq(_db.figures[item["def_id"]]["rank"], "legend")
	# 6000 cards at 1 % -> about 60.
	assert_between(legends, 25, 110)
	for i in 300:
		for item in Items.pack_contents(_db, {"type": "equipment", "size": "mega"}, 1, rng):
			assert_ne(item["kind"], "figure")


func test_figures_can_be_merged_on_the_reward_screen() -> void:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("coin_squire"), null]
	run.apply_battle_result({"victory": true})
	assert_true(run.move(1, 0))
	assert_null(run.row[1])


func test_team_entries_list_what_modifies_a_figure() -> void:
	var run := _planning_run()
	run.row = [_fig("coin_squire"), _fig("spark_bearer"), null]
	run.row[0]["bonus_attack"] = 2
	run.relics = ["war_chest", "eternal_ember", "beggars_bowl"]
	var team := run.player_battle_team()
	assert_has(team[0]["sources"], "war_chest")
	assert_has(team[0]["sources"], "tarot_strength")
	assert_does_not_have(team[0]["sources"], "eternal_ember")
	assert_has(team[1]["sources"], "eternal_ember", "spark bearer applies burn")
	assert_does_not_have(team[1]["sources"], "beggars_bowl", "gold relics affect no figure")


func test_object_slots_grow_with_level_and_fusion() -> void:
	var run := _planning_run()
	run.row[0] = _fig("coin_squire")
	run.tarots = ["strength", "strength"]
	assert_true(run.use_tarot(0, 0))
	assert_false(run.use_tarot(0, 0), "a new figure has one slot")
	var blade := {"base": "blade", "rarity": 0, "affixes": [], "drawback": {}}
	run.open_pack = {"pack": {"type": "equipment", "size": "normal"}, "picks_left": 1, "items": [{"kind": "equipment", "item": blade}]}
	assert_false(run.can_take_pack_item(0, 0))
	run.row[0]["xp"] = RunState.XP_FOR_LEVEL[2]
	assert_eq(run.object_limit(run.row[0]), 2, "level 3: two slots")
	assert_true(run.can_take_pack_item(0, 0))
	var fused := {"uid": 7, "def_id": "coin_squire", "xp": 0, "fusion": {"parts": ["coin_squire", "spark_bearer"],
		"suits": ["coins", "wands"], "abilities": [], "attack": 3, "health": 3}}
	assert_eq(run.object_limit(fused), 2, "F1 at level 1: 1 + 1")
	fused["fusion"]["parts"] = ["coin_squire", "spark_bearer", "altar_server", "executioner"]
	fused["xp"] = RunState.XP_FOR_LEVEL[2]
	assert_eq(run.object_limit(fused), 3, "capped at three")


func test_reroll_keeps_the_packs() -> void:
	var run := _planning_run()
	run.gold = 20
	var packs_before := run.packs.duplicate(true)
	run.reroll()
	assert_eq(run.packs, packs_before)


func test_enemy_options_use_different_enemies() -> void:
	for seed_value in range(1, 30):
		var run := RunState.new_run(_db, seed_value)
		# The options are built from different enemies; only the cheap ones
		# added to reach the next difficulty step may repeat.
		var first: Array = run.enemy_options[0]["team"].map(func(u): return u["def_id"])
		var second: Array = run.enemy_options[1]["team"].map(func(u): return u["def_id"])
		var fresh := second.filter(func(id): return not id in first)
		assert_gt(fresh.size(), 0, "seed %d: the medium option brings new enemies" % seed_value)
