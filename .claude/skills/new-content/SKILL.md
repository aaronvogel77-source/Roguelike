---
name: new-content
description: Checklist for adding a figure, enemy, relic, tarot card, pact, event, master ability or skin to Arcana so nothing is forgotten. Use whenever new game content is added.
---

# Adding content to Arcana

Design first: new content is decided with the player in a planning round (multiple-choice questions),
recorded in `GAME_DESIGN.md`, and built only after approval.

## Figure (court card or ace)
1. `data/figures.json`: id, suit, rank, attack, health, ability (trigger, target, effect, values per level).
2. New effect? Add it to `scripts/core/ability_effects.gd` (return true only when something happened).
3. `translations/strings.csv`: `FIG_<ID>`, `ABIL_<ID>` (`{v}` = level value), for kings/legends `SPECIAL_<ID>`,
   fusion names `NAME_STEM_<ID>` and `NAME_CORE_<ID>`. Quote values containing commas.
4. Pixel design in `scripts/ui/stage/figure_art.gd` `SPECS` (torso, head, weapon, skin, robe, cape, extras),
   matching name and ability. Ranged figures go into `RANGED`.
5. Preview: `godot --headless -s tools/render_figures.gd -- <scratchpad>/figs.png` and look at it.
6. Test in `tests/unit/test_abilities.gd`; run all tests.

## Enemy or boss
`data/enemies.json` (cost, role, themes) or `data/regions.json` (bosses), `ENEMY_<ID>`/`ABIL_<ID>` strings,
creature art in `scripts/ui/stage/creature_art.gd` (add the id to the art list and the `_make` match),
preview with `tools/render_creatures.gd`.

## Relic, tarot, pact, event
`data/items.json` plus strings (`RELIC_`, `TAROT_`, `PACT_..._DESC/_COST`, `EVENT_..._DESC`), logic in
`scripts/core/run_state.gd` or the battle options. Decide whether it starts locked (`data/meta.json` → `locked`).

## Master ability or skin
Masters: `data/fusion.json` + `MASTER_<ID>`/`_DESC`. Skins: `data/meta.json` cosmetics (price, rarity, fx),
`SKINS` and `FX_COLORS` in `figure_art.gd`, effects in `figure_actor.gd`, `COSMETIC_`/`SPECIAL_` strings.

## Always
The grimoire lists content automatically; check it with `?debug=1`. Then use the `deploy` skill.
