# Curse of Blackthorn Keep: Digital Redesign

Nov 7, 2026 · @Asia

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

Each run places 5 special rooms at random:

| Room | What you can do there | Limit |
| --- | --- | --- |
| Chapel | Heal 1 Health | Once per run |
| Library | See where the Knight will move next turn | Once per visit |
| Bell Tower | Ring the bell: the Noise token goes to the Bell Tower, not to you, luring the Knight away | Once per run |
| Secret Passage | Step straight to the paired passage room in another corner, with no Noise | Any time |
| Armory | Take one guaranteed Minor Treasure | Once per run |

**The keep shifts.** Each time you restore a Seal, the curse fights back: one doorway slams shut and another opens somewhere else. A shift never cuts you off from an unrestored Seal. The change shows on screen, so you replan with a castle that is now partly new.

**Corrupted rooms.** When the second Seal is restored, the curse corrupts 2 special rooms chosen at random. A corrupted room turns dark on the map and its ability no longer works for the rest of the run. Players who saved the Chapel or the Bell Tower for later may lose them, so using rooms early becomes a real choice.

The turn limit rises from 24 to about 30 to fit the bigger map. The bot simulation in step 4 sets the exact number.

## Your turn, cards and items

The core stays the same: draw 2 Action Cards, play 1, discard 1, then the Knight acts. Three fixes stop a bad roll or a bad hand from wasting a turn.

1. **Any card can be played as a Sneak.** Instead of its printed action, play any card face down to move 1 room with no Noise, or to lower Noise by 1. A hand of two unusable Activates is never a dead turn again.
2. **Misses build up.** A failed Search gives +1 to your next Search roll, and a failed Activate gives +1 to your next Activate on that Seal. A run of bad rolls gets easier, not worse.
3. **One Focus per Seal.** You start with 1 Focus and gain 1 each time you restore a Seal. Spend it to discard your hand and draw 2 new cards.

**Items are less luck-based.** A Search finds a Minor Treasure on a 5 or 6, not only a 6. The Armory always holds one, and you can carry 2 instead of 1. Two new treasures fit the bigger castle:

| Treasure | Effect |
| --- | --- |
| Smoke Vial | In an encounter, escape to an adjacent room with no damage and no Noise |
| Spirit Bell | Send the Wandering Spirit 2 rooms in the direction you choose |

The four existing treasures (Ward Charm, Old Shield, Emergency Ration, Secret Passage Map) stay as they are.

## The Cursed Knight and the Wandering Spirit

The Knight is a state machine with four states and a short memory of where it last heard you. It never cheats: it knows only what its senses tell it, and it never sees your room unless it is hunting or you share a room.

| State | Enters when | What it does |
| --- | --- | --- |
| Patrol | Quiet: no recent noise in memory | Walks a guard loop that passes all three Seals, rebuilt each run for the random map |
| Investigate | It hears a noise (Noise 0–2, token on the map) | Takes the shortest route to the last noise it heard |
| Hunt | Noise 3 or more | Knows your room and takes the shortest route to you |
| Search | It reaches a noise and you are not there, or it loses you during a hunt | Checks the rooms next to that spot for 2 turns, then goes back to Patrol |

Search is the new state. In the paper rules the Knight gave up the moment it reached an empty noise room. Now it looks around like a real guard would, which makes it more believable and gives you a reason to leave the area quickly.

The Knight now guards restored Seals more closely. Each restored Seal is added to its patrol loop twice, so the castle feels more dangerous as you get closer to winning.

**The Wandering Spirit** is a second, harmless NPC. It drifts 1 room at random each turn and never chases you. If it ends a turn in your room, it shrieks: Noise +1 and the Noise token moves to your room. A Spirit Bell pushes it away, or you can steer it toward the Knight's side of the castle. It adds a risk you can see coming and plan around.

## Difficulty levels

Difficulty changes only the Knight's senses and reactions, never the rules you play by, so it stays fair and believable on every level. The bigger 5×5 map is why the Knight moves more often than the paper version's 5–6.

| Setting | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Knight moves on a D6 roll of | 4–6 | 3–6 | 2–6 |
| Remembers a noise for | 1 turn | 2 turns | 3 turns |
| Starts hunting at Noise | 4 | 3 | 3 |
| Steps per move when hunting | 1 | 1 | 2 |
| Search state lasts | 1 turn | 2 turns | 3 turns, and checks hiding spots |
| Target player win rate | 65–75% | 45–55% | 25–35% |

The win-rate targets are starting points. Step 4's bot simulation checks them and we tune the numbers until each level lands in its range.

## Replayability: heroes and unlocks

Every run has a new castle, and wins unlock new heroes and the next difficulty. Progress is saved on the player's computer.

| Hero | Item (single use) | How to unlock |
| --- | --- | --- |
| Ranger | Enchanted Lantern: the Knight skips its next turn | Start |
| Alchemist | Healing Potion: restore 1 Health | Start |
| Mage | Silence Scroll: Noise −2 | Win 1 game |
| Knight | Rune Key: an Activate roll of 2 counts as 3 | Win on Normal |
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
