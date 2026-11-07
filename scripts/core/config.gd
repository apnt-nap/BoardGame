extends RefCounted
## All tunable rules and content in one place. The simulation and the UI both read from here.

const GRID := 5
const MAX_HEALTH := 3
const TURN_LIMIT := 36  # tuned with the bot simulation (see docs/BALANCE.md)
const MAX_NOISE := 5
const MAX_TREASURES := 2
const SHARDS_PER_SEAL := 2
const START_FOCUS := 1
const EXTRA_DOOR_CHANCE := 0.30
const SEAL_MIN_DISTANCE := 3
const SPIRIT_BLESS_TURNS := 5

## Knight senses per difficulty (the Knight never knows more than this).
## sight = how many doorways away it can see you. hunt_steps applies when it charges at loud Noise.
const DIFFICULTY := {
	"easy":   {"name": "Easy",   "move_min": 4, "memory": 1, "hunt_at": 4, "hunt_steps": 1, "search_turns": 1, "sight": 0, "checks_hiding": false},
	"normal": {"name": "Normal", "move_min": 2, "memory": 2, "hunt_at": 3, "hunt_steps": 1, "search_turns": 2, "sight": 1, "checks_hiding": false},
	"hard":   {"name": "Hard",   "move_min": 2, "memory": 3, "hunt_at": 3, "hunt_steps": 2, "search_turns": 3, "sight": 2, "checks_hiding": true},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]

## 16 cards. Fewer Explores than the paper deck: Sneak already moves 1 silently, so the slots went to Search and Activate.
const DECK := {"explore": 2, "dash": 2, "search": 6, "activate": 4, "hide": 2}
const CARDS := {
	"explore":  {"name": "Explore",  "text": "Move 1 room. Silent."},
	"dash":     {"name": "Dash",     "text": "Move up to 2 rooms. Noise +1 (token at the end room)."},
	"search":   {"name": "Search",   "text": "Roll D6: 1 fail (+1 Noise) | 2-3 one Shard | 4-5 two Shards | 5-6 Treasure too."},
	"activate": {"name": "Activate", "text": "On a Seal with 2+ Shards. Roll D6: 1-2 fail (+1 Noise) | 3-5 restored | 6 restored, Noise -1."},
	"hide":     {"name": "Hide",     "text": "Noise -1."},
}

const TREASURES := ["ward_charm", "old_shield", "ration", "passage_map", "smoke_vial", "spirit_bell"]
const TREASURE_INFO := {
	"ward_charm":  {"name": "Ward Charm",         "text": "Noise -1."},
	"old_shield":  {"name": "Old Shield",         "text": "Blocks 1 damage automatically."},
	"ration":      {"name": "Emergency Ration",   "text": "Heal 1 (only at 1 Health)."},
	"passage_map": {"name": "Secret Passage Map", "text": "Your next Explore may move 2 rooms."},
	"smoke_vial":  {"name": "Smoke Vial",         "text": "Encounter: escape with no damage and no noise."},
	"spirit_bell": {"name": "Spirit Bell",        "text": "Push the Wandering Spirit 2 rooms away."},
}

const HEROES := {
	"ranger":    {"name": "Ranger",    "item": "lantern",   "item_name": "Lantern",        "text": "The Knight skips its next turn. In an encounter: also escape 1 room silently.", "unlock": "Available from the start"},
	"alchemist": {"name": "Alchemist", "item": "potion",    "item_name": "Healing Potion", "text": "Heal 1.", "unlock": "Available from the start"},
	"mage":      {"name": "Mage",      "item": "silence",   "item_name": "Silence Scroll", "text": "Noise -2. In an encounter: also escape 1 room.", "unlock": "Win once"},
	"knight":    {"name": "Knight",    "item": "rune_key",  "item_name": "Rune Key",       "text": "Passive: the first Activate roll of 2 counts as 3.", "unlock": "Win on Normal"},
	"thief":     {"name": "Thief",     "item": "smoke",     "item_name": "Smoke Vial",     "text": "Encounter: escape with no damage and no noise.", "unlock": "Win with 3 different heroes"},
	"priest":    {"name": "Priest",    "item": "blessing",  "item_name": "Blessing",       "text": "The Spirit cannot shriek at you for 5 turns.", "unlock": "Win on Hard"},
}
const HERO_ORDER := ["ranger", "alchemist", "mage", "knight", "thief", "priest"]

const SPECIALS := {
	"chapel":     {"name": "Chapel",          "text": "Heal 1. Once per run."},
	"library":    {"name": "Library",         "text": "Read the Knight's next move. Once per visit."},
	"bell_tower": {"name": "Bell Tower",      "text": "Ring: the Noise token moves here. Once per run."},
	"armory":     {"name": "Armory",          "text": "Take a Minor Treasure. Once per run."},
	"passage":    {"name": "Secret Passage",  "text": "Slip to the paired corner. No noise. The Knight does not know it."},
}
