# Curse of Blackthorn Keep

A single-player, turn-based survival board game for Windows, built in **Godot 4.7 (GDScript)**.
Sneak through a random 5×5 castle, gather Rune Shards and restore Seals A, B and C before
midnight, while the Cursed Knight hunts you by sound and sight.

This is the digital redesign of the paper prototype (`Curse-of-Blackthorn-Keep-Rulebook (1).pdf`).
The redesign is described in [`Design-Doc.md`](Design-Doc.md), and the tuning that changed numbers from it
is in [`docs/BALANCE.md`](docs/BALANCE.md).

---

## Run it

1. Install **Godot 4.7.x (standard, not .NET)**. On this laptop it is at
   `Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`.
2. Open Godot, click **Import**, select this folder's `project.godot`, then press **F5** (Run).

From a terminal in this folder:

```
Godot_v4.7.2-stable_win64_console.exe --path .
```

## Export the .exe

1. In the Godot editor: **Editor → Manage Export Templates → Download and Install** (one time, about 1 GB).
2. **Project → Export…** → the preset **Windows Desktop** is already set up → **Export Project** →
   it writes `build/BlackthornKeep.exe` (one file; the game data is embedded).

Command-line equivalent, after the templates are installed:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/BlackthornKeep.exe
```

**Sharing with friends.** Zip `build/BlackthornKeep.exe` (about 44 MB zipped) and share it with a Google Drive or OneDrive link,
or attach it to a GitHub Release. It is too big for email or Discord. Your friend unzips it and double-clicks the exe; nothing needs installing.
The exe isn't code-signed, so Windows SmartScreen may show "Windows protected your PC". Click **More info → Run anyway**.

---

## How to play

**Goal.** Restore all three Seals (2 Rune Shards each) before your Health hits 0 or Turn 36 ends.

**Your turn.** You hold 2 Action Cards. Play 1; the other is discarded. Then the Wandering Spirit and the Knight move.

| Card | Copies | Effect |
|---|---|---|
| Explore | 2 | Move up to 2 rooms. Silent. |
| Dash | 2 | Move up to 3 rooms. Noise +1 in total, the token goes to where you stop. |
| Search | 6 | Not on a Seal. D6: 1 fail (+1 Noise, token here) · 2–5 one Shard · 6 one Shard and a Minor Treasure (the miss bonus counts, so a 5 after a failed Search also finds one). Each room can be searched successfully once. |
| Activate | 4 | On an unrestored Seal: spend 2 Shards and the Seal is restored. No roll, it always works. |
| Hide | 2 | Stay. Noise −2 (needs Noise above 0). |

- **Sneak:** any card can be played face-down to *move 1 room silently* or to *keep still* (Noise −1).
  You never have a dead turn.
- **Misses build up:** a failed Search gives +1 to your next Search (used up on that roll, never more than +1; the result is capped at 6).
- **Free redraw:** once per run, before you play your card, discard both cards and draw 2 new ones. It costs no turn.
- **Noise** goes from 0 to 5.
- **Rooms:** Chapel (heal 1, once), Bell Tower
  (move the Noise token to the tower, once), Armory (a free treasure, once), Secret Passages (two
  linked corners, silent, and the Knight doesn't know about them). Using a room is free, once per turn.
- **The Keep fights back:** every restored Seal closes one doorway and opens another. The second Seal
  corrupts 2 special rooms for the rest of the run.
- **Encounter** (the Knight ends its move in your room): **RUN** (1–2: −1 Health; always flee 1 room, Noise +1),
  **HIDE** (1–3: −1 Health and flee; 4–6: safe, but it's still in the room), or use an item.
  Potion, Ward Charm and Ration can be used first, and then you still choose.
- **Wandering Spirit:** harmless, drifts randomly. If it ends in your room it shrieks: Noise +1.

**Reading the Knight.** The icon above it shows its state: `~` Patrol, `?` Investigate, `!` Hunt,
`?!` Search. The arrow shows its next step. Rooms tinted red are inside its line of sight (Normal/Hard).
The orange token is the last noise it heard.

**Controls.** Mouse for everything · `1`/`2` play a card · `Esc` cancels a move · **`F1` shows the Knight's
mind** (state, memory, pre-rolled die, planned route, recent decisions) · `M` mutes.

**Heroes and unlocks** (saved in `%APPDATA%\Godot\app_userdata\Curse of Blackthorn Keep\profile.cfg`):

| Hero | Single-use item | Unlock |
|---|---|---|
| Ranger | Lantern: the Knight skips its next turn; in an encounter, also escape silently | Start |
| Alchemist | Healing Potion: +1 Health | Start |
| Mage | Silence Scroll: Noise −2; in an encounter, also escape | Win once |
| Knight | Rune Key: once per run, restore a Seal with 1 Shard instead of 2 (you still need the Activate card and to be on the Seal) | Win on Normal |
| Thief | Smoke Vial: escape an encounter with no damage and no noise | Win with 3 different heroes |
| Priest | Blessing: the Spirit can't shriek at you for 5 turns | Win on Hard |

Hard unlocks after a Normal win. The end screen shows turns, damage taken and times found.

---

## The Cursed Knight AI

`scripts/core/knight_ai.gd` is a finite state machine with memory. It acts **only on its senses**:
the Noise level, the Last Known Noise token, and your room *only* while Noise is at its hunt
threshold or while you are within its sight range. It never reads hidden game state.

| State | Enters when | Behaviour |
|---|---|---|
| PATROL | Nothing heard | Loops through all three Seals by the shortest route; restored Seals are visited twice per loop |
| INVESTIGATE | A new noise token appears (or the trail faded but is still in memory) | Shortest path to the token |
| HUNT | Noise ≥ hunt threshold (charges, Hard = 2 rooms/move) or it sees you (stalks, 1 room) | Shortest path to your room |
| SEARCH | It reaches the noise and you're gone, it loses the trail, or you out-hide it | Checks the rooms around that spot for N turns, then patrols |

On Easy and Hard a pre-rolled D6 decides move or stay. On Normal there is no die: the Knight moves every turn
(unless stunned): 2 rooms when it hears you (Noise at the threshold, even if it also sees you), otherwise 1 room
(Patrol, Investigate, Search, a sight-only Hunt, and following its memory after losing you). It always stops on
entering your room. Every decision
is logged with its reason, both on screen (F1) and in `%APPDATA%\Godot\app_userdata\Curse of Blackthorn Keep\knight_log.txt`.

| Difficulty | Moves on | Memory | Hunts at Noise | Steps when charging | Search | Sight | Hide check |
|---|---|---|---|---|---|---|---|
| Easy | 4–6 | 1 turn | 4 | 1 | 1 turn | same room only | 4–6 safe |
| Normal | every turn (no die) | 2 turns | 3 | 2 | 2 turns | 1 doorway | 4–6 safe |
| Hard | 2–6 | 3 turns | 3 | 2 | 3 turns | 2 doorways | 5–6 safe |

## Balance simulation

A heuristic bot plays the real rules (same code as the game) with only the information a player sees.

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/sim/simulate.gd -- --games 1000 --out res://docs/sim_results.csv
```

