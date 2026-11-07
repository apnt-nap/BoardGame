# Balance and AI Evaluation

Build v1.0 · 7 Nov 2026 · raw data: [`sim_results.csv`](sim_results.csv)

## Method

`scripts/sim/simulate.gd` runs the real game code (`scripts/core/`) headless. A heuristic bot
(`scripts/core/bot.gd`) plays **1,000 games per hero per difficulty (18,000 games)** on fresh random castles.
The bot sees only what a human sees on the board: the Knight's room, its intent arrow, the Noise token
and the Spirit. It never reads the Knight's memory or its pre-rolled die. Its plan: gather Shards in the
nearest unsearched room, walk to the nearest Seal that isn't guarded, avoid the Knight's room and its next
step, go quiet when Noise nears the hunt threshold, and HIDE in encounters (escape items at 2 Health or less).

Re-run it:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/sim/simulate.gd -- --games 1000 --out res://docs/sim_results.csv
```

## Results

| Hero | Easy | Normal | Hard |
|---|---|---|---|
| Ranger | 70.4% | 50.3% | 34.1% |
| Alchemist | 69.8% | 54.4% | 32.6% |
| Mage | 70.3% | 55.1% | 34.8% |
| Knight | 73.3% | 55.7% | 37.4% |
| Thief | 70.6% | 54.2% | 30.8% |
| Priest | 70.6% | 51.4% | 29.4% |
| **Average** | **70.8%** | **53.5%** | **33.2%** |
| Target | 65–75% | 45–55% | 25–35% |

| Difficulty | Avg turns | Encounters / game | Damage / game | Losses: Health | Losses: time |
|---|---|---|---|---|---|
| Easy | 30.1 | 0.88 | 0.33 | 2% | 98% |
| Normal | 30.0 | 3.68 | 1.46 | 30% | 70% |
| Hard | 29.1 | 3.84 | 2.05 | 45% | 55% |

With 1,000 games, each win rate has a margin of about ±3 points (95%).

## What the numbers say about the AI

- **Every level lands in its target band** on average, and 16 of the 18 hero × difficulty cells are inside it.
- **The difficulty comes from the Knight, not from different rules.** Only the Knight's senses change between
  levels, yet encounters per game rise from 0.9 (Easy) to 3.7–3.8 (Normal/Hard). Health losses rise from 2% to 30% to 45%.
  On Easy the Knight is a presence you route around. On Hard it is the most common reason you lose.
- **Hard hurts more per encounter.** It has about as many encounters as Normal but 40% more damage. Its search lasts
  longer, it remembers for 3 turns, it charges 2 rooms when it hears you, and it checks hiding spots (HIDE is safe only on 5–6).
- **The Knight hero is the strongest** (+2 to +4 points), the same result as the paper playtests: time is the most common
  way to lose, and the Rune Key is the only item that saves time. It stays slightly above the band on Normal and Hard.
  We kept it, because it is a reward unlocked by winning on Normal.

## Tuning history

The design doc's first numbers (turn limit 30, the paper deck, no sight) gave these bot win rates. Intermediate rows come from a Python copy of the rules
(300–500 games each, Ranger) used for fast iteration. The final row is the Godot run above:

| Step | Easy | Normal | Hard | Problem / fix |
|---|---|---|---|---|
| Design doc numbers | 10–19% | 10–14% | 8–14% | Time-outs: almost every loss came at turn 30 with 1–2 Seals done |
| Bot waits on a Seal instead of wandering (Sneak "keep still" allowed at Noise 0) | 24% | 19% | 18% | Still a race; difficulty barely mattered |
| Deck 2/2/6/4/2 (Explore was redundant with Sneak), bot HIDEs | 34% | 29% | 31% | Difficulty still barely mattered: the Knight wasn't threatening |
| Add **sight** sense (0/1/2 doorways) | — | 43% | 41% → 7% | Sight 2 plus 2-step hunting was far too strong |
| Sight-chase moves 1; only a Noise charge uses 2 steps | — | — | 32% | Hard on target |
| Turn limit 36, Normal moves on 2–6 | **71%** | **54%** | **33%** | On target (Godot results above) |

## Caveats for the report

- The bot is consistent but not a human. Humans make more mistakes, but they also use the Library, the Bell Tower and
  Secret Passages better. Treat these rates as a calibration of the AI, and use the playtest survey (`SURVEY.md`)
  for how it feels.
- Every game writes `knight_log.txt` (shown on the end screen). It lists each Knight decision with its reason,
  for example `T07 [INVESTIGATE] Rolled 5 (needs 2+): moves C3 -> C2. Heard something at A4: goes to investigate`.
