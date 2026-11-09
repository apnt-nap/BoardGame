extends Control
## Screens, HUD and event playback in the storybook style. All rules live in scripts/core; this
## file only shows them. Flow: Title > Hero > Difficulty > Game (Pause, Encounter, End), plus
## How to play and Settings from the title or the pause menu.

const Config = preload("res://scripts/core/config.gd")
const Game = preload("res://scripts/core/game.gd")
const P = preload("res://scripts/ui/palette.gd")
const Board = preload("res://scripts/ui/board_view.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const Profile = preload("res://scripts/ui/profile.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const Art = preload("res://scripts/ui/art.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const DiceView = preload("res://scripts/ui/dice_view.gd")

const LOG_PATH := "user://knight_log.txt"

## Card copy shown to the player (rules: config.gd and game.gd).
const CARD_COPY := {
	"explore": {"rule": "Move silently up to 2 connected rooms.", "req": ""},
	"dash": {"rule": "Move up to 3 connected rooms. Noise +1, and the marker lands where you stop.", "req": ""},
	"search": {"rule": "Look for a Rune Shard. Die 1 fails, 2-5 gives 1 Shard, 6 gives 1 Shard and a treasure.", "req": "Not on a Seal. Each room once."},
	"activate": {"rule": "Spend 2 Shards to restore this Seal. It always works.", "req": "Stand on an unrestored Seal."},
	"hide": {"rule": "Stay and lower Noise by 2 (never below 0).", "req": ""},
}

const RULES_PAGES := [
	["The goal", "seal_shrine", "Restore all three [b]Seals[/b] before midnight (turn 36 ends). Each Seal needs [b]2 Rune Shards[/b]. You lose if your Health reaches 0.\n\nThe Cursed Knight walks the Keep. It never knows where you are unless it [b]hears[/b] you or [b]sees[/b] you."],
	["Your turn", "cardart_explore", "You hold [b]2 cards[/b]. Play one; the other is discarded.\n\n[b]Explore[/b] and [b]Dash[/b] move you. [b]Search[/b] finds Shards. [b]Activate[/b] restores a Seal. [b]Hide[/b] (the card) lowers Noise.\n\n[b]Sneak[/b] lets any card move you 1 room silently, or keep still and lower Noise by 1. Once per run you may [b]redraw[/b] your hand for free."],
	["Noise and the Knight", "knight", "Dash and failed Searches make [b]Noise[/b] and drop an orange [b]marker[/b]. The Knight walks to the marker.\n\nAt [b]Noise 3[/b] (4 on Easy) it hears you and knows your room. It also sees you down a straight corridor of open doorways: [b]hatched rooms[/b] are in its sight.\n\nAfter you act, the Knight moves. Its arrow appears only when you can know where it is going."],
	["Encounters", "cardart_hide", "If the Knight ends its move in your room, it finds you.\n\n[b]RUN[/b]: flee 1 room, Noise +1. On a die roll of 1-2 you also lose 1 Health.\n[b]HIDE[/b]: on 4-6 (5-6 on Hard) you stay safe and it searches nearby. Otherwise you lose 1 Health and flee.\n\nYour hero item and the Smoke Vial can get you out cleanly."],
	["Seals and the Keep", "cardart_activate", "Stand on a Seal with 2 Shards and play [b]Activate[/b]. It always works.\n\nEach restored Seal shifts a doorway and sends a [b]signal[/b] that draws the Knight to that room, so leave quickly. The second Seal corrupts two special rooms.\n\n[b]Chapel[/b] heals once. [b]Bell Tower[/b] moves the marker to it. [b]Armory[/b] gives a treasure. [b]Secret Passages[/b] link two corners."],
	["Controls", "", "[b]Mouse[/b]: click a card, then a highlighted room or the card again to confirm. Right-click cancels.\n\n[b]1 / 2[/b] pick a card. [b]Space[/b] confirms. [b]Esc[/b] cancels, or opens the pause menu. [b]R[/b] redraws. [b]Tab[/b] steps through the rooms you can reach. [b]M[/b] mutes.\n\nSettings has reduced motion, faster animations, larger text and one-click play."],
]

var profile = Profile.new()
var settings = Settings.new()
var sfx
var game
var board
var sel_hero := "ranger"
var sel_diff := "normal"
var pending := {}          # card waiting for confirmation or a room: {i, mode}
var sneak_mode := ""       # Sneak picked first: "sneak_move" | "sneak_quiet", waiting for a card
var hover_target := -1
var reason_line := ""      # why the last clicked card can't be played
var banner_text := ""      # stays until your next action (e.g. after a successful HIDE)
var recent: Array = []     # last result lines for the side panel
var queue: Array = []
var busy := false
var knight_log: Array = []
var ui := {}
var screen := "title"
var rules_page := 0
var _prev_kstate := ""

var root_box: Control
var menu_root: Control     # title screen
var hero_root: Control
var diff_root: Control
var game_root: Control
var end_root: Control
var pause_root: Control
var settings_root: Control
var rules_root: Control
var overlay: Control


func _ready() -> void:
	profile.load_profile()
	settings.load_settings()
	sfx = Sfx.new()
	add_child(sfx)
	_apply_audio()
	_build_all()
	_show("title")


func _build_all() -> void:
	if root_box != null:
		root_box.queue_free()
	ui = {}
	theme = _make_theme()
	root_box = Control.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_box)
	var bg := ColorRect.new()
	bg.color = P.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(bg)
	_build_title()
	_build_heroes()
	_build_difficulty()
	_build_game()
	_build_end()
	_build_pause()
	_build_settings()
	_build_rules()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(overlay)


# ================================================================== theme / helpers

class ParchPanel extends PanelContainer:
	## Parchment panel: the painted sheet as fill, a gold frame and a soft shadow.
	var frame := Color("c99a3e")
	var frame_w := 3
	var tint := Color.WHITE
	var radius := 10
	var pad := 14
	var tex: Texture2D

	func _ready() -> void:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = pad
		sb.content_margin_right = pad
		sb.content_margin_top = pad * 0.75
		sb.content_margin_bottom = pad * 0.75
		add_theme_stylebox_override("panel", sb)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0.35)
		sh.set_corner_radius_all(radius)
		draw_style_box(sh, Rect2(r.position + Vector2(3, 5), r.size))
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("f3e6c8") * tint
		fill.set_corner_radius_all(radius)
		draw_style_box(fill, r)
		if tex != null:
			var inner := r.grow(-frame_w)
			var ts := tex.get_size()
			var sc := maxf(inner.size.x / ts.x, inner.size.y / ts.y)
			var src := inner.size / sc
			draw_texture_rect_region(tex, inner, Rect2((ts - src) * 0.5, src), tint)
		var fr := StyleBoxFlat.new()
		fr.bg_color = Color(0, 0, 0, 0)
		fr.border_color = frame
		fr.set_border_width_all(frame_w)
		fr.set_corner_radius_all(radius)
		draw_style_box(fr, r)
		var ink := StyleBoxFlat.new()
		ink.bg_color = Color(0, 0, 0, 0)
		ink.border_color = Color(0.16, 0.13, 0.22, 0.55)
		ink.set_border_width_all(1)
		ink.set_corner_radius_all(radius)
		draw_style_box(ink, r.grow(1))


class Pips extends Control:
	## Noise or Health pips, with a notch at the hearing level.
	var value := 0
	var max_value := 5
	var notch := -1            # pip index (1-based) where the Knight hears you
	var color := Color.ORANGE
	var ink := Color("2a2238")

	func _draw() -> void:
		var w := (size.x - (max_value - 1) * 5.0) / max_value
		for i in max_value:
			var r := Rect2(Vector2(i * (w + 5.0), size.y * 0.15), Vector2(w, size.y * 0.7))
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(4)
			sb.bg_color = color if i < value else Color(color, 0.15)
			sb.border_color = ink
			sb.set_border_width_all(2)
			draw_style_box(sb, r)
			if i == notch - 1:
				draw_line(Vector2(r.position.x - 3.5, 0), Vector2(r.position.x - 3.5, size.y), ink, 3.0)


func _fs(px: float) -> int:
	return int(round(px * settings.text_scale))


