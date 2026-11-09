extends RefCounted
## All tunable rules and content in one place. The simulation and the UI both read from here.

const GRID := 5
const MAX_HEALTH := 3
const TURN_LIMIT := 36  # Normal and Hard; each difficulty sets its own "turns" below
const MAX_NOISE := 5
const MAX_TREASURES := 2
const SHARDS_PER_SEAL := 2
const EXTRA_DOOR_CHANCE := 0.30
const SEAL_MIN_DISTANCE := 3
const SEAL_NAMES := ["I", "II", "III"]  # player-facing Seal names (index 0-2 stays the id)

## Knight senses per difficulty (the Knight never knows more than this).
## sight = how many doorways away it can see you. hunt_steps applies when it charges at loud Noise.
## fixed_move: no movement die; it moves every turn (move_min is then unused). All three
## difficulties walk like Normal; Easy and Hard differ only in turns, hunt_at and checks_hiding.
const DIFFICULTY := {
	"easy":   {"name": "Easy",   "turns": 42, "move_min": 2, "fixed_move": true, "memory": 2, "hunt_at": 4, "hunt_steps": 2, "search_turns": 2, "sight": 1, "checks_hiding": false},
	"normal": {"name": "Normal", "turns": 36, "move_min": 2, "fixed_move": true, "memory": 2, "hunt_at": 3, "hunt_steps": 2, "search_turns": 2, "sight": 1, "checks_hiding": false},
	"hard":   {"name": "Hard",   "turns": 36, "move_min": 2, "fixed_move": true, "memory": 2, "hunt_at": 2, "hunt_steps": 2, "search_turns": 2, "sight": 1, "checks_hiding": true},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]

## 16 cards. Fewer Explores than the paper deck: Sneak already moves 1 silently, so the slots went to Search and Activate.
const DECK := {"explore": 2, "dash": 2, "search": 6, "activate": 4, "hide": 2}
const CARDS := {
	"explore":  {"name": "Explore",  "text": "Move up to 2 rooms. Silent."},
	"dash":     {"name": "Dash",     "text": "Move up to 3 rooms. Noise +1 (token at the end room)."},
	"search":   {"name": "Search",   "text": "Roll D6: 1 fail (+1 Noise, next Search +1) | 2-5 one Shard | 6 one Shard + a Treasure."},
	"activate": {"name": "Activate", "text": "On an unrestored Seal: spend 2 Shards to restore it. Always succeeds."},
	"hide":     {"name": "Hide",     "text": "Stay. Noise -2 (never below 0)."},
}

const TREASURES := ["ward_charm", "old_shield", "ration", "smoke_vial"]
const TREASURE_INFO := {
	"ward_charm":  {"name": "Ward Charm",         "text": "Noise -1."},
	"old_shield":  {"name": "Old Shield",         "text": "Blocks 1 damage automatically."},
	"ration":      {"name": "Emergency Ration",   "text": "Heal 1 (only at 1 Health)."},
	"smoke_vial":  {"name": "Smoke Vial",         "text": "Encounter: escape with no damage and no noise."},
}

const HEROES := {
	"ranger":    {"name": "Ranger",    "item": "lantern",   "item_name": "Lantern",        "text": "The Knight skips its next turn. In an encounter: also escape 1 room silently.", "unlock": "Available from the start"},
	"alchemist": {"name": "Alchemist", "item": "potion",    "item_name": "Healing Potion", "text": "Heal 1.", "unlock": "Available from the start"},
	"mage":      {"name": "Mage",      "item": "silence",   "item_name": "Silence Scroll", "text": "Noise -2. In an encounter: also escape 1 room.", "unlock": "Win once"},
	"knight":    {"name": "Knight",    "item": "rune_key",  "item_name": "Rune Key",       "text": "Once per run: restore a Seal with 1 Shard instead of 2.", "unlock": "Win on Normal"},
	"thief":     {"name": "Thief",     "item": "smoke",     "item_name": "Smoke Vial",     "text": "Encounter: escape with no damage and no noise.", "unlock": "Win with 3 different heroes"},
}
## Hero ids are stable strings ("priest" was removed; old saves may still list it in heroes_won).
const HERO_ORDER := ["ranger", "alchemist", "mage", "knight", "thief"]

const SPECIALS := {
	"chapel":     {"name": "Chapel",          "text": "Heal 1. Once per run."},
	"bell_tower": {"name": "Bell Tower",      "text": "Ring: the Noise token moves here. Once per run."},
	"armory":     {"name": "Armory",          "text": "Take a Minor Treasure. Once per run."},
	"passage":    {"name": "Secret Passage",  "text": "Slip to the paired corner. No noise. The Knight does not know it."},
}
