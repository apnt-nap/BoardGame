# Curse of Blackthorn Keep: Digital Redesign

> **Playtest rules (build v1.1, 8 Nov 2026).** These override anything below that disagrees.
>
> - **Cards** (deck unchanged: 2 Explore, 2 Dash, 6 Search, 4 Activate, 2 Hide). Explore: move silently up to 2 rooms. Dash: move up to 3 rooms, Noise +1 in total, token at the destination. Hide card: stay, Noise −2 (the encounter HIDE is unchanged). Sneak (any card): move 1 room silently, or stay and lower Noise by 1 (allowed at Noise 0). Noise stays between 0 and 5.
> - **Search** (not on a Seal, each room once): D6 1 fail, Noise +1 and token here · 2–5 one Shard · 6 one Shard and a treasure. A fail gives +1 to the next Search only (no stacking, capped at 6).
> - **Activate:** on an unrestored Seal with 2 Shards, it always succeeds. No roll, no miss bonus, no Noise change, no Focus. The third Seal still wins at once.
> - **Focus is gone.** Instead you get one free redraw per run, before playing your card.
> - **Removed:** the Library room and the Secret Passage Map treasure. Rooms are now Chapel, Armory, Bell Tower and Secret Passage.
> - **Rune Key:** once per run, restore a Seal with 1 Shard instead of 2 (you still need the Activate card and to be on the Seal).
> - **Normal Knight: no movement die.** It moves every turn unless stunned: 2 rooms when it hears you (Noise at the threshold, even if it also sees you), 1 room otherwise (Patrol, Investigate, Search, sight-only Hunt, memory pursuit). It stops on entering your room. Easy and Hard keep the die.
> - **Seal signal:** restoring the 1st or 2nd Seal sends a signal from its room. On its next turn the Knight heads there (2 rooms per turn, no die, all difficulties) unless it hears or sees you, which comes first and cancels the signal. Stun keeps the signal. Reaching the Seal with nobody there starts a Search. A newer signal replaces an older one. The third Seal wins at once with no signal.
> - **Line of sight:** the Knight sees you only in a straight row or column through open doorways, up to its sight range. It cannot see around a corner or through a wall.
> - The bot results in `docs/BALANCE.md` were measured with the v1.0 rules and have not been re-run for v1.1.

Nov 7, 2026 · @Asia · updated after bot tuning for build v1.0 (see "Tuning changes" at the end)

## Goal

Turn the paper prototype into a Windows .exe that is worth replaying: a bigger random castle, fewer dead turns, and a Cursed Knight AI we can explain and measure. The win condition stays the same: restore Seals A, B and C (2 Rune Shards each) before Health hits 0 or the turn limit ends.

What changes from the paper version:

- The castle grows from 3×3 to 5×5, is randomized every run, and has special rooms.
- The castle shifts each time a Seal is restored.
- Items are less luck-based, and bad rolls or bad hands always leave a useful action.
- A second NPC, the Wandering Spirit, joins the Knight.
- Three difficulty levels change only what the Knight senses and how fast it reacts.
- Heroes unlock as you win.

## The castle

The castle is a 5×5 grid of 25 rooms, generated fresh every run. Rooms connect only through doorways, and not every wall has one, so routes matter. The generator always keeps every room reachable and puts the three Seals at least 3 rooms apart.

Each run places 4 special room types at random (5 rooms, because the Secret Passage has two linked ends):

| Room | What you can do there | Limit |
| --- | --- | --- |
| Chapel | Heal 1 Health | Once per run |
| Bell Tower | Ring the bell: the Noise token goes to the Bell Tower, not to you, luring the Knight away | Once per run |
| Secret Passage | Step straight to the paired passage room in another corner, with no Noise | Any time |
| Armory | Take one guaranteed Minor Treasure | Once per run |

**The keep shifts.** Each time you restore a Seal, the curse fights back: one doorway slams shut and another opens somewhere else. A shift never cuts you off from an unrestored Seal. The change shows on screen, so you replan with a castle that is now partly new.

**Corrupted rooms.** When the second Seal is restored, the curse corrupts 2 special rooms chosen at random. A corrupted room turns dark on the map and its ability no longer works for the rest of the run. Players who saved the Chapel or the Bell Tower for later may lose them, so using rooms early becomes a real choice.

