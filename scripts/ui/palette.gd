extends RefCounted
## The whole storybook look lives here (colours from "Game Presentation - Final"). Swap these
## values to reskin the game without touching any logic.

# Night castle (backgrounds)
const NIGHT := Color("221a42")
const NIGHT_2 := Color("2e2457")
const NIGHT_3 := Color("3b2c6b")
const STARLIGHT := Color("f6e3a6")      # cream text and sparkles on night backgrounds
const MOON_TEXT := Color("c9bedf")      # secondary text on night backgrounds

# Stone rooms
const STONE := Color("5a5470")
const STONE_DARK := Color("3a3a44")
const STONE_LIGHT := Color("6e6886")
const FLOOR := Color("4a4462")
const FLOOR_LINE := Color("403a56")
const DOORWAY := Color("8a7a66")
const INK := Color("2a2238")            # thick storybook outlines and body text on parchment

# Parchment UI
const PARCHMENT := Color("f3e6c8")
const PARCHMENT_DARK := Color("e8d6ac")
const PARCHMENT_EDGE := Color("d9b47a")
const TEXT := Color("2a2238")           # on parchment, 12:1
const TEXT_DIM := Color("5a4a3a")       # on parchment, 6.8:1
const GOLD := Color("c99a3e")
const GOLD_DARK := Color("8a5a12")      # gold text on parchment, 4.8:1
const AMBER := Color("f2b544")          # lantern light

# Meaning colours. Every one is always paired with an icon or a word.
const HEALTH := Color("c0392b")
const HEALTH_TEXT := Color("a3302a")
const NOISE := Color("e8743b")
const NOISE_TEXT := Color("9a4518")
const SHARD := Color("a64be0")
const CRYSTAL := Color("a64be0")
const CRYSTAL_LIGHT := Color("c77dff")
const GOOD := Color("3f7a3a")
const BAD := Color("a3302a")
const SIGHT := Color("e8743b")

# Card categories: [frame colour, text colour on parchment]
const CATEGORY := {
	"movement": {"name": "Movement", "color": Color("1f6f78"), "text": Color("1f6f78")},
	"gathering": {"name": "Gathering", "color": Color("d98a35"), "text": Color("8a5a12")},
	"objective": {"name": "Objective", "color": Color("6b3fa0"), "text": Color("6b3fa0")},
	"stealth": {"name": "Stealth", "color": Color("4e7a3a"), "text": Color("3f6630")},
}
const CARD_CATEGORY := {"explore": "movement", "dash": "movement", "search": "gathering", "activate": "objective", "hide": "stealth"}

# The Cursed Knight
const KNIGHT_ARMOR := Color("3b3440")
const KNIGHT_TRIM := Color("f2d33a")
const KNIGHT_VISOR := Color("f08a1c")
const KNIGHT_CAPE := Color("5e2f4f")
const PLUM := Color("5e2f4f")           # encounter HIDE frame (never used by the Hide card)

const STATE_COLORS := {
	"PATROL": Color("8a8f9e"),
	"INVESTIGATE": Color("e0b040"),
	"HUNT": Color("e5383b"),
	"SEARCH": Color("c77dff"),
}
const STATE_WORD := {"PATROL": "Patrol", "INVESTIGATE": "Investigate", "HUNT": "Hunt", "SEARCH": "Search"}

# Hero card frames: [border, fill]
const HERO_FRAME := {
	"ranger": [Color("4e7d57"), Color("afd39b")],
	"alchemist": [Color("e2a64e"), Color("f7db92")],
	"mage": [Color("8b79d1"), Color("ecebfb")],
	"knight": [Color("3f689c"), Color("afd7ec")],
	"thief": [Color("b9505f"), Color("fabfc6")],
}
const HERO_BEST_FOR := {
	"ranger": "Getting out of tight spots.",
	"alchemist": "Surviving a mistake.",
	"mage": "Recovering after a loud turn.",
	"knight": "Restoring Seals faster.",
	"thief": "Escaping encounters cleanly.",
}

const SPECIAL_COLORS := {
	"chapel": Color("f6e3a6"),
	"bell_tower": Color("f2b544"),
	"armory": Color("c9ced6"),
	"passage": Color("3fc1b0"),
}

# Seals: one shrine art, told apart by shape and letter (not by colour alone).
const SEAL_SHAPES := ["triangle", "diamond", "circle"]

# Art file names in res://art/ (see scripts/tools/import_art.gd). A missing file falls back to
# shapes drawn in code.
const SHRINE_ART := "seal_shrine"
const KNIGHT_ART := "knight"
const PARCHMENT_ART := "parchment"
const MENU_ART := "menu_bg"
const TITLE_ART := "title_bg"
const CARD_ART := {"explore": "cardart_explore", "dash": "cardart_dash", "search": "cardart_search", "activate": "cardart_activate", "hide": "cardart_hide"}
const HERO_ART := {"ranger": "hero_ranger", "alchemist": "hero_alchemist", "mage": "hero_mage", "knight": "hero_knight", "thief": "hero_thief"}
const ITEM_ART := {
	"lantern": "item_lantern", "potion": "item_potion", "silence": "item_scroll", "rune_key": "item_rune_key",
	"smoke": "item_smoke", "smoke_vial": "item_smoke", "ward_charm": "item_ward_charm",
}

const ROOM_NAMES := ["Great Hall", "Crypt", "Barracks", "Cellar", "Gallery", "Solar", "Larder",
	"Guardroom", "Courtyard", "Throne Room", "Dungeon", "Forge", "Pantry", "Kennels", "Well Room",
	"Trophy Hall", "Scriptorium", "Ossuary", "Wine Vault", "Kitchens", "Mews", "Map Room",
	"Garderobe", "Music Room", "Lady's Bower", "Watch Post", "Undercroft", "Gatehouse"]
