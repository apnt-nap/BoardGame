extends Control
## Screens, HUD and event playback. All rules live in scripts/core; this file only shows them.

const Config = preload("res://scripts/core/config.gd")
const Game = preload("res://scripts/core/game.gd")
const P = preload("res://scripts/ui/palette.gd")
const Board = preload("res://scripts/ui/board_view.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const Profile = preload("res://scripts/ui/profile.gd")
const Art = preload("res://scripts/ui/art.gd")
const DiceView = preload("res://scripts/ui/dice_view.gd")

const LOG_PATH := "user://knight_log.txt"

var profile = Profile.new()
var sfx
var game
var board
var sel_hero := "ranger"
var sel_diff := "normal"
var pending := {}          # card waiting for a room click: {i, mode}
var queue: Array = []
var busy := false
var knight_log: Array = []
var ui := {}

var menu_root: Control
var game_root: Control
var end_root: Control
var overlay: Control


func _ready() -> void:
	profile.load_profile()
	sfx = Sfx.new()
	add_child(sfx)
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = P.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_menu()
	_build_game()
	_build_end()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_show("menu")


# ================================================================== theme / helpers

func _box(color: Color, border: Color = P.BORDER, radius: int = 8, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 17
	th.set_stylebox("normal", "Button", _box(P.PANEL_LIGHT))
	th.set_stylebox("hover", "Button", _box(P.PANEL_LIGHT.lightened(0.12), P.GOLD))
	th.set_stylebox("pressed", "Button", _box(P.GOLD.darkened(0.55), P.GOLD))
	th.set_stylebox("disabled", "Button", _box(P.PANEL, Color(P.BORDER, 0.4)))
	th.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), P.GOLD))
	th.set_color("font_color", "Button", P.TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", P.GOLD)
	th.set_color("font_disabled_color", "Button", Color(P.TEXT_DIM, 0.45))
	th.set_color("font_color", "Label", P.TEXT)
	th.set_stylebox("panel", "PanelContainer", _box(P.PANEL))
	th.set_color("default_color", "RichTextLabel", P.TEXT)
	return th


func _label(text: String, size_px: int = 17, color: Color = P.TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func():
		sfx.play("click")
		cb.call())
	return b


func _art_rect(name: String, min_size: Vector2, dim: float = 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = min_size
	t.clip_contents = true
	t.modulate = Color(dim, dim, dim)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _set_icon(b: Button, name: String, max_w: int) -> void:
	b.icon = Art.tex(name)
	b.expand_icon = b.icon != null
	b.add_theme_constant_override("icon_max_width", max_w)


func _vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _panel(child: Control, color: Color = P.PANEL, border: Color = P.BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(color, border))
	p.add_child(child)
	return p


func _margin(child: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc


func _show(screen: String) -> void:
	menu_root.visible = screen == "menu"
	game_root.visible = screen == "game" or screen == "end"
	end_root.visible = screen == "end"
	if screen == "menu":
		_refresh_menu()


# ================================================================== menu

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)
	var backdrop := _art_rect("map", Vector2.ZERO, 0.28)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var col := _vbox(14)
	col.custom_minimum_size = Vector2(1100, 0)
	center.add_child(col)

	col.add_child(_label("CURSE OF", 30, P.TEXT))
	col.add_child(_label("BLACKTHORN KEEP", 64, P.GOLD))
	col.add_child(_label("Restore the three Seals before midnight. The Cursed Knight is listening.", 19, P.TEXT_DIM))
	col.add_child(HSeparator.new())

	col.add_child(_label("Choose your hero", 22, P.TEXT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	var group := ButtonGroup.new()
	ui["hero_buttons"] = {}
	for h in Config.HERO_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(355, 104)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_icon(b, P.HERO_ART.get(h, ""), 120)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func():
			sfx.play("click")
			sel_hero = h
			_refresh_menu())
		grid.add_child(b)
		ui["hero_buttons"][h] = b

	col.add_child(_label("Difficulty: changes only what the Knight senses", 22, P.TEXT))
	var drow := _hbox(10)
	col.add_child(drow)
	var dgroup := ButtonGroup.new()
	ui["diff_buttons"] = {}
	for d in Config.DIFFICULTY_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = dgroup
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(355, 74)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func():
			sfx.play("click")
			sel_diff = d
			_refresh_menu())
		drow.add_child(b)
		ui["diff_buttons"][d] = b

	var row := _hbox(12)
	col.add_child(row)
	var start := _button("ENTER THE KEEP", _start_game, 300)
	start.custom_minimum_size.y = 56
	start.add_theme_font_size_override("font_size", 22)
	row.add_child(start)
	row.add_child(_button("How to play", func(): ui["howto"].visible = not ui["howto"].visible, 180))
	ui["mute"] = _button("Sound: on", _toggle_mute, 150)
	row.add_child(ui["mute"])
	ui["profile_label"] = _label("", 15, P.TEXT_DIM)
	row.add_child(ui["profile_label"])

	var how := RichTextLabel.new()
	how.bbcode_enabled = true
	how.fit_content = true
	how.custom_minimum_size = Vector2(1100, 0)
	how.text = _howto_text()
	ui["howto"] = _panel(how)
	ui["howto"].visible = false
	col.add_child(ui["howto"])


func _howto_text() -> String:
	return ("[b][color=#d9a441]Goal[/color][/b]  Restore Seals A, B and C (2 Rune Shards each) before your Health hits 0 or Turn %d ends.\n" % Config.TURN_LIMIT) + \
		"[b][color=#d9a441]Each turn[/color][/b]  You hold 2 cards: play 1, the other is discarded. [b]Search[/b] rooms for Shards, [b]Activate[/b] a Seal with 2 Shards (it always works). Any card can be played face-down as a [b]Sneak[/b]: move 1 room silently, or keep still (Noise -1). Once per run you may redraw your hand for free.\n" + \
		"[b][color=#d9a441]Noise[/color][/b]  Dash, failed Searches and running make Noise and drop the orange token where it happened. The Knight walks to the token. At high Noise it hears exactly where you are.\n" + \
		"[b][color=#d9a441]The Knight[/color][/b]  Its icon shows its mind: [color=#8a8f9e]~ Patrol[/color], [color=#e0b040]? Investigate[/color], [color=#e5383b]! Hunt[/color], [color=#c77dff]?! Search[/color]. The arrow is its next step. Red-tinted rooms are in its line of sight.\n" + \
		"[b][color=#d9a441]Rooms[/color][/b]  Chapel heals, Bell Tower lures it away, Armory gives a treasure, Secret Passages link two corners. Restoring a Seal shifts the Keep; the second Seal corrupts two special rooms.\n" + \
		"[b][color=#d9a441]Keys[/color][/b]  1 / 2 play a card, Esc cancels, F1 shows the Knight's mind (debug), M mutes."


func _refresh_menu() -> void:
	for h in Config.HERO_ORDER:
		var b: Button = ui["hero_buttons"][h]
		var info: Dictionary = Config.HEROES[h]
		var unlocked: bool = profile.hero_unlocked(h)
		b.disabled = not unlocked
		b.modulate = Color.WHITE if unlocked else Color(0.6, 0.6, 0.65)
		b.text = ("%s  -  %s\n%s" % [info["name"], info["item_name"], info["text"]]) if unlocked else ("%s  (locked)\nUnlock: %s" % [info["name"], info["unlock"]])
		b.button_pressed = sel_hero == h
	for d in Config.DIFFICULTY_ORDER:
		var b: Button = ui["diff_buttons"][d]
		var info: Dictionary = Config.DIFFICULTY[d]
		var unlocked: bool = profile.difficulty_unlocked(d)
		b.disabled = not unlocked
		var desc := ("moves every turn" if info.get("fixed_move", false) else "moves on %d+" % info["move_min"]) + ", sight %d, hunts at Noise %d" % [info["sight"], info["hunt_at"]]
		b.text = ("%s\n%s" % [info["name"], desc]) if unlocked else "%s (locked)\nWin on Normal to unlock" % info["name"]
		b.button_pressed = sel_diff == d
	var best := ""
	for d in profile.best_turns:
		best += "  best %s: %d turns" % [Config.DIFFICULTY[d]["name"], profile.best_turns[d]]
	ui["profile_label"].text = "Runs %d  |  Wins %d%s" % [profile.games, profile.wins, best]


func _toggle_mute() -> void:
	sfx.muted = not sfx.muted
	ui["mute"].text = "Sound: off" if sfx.muted else "Sound: on"


# ================================================================== game screen

func _build_game() -> void:
	game_root = Control.new()
	game_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_root)
	var row := _hbox(18)
	var m := _margin(row, 18)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_root.add_child(m)

	board = Board.new()
	board.custom_minimum_size = Vector2(740, 740)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.room_clicked.connect(_on_room_clicked)
	row.add_child(board)

	var side := _vbox(10)
	side.custom_minimum_size.x = 640
	row.add_child(side)

	# Status bar.
	var status := _hbox(8)
	side.add_child(_panel(status))
	status.add_child(_art_rect("tok_turn", Vector2(30, 30)))
	ui["turn"] = _label("", 20, P.TEXT)
	status.add_child(ui["turn"])
	status.add_child(_art_rect("tok_health", Vector2(30, 30)))
	ui["health"] = _pips(Config.MAX_HEALTH, P.BLOOD)
	status.add_child(_titled("Health", ui["health"]))
	status.add_child(_art_rect("tok_noise", Vector2(30, 30)))
	ui["noise"] = _pips(Config.MAX_NOISE, P.EMBER)
	status.add_child(_titled("Noise", ui["noise"]))
	status.add_child(_art_rect("tok_shards", Vector2(30, 30)))
	ui["shards"] = _label("", 20, P.SPIRIT)
	status.add_child(_titled("Shards", ui["shards"]))
	ui["redraw"] = _label("", 20, P.GOLD)
	status.add_child(_titled("Redraw", ui["redraw"]))
	ui["seals"] = _hbox(6)
	for i in 3:
		var l := _label(char(65 + i), 20, P.SEAL_COLORS[i])
		l.custom_minimum_size = Vector2(30, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui["seals"].add_child(l)
	status.add_child(_titled("Seals", ui["seals"]))

	# Knight intent.
	var kb := _vbox(4)
	ui["knight_panel"] = _panel(kb)
	side.add_child(ui["knight_panel"])
	ui["knight_state"] = _label("", 20, P.TEXT)
	kb.add_child(ui["knight_state"])
	ui["knight_reason"] = _label("", 15, P.TEXT_DIM, true)
	kb.add_child(ui["knight_reason"])
	ui["danger"] = _label("", 15, P.BLOOD, true)
	kb.add_child(ui["danger"])

	# Room + items.
	var rb := _hbox(10)
	side.add_child(_panel(rb))
	var rinfo := _vbox(2)
	rinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.add_child(rinfo)
	ui["room_name"] = _label("", 19, P.TEXT)
	rinfo.add_child(ui["room_name"])
	ui["room_text"] = _label("", 14, P.TEXT_DIM, true)
	rinfo.add_child(ui["room_text"])
	ui["room_btn"] = _button("Use room", _on_room_action, 150)
	rb.add_child(ui["room_btn"])

	var items := _hbox(8)
	side.add_child(items)
	ui["hero_btn"] = _button("", _on_hero_item, 200)
	ui["hero_btn"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items.add_child(ui["hero_btn"])
	ui["treasure_btns"] = []
	for i in Config.MAX_TREASURES:
		var idx: int = i
		var tb := _button("", func(): _on_treasure(idx), 200)
		tb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		items.add_child(tb)
		ui["treasure_btns"].append(tb)

	# Hand.
	var hand := _hbox(10)
	side.add_child(hand)
	ui["cards"] = []
	for i in 2:
		var idx: int = i
		var cv := _vbox(6)
		var card := _panel(cv, P.PANEL_LIGHT, P.GOLD.darkened(0.4))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 250
		hand.add_child(card)
		var art := _art_rect("", Vector2(0, 84))
		cv.add_child(art)
		var title := _label("", 22, P.GOLD)
		cv.add_child(title)
		var text := _label("", 14, P.TEXT_DIM, true)
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(text)
		var play := _button("Play", func(): _on_card(idx, "normal"))
		cv.add_child(play)
		var sneak_row := _hbox(6)
		cv.add_child(sneak_row)
		var smove := _button("Sneak: move", func(): _on_card(idx, "sneak_move"))
		smove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sneak_row.add_child(smove)
		var squiet := _button("Sneak: still", func(): _on_card(idx, "sneak_quiet"))
		squiet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sneak_row.add_child(squiet)
		# Knight hero only: Activate paying 1 Shard with the Rune Key.
		var keyb := _button("Play with Rune Key (1 Shard)", func(): _on_card(idx, "rune_key"))
		keyb.visible = false
		cv.add_child(keyb)
		ui["cards"].append({"panel": card, "art": art, "title": title, "text": text, "play": play, "key": keyb, "move": smove, "quiet": squiet})

	var frow := _hbox(10)
	side.add_child(frow)
	ui["redraw_btn"] = _button("Free redraw (once per run)", _on_redraw, 220)
	frow.add_child(ui["redraw_btn"])
	ui["hint"] = _label("", 15, P.GOLD, true)
	ui["hint"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(ui["hint"])

	var log := RichTextLabel.new()
	log.bbcode_enabled = true
	log.scroll_following = true
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.custom_minimum_size.y = 120
	ui["log"] = log
	var lp := _panel(log)
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(lp)

	# Encounter modal.
	var enc_center := CenterContainer.new()
	enc_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	enc_center.mouse_filter = Control.MOUSE_FILTER_STOP
	game_root.add_child(enc_center)
	var ev := _vbox(12)
	ev.custom_minimum_size.x = 560
	var ep := _panel(_margin(ev, 10), Color("1d0f14"), P.BLOOD)
	enc_center.add_child(ep)
	ev.add_child(_art_rect(P.ENCOUNTER_ART["header"], Vector2(0, 150)))
	ev.add_child(_label("THE CURSED KNIGHT FOUND YOU!", 30, P.BLOOD))
	ui["enc_text"] = _label("", 16, P.TEXT_DIM, true)
	ev.add_child(ui["enc_text"])
	ui["enc_opts"] = _vbox(8)
	ev.add_child(ui["enc_opts"])
	ui["encounter"] = enc_center
	enc_center.visible = false

	# Debug overlay (F1).
	var dbg := _label("", 14, P.TEXT, true)
	dbg.custom_minimum_size.x = 520
	var dp := _panel(dbg, Color(0, 0, 0, 0.82), P.STATE_COLORS["SEARCH"])
	dp.position = Vector2(30, 30)
	dp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dp.visible = false
	game_root.add_child(dp)
	ui["debug"] = dp
	ui["debug_text"] = dbg


func _pips(n: int, color: Color) -> HBoxContainer:
	var h := _hbox(4)
	for i in n:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(18, 18)
		c.color = color
		h.add_child(c)
	h.set_meta("color", color)
	return h


func _set_pips(h: HBoxContainer, value: int, marker: int = -1) -> void:
	var col: Color = h.get_meta("color")
	for i in h.get_child_count():
		var c: ColorRect = h.get_child(i)
		c.color = col if i < value else Color(col, 0.15)
		if i == marker - 1:
			c.color = c.color.lightened(0.25) if i < value else Color(P.BLOOD, 0.45)
			c.custom_minimum_size = Vector2(18, 24)
		else:
			c.custom_minimum_size = Vector2(18, 18)


func _titled(title: String, child: Control) -> VBoxContainer:
	var v := _vbox(2)
	v.add_child(_label(title, 12, P.TEXT_DIM))
	v.add_child(child)
	return v


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
	board.game = game
	board.room_names = names
	board.targets = []
	board.place("player", game.player_room, true)
	board.place("knight", game.knight.room, true)
	board.place("spirit", game.spirit_room, true)
	pending = {}
	queue = []
	busy = false
	ui["log"].clear()
	knight_log = ["Curse of Blackthorn Keep - Knight decision log",
		"Hero: %s   Difficulty: %s   Seed: %d" % [Config.HEROES[sel_hero]["name"], Config.DIFFICULTY[sel_diff]["name"], game.rng.seed],
		"Senses on this difficulty: %s" % str(Config.DIFFICULTY[sel_diff]), ""]
	_show("game")
	await get_tree().process_frame
	board.place("player", game.player_room, true)
	board.place("knight", game.knight.room, true)
	board.place("spirit", game.spirit_room, true)
	_after_action()


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
		await get_tree().create_timer(0.8).timeout
		_show_end()


func _sync_pieces() -> void:
	board.place("player", game.player_room)
	board.place("knight", game.knight.room)
	board.place("spirit", game.spirit_room)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _log(text: String, color: Color = P.TEXT) -> void:
	if text == "":
		return
	ui["log"].append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


func _handle(e: Dictionary) -> void:
	var t: String = e["type"]
	match t:
		"move":
			board.place("player", e["to"])
			sfx.play("move")
			await _wait(0.22)
		"spirit_move":
			board.place("spirit", e["to"])
		"knight":
			if e["text"] != "":
				knight_log.append(e["text"])
				_log("Knight: " + e["text"].substr(e["text"].find("]") + 2), P.STATE_COLORS.get(e["state"], P.TEXT_DIM))
			if e.get("roll", 0) > 0:
				await _knight_die(e["roll"], e["roll"] >= e["need"])
			for r in e["path"]:
				board.place("knight", r)
				sfx.play("knight_step")
				await _wait(0.32)
			if e["path"].is_empty():
				await _wait(0.15)
		"dice":
			_log(e["text"], P.HEAL if e["ok"] else P.EMBER)
			await _roll_dice(e["roll"], e["ok"], e["text"])
		"noise":
			sfx.play("noise")
			board.pulse(e["room"], 0.8)
			_float_text(e["room"], "NOISE %d" % game.noise if game.noise >= 0 else "", P.EMBER)
			_log(e["text"], P.EMBER)
			await _wait(0.25)
		"quiet":
			sfx.play("quiet")
			_log(e["text"], P.SPIRIT)
		"damage":
			sfx.play("damage")
			board.shake = 1.0
			board.flash = Color(P.BLOOD, 0.45)
			_float_text(game.player_room, "-1 HEALTH", P.BLOOD)
			_log(e["text"], P.BLOOD)
			await _wait(0.6)
		"block":
			sfx.play("good")
			_float_text(game.player_room, "BLOCKED", P.GOLD)
			_log(e["text"], P.GOLD)
			await _wait(0.4)
		"heal":
			sfx.play("heal")
			_float_text(game.player_room, "+1 HEALTH", P.HEAL)
			_log(e["text"], P.HEAL)
			await _wait(0.4)
		"encounter":
			sfx.play("encounter")
			board.shake = 0.7
			board.flash = Color(P.BLOOD, 0.3)
			_log(e["text"], P.BLOOD)
			await _wait(0.4)
		"hidden":
			sfx.play("good")
			_float_text(game.player_room, "UNSEEN", P.SPIRIT)
			_log(e["text"], P.SPIRIT)
			await _wait(0.4)
		"shriek":
			sfx.play("shriek")
			board.flash = Color(P.SPIRIT, 0.25)
			_float_text(game.spirit_room, "SHRIEK!", P.SPIRIT)
			_log(e["text"], P.SPIRIT)
			await _wait(0.4)
		"seal":
			sfx.play("seal")
			board.flash = Color(P.SEAL_COLORS[e["seal"]], 0.35)
			_float_text(game.player_room, "SEAL %s RESTORED" % char(65 + e["seal"]), P.SEAL_COLORS[e["seal"]])
			_log(e["text"], P.GOLD)
			await _wait(0.8)
		"shift":
			sfx.play("shift")
			board.shake = 0.5
			for k in [e["closed"], e["opened"]]:
				for part in k.split("_"):
					board.pulse(int(part), 2.0)
			_log(e["text"], P.GOLD)
			await _wait(0.7)
		"corrupt":
			sfx.play("bad")
			_log(e["text"], Color("b07cd0"))
			await _wait(0.5)
		"bell", "signal":
			sfx.play("bell")
			board.pulse(e["room"], 1.5)
			_log(e["text"], P.GOLD)
			await _wait(0.4)
		"shard":
			sfx.play("good")
			_float_text(game.player_room, "+%d SHARD" % e["amount"], P.SPIRIT)
		"treasure", "armory", "hero", "escape", "passage", "redraw", "spirit":
			sfx.play("good" if t != "spirit" else "click")
			_log(e["text"], P.GOLD)
		"won":
			sfx.play("win")
			_log(e["text"], P.GOLD)
		"lost":
			sfx.play("lose")
			_log(e["text"], P.BLOOD)
		"turn":
			_log("- " + e["text"], P.TEXT_DIM)
			if game.castle.distance(game.player_room, game.knight.room) <= 1:
				sfx.play("heartbeat")
		"card":
			sfx.play("card")
			_log(e["text"], P.TEXT)
		_:
			_log(e["text"], P.TEXT_DIM)


func _float_text(room: int, text: String, color: Color) -> void:
	if room < 0 or text == "":
		return
	var l := _label(text, 22, color)
	l.add_theme_color_override("font_outline_color", P.BG)
	l.add_theme_constant_override("outline_size", 6)
	overlay.add_child(l)
	l.position = board.global_position + board.room_center(room) - Vector2(60, 30)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## Big die in the middle of the board for the player's rolls, with the outcome under it.
func _roll_dice(roll: int, ok: bool, text: String) -> void:
	var d := DiceView.new()
	d.size = Vector2(120, 120)
	d.sfx = sfx
	overlay.add_child(d)
	d.position = board.global_position + board.size * 0.5 - d.size * 0.5
	d.pivot_offset = d.size * 0.5
	await d.roll_to(roll, P.HEAL if ok else P.BLOOD, 0.75)
	var l := _label(text.get_slice(":", 1).strip_edges() if text.contains(":") else text, 22, P.HEAL if ok else P.BLOOD, true)
	l.add_theme_color_override("font_outline_color", P.BG)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(520, 0)
	overlay.add_child(l)
	l.position = d.position + Vector2(d.size.x * 0.5 - 260, d.size.y + 22)
	await _wait(0.9)
	for n in [d, l]:
		var tw: Tween = n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.25)
		tw.tween_callback(n.queue_free)
	await _wait(0.15)


## Small red die beside the Knight: its move-or-stay roll.
func _knight_die(roll: int, moves: bool) -> void:
	if not board._pos.has("knight"):
		return
	var d := DiceView.new()
	d.size = Vector2(54, 54)
	d.body = Color("7a1d24")
	d.pip = Color("f5e6d0")
	d.edge = Color("3a0d12")
	d.sfx = sfx
	overlay.add_child(d)
	var kp: Vector2 = board._pos["knight"]
	var side := 28.0 if kp.x < board.size.x * 0.6 else -28.0 - d.size.x
	d.position = board.global_position + kp + Vector2(side, -70)
	d.pivot_offset = d.size * 0.5
	await d.roll_to(roll, P.BLOOD if moves else P.TEXT_DIM, 0.4)
	var l := _label("moves" if moves else "stays", 16, P.BLOOD if moves else P.TEXT_DIM)
	l.add_theme_color_override("font_outline_color", P.BG)
	l.add_theme_constant_override("outline_size", 6)
	overlay.add_child(l)
	l.position = d.position + Vector2(0, d.size.y + 2)
	await _wait(0.35)
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
	return game != null and not busy and game.phase == "player" and game_root.visible and not end_root.visible


func _on_card(i: int, mode: String) -> void:
	if not _can_act() or not game.can_play(i, mode):
		return
	var card: String = game.hand[i]
	if game.needs_target(card, mode):
		pending = {"i": i, "mode": mode}
		board.targets = game.move_options(card, mode)
		_refresh()
		return
	pending = {}
	board.targets = []
	game.play_card(i, mode)
	_after_action()


func _on_room_clicked(r: int) -> void:
	if pending.is_empty() or not _can_act():
		return
	if not (r in board.targets):
		return
	var p := pending
	pending = {}
	board.targets = []
	if game.play_card(p["i"], p["mode"], r):
		_after_action()
	else:
		_refresh()


func _on_room_action() -> void:
	if _can_act() and game.do_room_action():
		_after_action()


func _on_hero_item() -> void:
	if game != null and not busy and game.use_hero_item():
		_after_action()


func _on_treasure(i: int) -> void:
	if game != null and not busy and game.use_treasure(i):
		_after_action()


func _on_redraw() -> void:
	if _can_act() and game.redraw_hand():
		pending = {}
		board.targets = []
		_after_action()


func _on_encounter(choice: String) -> void:
	if game == null or busy or game.phase != "encounter":
		return
	if game.resolve_encounter(choice):
		_after_action()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			if board.game != null:
				board.show_debug = not board.show_debug
				ui["debug"].visible = board.show_debug
				_refresh()
		KEY_ESCAPE:
			pending = {}
			board.targets = []
			if game != null:
				_refresh()
		KEY_1:
			_on_card(0, "normal")
		KEY_2:
			_on_card(1, "normal")
		KEY_M:
			_toggle_mute()


# ================================================================== refresh

func _refresh() -> void:
	if game == null:
		return
	var act := _can_act()
	ui["turn"].text = "Turn %d / %d" % [mini(game.turn, Config.TURN_LIMIT), Config.TURN_LIMIT]
	ui["turn"].add_theme_color_override("font_color", P.BLOOD if game.turns_left() <= 5 else P.TEXT)
	_set_pips(ui["health"], game.health)
	_set_pips(ui["noise"], game.noise, game.diff["hunt_at"])
	ui["shards"].text = str(game.shards)
	ui["redraw"].text = "Ready" if game.redraw_ready else "Used"
	for i in 3:
		var l: Label = ui["seals"].get_child(i)
		l.text = char(65 + i) + ("*" if game.restored[i] else "")
		l.add_theme_color_override("font_color", P.SEAL_COLORS[i] if game.restored[i] else Color(P.SEAL_COLORS[i], 0.45))

	var k = game.knight
	var kc: Color = P.STATE_COLORS[k.state]
	ui["knight_state"].text = "Cursed Knight:  %s %s" % [P.STATE_ICON[k.state], k.state]
	ui["knight_state"].add_theme_color_override("font_color", kc)
	ui["knight_reason"].text = k.reason
	ui["knight_panel"].add_theme_stylebox_override("panel", _box(P.PANEL, kc.darkened(0.3)))
	var kd: int = game.castle.distance(game.player_room, k.room)
	ui["danger"].text = "" if kd > 1 else ("It is in your room!" if kd == 0 else "Heavy footsteps right next door...")

	var here: int = game.player_room
	var sp: String = game.castle.special_at(here)
	var si: int = game.castle.seal_index(here)
	var rname: String = board.room_names[here]
	if si >= 0:
		rname = "Seal %s" % char(65 + si)
	elif game.castle.specials.has(here):
		rname = Config.SPECIALS[game.castle.specials[here]]["name"]
	ui["room_name"].text = "%s  (%s)" % [rname, game.room_name(here)]
	var rt := ""
	if si >= 0:
		rt = "Restored." if game.restored[si] else ("Activate here with 2 Shards (1 with the Rune Key)." if game.rune_key_ready else "Activate here with 2 Shards.")
	elif game.castle.corrupted.has(here):
		rt = "Corrupted: its power is gone."
	elif sp != "":
		rt = Config.SPECIALS[sp]["text"]
	else:
		rt = "Already searched." if game.searched.has(here) else "Unsearched: Rune Shards may be hidden here."
	if game.search_bonus > 0:
		rt += "  Next Search +1."
	ui["room_text"].text = rt
	var ra: String = game.room_action()
	ui["room_btn"].text = {"chapel": "Pray (+1 Health)","bell_tower": "Ring the bell", "armory": "Search rack", "passage": "Take passage"}.get(ra, "Use room")
	ui["room_btn"].disabled = not act or ra == ""

	var hi: Dictionary = Config.HEROES[game.hero]
	var hero_ready: bool = game.hero_item_ready or (hi["item"] == "rune_key" and game.rune_key_ready)
	ui["hero_btn"].text = "%s%s" % [hi["item_name"], "" if hero_ready else " (used)"]
	ui["hero_btn"].tooltip_text = hi["text"]
	_set_icon(ui["hero_btn"], P.ITEM_ART.get(hi["item"], P.HERO_ART.get(game.hero, "")), 36)
	ui["hero_btn"].disabled = busy or not game.can_use_hero_item()
	for i in Config.MAX_TREASURES:
		var tb: Button = ui["treasure_btns"][i]
		if i < game.treasures.size():
			var t: String = game.treasures[i]
			tb.text = Config.TREASURE_INFO[t]["name"]
			tb.tooltip_text = Config.TREASURE_INFO[t]["text"]
			_set_icon(tb, P.ITEM_ART.get(t, ""), 36)
			tb.disabled = busy or not game.can_use_treasure(t)
		else:
			tb.text = "(empty pack slot)"
			tb.icon = null
			tb.tooltip_text = ""
			tb.disabled = true

	for i in 2:
		var cui: Dictionary = ui["cards"][i]
		if i < game.hand.size():
			var c: String = game.hand[i]
			cui["title"].text = Config.CARDS[c]["name"]
			cui["art"].texture = Art.tex(P.CARD_ART.get(c, ""))
			cui["text"].text = Config.CARDS[c]["text"]
			cui["play"].disabled = not act or not game.can_play(i, "normal")
			cui["key"].visible = c == "activate" and game.rune_key_ready
			cui["key"].disabled = not act or not game.can_play(i, "rune_key")
			cui["move"].disabled = not act
			cui["quiet"].disabled = not act
			var selected: bool = not pending.is_empty() and pending["i"] == i
			cui["panel"].add_theme_stylebox_override("panel", _box(P.PANEL_LIGHT, P.GOLD if selected else P.GOLD.darkened(0.4)))
		else:
			cui["title"].text = ""
			cui["text"].text = ""
			cui["art"].texture = null
			cui["key"].visible = false
			for key in ["play", "move", "quiet"]:
				cui[key].disabled = true
	ui["redraw_btn"].disabled = not act or not game.can_redraw()
	ui["redraw_btn"].text = "Free redraw (once per run)" if game.redraw_ready else "Redraw used this run"
	if not pending.is_empty():
		ui["hint"].text = "Click a highlighted room (Esc to cancel)."
	elif busy:
		ui["hint"].text = "The Keep stirs..."
	elif act:
		ui["hint"].text = "Your move. Play one card; the other is discarded."
	else:
		ui["hint"].text = ""

	var enc: bool = game.phase == "encounter" and not busy
	ui["encounter"].visible = enc
	if enc:
		ui["enc_text"].text = "Health %d. Noise %d. Choose quickly." % [game.health, game.noise]
		for ch in ui["enc_opts"].get_children():
			ch.queue_free()
		for o in game.encounter_options():
			var id: String = o["id"]
			var b := _button("%s   -   %s" % [o["label"], o["text"]], func(): _on_encounter(id))
			b.custom_minimum_size.y = 64
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_set_icon(b, P.ENCOUNTER_ART.get(id, P.ITEM_ART.get(id, P.ENCOUNTER_ART["item"])), 90)
			ui["enc_opts"].add_child(b)
		var extras := _hbox(8)
		if game.can_use_hero_item():
			extras.add_child(_button("Use " + hi["item_name"] + " first", _on_hero_item))
		for i in game.treasures.size():
			var idx: int = i
			if game.can_use_treasure(game.treasures[i]):
				extras.add_child(_button("Use " + Config.TREASURE_INFO[game.treasures[i]]["name"] + " first", func(): _on_treasure(idx)))
		ui["enc_opts"].add_child(extras)

	if board.show_debug:
		var lines: Array = k.debug_lines()
		lines.append("Senses now: Noise %d, token %s (#%d), sight %d" % [game.noise, game.room_name(game.token), game.token_serial, game.diff["sight"]])
		lines.append("")
		lines.append("Recent decisions:")
		var tail: Array = k.log_lines.slice(maxi(0, k.log_lines.size() - 8))
		lines.append_array(tail)
		lines.append("")
		lines.append("Full log: " + ProjectSettings.globalize_path(LOG_PATH))
		ui["debug_text"].text = "\n".join(PackedStringArray(lines))


# ================================================================== end screen

func _build_end() -> void:
	end_root = CenterContainer.new()
	end_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(end_root)
	var v := _vbox(12)
	v.custom_minimum_size.x = 620
	end_root.add_child(_panel(_margin(v, 16), Color(0.06, 0.05, 0.08, 0.96), P.GOLD))
	ui["end_title"] = _label("", 44, P.GOLD)
	v.add_child(ui["end_title"])
	ui["end_reason"] = _label("", 17, P.TEXT_DIM, true)
	v.add_child(ui["end_reason"])
	ui["end_stats"] = _label("", 18, P.TEXT, true)
	v.add_child(ui["end_stats"])
	ui["end_unlocks"] = _label("", 20, P.GOLD, true)
	v.add_child(ui["end_unlocks"])
	ui["end_log"] = _label("", 13, P.TEXT_DIM, true)
	v.add_child(ui["end_log"])
	var row := _hbox(10)
	v.add_child(row)
	row.add_child(_button("Play again", _start_game, 200))
	row.add_child(_button("Main menu", func(): _show("menu"), 200))
	end_root.visible = false


func _show_end() -> void:
	var won: bool = game.phase == "won"
	var turns: int = mini(game.turn, Config.TURN_LIMIT)
	var unlocks: Array = profile.record(game.hero, game.difficulty, won, turns, _hero_names())
	ui["end_title"].text = "THE CURSE IS BROKEN" if won else "LOST IN BLACKTHORN"
	ui["end_title"].add_theme_color_override("font_color", P.GOLD if won else P.BLOOD)
	ui["end_reason"].text = game.end_reason
	var s: Dictionary = game.stats
	ui["end_stats"].text = "Hero: %s  |  %s\nTurns: %d of %d\nDamage taken: %d\nTimes the Knight found you: %d\nNoise made: %d   Shards found: %d   Keep shifts: %d\nSeals restored: %d / 3" % [
		Config.HEROES[game.hero]["name"], Config.DIFFICULTY[game.difficulty]["name"], turns, Config.TURN_LIMIT,
		s["damage"], s["found"], s["noise_made"], s["shards"], s["keep_shifts"], game.seals_restored()]
	ui["end_unlocks"].text = ("Unlocked: " + ", ".join(PackedStringArray(unlocks))) if not unlocks.is_empty() else ""
	ui["end_log"].text = "Every Knight decision this run: " + ProjectSettings.globalize_path(LOG_PATH)
	knight_log.append("")
	knight_log.append("RESULT: %s on turn %d" % ["WIN" if won else "LOSS", turns])
	_write_log()
	_show("end")


func _hero_names() -> Dictionary:
	var d := {}
	for h in Config.HERO_ORDER:
		d[h] = Config.HEROES[h]["name"]
	return d