The turn limit rises from 24 to **36** to fit the bigger map. The bot simulation set the exact number (see Tuning changes).

## Your turn, cards and items

The core stays the same: draw 2 Action Cards, play 1, discard 1, then the Knight acts. The 16-card deck is now 2 Explore, 2 Dash, 6 Search, 4 Activate and 2 Hide. Sneak already moves you 1 room silently, so three Explore copies became Search and Activate. Three fixes stop a bad roll or a bad hand from wasting a turn.

1. **Any card can be played as a Sneak.** Instead of its printed action, play any card face down to move 1 room with no Noise, or to keep still and lower Noise by 1 (this also works at Noise 0, as a silent wait). A hand of two unusable Activates is never a dead turn again.
2. **Misses build up.** A failed Search gives +1 to your next Search roll (used up on that roll, never more than +1, result capped at 6). Activate has no roll any more (see Playtest rules).
3. **One free redraw per run.** Before playing your card, discard both cards and draw 2 new ones. It costs no turn, and you get it once per run. (This replaced Focus.)

**Items are less luck-based.** A Search finds a Minor Treasure on a 6 (playtest v1.1; a failed Search's +1 bonus counts). The Armory always holds one, and you can carry 2 instead of 1. Two new treasures fit the bigger castle:

| Treasure | Effect |
| --- | --- |
| Smoke Vial | In an encounter, escape to an adjacent room with no damage and no Noise |
| Spirit Bell | Push the Wandering Spirit up to 2 rooms away from you |

Three existing treasures (Ward Charm, Old Shield, Emergency Ration) stay as they are. The Secret Passage Map was removed in the playtest rules.

## The Cursed Knight and the Wandering Spirit

The Knight is a state machine with four states and a short memory of where it last heard you. It never cheats: it knows only what its senses tell it, and it never sees your room unless it is hunting or you share a room.

| State | Enters when | What it does |
| --- | --- | --- |
| Patrol | Quiet: no recent noise in memory | Walks a guard loop that passes all three Seals, rebuilt each run for the random map |
| Investigate | It hears a noise (Noise 0–2, token on the map) | Takes the shortest route to the last noise it heard |
| Hunt | Noise at the hunt threshold (it hears you), or you are within its sight range (it sees you) | Knows your room and takes the shortest route to you. Charging at loud Noise uses the "steps when hunting" value; stalking by sight is 1 room |
| Search | It reaches a noise and you are not there, it loses you during a hunt, or you out-hide it in an encounter | Checks the rooms next to that spot for 1–3 turns (by difficulty), then goes back to Patrol |

Search is the new state. In the paper rules the Knight gave up the moment it reached an empty noise room. Now it looks around like a real guard would, which makes it more believable and gives you a reason to leave the area quickly.

The Knight now guards restored Seals more closely. Each restored Seal is added to its patrol loop twice, so the castle feels more dangerous as you get closer to winning.

**The Wandering Spirit** is a second, harmless NPC. It drifts 1 room at random each turn and never chases you. If it ends a turn in your room, it shrieks: Noise +1 and the Noise token moves to your room. A Spirit Bell pushes it away, or you can steer it toward the Knight's side of the castle. It adds a risk you can see coming and plan around.

## Difficulty levels

Difficulty changes only the Knight's senses and reactions, never the rules you play by, so it stays fair and believable on every level. The bigger 5×5 map is why the Knight moves more often than the paper version's 5–6.

| Setting | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Knight moves on a D6 roll of | 4–6 | every turn, no die (playtest v1.1) | 2–6 |
| Remembers a noise for | 1 turn | 2 turns | 3 turns |
| Starts hunting at Noise | 4 | 3 | 3 |
| Steps per move when hunting | 1 | 2 (playtest v1.1; was 1) | 2 |
| Search state lasts | 1 turn | 2 turns | 3 turns |
| Sees you down a straight corridor of open doorways (sight, rooms) | 0 (same room only) | 1 | 2 |
| Encounter HIDE is safe on | 4–6 | 4–6 | 5–6 (it checks hiding spots) |
| Target player win rate | 65–75% | 45–55% | 25–35% |

The win-rate targets are starting points. Step 4's bot simulation checks them and we tune the numbers until each level lands in its range.

## Replayability: heroes and unlocks

Every run has a new castle, and wins unlock new heroes and the next difficulty. Progress is saved on the player's computer.

| Hero | Item (single use) | How to unlock |
| --- | --- | --- |
| Ranger | Enchanted Lantern: the Knight skips its next turn | Start |
| Alchemist | Healing Potion: restore 1 Health | Start |
| Mage | Silence Scroll: Noise −2 | Win 1 game |
| Knight | Rune Key: once per run, restore a Seal with 1 Shard instead of 2 | Win on Normal |
| Thief (new) | Smoke Vial: escape an encounter with no damage and no Noise | Win with 3 different heroes |
| Priest (new) | Blessing: the Spirit cannot shriek at you for 5 turns | Win on Hard |

Hard unlocks after your first Normal win. The end screen shows your turns, damage taken and how often the Knight found you, so players have a score to beat.

## How we show the AI works

The professor's three questions each get their own evidence.

| Question | Evidence | How we get it |
| --- | --- | --- |
| How does the AI behave? | An on-screen debug view (press F1) showing the Knight's state, its memory of your last noise and its planned route | Built into the game |
| Does it suit the difficulty? | Win rate, average game length and encounters per game at each level | A bot plays 1,000 games per hero per level, the same method as the paper rulebook's 20,000-game test |
| Is it believable? | Playtester ratings and comments | 5 or more people play 2 games each, then answer a short survey |

The survey asks players to rate from 1 to 5: "The Knight acted like a real guard", "I could predict where it would go", "When it caught me, it felt fair" and "I wanted to play again". It also asks one open question: "Describe a moment the Knight surprised you." A believability score of 4 or more out of 5 is the target. Each game also writes a log of every Knight decision and its reason, which the report can quote.

## Tech and timeline

The game is built in Godot 4 with GDScript, which reads like Python, and exported as a Windows .exe of about 70–100 MB. Its visual editor lets you tweak screens and art yourself. Art starts as simple flat shapes and icons in a dark-fantasy palette, so the final look can be chosen later without changing any code.

1. **7 Nov:** agree on this design doc, then build the castle generator, the turn loop and the cards.
2. **8 Nov:** build the Knight and Spirit AI, the debug view, the difficulty levels and the unlocks. Run the bot simulation and tune the numbers.
3. **8–9 Nov:** package the .exe, run the playtests and the survey, and write up the AI results for the report.

Open question: the deadline is assumed to be 9 November 2026. If it is a different date, the timeline moves.

## Tuning changes (build v1.0)

The bot simulation (1,000 games per hero per difficulty; the full method and results are in `docs/BALANCE.md`) showed that the first numbers made the game a pure race against the clock. Win rates were only 10–25% on every level, and Easy, Normal and Hard played almost the same, because the Knight was rarely the reason anyone lost. The changes below fix that while keeping the design's rules:

| Change | Why |
| --- | --- |
| Turn limit 30 → **36** | A 5×5 castle, 6 Shards and 3 Activations need about 30 turns of good play. With 30, most losses were time-outs |
| Deck: Explore 5 → 2, Search 4 → 6, Activate 3 → 4 | Sneak already gives a free silent move, so extra Explores only caused waiting turns |
| New Knight sense: **sight** (0 / 1 / 2 doorways) | The main lever that separates the difficulties. It also makes the guard more believable: it notices you in the next room on its own, without waiting for noise |
| Normal moves on 2–6 (was 3–6) | Puts Normal in its 45–55% band once the race was fixed |
| Hunt-by-sight moves 1 room; only a Noise charge uses Hard's 2 steps | With sight 2 *and* 2 steps, Hard dropped to about 8% |
| Encounters happen only after the Knight's move, and a successful HIDE leaves the Knight in your room (paper rules) | Keeps the paper version's tension: after hiding you must slip away on your own turn |
| Potion, Ward Charm and Ration work inside an encounter, before RUN or HIDE (paper rules) | As in the paper rulebook |

The bot hides in encounters. As in the paper playtests, hiding wins more often than running.

