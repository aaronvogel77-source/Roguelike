---
name: balance
description: Measure Arcana's balance with the strategy bots (tools/bots.gd) and the report (tools/balance_report.gd). Use before and after changing enemy budgets, bosses, figures, items, economy or fusion values.
---

# Balancing with bots

Seven bots play whole runs like players (buy/sell figures, reroll, open packs, equip, use tarot,
take fusions, play events, rearrange, take boss treasures): Verschwender (spends everything), Sparer
(keeps gold for interest), Leveler (merges duplicates), Farbspezialist (one suit), Fusionist (seeks
fusions), Taktiker (adaptive enemy choice), Stratege (takes the hard band 80 % of the time, tries each
shop purchase on a copy of the run against the coming band). Strategies are knobs in
`BalanceBot.STRATEGIES`.

Every bot counters the enemy band with test battles: it tries orders of its row in the simulator
(all orders up to 4 figures, pair swaps above) and keeps the best; adaptive bots pick the hardest
band they beat in such a test. A full report takes about 2-3 minutes - run it in the background.

## Tools (all deterministic: run i always uses seed i, so two measurements differ only by the change)

| Tool | Question it answers | Time |
|---|---|---|
| `tools/balance_report.gd -- 150 --out=new.json --compare=old.json` | Win rate per bot and station, each with its 95 % interval; with `--compare` the change against an earlier report (`*` = very likely real) | ~2-3 min |
| `tools/duel_matrix.gd -- [gold]` | Each figure (plus a neutral 2/4 helper) against each enemy pair, levels 1-3, without shop luck; outliers within a rank are flagged | < 1 s |
| `tools/ablation.gd -- 30 [figures\|relics\|pacts\|all]` | Real strength of a card: all bots without the figure / starting with the relic or pact; difference to the baseline in points | ~20 min (all) |
| `tools/auto_tune.gd -- 20 50` | Searches enemy values station by station until the bots land in the corridors of `tools/balance_targets.json`; prints proposals, writes nothing | ~15-25 min |

```bash
timeout 1500 godot --headless -s tools/balance_report.gd -- 150 --out=/tmp/new.json 2>&1 | grep -v "^WARNING\|^ERROR\|leaked\|at:"
```
Shared helpers (batches, Wilson interval, z-test) live in `tools/balance_lab.gd`. Long tools belong in the
background. Store reports for comparison in the scratchpad, never in the repository.

**Workflow:** duel matrix (cheap, finds broken single cards) → ablation (what really carries runs) →
fix cards → auto-tune enemy values to the target corridors → full report with `--compare` against the
previous one → only report changes marked `*` as real; anything inside the interval is noise.

Read in this order:
1. **Stationen**: per fight (A1 K1 ... A2 K3) win rate, average own power vs enemy power, figures
   in the row, chosen difficulty. Look for jumps (a station far below its neighbours).
2. **Bots**: win rate and where runs end per strategy - one strategy far above the rest means it
   dominates; one far below means its approach is not viable.
3. **figures / relics / pacts / masters**: how often they are in the final row and the win rate.
   Low-rank figures always look weak late (they are sold or carried by early losers) - compare
   within a rank.

Bots play weaker than humans in the shop (few rerolls, simple fusions) but arrange perfectly against the visible band, so treat their win rates as a rough guide.
Change one thing at a time, measure again with the same run count, record the numbers in the
GAME_DESIGN.md decision log, then use the `deploy` skill. Corridors in `tools/balance_targets.json`
are design decisions of the player - change them only after asking.