The CSV columns are hero, difficulty, games, win_rate, avg_turns, avg_encounters, avg_damage,
loss_health and loss_time. Results and tuning notes are in [`docs/BALANCE.md`](docs/BALANCE.md).

Rules tests (movement, Search, automatic Activate, Rune Key, redraw, removed content, castle generation, 60 bot games):

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/tests/rules_test.gd
```

UI smoke test (plays whole games through the real interface and saves screenshots to `build/shots/`):

```
Godot_v4.7.2-stable_win64_console.exe --path . --script res://scripts/tests/ui_smoke.gd -- --games 2
```

## Playtest

Hand testers [`SURVEY.md`](SURVEY.md) after 2 games each.

---

## Project layout

```
project.godot, export_presets.cfg
scenes/main.tscn          the only scene; the UI is built in code
scripts/core/             game logic, no visuals (shared by the game and the simulation)
  config.gd               every rule number, card, treasure, hero, difficulty
  castle.gd               random 5x5 generation, doorways, pathfinding, keep shift, corruption
  knight_ai.gd            Cursed Knight state machine + decision log
  game.gd                 turn loop, cards, dice, noise, encounters, items, Spirit
  bot.gd                  simulated player
scripts/ui/               visuals only
  palette.gd              colours, icons, room names: reskin here
  board_view.gd           draws the castle and animates the pieces
  main.gd                 menu, HUD, encounter, end screen, F1 debug, event playback
  sfx.gd                  sound hooks (placeholder synth tones)
  profile.gd              unlock progress
scripts/sim/simulate.gd   headless balance simulation
scripts/tests/ui_smoke.gd UI smoke test
scripts/tools/import_art.gd cuts the painted art out of Game Design.pdf
art/                      painted art used by the game
docs/                     balance results
```

**Art.** The painted art comes from `Game Design.pdf`: room tiles, Seal tokens, the player and Knight miniatures,
hero portraits, card, item and encounter illustrations, and HUD tokens. It is cut into `art/` by a script, so it can be redone
after the PDF changes:

```
mutool extract "Game Design.pdf"            (run inside build/art_src/)
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/tools/import_art.gd
```

Crop rectangles are listed at the top of `scripts/tools/import_art.gd`. Which picture goes where (room tiles per room type,
card art, hero portraits) is set in `scripts/ui/palette.gd`. Any element whose file is missing falls back to the flat vector style.
Thief and Priest have no portraits in the PDF yet; they borrow the Hide card and Use Item art.

**Reskinning.** Every colour is in `scripts/ui/palette.gd`. To use painted icons, map a room type to a texture
in `ICON_TEXTURES` (for example `"chapel": "res://art/chapel.png"`). For real sounds, drop
`res://audio/<hook>.ogg` or `.wav` files named after the hooks in `sfx.gd` (`seal`, `damage`, `encounter`,
`knight_step`, `shriek`, `bell`, `win`, `lose`, …). They replace the synthesized placeholders automatically.
