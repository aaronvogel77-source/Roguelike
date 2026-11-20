extends GutTest
## Content files load and are well-formed; RNG streams are reproducible.


func test_slice_content_counts() -> void:
	var db := ContentDb.load_default()
	assert_eq(db.regular_figures().size(), 16, "16 player figures in the slice")
	assert_eq(db.legendary_figures().size(), 4, "4 legendary aces")
	assert_eq(db.regular_enemies(99, "coins").size(), 16, "16 coin-region enemies (6 of them act-2 elites)")
	assert_eq(db.regular_enemies(1, "coins").size(), 10, "10 of them in act 1")


func test_four_figures_per_suit_one_per_rank() -> void:
	var db := ContentDb.load_default()
	for suit in ContentDb.SUITS:
		var ranks: Array = []
		for figure in db.regular_figures():
			if figure["suit"] == suit:
				ranks.append(figure["rank"])
		ranks.sort()
		var expected := ContentDb.RANKS.duplicate()
		expected.sort()
		assert_eq(ranks, expected, "suit " + suit)


func test_every_name_has_a_translation() -> void:
	TranslationServer.set_locale("de")
	var db := ContentDb.load_default()
	for definition in db.figures.values() + db.enemies.values():
		var key := ContentDb.name_key(definition)
		assert_ne(tr(key), key, "missing translation for " + key)


func test_stats_are_positive() -> void:
	var db := ContentDb.load_default()
	for definition in db.figures.values() + db.enemies.values():
		assert_gte(int(definition["attack"]), 0, definition["id"])
		assert_gt(int(definition["health"]), 0, definition["id"])


func test_rng_streams_are_reproducible_and_independent() -> void:
	var a := RngStreams.new(42)
	var b := RngStreams.new(42)
	assert_eq(a.stream("shop").randi(), b.stream("shop").randi())
	# Drawing from one stream must not change another.
	var c := RngStreams.new(42)
	c.stream("enemy_gen").randi()
	c.stream("enemy_gen").randi()
	var d := RngStreams.new(42)
	assert_eq(c.stream("shop").randi(), d.stream("shop").randi())
	assert_ne(RngStreams.new(42).stream("shop").randi(), RngStreams.new(43).stream("shop").randi())
