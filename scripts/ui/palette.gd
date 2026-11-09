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
const DOORWAY := Color("dcd0c3")       # matches the doorway gaps in the room tiles
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
const SHRINE_ARTS := ["seal_shrine_a", "seal_shrine_b", "seal_shrine_c"]
const SHRINE_RESTORED := ["seal_shrine_restored", "seal_shrine_b_restored", "seal_shrine_c_restored"]  # B and C: recoloured from the unrestored art
const ROOM_TILES := ["room_floor_plain", "room_floor_desk", "room_floor_barrels"]  # walls with a doorway gap on every side
## Asia's full-board painting, cut into cells that tile edge to edge (scripts/tools/import_art.gd).
## These have their names painted on, so the board draws no name or prop over them.
const BOARD_SEAL_RING := ["tile_seal_1_ring", "tile_seal_2_ring", "tile_seal_3_ring"]          # before restoring
const BOARD_SEAL_CRYSTAL := ["tile_seal_1_crystal", "tile_seal_2_crystal", "tile_seal_3_crystal"]  # after
const BOARD_SPECIAL := {"chapel": "tile_chapel", "bell_tower": "tile_bell_tower", "armory": "tile_armory"}
const BOARD_PASSAGE := ["tile_passage_a", "tile_passage_b"]
const BOARD_ENTRY := "tile_entry"
## Furnished ordinary cells and their empty name plaque [x, y, w, h] as a share of the tile ([] = none).
const BOARD_ROOMS := {
	"tile_room_01": [0.291, 0.707, 0.439, 0.162], "tile_room_02": [0.258, 0.685, 0.453, 0.185],
	"tile_room_03": [0.315, 0.686, 0.44, 0.179], "tile_room_04": [0.275, 0.681, 0.475, 0.179],
	"tile_room_05": [0.299, 0.686, 0.449, 0.175], "tile_room_06": [], "tile_room_07": [0.407, 0.735, 0.415, 0.151],
	"tile_room_08": [], "tile_room_09": [0.336, 0.713, 0.436, 0.157], "tile_room_10": [0.25, 0.668, 0.496, 0.193],
	"tile_room_11": [0.403, 0.713, 0.419, 0.157], "tile_room_12": [], "tile_room_13": [],
	"tile_room_14": [0.275, 0.689, 0.47, 0.187], "tile_room_15": [], "tile_room_16": [],
}
const BOARD_WALL_HALF := 0.088   # half the wall thickness as a share of the cell (20 px of ~232)
const BOARD_WALL_LEN := 0.30     # wall patch length as a share of the cell side
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
