---
name: balance
description: Measure Arcana's balance with the strategy bots (tools/bots.gd) and the report (tools/balance_report.gd). Use before and after changing enemy budgets, bosses, figures, items, economy or fusion values.
---

# Balancing with bots

Six bots play whole runs like players (buy/sell figures, reroll, open packs, equip, use tarot,
take fusions, play events, rearrange): Verschwender (spends everything), Sparer (keeps gold for
interest), Leveler (merges duplicates), Farbspezialist (one suit), Fusionist (seeks fusions),
Taktiker (adaptive enemy choice, tactical order). Strategies are knobs in `BalanceBot.STRATEGIES`.

```bash
timeout 900 godot --headless -s tools/balance_report.gd -- 150 2>&1 | grep -v "^WARNING\|^ERROR\|leaked\|at:"
```

Read in this order:
1. **Stationen**: per fight (A1 K1 ... A2 K3) win rate, average own power vs enemy power, figures
   in the row, chosen difficulty. Look for jumps (a station far below its neighbours).
2. **Bots**: win rate and where runs end per strategy - one strategy far above the rest means it
   dominates; one far below means its approach is not viable.
3. **figures / relics / pacts / masters**: how often they are in the final row and the win rate.
   Low-rank figures always look weak late (they are sold or carried by early losers) - compare
   within a rank.

Bots play weaker than humans (few rerolls, simple fusions), so treat their win rates as a floor.
Change one thing at a time, measure again with the same run count, record the numbers in the
GAME_DESIGN.md decision log, then use the `deploy` skill.
