extends RefCounted
## The whole visual style lives here. Swap these values (or point ICON_TEXTURES at art files)
## to reskin the game without touching any logic.

const BG := Color("0e0c12")
const PANEL := Color("1b1720")
const PANEL_LIGHT := Color("262030")
const BORDER := Color("4a3b52")
const TEXT := Color("efe6d6")
const TEXT_DIM := Color("a89cab")
const GOLD := Color("d9a441")
const BLOOD := Color("b3262e")
const EMBER := Color("e8743b")
const SPIRIT := Color("9fd8e8")
const ROOM := Color("2a2430")
const ROOM_EDGE := Color("5a4a5e")
const ROOM_SEARCHED := Color("221d27")
const ROOM_CORRUPT := Color("140d18")
const DOOR := Color("3a3140")
const TARGET := Color("d9a441")
const SIGHT := Color(0.70, 0.12, 0.15, 0.16)
const HEAL := Color("6fcf7a")

const SEAL_COLORS := [Color("d94a3d"), Color("3f8de0"), Color("3fbf6a")]

const STATE_COLORS := {
	"PATROL": Color("8a8f9e"),
	"INVESTIGATE": Color("e0b040"),
	"HUNT": Color("e5383b"),
	"SEARCH": Color("c77dff"),
}
const STATE_ICON := {"PATROL": "~", "INVESTIGATE": "?", "HUNT": "!", "SEARCH": "?!"}

const SPECIAL_COLORS := {
	"chapel": Color("f2e4b0"),
	"library": Color("b08a5a"),
	"bell_tower": Color("d9a441"),
	"armory": Color("b9c2cc"),
	"passage": Color("7f6aa8"),
}

## Optional art: put a texture path here (e.g. "res://art/chapel.png") to replace a vector icon.
const ICON_TEXTURES := {}

const ROOM_NAMES := ["Great Hall", "Crypt", "Barracks", "Cellar", "Gallery", "Solar", "Larder",
	"Guardroom", "Courtyard", "Throne Room", "Dungeon", "Forge", "Pantry", "Kennels", "Well Room",
	"Trophy Hall", "Scriptorium", "Ossuary", "Wine Vault", "Kitchens", "Mews", "Map Room",
	"Garderobe", "Torture Hall", "Lady's Bower", "Watch Post", "Undercroft", "Gatehouse"]
