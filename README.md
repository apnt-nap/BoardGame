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

**Your turn.** You hold 2 Action Cards. Play 1; the other is discarded. Then the Knight moves.

| Card | Copies | Effect |
|---|---|---|
| Explore | 2 | Move up to 2 rooms. Silent. |
| Dash | 2 | Move up to 3 rooms. Noise +1 in total, the token goes to where you stop. |
| Search | 6 | Not on a Seal. D6: 1 fail (+1 Noise, token here) · 2–5 one Shard · 6 one Shard and a Minor Treasure (the miss bonus counts, so a 5 after a failed Search also finds one). Each room can be searched successfully once. |
| Activate | 4 | On an unrestored Seal: spend 2 Shards and the Seal is restored. No roll, it always works. |
| Hide | 2 | Stay. Noise −2, never below 0 (playable at Noise 0 as a silent wait). |

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

**Reading the Knight.** The badge above it and the Knight panel show what it is doing, as an icon and a
word: Patrol (loop), Investigate (question mark, marker pin or signal rings), Hunt (ear when it hears you, eye
when it sees you), Search (magnifier), Stunned (stars). Its heading arrow appears only when you could know its
target: when it hunts you, walks to the noise marker, or follows a Seal signal. It never shows during Patrol or
Search. Hatched rooms with an eye are in its line of sight (Normal/Hard): straight down a row or column through
open doorways, never around a corner. The orange pin is the noise marker.

**Controls.** Click a card to see a preview of what will happen, then click a highlighted room (moves) or the
card again (everything else) to confirm. `1`/`2` pick a card · `Space` confirms · `Esc` or right-click
cancels, or opens the pause menu · `R` redraws · `Tab` steps through reachable rooms · `M` mutes.
Settings: effects volume, reduced motion, faster animations, larger text, and one-click play (confirm off).
In debug builds only, `F1` shows the Knight's mind (state, memory, pre-rolled die, planned route, decisions).

**Heroes and unlocks** (saved in `%APPDATA%\Godot\app_userdata\Curse of Blackthorn Keep\profile.cfg`):

| Hero | Single-use item | Unlock |
|---|---|---|
| Ranger | Lantern: the Knight skips its next turn; in an encounter, also escape silently | Start |
| Alchemist | Healing Potion: +1 Health | Start |
| Mage | Silence Scroll: Noise −2; in an encounter, also escape | Win once |
| Knight | Rune Key: once per run, restore a Seal with 1 Shard instead of 2 (you still need the Activate card and to be on the Seal) | Win on Normal |
| Thief | Smoke Vial: escape an encounter with no damage and no noise | Win with 3 different heroes |

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
entering your room.

**Seal signal (all difficulties).** Restoring the 1st or 2nd Seal sends a signal from that Seal's room. On its
next normal turn the Knight heads for that room (not for you), 2 rooms per turn with no die, unless it hears or
sees you, which still comes first and cancels the signal. A Lantern stun skips the turn but keeps the signal. If it
reaches the Seal and you're gone, it starts searching there. A newer signal replaces an older one. The third Seal
wins at once, with no signal. Every decision
is logged with its reason, both in the debug overlay (F1, debug builds) and in `%APPDATA%\Godot\app_userdata\Curse of Blackthorn Keep\knight_log.txt`.

| Difficulty | Moves on | Memory | Hunts at Noise | Steps when charging | Search | Sight | Hide check |
|---|---|---|---|---|---|---|---|
| Easy | 4–6 | 1 turn | 4 | 1 | 1 turn | same room only | 4–6 safe |
| Normal | every turn (no die) | 2 turns | 3 | 2 | 2 turns | 1 room, straight line | 4–6 safe |
| Hard | 2–6 | 3 turns | 3 | 2 | 3 turns | 2 rooms, straight line | 5–6 safe |

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
Godot_v4.7.2-stable_win64_console.exe --path . --script res://scripts/tests/ui_smoke.gd -- --games 3
```

It also saves the title, hero select, difficulty, How to play and Settings screens, the main screen, a move
preview, an encounter, a restored Seal and each end screen.

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
  game.gd                 turn loop, cards, dice, noise, encounters, items
  bot.gd                  simulated player
scripts/ui/               visuals only
  palette.gd              storybook colours, card categories, art names, room names: reskin here
  art.gd                  loads art/ and fonts/ (missing files fall back to shapes drawn in code)
  icon.gd                 small icons drawn in code (hearts, shards, Knight states, card categories)
  board_view.gd           draws the castle and animates the pieces
  main.gd                 title, hero and difficulty select, HUD, previews, encounter, end, pause,
                          settings, How to play, event playback
  settings.gd             player settings (user://settings.cfg)
  sfx.gd                  sound hooks (placeholder synth tones)
  profile.gd              unlock progress
scripts/sim/simulate.gd   headless balance simulation
scripts/tests/ui_smoke.gd UI smoke test
scripts/tools/import_art.gd cuts the art out of "Game Presentation - Final.pdf"
art/                      storybook art used by the game
fonts/                    Cinzel Decorative, Cinzel, Crimson Pro (SIL Open Font License, see fonts/OFL.txt)
docs/                     balance results
```

**Art.** The art comes from the deck "Game Presentation - Final.pdf": the Seal crystal shrine, the Cursed
Knight, the five heroes, the item icons, the action-card illustrations, the parchment and the castle paintings.
It is cut into `art/` by a script, so it can be redone after the deck changes:

```
mutool extract "Game Presentation - Final.pdf"     (run inside build/ref_images/)
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/tools/import_art.gd -- --contact
```

Crops are listed at the top of `scripts/tools/import_art.gd`; which file is used where is set in
`scripts/ui/palette.gd`. Rooms, doorways, special-room props, icons and the Seal states are drawn in code in the
same thick-outline style, because the deck has no art for them. Card names and rules are text, not part of the
images, so they stay editable.

**Reskinning.** Every colour is in `scripts/ui/palette.gd`. For real sounds, drop
`res://audio/<hook>.ogg` or `.wav` files named after the hooks in `sfx.gd` (`seal`, `damage`, `encounter`,
`knight_step`, `bell`, `win`, `lose`, …). They replace the synthesized placeholders automatically.