func _sb(fill: Color, border: Color, bw: int = 2, radius: int = 10, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.55
	sb.content_margin_bottom = pad * 0.55
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = Art.body_font()
	th.default_font_size = _fs(19)
	th.set_stylebox("normal", "Button", _sb(P.PARCHMENT_DARK, P.INK))
	th.set_stylebox("hover", "Button", _sb(P.PARCHMENT, P.GOLD_DARK, 3))
	th.set_stylebox("pressed", "Button", _sb(P.AMBER, P.INK, 3))
	th.set_stylebox("disabled", "Button", _sb(Color(P.PARCHMENT_DARK, 0.55), Color(P.INK, 0.35)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(k, "Button", P.INK)
	th.set_color("font_disabled_color", "Button", Color(P.INK, 0.5))
	th.set_font("font", "Button", Art.heading_font())
	th.set_font_size("font_size", "Button", _fs(17))
	th.set_color("font_color", "Label", P.TEXT)
	th.set_stylebox("panel", "PanelContainer", _sb(P.PARCHMENT, P.GOLD))
	th.set_color("default_color", "RichTextLabel", P.TEXT)
	th.set_font("normal_font", "RichTextLabel", Art.body_font())
	th.set_font("bold_font", "RichTextLabel", Art.body_bold_font())
	th.set_font_size("normal_font_size", "RichTextLabel", _fs(19))
	th.set_font_size("bold_font_size", "RichTextLabel", _fs(19))
	th.set_color("font_color", "CheckButton", P.INK)
	th.set_color("font_hover_color", "CheckButton", P.INK)
	th.set_color("font_pressed_color", "CheckButton", P.INK)
	th.set_color("font_hover_pressed_color", "CheckButton", P.INK)
	th.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	th.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	th.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	th.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	th.set_font("font", "CheckButton", Art.body_font())
	th.set_font_size("font_size", "CheckButton", _fs(19))
	th.set_font("font", "TooltipLabel", Art.body_font())
	th.set_font_size("font_size", "TooltipLabel", _fs(17))
	th.set_color("font_color", "TooltipLabel", P.INK)
	th.set_stylebox("panel", "TooltipPanel", _sb(P.PARCHMENT, P.INK, 2, 6, 10))
	return th


## kind: body | bold | head | title
func _label(text: String, px: float = 19, color: Color = P.TEXT, wrap: bool = false, kind: String = "body") -> Label:
	var l := Label.new()
	l.text = text
	var f: Font = {"body": Art.body_font(), "bold": Art.body_bold_font(), "head": Art.heading_font(), "title": Art.title_font()}[kind]
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", _fs(px))
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Title text on a night background: cream with an ink outline.
func _night_title(text: String, px: float, kind: String = "title") -> Label:
	var l := _label(text, px, P.STARLIGHT, false, kind)
	l.add_theme_color_override("font_outline_color", P.INK)
	l.add_theme_constant_override("outline_size", maxi(4, int(px * 0.14)))
	return l


func _rich(px: float = 19) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", _fs(px))
	r.add_theme_font_size_override("bold_font_size", _fs(px))
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


func _button(text: String, cb: Callable, min_w: int = 0, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, _fs(44))
	if primary:
		b.add_theme_stylebox_override("normal", _sb(P.AMBER, P.INK, 3))
		b.add_theme_stylebox_override("hover", _sb(P.AMBER.lightened(0.2), P.INK, 3))
		b.add_theme_stylebox_override("pressed", _sb(P.GOLD, P.INK, 3))
		b.add_theme_font_size_override("font_size", _fs(20))
	b.pressed.connect(func():
		sfx.play("click")
		cb.call())
	return b


func _art_rect(name: String, min_size: Vector2, mode: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = mode
	t.custom_minimum_size = min_size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _parch(child: Control, pad: int = 14, frame: Color = P.GOLD, frame_w: int = 3) -> ParchPanel:
	var p := ParchPanel.new()
	p.pad = pad
	p.frame = frame
	p.frame_w = frame_w
	p.tex = Art.tex(P.PARCHMENT_ART)
	p.add_child(child)
	return p


func _margin(child: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _backdrop(parent: Control, art: String, dim: float) -> void:
	var t := _art_rect(art, Vector2.ZERO, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	parent.add_child(_full(t))
	var c := ColorRect.new()
	c.color = Color(P.NIGHT, dim)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_full(c))


func _dim_layer(alpha: float = 0.6) -> Control:
	var root := Control.new()
	_full(root)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var c := ColorRect.new()
	c.color = Color(P.NIGHT, alpha)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_full(c))
	return root


func _show(s: String) -> void:
	screen = s
	menu_root.visible = s == "title"
	hero_root.visible = s == "heroes"
	diff_root.visible = s == "difficulty"
	game_root.visible = s == "game" or s == "end"
	end_root.visible = s == "end"
	pause_root.visible = false
	settings_root.visible = false
	rules_root.visible = false
	match s:
		"title":
			_refresh_title()
		"heroes":
			_refresh_heroes()
		"difficulty":
			_refresh_difficulty()


func _apply_audio() -> void:
	sfx.muted = settings.muted
	sfx.volume = settings.volume


# ================================================================== title

func _build_title() -> void:
	menu_root = _full(Control.new())
	root_box.add_child(menu_root)
	_backdrop(menu_root, P.MENU_ART, 0.15)
	var shade := ColorRect.new()
	shade.color = Color(P.NIGHT, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.0
	shade.offset_right = 640
	menu_root.add_child(shade)
	var col := _vbox(14)
	col.position = Vector2(80, 110)
	col.custom_minimum_size = Vector2(500, 0)
	menu_root.add_child(col)
	col.add_child(_night_title("Curse of", 40))
	col.add_child(_night_title("Blackthorn Keep", 58))
	col.add_child(_label("Restore the three Seals before midnight. The Cursed Knight is listening.", 21, P.MOON_TEXT, true, "body"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	col.add_child(gap)
	col.add_child(_button("Play", func(): _show("heroes"), 380, true))
	col.add_child(_button("How to play", func(): _open_rules(), 380))
	col.add_child(_button("Settings", func(): _open_settings(), 380))
	col.add_child(_button("Quit", func(): get_tree().quit(), 380))
	ui["intro"] = _label("New here? Read How to play first. It takes two minutes.", 19, P.AMBER, true, "bold")
	col.add_child(ui["intro"])
	ui["profile_label"] = _label("", 17, P.MOON_TEXT)
	col.add_child(ui["profile_label"])


func _refresh_title() -> void:
	ui["intro"].visible = profile.games == 0 and not settings.seen_intro
	var best := ""
	for d in profile.best_turns:
		best += "   Best on %s: %d turns" % [Config.DIFFICULTY[d]["name"], profile.best_turns[d]]
	ui["profile_label"].text = ("Runs %d   Wins %d%s" % [profile.games, profile.wins, best]) if profile.games > 0 else ""


# ================================================================== hero select

func _build_heroes() -> void:
	hero_root = _full(Control.new())
	root_box.add_child(hero_root)
	_backdrop(hero_root, P.TITLE_ART, 0.35)
	var col := _vbox(18)
	var m := _margin(col, 40)
	hero_root.add_child(_full(m))
	col.add_child(_night_title("Choose your hero", 40))
	var row := _hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	ui["hero_cards"] = {}
	var group := ButtonGroup.new()
	for h in Config.HERO_ORDER:
		var hid: String = h
		var frame: Array = P.HERO_FRAME[h]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(260, 330)
		b.add_theme_stylebox_override("normal", _sb(frame[1], frame[0], 4, 16))
		b.add_theme_stylebox_override("hover", _sb(frame[1].lightened(0.15), frame[0], 5, 16))
		b.add_theme_stylebox_override("pressed", _sb(frame[1].lightened(0.25), P.INK, 6, 16))
		b.add_theme_stylebox_override("hover_pressed", _sb(frame[1].lightened(0.25), P.INK, 6, 16))
		b.pressed.connect(func():
			sfx.play("click")
			sel_hero = hid
			_refresh_heroes())
		var v := _vbox(4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(_full(_margin(v, 12)))
		var art := _art_rect(P.HERO_ART[h], Vector2(0, 230))
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(art)
		var name_l := _label(Config.HEROES[h]["name"], 24, P.INK, false, "head")
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_l)
		var sub := _label("", 16, P.TEXT_DIM, true)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
		var lock := Icon.make("lock", P.GOLD, 40)
		lock.position = Vector2(12, 12)
		b.add_child(lock)
		for n in [v, art, name_l, sub]:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(b)
		ui["hero_cards"][h] = {"button": b, "art": art, "sub": sub, "lock": lock}

	var dv := _hbox(24)
	var detail := _parch(dv, 20)
	col.add_child(detail)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	ui["hero_big"] = _art_rect("", Vector2(150, 200))
	dv.add_child(ui["hero_big"])
	var dt := _vbox(6)
	dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_child(dt)
	ui["hero_name"] = _label("", 30, P.INK, false, "head")
	dt.add_child(ui["hero_name"])
	var item_row := _hbox(10)
	dt.add_child(item_row)
	ui["hero_item_art"] = _art_rect("", Vector2(56, 56))
	item_row.add_child(ui["hero_item_art"])
	ui["hero_item"] = _label("", 21, P.INK, true, "bold")
	ui["hero_item"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(ui["hero_item"])
	ui["hero_text"] = _label("", 20, P.TEXT, true)
	dt.add_child(ui["hero_text"])
	ui["hero_best"] = _label("", 19, P.TEXT_DIM, true)
	dt.add_child(ui["hero_best"])
	ui["hero_lock"] = _label("", 19, P.BAD, true, "bold")
	dt.add_child(ui["hero_lock"])

	var nav := _hbox(16)
	col.add_child(nav)
	nav.add_child(_button("Back", func(): _show("title"), 200))
	nav.add_child(_spacer())
	ui["hero_next"] = _button("Next: Difficulty", func(): _show("difficulty"), 300, true)
	nav.add_child(ui["hero_next"])


func _refresh_heroes() -> void:
	for h in Config.HERO_ORDER:
		var hc: Dictionary = ui["hero_cards"][h]
		var unlocked: bool = profile.hero_unlocked(h)
		hc["button"].button_pressed = sel_hero == h
		hc["art"].modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.42)
		hc["lock"].visible = not unlocked
		hc["sub"].text = Config.HEROES[h]["item_name"] if unlocked else "Locked: " + Config.HEROES[h]["unlock"].to_lower()
	var info: Dictionary = Config.HEROES[sel_hero]
	var ok: bool = profile.hero_unlocked(sel_hero)
	ui["hero_big"].texture = Art.tex(P.HERO_ART[sel_hero])
	ui["hero_big"].modulate = Color.WHITE if ok else Color(0.4, 0.4, 0.48)
	ui["hero_name"].text = info["name"]
	ui["hero_item_art"].texture = Art.tex(P.ITEM_ART.get(info["item"], ""))
	ui["hero_item"].text = "Starting item: %s (one use)" % info["item_name"]
	ui["hero_text"].text = info["text"]
	ui["hero_best"].text = "Best for: " + P.HERO_BEST_FOR.get(sel_hero, "")
	ui["hero_lock"].text = "" if ok else "Locked: %s to unlock the %s." % [info["unlock"].to_lower(), info["name"]]
	ui["hero_next"].disabled = not ok


# ================================================================== difficulty

func _build_difficulty() -> void:
	diff_root = _full(Control.new())
	root_box.add_child(diff_root)
	_backdrop(diff_root, P.TITLE_ART, 0.35)
	var col := _vbox(18)
	diff_root.add_child(_full(_margin(col, 40)))
	col.add_child(_night_title("Choose the difficulty", 40))
	col.add_child(_night_title("It only changes what the Knight senses. Your rules stay the same.", 21, "body"))
	var row := _hbox(22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	ui["diff_cards"] = {}
	var group := ButtonGroup.new()
	for d in Config.DIFFICULTY_ORDER:
		var did: String = d
		var info: Dictionary = Config.DIFFICULTY[d]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", _sb(P.PARCHMENT_DARK, P.GOLD, 3, 16))
		b.add_theme_stylebox_override("hover", _sb(P.PARCHMENT, P.GOLD_DARK, 4, 16))
		b.add_theme_stylebox_override("pressed", _sb(P.PARCHMENT, P.INK, 6, 16))
		b.add_theme_stylebox_override("hover_pressed", _sb(P.PARCHMENT, P.INK, 6, 16))
		b.add_theme_stylebox_override("disabled", _sb(Color(P.PARCHMENT_DARK, 0.6), Color(P.INK, 0.3), 3, 16))
		b.pressed.connect(func():
			sfx.play("click")
			sel_diff = did
			_refresh_difficulty())
		var v := _vbox(16)
		b.add_child(_full(_margin(v, 26)))
		v.add_child(_label(info["name"], 32, P.INK, false, "head"))
		var moves: String = "Every turn" if info.get("fixed_move", false) else "On a die roll of %d-6" % info["move_min"]
		var sees: String = "Same room only" if info["sight"] == 0 else "%d room%s in a straight line" % [info["sight"], "" if info["sight"] == 1 else "s"]
		var rows := [
			["Knight moves", moves],
			["Hears you at Noise", str(info["hunt_at"])],
			["Sees you", sees],
			["Charges when it hears you", "%d room%s" % [info["hunt_steps"], "" if info["hunt_steps"] == 1 else "s"]],
			["Remembers and searches", "%d turn%s" % [info["memory"], "" if info["memory"] == 1 else "s"]],
			["Encounter HIDE is safe on", "5-6" if info["checks_hiding"] else "4-6"],
		]
		for rw in rows:
			var line := _vbox(0)
			line.add_child(_label(rw[0], 18, P.TEXT_DIM))
			line.add_child(_label(rw[1], 25, P.INK, true, "bold"))
			v.add_child(line)
		var lock := _label("", 18, P.BAD, true, "bold")
		v.add_child(lock)
		for n in v.find_children("*", "Control", true, false):
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(b)
		ui["diff_cards"][d] = {"button": b, "lock": lock}
	ui["diff_best"] = _night_title("", 19, "body")
	col.add_child(ui["diff_best"])
	var nav := _hbox(16)
	col.add_child(nav)
	nav.add_child(_button("Back", func(): _show("heroes"), 200))
	nav.add_child(_spacer())
	ui["diff_start"] = _button("Enter the Keep", _start_game, 300, true)
	nav.add_child(ui["diff_start"])


func _refresh_difficulty() -> void:
	if not profile.difficulty_unlocked(sel_diff):
		sel_diff = "normal"
	for d in Config.DIFFICULTY_ORDER:
		var dc: Dictionary = ui["diff_cards"][d]
		var ok: bool = profile.difficulty_unlocked(d)
		dc["button"].disabled = not ok
		dc["button"].button_pressed = sel_diff == d
		dc["lock"].text = "" if ok else "Locked: win on Normal to unlock."
	var best := []
	for d in Config.DIFFICULTY_ORDER:
		if profile.best_turns.has(d):
			best.append("%s %d turns" % [Config.DIFFICULTY[d]["name"], profile.best_turns[d]])
	ui["diff_best"].text = ("Your best wins: " + ", ".join(PackedStringArray(best))) if not best.is_empty() else ""


# ================================================================== game screen

func _build_game() -> void:
	game_root = _full(Control.new())
	root_box.add_child(game_root)
	var col := _vbox(14)
	game_root.add_child(_full(_margin(col, 16)))

	# ---- top bar
	var bar := _hbox(18)
	var barp := _parch(bar, 16)
	col.add_child(barp)
	var hb := _hbox(4)
	bar.add_child(hb)
	ui["hearts"] = []
	for i in Config.MAX_HEALTH:
		var hi := Icon.make("heart", P.HEALTH, 26)
		hb.add_child(hi)
		ui["hearts"].append(hi)
	ui["health_l"] = _label("", 19, P.INK, false, "bold")
	hb.add_child(ui["health_l"])
	ui["health_box"] = hb
	bar.add_child(VSeparator.new())
	var nb := _hbox(8)
	bar.add_child(nb)
	nb.add_child(Icon.make("noise", P.NOISE_TEXT, 26))
	var pips := Pips.new()
	pips.custom_minimum_size = Vector2(130, 26)
	pips.color = P.NOISE
	pips.max_value = Config.MAX_NOISE
	nb.add_child(pips)
	ui["noise_pips"] = pips
	var nl := _vbox(0)
	nb.add_child(nl)
	ui["noise_l"] = _label("", 18, P.INK, false, "bold")
	nl.add_child(ui["noise_l"])
	ui["noise_warn"] = _label("", 15, P.NOISE_TEXT, false, "bold")
	nl.add_child(ui["noise_warn"])
	ui["noise_box"] = nb
	bar.add_child(VSeparator.new())
	var sb := _hbox(6)
	bar.add_child(sb)
	sb.add_child(Icon.make("shard", P.SHARD, 26))
	ui["shards_l"] = _label("", 19, P.INK, false, "bold")
	sb.add_child(ui["shards_l"])
	ui["shard_box"] = sb
	bar.add_child(VSeparator.new())
	var sl := _hbox(6)
	bar.add_child(sl)
	sl.add_child(_label("Seals", 18, P.TEXT_DIM, false, "bold"))
	ui["seal_icons"] = []
	for i in 3:
		var si := Icon.make(P.SEAL_SHAPES[i], P.CRYSTAL_LIGHT, 24)
		sl.add_child(si)
		ui["seal_icons"].append(si)
	ui["seals_l"] = _label("", 19, P.INK, false, "bold")
	sl.add_child(ui["seals_l"])
	ui["seal_box"] = sl
	bar.add_child(VSeparator.new())
	var tb := _hbox(6)
	bar.add_child(tb)
	tb.add_child(Icon.make("hourglass", P.AMBER, 24))
	ui["turns_l"] = _label("", 19, P.INK, false, "bold")
	tb.add_child(ui["turns_l"])
	bar.add_child(_spacer())
	var menu_b := _button("Menu", _open_pause, 110)
	menu_b.tooltip_text = "Pause (Esc)"
	bar.add_child(menu_b)

	# ---- body: board | side column
	var body := _hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	board = Board.new()
	board.custom_minimum_size = Vector2(760, 760)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.reduced_motion = settings.reduced_motion
	board.room_clicked.connect(_on_room_clicked)
	board.room_hovered.connect(_on_room_hovered)
	board.cancel_requested.connect(_cancel)
	body.add_child(board)

	var side := _vbox(10)
	side.custom_minimum_size.x = 760
	body.add_child(side)
	ui["side"] = side

	# Knight panel
	var kh := _hbox(12)
	ui["knight_panel"] = _parch(kh, 12)
	side.add_child(ui["knight_panel"])
	kh.add_child(_art_rect(P.KNIGHT_ART, Vector2(58, 76)))
	var kv := _vbox(2)
	kv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(kv)
	var krow := _hbox(8)
	kv.add_child(krow)
	ui["knight_icon"] = Icon.make("patrol", P.STATE_COLORS["PATROL"], 26)
	krow.add_child(ui["knight_icon"])
	ui["knight_state"] = _label("", 22, P.INK, false, "head")
	krow.add_child(ui["knight_state"])
	ui["knight_text"] = _label("", 19, P.TEXT, true)
	kv.add_child(ui["knight_text"])
	ui["danger"] = _label("", 18, P.BAD, true, "bold")
	kv.add_child(ui["danger"])

	# Room panel
	var rh := _hbox(12)
	side.add_child(_parch(rh, 12))
	var rv := _vbox(0)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rv)
	ui["room_name"] = _label("", 21, P.INK, false, "head")
	rv.add_child(ui["room_name"])
	ui["room_text"] = _label("", 18, P.TEXT, true)
	rv.add_child(ui["room_text"])
	ui["room_btn"] = _button("Use room", _on_room_action, 190)
	rh.add_child(ui["room_btn"])

	# Items
	var ih := _hbox(10)
	side.add_child(ih)
	ui["hero_btn"] = _item_button(_on_hero_item)
	ih.add_child(ui["hero_btn"])
	ui["treasure_btns"] = []
	for i in Config.MAX_TREASURES:
		var idx: int = i
		var b := _item_button(func(): _on_treasure(idx))
		ih.add_child(b)
		ui["treasure_btns"].append(b)
	ui["bonus_l"] = _label("", 16, P.STARLIGHT, true, "bold")
	ui["bonus_l"].custom_minimum_size.x = 120
	ih.add_child(ui["bonus_l"])

	# Hand
	var hand := _hbox(14)
	side.add_child(hand)
	ui["cards"] = []
	for i in 2:
		var cv := _make_card(i)
		hand.add_child(cv["root"])
		ui["cards"].append(cv)

	# Sneak + redraw
	var ctl := _hbox(10)
	side.add_child(ctl)
	var sn := _vbox(0)
	ctl.add_child(sn)
	sn.add_child(_label("Sneak", 18, P.STARLIGHT, false, "head"))
	sn.add_child(_label("uses a card", 14, P.MOON_TEXT))
	ui["sneak_move"] = _button("Move 1 room silently", func(): _on_sneak("sneak_move"), 210)
	ctl.add_child(ui["sneak_move"])
	ui["sneak_quiet"] = _button("Stay, Noise -1", func(): _on_sneak("sneak_quiet"), 170)
	ctl.add_child(ui["sneak_quiet"])
	ctl.add_child(_spacer())
	ui["redraw_btn"] = _button("", _on_redraw, 170)
	ui["redraw_btn"].icon = null
	ctl.add_child(ui["redraw_btn"])

	# Preview / last results
	var pv := _vbox(6)
	var pp := _parch(pv, 14)
	pp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(pp)
	ui["preview_panel"] = pp
	ui["preview"] = _rich(18)
	ui["preview"].fit_content = false
	ui["preview"].scroll_active = true
	ui["preview"].scroll_following = false
	ui["preview"].custom_minimum_size.y = 84
	ui["preview"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(ui["preview"])
	var prow := _hbox(10)
	pv.add_child(prow)
	ui["confirm"] = _button("Confirm", _confirm, 200, true)
	prow.add_child(ui["confirm"])
	ui["cancel"] = _button("Cancel", _cancel, 140)
	prow.add_child(ui["cancel"])
	ui["preview_buttons"] = prow

	# Banner over the board (e.g. after a successful HIDE). Stays until your next action.
	var ban := _label("", 21, P.INK, true, "bold")
	ban.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var banp := _parch(ban, 12, P.CRYSTAL, 3)
	banp.position = Vector2(140, 92)
	banp.custom_minimum_size = Vector2(540, 0)
	banp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_root.add_child(banp)
	ui["banner"] = banp
	ui["banner_l"] = ban

	_build_encounter()

	# Debug overlay (F1, debug builds only): the Knight's mind. Never shown to players.
	var dbg := _label("", 15, P.STARLIGHT, true)
	dbg.custom_minimum_size.x = 540
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.85), P.CRYSTAL, 2, 8, 12))
	dp.add_child(dbg)
	dp.position = Vector2(30, 100)
	dp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dp.visible = false
	game_root.add_child(dp)
	ui["debug"] = dp
	ui["debug_text"] = dbg


func _item_button(cb: Callable) -> Button:
	var b := _button("", cb, 0)
	b.custom_minimum_size = Vector2(190, _fs(60))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", Art.body_bold_font())
	b.add_theme_font_size_override("font_size", _fs(16))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 40)
	return b


## One card: category ribbon, name, illustration, rule, requirement, and a reason when it can't be played.
func _make_card(i: int) -> Dictionary:
	var idx := i
	var root := Button.new()
	root.focus_mode = Control.FOCUS_NONE
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(360, 272)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.pressed.connect(func(): _on_card_clicked(idx))
	var v := _vbox(5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_full(_margin(v, 12)))
	var head := _hbox(8)
	var headp := PanelContainer.new()
	headp.add_child(head)
	headp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(headp)
	var icon := Icon.make("movement", P.CATEGORY["movement"]["color"], 30)
	head.add_child(icon)
	var title := _label("", 24, P.INK, false, "head")
	head.add_child(title)
	head.add_child(_spacer())
	var cat := _label("", 15, P.INK, false, "bold")
	head.add_child(cat)
	var art := _art_rect("", Vector2(0, 96), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	art.clip_contents = true
	v.add_child(art)
	var rule := _label("", 18, P.TEXT, true)
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(rule)
	var req := _label("", 15, P.TEXT_DIM, true, "bold")
	v.add_child(req)
	var why := _label("", 16, P.BAD, true, "bold")
	v.add_child(why)
	var key := _button("Use Rune Key (1 Shard)", func(): _on_card(idx, "rune_key"))
	key.visible = false
	v.add_child(key)
	for n in [head, icon, title, cat, art, rule, req, why]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return {"root": root, "head": headp, "icon": icon, "title": title, "cat": cat, "art": art, "rule": rule, "req": req, "why": why, "key": key}


func _build_encounter() -> void:
	## Full-screen scene (layout from Asia's mockup): Knight left, hero right, title banner,
	## one card per choice. Every word is real text, so it always matches the rules.
	var layer := Control.new()
	_full(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	game_root.add_child(layer)
	ui["encounter"] = layer
	layer.visible = false
	_backdrop(layer, P.TITLE_ART, 0.3)
	var kn := _art_rect(P.KNIGHT_ART, Vector2.ZERO)
	kn.position = Vector2(30, 150)
	kn.size = Vector2(420, 560)
	layer.add_child(kn)
	var hero := _art_rect("", Vector2.ZERO)
	hero.position = Vector2(1210, 250)
	hero.size = Vector2(360, 460)
	layer.add_child(hero)
	ui["enc_hero"] = hero
	var col := _vbox(14)
	col.position = Vector2(360, 24)
	col.size = Vector2(880, 850)
	layer.add_child(col)
	var bv := _vbox(2)
	var banner := _parch(bv, 22, P.GOLD, 4)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(banner)
	var t := _label("The Cursed Knight found you", 40, P.INK, false, "title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(t)
	ui["enc_status"] = _label("", 21, P.TEXT, false, "bold")
	ui["enc_status"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(ui["enc_status"])
	ui["enc_shield"] = _label("", 19, P.GOOD, false, "bold")
	ui["enc_shield"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(ui["enc_shield"])
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(gap)
	var choose := _night_title("Choose your escape.", 32, "head")
	choose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(choose)
	ui["enc_opts"] = _hbox(18)
	ui["enc_opts"].alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(ui["enc_opts"])
	var fh := _hbox(10)
	fh.alignment = BoxContainer.ALIGNMENT_CENTER
	ui["enc_first_box"] = _parch(fh, 12)
	ui["enc_first_box"].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ui["enc_first_box"])
	fh.add_child(_label("First, if you like (does not end the encounter):", 18, P.TEXT_DIM, false, "bold"))
	ui["enc_first"] = _hbox(10)
	fh.add_child(ui["enc_first"])
	var foot := _night_title("Hero items and the Smoke Vial appear as extra choices while you have them.", 18, "body")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)


## A dark button with cream text (encounter choices, end screen).
func _dark_button(text: String, cb: Callable, fill: Color, min_w: int = 0) -> Button:
	var b := _button(text, cb, min_w)
	b.add_theme_stylebox_override("normal", _sb(fill, P.GOLD, 3))
	b.add_theme_stylebox_override("hover", _sb(fill.lightened(0.15), P.AMBER, 3))
	b.add_theme_stylebox_override("pressed", _sb(fill.darkened(0.2), P.AMBER, 3))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, P.STARLIGHT)
	b.add_theme_font_size_override("font_size", _fs(20))
	b.custom_minimum_size.y = _fs(52)
	return b


func _encounter_copy(id: String) -> Array:
	## [title, text, icon kind or "", art name or "", frame colour]
	var safe: int = game.hide_safe_min()
	match id:
		"run":
			return ["RUN", "Flee 1 connected room. Noise +1.\nRoll D6. On 1-2 you also lose 1 Health.", "run", "", Color("6b2a35")]
		"hide":
			return ["HIDE", "Roll D6. %d-6: safe. You stay and the Knight searches nearby.\n1-%d: lose 1 Health and flee 1 room. Noise unchanged." % [safe, safe - 1], "hide_enc", "", P.PLUM]
		"lantern":
			return ["LANTERN", "Escape 1 room silently. The Knight loses its next turn.", "", P.ITEM_ART["lantern"], P.GOLD_DARK]
		"silence":
			return ["SILENCE SCROLL", "Escape 1 room. Noise -2.", "", P.ITEM_ART["silence"], P.GOLD_DARK]
		"smoke", "smoke_vial":
			return ["SMOKE VIAL", "Escape 1 room. No damage and no Noise.", "", P.ITEM_ART["smoke"], P.GOLD_DARK]
	return [id.to_upper(), "", "", "", P.INK]


# ================================================================== pause / settings / rules

func _build_pause() -> void:
	pause_root = _dim_layer(0.7)
	root_box.add_child(pause_root)
	var cc := _full(CenterContainer.new())
	pause_root.add_child(cc)
	var v := _vbox(12)
	v.custom_minimum_size.x = 380
	cc.add_child(_parch(v, 26))
	var t := _label("Paused", 36, P.INK, false, "title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Resume", _close_pause, 0, true))
	v.add_child(_button("Restart this run", func():
		_close_pause()
		_start_game()))
	v.add_child(_button("How to play", _open_rules))
	v.add_child(_button("Settings", _open_settings))
	v.add_child(_button("Quit to title", func():
		_close_pause()
		_show("title")))


func _open_pause() -> void:
	if screen == "game" and not busy:
		pause_root.visible = true


func _close_pause() -> void:
	pause_root.visible = false


func _build_settings() -> void:
	settings_root = _dim_layer(0.7)
	root_box.add_child(settings_root)
	var cc := _full(CenterContainer.new())
	settings_root.add_child(cc)
	var v := _vbox(12)
	v.custom_minimum_size.x = 560
	cc.add_child(_parch(v, 28))
	v.add_child(_label("Settings", 36, P.INK, false, "title"))
	var vr := _hbox(12)
	v.add_child(vr)
	vr.add_child(_label("Effects volume", 19, P.INK, false, "bold"))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = settings.volume
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size.y = 32
	sl.value_changed.connect(func(x):
		settings.volume = x
		_apply_audio()
		sfx.play("click"))
	vr.add_child(sl)
	v.add_child(_toggle("Sound on", not settings.muted, func(on):
		settings.muted = not on
		_apply_audio()))
	v.add_child(_toggle("Reduced motion (no shaking, gliding or flashes)", settings.reduced_motion, func(on):
		settings.reduced_motion = on
		board.reduced_motion = on))
	v.add_child(_toggle("Skip repeated animations (faster steps and ripples)", settings.fast, func(on): settings.fast = on))
	v.add_child(_toggle("Larger text (115%)", settings.text_scale > 1.0, func(on):
		settings.text_scale = 1.15 if on else 1.0
		settings.save_settings()
		_rebuild_keep_state()))
	v.add_child(_toggle("Confirm actions (second click or Space)", settings.confirm, func(on): settings.confirm = on))
	v.add_child(_button("Done", _close_settings, 0, true))


func _toggle(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(x):
		sfx.play("click")
		cb.call(x)
		settings.save_settings())
	return c


func _open_settings() -> void:
	settings_root.visible = true


func _close_settings() -> void:
	settings.save_settings()
	settings_root.visible = false


func _rebuild_keep_state() -> void:
	var s := screen
	var paused := pause_root.visible
	var names: Array = board.room_names
	_build_all()
	_show(s)
	if game != null:
		ui["room_names"] = names
		board.game = game
		board.room_names = names
		_restore_board()
		_refresh()
	pause_root.visible = paused
	settings_root.visible = true


func _build_rules() -> void:
	rules_root = _dim_layer(0.75)
	root_box.add_child(rules_root)
	var cc := _full(CenterContainer.new())
	rules_root.add_child(cc)
	var v := _vbox(14)
	v.custom_minimum_size = Vector2(980, 560)
	cc.add_child(_parch(v, 30))
	ui["rules_title"] = _label("", 34, P.INK, false, "title")
	v.add_child(ui["rules_title"])
	var row := _hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	ui["rules_art"] = _art_rect("", Vector2(300, 300))
	row.add_child(ui["rules_art"])
	ui["rules_text"] = _rich(21)
	ui["rules_text"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ui["rules_text"])
	var nav := _hbox(12)
	v.add_child(nav)
	ui["rules_prev"] = _button("Back", func(): _rules_page(rules_page - 1), 150)
	nav.add_child(ui["rules_prev"])
	ui["rules_count"] = _label("", 18, P.TEXT_DIM, false, "bold")
	nav.add_child(ui["rules_count"])
	nav.add_child(_spacer())
	ui["rules_next"] = _button("Next", func(): _rules_page(rules_page + 1), 150, true)
	nav.add_child(ui["rules_next"])
	nav.add_child(_button("Close", _close_rules, 150))


func _open_rules() -> void:
	settings.seen_intro = true
	settings.save_settings()
	rules_root.visible = true
	_rules_page(0)


func _close_rules() -> void:
	rules_root.visible = false
	if screen == "title":
		_refresh_title()


func _rules_page(n: int) -> void:
	rules_page = clampi(n, 0, RULES_PAGES.size() - 1)
	var pg: Array = RULES_PAGES[rules_page]
	ui["rules_title"].text = pg[0]
	ui["rules_art"].texture = Art.tex(pg[1])
	ui["rules_art"].visible = pg[1] != ""
	ui["rules_text"].text = pg[2]
	ui["rules_count"].text = "%d of %d" % [rules_page + 1, RULES_PAGES.size()]
	ui["rules_prev"].disabled = rules_page == 0
	ui["rules_next"].disabled = rules_page == RULES_PAGES.size() - 1


# ================================================================== flow

func _start_game() -> void:
	if not profile.hero_unlocked(sel_hero):
		sel_hero = "ranger"
	if not profile.difficulty_unlocked(sel_diff):
		sel_diff = "normal"
	game = Game.new()
	game.new_game(sel_hero, sel_diff)
	var names: Array = P.ROOM_NAMES.duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = game.rng.seed
	for i in range(names.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = names[i]
		names[i] = names[j]
		names[j] = t
	ui["room_names"] = names
	board.game = game
	board.room_names = names
	board.targets = []
	board.knight_dust = 0.0
	board.dim = false
	pending = {}
	sneak_mode = ""
	reason_line = ""
	banner_text = ""
	recent = []
	queue = []
	busy = false
	_prev_kstate = game.knight.state
	knight_log = ["Curse of Blackthorn Keep - Knight decision log",
		"Hero: %s   Difficulty: %s   Seed: %d" % [Config.HEROES[sel_hero]["name"], Config.DIFFICULTY[sel_diff]["name"], game.rng.seed],
		"Senses on this difficulty: %s" % str(Config.DIFFICULTY[sel_diff]), ""]
	_show("game")
	await get_tree().process_frame
	_restore_board()
	_after_action()


func _restore_board() -> void:
	board.place("player", game.player_room, true)
	board.place("knight", game.knight.room, true)


func _after_action() -> void:
	queue.append_array(game.take_events())
	_pump()


func _pump() -> void:
	if busy:
		return
	busy = true
	_refresh()
	while not queue.is_empty():
		var e: Dictionary = queue.pop_front()
		await _handle(e)
	busy = false
	_sync_pieces()
	_write_log()
	_refresh()
	if game.phase == "won" or game.phase == "lost":
		await _wait(1.2 if game.phase == "won" else 0.8)
		_show_end()


func _sync_pieces() -> void:
	board.place("player", game.player_room)
	board.place("knight", game.knight.room)


func _t(sec: float) -> float:
	return sec * (0.5 if settings.fast else 1.0)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _note(text: String) -> void:
	if text == "":
		return
	recent.append(text)
	if recent.size() > 3:
		recent.pop_front()


func _bump(node: Control, col: Color) -> void:
	## Short highlight on a top-bar counter when it changes.
	if node == null or settings.reduced_motion:
		return
	node.pivot_offset = node.size * 0.5
	var tw: Tween = node.create_tween()
	node.modulate = col
	tw.set_parallel(true)
	tw.tween_property(node, "modulate", Color.WHITE, 0.5)
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.12)
	tw.chain().tween_property(node, "scale", Vector2.ONE, 0.2)


func _handle(e: Dictionary) -> void:
	var t: String = e["type"]
	match t:
		"move":
			board.place("player", e["to"])
			sfx.play("move")
			await _wait(_t(0.25))
		"knight":
			if e["text"] != "":
				knight_log.append(e["text"])
			var path: Array = e["path"]
			if e.get("roll", 0) > 0:
				await _knight_die(e["roll"], e["roll"] >= e["need"])
			for r in path:
				board.place("knight", r)
				sfx.play("knight_step")
				await _wait(_t(0.3))
			if path.is_empty():
				_note("The Knight is stunned and loses its turn." if game.knight.stunned_now else "The Knight stays in %s." % game.room_name(game.knight.room))
				await _wait(_t(0.15))
			else:
				_note("The Knight moves to %s." % game.room_name(path.back()))
			if e["state"] == "HUNT" and _prev_kstate != "HUNT":
				sfx.play("bad")
				board.pulse(game.knight.room, 0.8, P.HEALTH)
				_bump(ui["knight_panel"], Color(1.0, 0.75, 0.6))
			_prev_kstate = e["state"]
		"dice":
			_note(e["text"])
			await _roll_dice(e["roll"], e.get("total", e["roll"]), e["ok"], e["text"])
		"noise":
			sfx.play("noise")
			board.ripple(e["room"], P.NOISE)
			_float_text(e["room"], "Noise %d" % game.noise, P.NOISE)
			_bump(ui["noise_box"], Color(1.0, 0.7, 0.5))
			_note(e["text"])
			await _wait(_t(0.3))
		"quiet":
			sfx.play("quiet")
			_bump(ui["noise_box"], Color(0.8, 0.9, 1.0))
			_note(e["text"])
		"damage":
			sfx.play("damage")
			if not settings.reduced_motion:
				board.shake = 1.0
				board.vignette = 1.0
			_float_text(game.player_room, "-1 Health", P.HEALTH)
			_bump(ui["health_box"], Color(1.0, 0.5, 0.5))
			_note(e["text"])
			await _wait(0.6)
		"block":
			sfx.play("good")
			_float_text(game.player_room, "Blocked", P.GOLD)
			_note(e["text"])
			await _wait(0.4)
		"heal":
			sfx.play("heal")
			_float_text(game.player_room, "+1 Health", P.GOOD)
			_bump(ui["health_box"], Color(0.7, 1.0, 0.7))
			_note(e["text"])
			await _wait(0.4)
		"encounter":
			sfx.play("encounter")
			if not settings.reduced_motion:
				board.shake = 0.7
			_note(e["text"])
			await _wait(0.4)
		"hidden":
			sfx.play("good")
			_float_text(game.player_room, "Unseen", P.CRYSTAL_LIGHT)
			banner_text = "Unseen. The Knight is still in this room. Move away this turn."
			_note(e["text"])
			await _wait(0.4)
		"seal":
			sfx.play("seal")
			var sroom: int = game.castle.seals[e["seal"]]
			board.flare(sroom)
			if not settings.reduced_motion:
				board.flash = Color(P.CRYSTAL_LIGHT, 0.25)
			_float_text(sroom, "Seal %s restored" % char(65 + e["seal"]), P.CRYSTAL_LIGHT)
			_bump(ui["seal_box"], Color(0.85, 0.7, 1.0))
			_note(e["text"])
			await _wait(0.9)
		"shift":
			sfx.play("shift")
			if not settings.reduced_motion:
				board.shake = 0.4
			for part in String(e["closed"]).split("_"):
				board.pulse(int(part), 2.0, P.HEALTH)
			for part in String(e["opened"]).split("_"):
				board.pulse(int(part), 2.0, P.AMBER)
			_note("The Keep shifts: a doorway closes (red) and another opens (gold).")
			await _wait(_t(0.7))
		"corrupt":
			sfx.play("bad")
			for r in game.castle.corrupted:
				board.pulse(r, 2.0, P.CRYSTAL)
			_note(e["text"])
			await _wait(_t(0.5))
		"signal":
			sfx.play("bell")
			board.ripple(e["room"], P.CRYSTAL_LIGHT)
			_note(e["text"])
			await _wait(_t(0.5))
		"bell":
			sfx.play("bell")
			board.ripple(e["room"], P.AMBER)
			_note(e["text"])
			await _wait(_t(0.4))
		"shard":
			sfx.play("good")
			_float_text(game.player_room, "+%d Shard" % e["amount"], P.CRYSTAL_LIGHT)
			_bump(ui["shard_box"], Color(0.85, 0.7, 1.0))
		"treasure", "armory", "hero", "escape", "passage", "redraw":
			sfx.play("good")
			_note(e["text"])
		"won":
			sfx.play("win")
			_note(e["text"])
			if settings.reduced_motion:
				board.knight_dust = 1.0
			else:
				var tw: Tween = board.create_tween()
				tw.tween_property(board, "knight_dust", 1.0, 1.2)
		"lost":
			sfx.play("lose")
			_note(e["text"])
		"turn":
			if game.castle.distance(game.player_room, game.knight.room) <= 1:
				sfx.play("heartbeat")
		"card":
			sfx.play("card")
		"start":
			_note(e["text"])
		_:
			_note(e["text"])


func _float_text(room: int, text: String, color: Color) -> void:
	if room < 0 or text == "":
		return
	var l := _label(text, 24, color, false, "head")
	l.add_theme_color_override("font_outline_color", P.INK)
	l.add_theme_constant_override("outline_size", 7)
	l.add_to_group("board_float")
	overlay.add_child(l)
	l.position = board.global_position + board.room_center(room) - Vector2(70, 40)
	var tw := l.create_tween()
	tw.set_parallel(true)
	if not settings.reduced_motion:
		tw.tween_property(l, "position:y", l.position.y - 60, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


## Big die in the middle of the board, with a "+1" chip when the Search bonus applies.
func _roll_dice(roll: int, total: int, ok: bool, text: String) -> void:
	var d := DiceView.new()
	d.size = Vector2(120, 120)
	d.sfx = sfx
	d.body = P.PARCHMENT
	d.pip = P.INK
	d.edge = P.INK
	overlay.add_child(d)
	d.position = board.global_position + board.size * 0.5 - d.size * 0.5
	d.pivot_offset = d.size * 0.5
	var col: Color = P.GOOD if ok else P.HEALTH
	await d.roll_to(roll, col, 0.0 if settings.reduced_motion else _t(0.6))
	var nodes: Array = [d]
	if total != roll:
		var chip := _label("+%d" % (total - roll), 30, P.STARLIGHT, false, "head")
		chip.add_theme_color_override("font_outline_color", P.INK)
		chip.add_theme_constant_override("outline_size", 8)
		overlay.add_child(chip)
		chip.position = d.position + Vector2(d.size.x + 12, 30)
		nodes.append(chip)
	var outcome := text.get_slice(":", 1).strip_edges() if text.contains(":") else ""
	var head := "Rolled %d" % roll if total == roll else "Rolled %d + %d = %d" % [roll, total - roll, total]
	var l := _label(head + (". " + outcome if outcome != "" else "."), 24, P.STARLIGHT, true, "bold")
	l.add_theme_color_override("font_outline_color", P.INK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(600, 0)
	overlay.add_child(l)
	l.position = d.position + Vector2(d.size.x * 0.5 - 300, d.size.y + 22)
	nodes.append(l)
	await _wait(_t(1.0))
	for n in nodes:
		var tw: Tween = n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.25)
		tw.tween_callback(n.queue_free)
	await _wait(0.15)


## Small red die beside the Knight (Easy and Hard only): its move-or-stay roll.
func _knight_die(roll: int, moves: bool) -> void:
	if not board._pos.has("knight"):
		return
	var d := DiceView.new()
	d.size = Vector2(54, 54)
	d.body = Color("7a1d24")
	d.pip = P.PARCHMENT
	d.edge = P.INK
	d.sfx = sfx
	overlay.add_child(d)
	var kp: Vector2 = board._pos["knight"]
	var side := 28.0 if kp.x < board.size.x * 0.6 else -28.0 - d.size.x
	d.position = board.global_position + kp + Vector2(side, -90)
	d.pivot_offset = d.size * 0.5
	await d.roll_to(roll, P.HEALTH if moves else P.MOON_TEXT, 0.0 if settings.reduced_motion else _t(0.4))
	var l := _label("moves" if moves else "stays", 18, P.STARLIGHT, false, "bold")
	l.add_theme_color_override("font_outline_color", P.INK)
	l.add_theme_constant_override("outline_size", 6)
	overlay.add_child(l)
	l.position = d.position + Vector2(0, d.size.y + 2)
	await _wait(_t(0.35))
	for n in [d, l]:
		var tw: Tween = n.create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(n, "modulate:a", 0.0, 0.3)
		tw.tween_callback(n.queue_free)


func _write_log() -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(PackedStringArray(knight_log)) + "\n")


# ================================================================== input

func _can_act() -> bool:
	return game != null and not busy and game.phase == "player" and screen == "game" and not pause_root.visible


func _clear_selection() -> void:
	pending = {}
	sneak_mode = ""
	hover_target = -1
	reason_line = ""
	board.targets = []


func _on_card_clicked(i: int) -> void:
	if not _can_act():
		return
	if sneak_mode != "":
		var m := sneak_mode
		sneak_mode = ""
		_on_card(i, m)
		return
	_on_card(i, "normal")


## Select card `i` in `mode`. Moves wait for a room; other actions wait for a second click or
## Space (unless "Confirm actions" is off). Kept as the entry point used by the UI smoke test.
func _on_card(i: int, mode: String) -> void:
	if not _can_act() or i >= game.hand.size():
		return
	if not game.can_play(i, mode):
		_clear_selection()
		reason_line = game.why_not(i, mode)
		sfx.play("bad")
		_refresh()
		return
	var card: String = game.hand[i]
	if game.needs_target(card, mode):
		_clear_selection()
		pending = {"i": i, "mode": mode}
		board.targets = game.move_options(card, mode)
		sfx.play("card")
		_refresh()
		return
	if settings.confirm:
		if not pending.is_empty() and pending["i"] == i and pending["mode"] == mode:
			_confirm()
			return
		_clear_selection()
		pending = {"i": i, "mode": mode}
		sfx.play("card")
		_refresh()
		return
	_play(i, mode, -1)


func _on_sneak(mode: String) -> void:
	if not _can_act():
		return
	if not pending.is_empty() and pending["mode"] == "normal":
		var i: int = pending["i"]
		_clear_selection()
		_on_card(i, mode)
		return
	_clear_selection()
	sneak_mode = mode
	_refresh()


func _confirm() -> void:
	if pending.is_empty() or not _can_act():
		return
	var card: String = game.hand[pending["i"]]
	if game.needs_target(card, pending["mode"]):
		if hover_target in board.targets:
			_play(pending["i"], pending["mode"], hover_target)
		return
	_play(pending["i"], pending["mode"], -1)


func _cancel() -> void:
	if pending.is_empty() and sneak_mode == "" and reason_line == "":
		return
	_clear_selection()
	_refresh()


func _play(i: int, mode: String, target: int) -> void:
	_clear_selection()
	banner_text = ""
	if game.play_card(i, mode, target):
		_after_action()
	else:
		_refresh()


func _on_room_clicked(r: int) -> void:
	if pending.is_empty() or not _can_act():
		return
	if not (r in board.targets):
		return
	_play(pending["i"], pending["mode"], r)


func _on_room_hovered(r: int) -> void:
	if not pending.is_empty() and r in board.targets:
		hover_target = r
	elif not pending.is_empty():
		hover_target = -1
	if not pending.is_empty():
		_refresh_preview()


func _on_room_action() -> void:
	if _can_act() and game.do_room_action():
		_clear_selection()
		banner_text = ""
		_after_action()


func _on_hero_item() -> void:
	if game != null and not busy and game.use_hero_item():
		_clear_selection()
		_after_action()


func _on_treasure(i: int) -> void:
	if game != null and not busy and game.use_treasure(i):
		_clear_selection()
		_after_action()


func _on_redraw() -> void:
	if _can_act() and game.redraw_hand():
		_clear_selection()
		_after_action()


func _on_encounter(choice: String) -> void:
	if game == null or busy or game.phase != "encounter":
		return
	banner_text = ""
	if game.resolve_encounter(choice):
		_after_action()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			if OS.is_debug_build() and board.game != null:
				board.show_debug = not board.show_debug
				ui["debug"].visible = board.show_debug
				_refresh()
		KEY_ESCAPE:
			if rules_root.visible:
				_close_rules()
			elif settings_root.visible:
				_close_settings()
			elif pause_root.visible:
				_close_pause()
			elif not pending.is_empty() or sneak_mode != "" or reason_line != "":
				_cancel()
			elif screen == "game":
				_open_pause()
		KEY_1:
			_on_card_clicked(0)
		KEY_2:
			_on_card_clicked(1)
		KEY_SPACE, KEY_ENTER:
			_confirm()
		KEY_R:
			_on_redraw()
		KEY_TAB:
			if not board.targets.is_empty():
				var k: int = board.targets.find(hover_target)
				hover_target = board.targets[(k + 1) % board.targets.size()]
				board.hovered = hover_target
				_refresh_preview()
		KEY_M:
			settings.muted = not settings.muted
			_apply_audio()
			settings.save_settings()


# ================================================================== refresh

func _refresh() -> void:
	if game == null:
		return
	var act := _can_act()
	var hunt_at: int = game.diff["hunt_at"]

	# Top bar
	for i in Config.MAX_HEALTH:
		ui["hearts"][i].set_icon("heart", P.HEALTH, i < game.health)
	ui["health_l"].text = "Health %d/%d" % [game.health, Config.MAX_HEALTH]
	ui["noise_pips"].value = game.noise
	ui["noise_pips"].notch = hunt_at
	ui["noise_pips"].queue_redraw()
	ui["noise_l"].text = "Noise %d/%d, heard at %d" % [game.noise, Config.MAX_NOISE, hunt_at]
	ui["noise_warn"].text = "It can hear you" if game.noise >= hunt_at else ("1 more and it hears you" if game.noise == hunt_at - 1 else "")
	ui["shards_l"].text = "Shards %d" % game.shards
	for i in 3:
		ui["seal_icons"][i].set_icon(P.SEAL_SHAPES[i], P.CRYSTAL_LIGHT, game.restored[i])
	ui["seals_l"].text = "%d/3" % game.seals_restored()
	var left: int = maxi(0, game.turns_left())
	ui["turns_l"].text = "Turn %d, %d left" % [mini(game.turn, Config.TURN_LIMIT), left]
	ui["turns_l"].add_theme_color_override("font_color", P.BAD if left <= 5 else P.INK)

	# Knight panel (public information only)
	var k = game.knight
	var kp: Dictionary = game.knight_public()
	var kc: Color = P.STATE_COLORS[k.state]
	var icon_kind: String = {"hear": "ear", "see": "eye", "signal": "signal", "marker": "marker", "memory": "question", "search": "search", "patrol": "patrol", "stunned": "star"}[kp["kind"]]
	ui["knight_icon"].set_icon(icon_kind, kc if kp["kind"] != "stunned" else P.KNIGHT_TRIM)
	ui["knight_state"].text = "The Knight: %s" % ("Stunned" if kp["kind"] == "stunned" else P.STATE_WORD[k.state])
	ui["knight_text"].text = kp["text"]
	ui["knight_panel"].frame = kc.darkened(0.2)
	ui["knight_panel"].queue_redraw()
	var kd: int = game.castle.distance(game.player_room, k.room)
	ui["danger"].text = "" if kd > 1 else ("It is in your room." if kd == 0 else "Heavy footsteps right next door.")

	# Room panel
	var here: int = game.player_room
	var sp: String = game.castle.special_at(here)
	var si: int = game.castle.seal_index(here)
	var rname: String = board.room_names[here] if here < board.room_names.size() else ""
	if si >= 0:
		rname = "Seal %s" % char(65 + si)
	elif game.castle.specials.has(here):
		rname = Config.SPECIALS[game.castle.specials[here]]["name"]
	ui["room_name"].text = "This room: %s (%s)" % [rname, game.room_name(here)]
	var rt := ""
	if si >= 0:
		rt = "Restored." if game.restored[si] else ("Activate here with 2 Shards (1 with the Rune Key)." if game.rune_key_ready else "Activate here with 2 Shards.")
	elif game.castle.corrupted.has(here):
		rt = "Corrupted: its power is gone."
	elif sp != "":
		rt = Config.SPECIALS[sp]["text"]
		if game.used_once.has(sp):
			rt += " Already used."
	else:
		rt = "Already searched." if game.searched.has(here) else "Not searched yet: a Rune Shard may be hidden here."
	ui["room_text"].text = rt
	var ra: String = game.room_action()
	ui["room_btn"].text = {"chapel": "Pray (+1 Health)", "bell_tower": "Ring the bell", "armory": "Search the rack", "passage": "Take the passage"}.get(ra, "No room action")
	ui["room_btn"].disabled = not act or ra == ""
	ui["room_btn"].tooltip_text = "A free action. It does not use your card." if ra != "" else ""

	# Items
	var hi: Dictionary = Config.HEROES[game.hero]
	var hb: Button = ui["hero_btn"]
	var key_hero: bool = hi["item"] == "rune_key"
	var item_ready: bool = game.rune_key_ready if key_hero else game.hero_item_ready
	hb.icon = Art.tex(P.ITEM_ART.get(hi["item"], ""))
	hb.text = "%s\n%s" % [hi["item_name"], ("Ready: use it on an Activate card" if item_ready else "Used") if key_hero else ("Ready" if item_ready else "Used")]
	hb.tooltip_text = hi["text"]
	hb.disabled = busy or not game.can_use_hero_item()
	for i in Config.MAX_TREASURES:
		var tb: Button = ui["treasure_btns"][i]
		if i < game.treasures.size():
			var t: String = game.treasures[i]
			tb.icon = Art.tex(P.ITEM_ART.get(t, ""))
			var usable: bool = game.can_use_treasure(t)
			var note := "Use now" if usable else ("Automatic" if t == "old_shield" else ("Encounter only" if t == "smoke_vial" else "Not needed now"))
			tb.text = "%s\n%s" % [Config.TREASURE_INFO[t]["name"], note]
			tb.tooltip_text = Config.TREASURE_INFO[t]["text"]
			tb.disabled = busy or not usable
		else:
			tb.icon = null
			tb.text = "Empty\npack slot"
			tb.tooltip_text = "Treasures from a Search roll of 6 or the Armory go here."
			tb.disabled = true
	ui["bonus_l"].text = "Search +1: ready" if game.search_bonus > 0 else "Search +1: not earned"
	ui["bonus_l"].add_theme_color_override("font_color", P.AMBER if game.search_bonus > 0 else P.MOON_TEXT)

	# Cards
	for i in 2:
		_refresh_card(i, act)
	ui["sneak_move"].disabled = not act
	ui["sneak_quiet"].disabled = not act
	for key in ["sneak_move", "sneak_quiet"]:
		var on: bool = sneak_mode == key or (not pending.is_empty() and pending["mode"] == key)
		ui[key].add_theme_stylebox_override("normal", _sb(P.AMBER if on else P.PARCHMENT_DARK, P.INK, 3 if on else 2))
	var rb: Button = ui["redraw_btn"]
	rb.text = "Redraw: ready" if game.redraw_ready else "Redraw: used"
	rb.tooltip_text = "Once per run: swap both cards for two new ones. Costs no turn. (R)"
	rb.disabled = not act or not game.can_redraw()

	# Banner
	ui["banner"].visible = banner_text != "" and game.phase == "player"
	ui["banner_l"].text = banner_text

	_refresh_preview()
	_refresh_encounter(hi)

	if board.show_debug:
		var lines: Array = k.debug_lines()
		lines.append("Senses now: Noise %d, token %s (#%d), sight %d" % [game.noise, game.room_name(game.token), game.token_serial, game.diff["sight"]])
		lines.append("")
		lines.append("Recent decisions:")
		lines.append_array(k.log_lines.slice(maxi(0, k.log_lines.size() - 8)))
		lines.append("")
		lines.append("Full log: " + ProjectSettings.globalize_path(LOG_PATH))
		ui["debug_text"].text = "\n".join(PackedStringArray(lines))


func _refresh_card(i: int, act: bool) -> void:
	var cui: Dictionary = ui["cards"][i]
	var root: Button = cui["root"]
	if i >= game.hand.size():
		root.visible = false
		return
	root.visible = true
	var c: String = game.hand[i]
	var cat_id: String = P.CARD_CATEGORY[c]
	var cat: Dictionary = P.CATEGORY[cat_id]
	cui["icon"].set_icon(cat_id, cat["color"])
	cui["title"].text = Config.CARDS[c]["name"] + (" (card)" if c == "hide" else "")
	cui["cat"].text = cat["name"]
	cui["cat"].add_theme_color_override("font_color", cat["text"])
	cui["head"].add_theme_stylebox_override("panel", _sb(Color(cat["color"]).lerp(P.PARCHMENT, 0.75), cat["color"], 2, 8, 8))
	cui["art"].texture = Art.tex(P.CARD_ART.get(c, ""))
	cui["rule"].text = CARD_COPY[c]["rule"]
	cui["req"].text = CARD_COPY[c]["req"]
	cui["req"].visible = CARD_COPY[c]["req"] != ""
	var playable: bool = game.can_play(i, "normal")
	var why: String = game.why_not(i, "normal")
	cui["why"].text = ("Can't play: " + why) if why != "" else ""
	cui["why"].visible = why != ""
	var key_ok: bool = c == "activate" and game.rune_key_ready
	cui["key"].visible = key_ok
	cui["key"].disabled = not act or not game.can_play(i, "rune_key")
	var selected: bool = not pending.is_empty() and pending["i"] == i
	var sneaking: bool = sneak_mode != ""
	var border: Color = P.AMBER if selected else (P.CRYSTAL_LIGHT if sneaking else P.GOLD)
	var bw := 6 if selected or sneaking else 4
	var fill: Color = P.PARCHMENT if (playable or sneaking) else P.PARCHMENT_DARK
	root.add_theme_stylebox_override("normal", _sb(fill, border, bw, 14, 0))
	root.add_theme_stylebox_override("hover", _sb(P.PARCHMENT.lightened(0.3), P.AMBER, bw, 14, 0))
	root.add_theme_stylebox_override("pressed", _sb(P.PARCHMENT, P.AMBER, 6, 14, 0))
	root.add_theme_stylebox_override("disabled", _sb(P.PARCHMENT_DARK, Color(P.GOLD, 0.6), 4, 14, 0))
	root.disabled = not act
	cui["art"].modulate = Color.WHITE if (playable or sneaking) else Color(0.6, 0.6, 0.6)
	root.tooltip_text = "Press %d to pick this card." % (i + 1)


func _refresh_preview() -> void:
	var rt: RichTextLabel = ui["preview"]
	var show_buttons := false
	var txt := ""
	var bad := "#" + P.BAD.to_html(false)
	var dim := "#" + P.TEXT_DIM.to_html(false)
	if game == null:
		return
	if game.phase == "won" or game.phase == "lost":
		txt = "[b]%s[/b]" % game.end_reason
	elif busy:
		txt = "[color=%s]The Keep stirs...[/color]\n" % dim + _recent_text()
	elif sneak_mode != "":
		txt = "[b]Sneak:[/b] %s\nPick the card to spend. Its own effect does not happen." % ("move 1 room silently." if sneak_mode == "sneak_move" else "stay here and lower Noise by 1.")
		show_buttons = true
	elif not pending.is_empty():
		var i: int = pending["i"]
		var mode: String = pending["mode"]
		var card: String = game.hand[i]
		var cname: String = Config.CARDS[card]["name"]
		var head := cname
		if mode == "sneak_move":
			head = "Sneak (move) with %s" % cname
		elif mode == "sneak_quiet":
			head = "Sneak (stay) with %s" % cname
		elif mode == "rune_key":
			head = "Activate with the Rune Key"
		var p: Dictionary = game.preview(i, mode, hover_target if game.needs_target(card, mode) else -1)
		txt = "[b]%s[/b]  [color=%s]uses this card, discards the other[/color]\n" % [head, dim]
		for l in p["will"]:
			txt += "%s\n" % l
		for l in p["warn"]:
			txt += "[color=%s][b]Warning:[/b] %s[/color]\n" % [bad, l]
		if not p["might"].is_empty():
			txt += "[color=%s][b]Might happen:[/b] %s[/color]" % [dim, "  ".join(PackedStringArray(p["might"]))]
		show_buttons = true
	elif reason_line != "":
		txt = "[color=%s][b]Can't play that card:[/b] %s[/color]" % [bad, reason_line]
	elif game.phase == "encounter":
		txt = _recent_text()
	else:
		txt = "[b]Your move.[/b] Pick a card. You play one; the other is discarded.\n" + _recent_text()
	rt.text = txt.strip_edges()
	ui["preview_buttons"].visible = show_buttons
	var needs_room := false
	if not pending.is_empty():
		needs_room = game.needs_target(game.hand[pending["i"]], pending["mode"])
	ui["confirm"].visible = not pending.is_empty()
	ui["confirm"].disabled = needs_room and not (hover_target in board.targets)
	ui["confirm"].text = ("Confirm: %s" % game.room_name(hover_target)) if needs_room and hover_target >= 0 else ("Pick a room" if needs_room else "Confirm (Space)")


func _recent_text() -> String:
	if recent.is_empty():
		return ""
	var dim := "#" + P.TEXT_DIM.to_html(false)
	var out := ""
	for k in recent.size():
		var line: String = recent[k]
		out += ("[color=%s]%s[/color]\n" % [dim, line]) if k < recent.size() - 1 else ("[b]Last:[/b] %s\n" % line)
	return out


func _refresh_encounter(hi: Dictionary) -> void:
	var enc: bool = game.phase == "encounter" and not busy
	ui["encounter"].visible = enc
	board.dim = enc
	if enc:
		get_tree().call_group("board_float", "queue_free")  # board pop-ups must not float over the full-screen scene
	if not enc:
		return
	ui["enc_hero"].texture = Art.tex(P.HERO_ART.get(game.hero, ""))
	ui["enc_status"].text = "Health %d/%d    Noise %d/%d" % [game.health, Config.MAX_HEALTH, game.noise, Config.MAX_NOISE]
	ui["enc_shield"].text = "Your Old Shield will block the next hit." if "old_shield" in game.treasures else ""
	ui["enc_shield"].visible = ui["enc_shield"].text != ""
	for ch in ui["enc_first"].get_children():
		ch.queue_free()
	var any_first := false
	if game.can_use_hero_item() and hi["item"] == "potion":
		var b := _button("Healing Potion: +1 Health", _on_hero_item)
		b.icon = Art.tex(P.ITEM_ART["potion"])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 34)
		ui["enc_first"].add_child(b)
		any_first = true
	for i in game.treasures.size():
		var idx: int = i
		var t: String = game.treasures[i]
		if game.can_use_treasure(t):
			var b := _button("%s: %s" % [Config.TREASURE_INFO[t]["name"], Config.TREASURE_INFO[t]["text"]], func(): _on_treasure(idx))
			b.icon = Art.tex(P.ITEM_ART.get(t, ""))
			b.expand_icon = b.icon != null
			b.add_theme_constant_override("icon_max_width", 34)
			ui["enc_first"].add_child(b)
			any_first = true
	ui["enc_first_box"].visible = any_first
	for ch in ui["enc_opts"].get_children():
		ch.queue_free()
	var opts: Array = game.encounter_options()
	var w := 400 if opts.size() <= 2 else 280
	for o in opts:
		var id: String = o["id"]
		var cp: Array = _encounter_copy(id)
		var card := _vbox(0)
		card.custom_minimum_size.x = w
		# Name plate
		var plate_row := _hbox(12)
		plate_row.alignment = BoxContainer.ALIGNMENT_CENTER
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", _sb(cp[4], P.GOLD, 4, 12, 16))
		plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plate.add_child(plate_row)
		var ic: Control
		if cp[3] != "":
			ic = _art_rect(cp[3], Vector2(44, 44))
		else:
			ic = Icon.make(cp[2], P.STARLIGHT, 40)
			ic.set("outline", Color(0, 0, 0, 0))
		plate_row.add_child(ic)
		plate_row.add_child(_label(cp[0], 30 if w > 300 else 24, P.STARLIGHT, false, "head"))
		card.add_child(plate)
		# Parchment body with the rule and the choose button
		var bodyv := _vbox(14)
		var bodyp := _parch(bodyv, 20, P.GOLD, 4)
		bodyp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(bodyp)
		var tx := _label(cp[1], 20, P.INK, true)
		tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tx.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tx.custom_minimum_size.y = _fs(84)
		bodyv.add_child(tx)
		var cb := _dark_button("Choose " + String(cp[0]).capitalize(), func(): _on_encounter(id), cp[4])
		cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cb.custom_minimum_size.x = mini(w - 60, 300)
		bodyv.add_child(cb)
		ui["enc_opts"].add_child(card)


# ================================================================== end screen

func _build_end() -> void:
	## Full-screen victory and defeat scenes (layout from Asia's mockups), with live text.
	end_root = Control.new()
	_full(end_root)
	end_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root_box.add_child(end_root)
	var bg := _art_rect("", Vector2.ZERO, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	end_root.add_child(_full(bg))
	ui["end_bg"] = bg
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_root.add_child(_full(dim))
	ui["end_dim"] = dim
	var kn := _art_rect(P.KNIGHT_ART, Vector2.ZERO)
	kn.position = Vector2(1210, 120)
	kn.size = Vector2(360, 500)
	end_root.add_child(kn)
	ui["end_knight"] = kn
	var hero := _art_rect("", Vector2.ZERO)
	hero.position = Vector2(40, 320)
	hero.size = Vector2(330, 520)
	end_root.add_child(hero)
	ui["end_hero"] = hero
	var col := _vbox(16)
	col.position = Vector2(380, 24)
	col.size = Vector2(840, 860)
	end_root.add_child(col)
	var bv := _vbox(2)
	var banner := _parch(bv, 26, P.GOLD, 4)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(banner)
	ui["end_title"] = _label("", 50, P.INK, false, "title")
	ui["end_title"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(ui["end_title"])
	ui["end_reason"] = _label("", 22, P.TEXT, true, "bold")
	ui["end_reason"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui["end_reason"].custom_minimum_size.x = 640
	bv.add_child(ui["end_reason"])
	# Victory: the three restored shrines. Defeat: what ended the run (heart or hourglass).
	var shr := _hbox(30)
	shr.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(shr)
	ui["end_shrines"] = shr
	for k in 3:
		shr.add_child(_art_rect(P.SHRINE_RESTORED[k], Vector2(150, 200)))
	var cause := _hbox(24)
	cause.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cause)
	ui["end_cause"] = cause
	ui["cause_health"] = _vbox(4)
	ui["cause_health"].add_child(Icon.make("heart", P.HEALTH, 110, false))
	var hl := _night_title("Health reached 0.", 22, "body")
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui["cause_health"].add_child(hl)
	cause.add_child(ui["cause_health"])
	cause.add_child(_night_title("or", 26, "head"))
	ui["cause_time"] = _vbox(4)
	ui["cause_time"].add_child(Icon.make("hourglass", P.AMBER, 110))
	var tl := _night_title("Turn %d ended." % Config.TURN_LIMIT, 22, "body")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui["cause_time"].add_child(tl)
	cause.add_child(ui["cause_time"])
	var sv := _vbox(4)
	var sp := _parch(sv, 18)
	sp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(sp)
	ui["end_stats"] = _rich(18)
	ui["end_stats"].custom_minimum_size.x = 600
	sv.add_child(ui["end_stats"])
	ui["end_tip"] = _label("", 19, P.TEXT_DIM, true, "bold")
	ui["end_tip"].custom_minimum_size.x = 600
	sv.add_child(ui["end_tip"])
	ui["end_unlocks"] = _label("", 22, P.GOLD_DARK, true, "head")
	sv.add_child(ui["end_unlocks"])
	var row := _hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	ui["end_again"] = _dark_button("Play again", _start_game, Color("3f7a3a"), 230)
	row.add_child(ui["end_again"])
	row.add_child(_dark_button("Main menu", func(): _show("title"), P.PLUM, 230))
	row.add_child(_button("Change hero", func(): _show("heroes"), 170))
	ui["end_footer"] = _night_title("", 22, "head")
	ui["end_footer"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ui["end_footer"])
	var lb := LinkButton.new()
	lb.text = "Show Knight log"
	lb.focus_mode = Control.FOCUS_NONE
	lb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lb.add_theme_color_override("font_color", P.MOON_TEXT)
	lb.add_theme_font_size_override("font_size", _fs(15))
	col.add_child(lb)
	ui["end_log"] = _night_title("", 15, "body")
	ui["end_log"].visible = false
	col.add_child(ui["end_log"])
	lb.pressed.connect(func(): ui["end_log"].visible = not ui["end_log"].visible)
	end_root.visible = false


func _show_end() -> void:
	get_tree().call_group("board_float", "queue_free")
	var won: bool = game.phase == "won"
	var turns: int = mini(game.turn, Config.TURN_LIMIT)
	var unlocks: Array = profile.record(game.hero, game.difficulty, won, turns, _hero_names())
	var s: Dictionary = game.stats
	var timed_out: bool = game.health > 0 and not won
	ui["end_bg"].texture = Art.tex(P.MENU_ART if won else P.TITLE_ART)
	ui["end_dim"].color = Color(P.NIGHT, 0.25 if won else 0.55)
	ui["end_hero"].texture = Art.tex(P.HERO_ART.get(game.hero, ""))
	ui["end_hero"].modulate = Color.WHITE if won else Color(0.7, 0.68, 0.8)
	ui["end_knight"].visible = not won
	ui["end_shrines"].visible = won
	ui["end_cause"].visible = not won
	ui["cause_health"].modulate = Color(1, 1, 1, 0.35 if timed_out else 1.0)
	ui["cause_time"].modulate = Color(1, 1, 1, 1.0 if timed_out else 0.35)
	ui["end_title"].text = "The curse is lifted" if won else "The Keep remains cursed"
	ui["end_reason"].text = "All three Seals are restored." if won else ("Midnight: turn %d ended before the last Seal was restored." % Config.TURN_LIMIT if timed_out else "Your Health reached 0. The Cursed Knight caught you one time too many.")
	ui["end_again"].text = "Play again" if won else "Try again"
	ui["end_footer"].text = "You escaped Blackthorn Keep." if won else ""
	ui["end_footer"].visible = won
	var best: String = ("    Best on %s: %d turns" % [Config.DIFFICULTY[game.difficulty]["name"], profile.best_turns[game.difficulty]]) if profile.best_turns.has(game.difficulty) else ""
	ui["end_stats"].text = "[b]%s[/b] on %s    Turns: %d of %d%s\nSeals restored: %d of 3    Times found: %d    Damage taken: %d\nShards found: %d    Noise made: %d    Keep shifts: %d" % [
		Config.HEROES[game.hero]["name"], Config.DIFFICULTY[game.difficulty]["name"], turns, Config.TURN_LIMIT, best,
		game.seals_restored(), s["found"], s["damage"], s["shards"], s["noise_made"], s["keep_shifts"]]
	var tip := ""
	if not won:
		if timed_out:
			tip = "Try a different route: aim to restore a Seal about every 11 turns, and Search rooms on your way between Seals."
		elif s["found"] >= 3:
			tip = "Try a different route: the Knight found you %d times. Keep Noise below %d so it can't hear you, and leave hatched rooms it can see." % [s["found"], game.diff["hunt_at"]]
		else:
			tip = "Try a different route: with 1 Health left, use your hero item or a Smoke Vial to escape an encounter instead of rolling."
	ui["end_tip"].text = tip
	ui["end_tip"].visible = tip != ""
	ui["end_unlocks"].text = ("Unlocked: " + ", ".join(PackedStringArray(unlocks))) if not unlocks.is_empty() else ""
	ui["end_unlocks"].visible = not unlocks.is_empty()
	ui["end_log"].text = "Every Knight decision this run is saved to " + ProjectSettings.globalize_path(LOG_PATH)
	knight_log.append("")
	knight_log.append("RESULT: %s on turn %d" % ["WIN" if won else "LOSS", turns])
	_write_log()
	_show("end")


func _hero_names() -> Dictionary:
	var d := {}
	for h in Config.HERO_ORDER:
		d[h] = Config.HEROES[h]["name"]
	return d
