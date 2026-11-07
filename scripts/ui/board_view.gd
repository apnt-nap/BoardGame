extends Control
## Draws the Keep from the game state with flat vector shapes. Pieces glide between rooms.

signal room_clicked(room: int)

const P = preload("res://scripts/ui/palette.gd")
const Config = preload("res://scripts/core/config.gd")
const Art = preload("res://scripts/ui/art.gd")

var game                       # scripts/core/game.gd instance
var room_names: Array = []
var targets: Array = []        # rooms the player may click right now
var show_debug := false
var reveal_path: Array = []    # Library reveal of the Knight's route
var hovered := -1
var shake := 0.0
var flash := Color(0, 0, 0, 0)

var _pos := {}                 # piece -> current pixel centre
var _goal := {}                # piece -> room it is gliding to
var _time := 0.0
var _pulse_rooms := {}
var _off := Vector2.ZERO        # screen-shake offset for this frame         # room -> remaining pulse time (keep-shift / bell highlight)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func cell() -> float:
	return minf(size.x, size.y) / 5.0


func origin() -> Vector2:
	var s := minf(size.x, size.y)
	return (size - Vector2(s, s)) * 0.5


func room_rect(r: int) -> Rect2:
	var c := cell()
	var p := Vector2(r % 5, r / 5) * c + origin()
	var pad := c * 0.09
	return Rect2(p + Vector2(pad, pad), Vector2(c - pad * 2, c - pad * 2))


func room_center(r: int) -> Vector2:
	return room_rect(r).get_center()


func room_at(point: Vector2) -> int:
	var local := point - origin()
	var c := cell()
	var x := int(floor(local.x / c))
	var y := int(floor(local.y / c))
	if x < 0 or y < 0 or x > 4 or y > 4:
		return -1
	return y * 5 + x


## Snap or glide a piece to a room.
func place(piece: String, r: int, snap: bool = false) -> void:
	_goal[piece] = r
	if snap or not _pos.has(piece):
		_pos[piece] = _piece_target(piece, r)


func pulse(r: int, t: float = 1.2) -> void:
	_pulse_rooms[r] = t


func _piece_target(piece: String, r: int) -> Vector2:
	var c := room_center(r)
	var o := cell() * 0.2
	match piece:
		"player":
			return c + Vector2(-o, o * 0.6)
		"knight":
			return c + Vector2(o, -o * 0.3)
		"spirit":
			return c + Vector2(-o * 0.9, -o * 0.9)
	return c


func is_animating() -> bool:
	for piece in _goal:
		if _pos[piece].distance_to(_piece_target(piece, _goal[piece])) > 2.0:
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	for piece in _goal:
		var t := _piece_target(piece, _goal[piece])
		_pos[piece] = _pos[piece].lerp(t, minf(1.0, delta * 9.0))
	shake = maxf(0.0, shake - delta * 2.5)
	flash.a = maxf(0.0, flash.a - delta * 1.6)
	for r in _pulse_rooms.keys():
		_pulse_rooms[r] -= delta
		if _pulse_rooms[r] <= 0.0:
			_pulse_rooms.erase(r)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = room_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var r := room_at(event.position)
		if r >= 0:
			room_clicked.emit(r)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and game != null:
		for piece in _goal:
			_pos[piece] = _piece_target(piece, _goal[piece])


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if game == null:
		return
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0
	_off = off
	draw_set_transform(off)
	var castle = game.castle
	var font := ThemeDB.fallback_font
	var c := cell()
	var sight: int = game.diff["sight"]
	var kdist: Array = castle.distances(game.knight.room)

	# Corridors (doorways) under the rooms.
	var w := c * 0.22
	for r in 25:
		for g in castle.neighbors(r):
			if g > r:
				var a := room_center(r)
				var b := room_center(g)
				var rect := Rect2(a, Vector2.ZERO).expand(b).grow(w * 0.5)
				draw_rect(rect, P.DOOR)

	for r in 25:
		var rect := room_rect(r)
		var corrupted: bool = castle.corrupted.has(r)
		var fill: Color = P.ROOM
		if corrupted:
			fill = P.ROOM_CORRUPT
		elif game.searched.has(r):
			fill = P.ROOM_SEARCHED
		draw_rect(rect, fill)
		var tile := _room_tile(r)
		if tile != null:
			var shade := Color(0.72, 0.70, 0.74)
			if corrupted:
				shade = Color(0.22, 0.14, 0.28)
			elif game.searched.has(r):
				shade = Color(0.42, 0.40, 0.45)
			draw_texture_rect_region(tile, rect, _cover_src(tile, rect.size), shade)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 26)), Color(0, 0, 0, 0.6))
		# Knight's line of sight.
		if sight > 0 and kdist[r] >= 0 and kdist[r] <= sight:
			draw_rect(rect, P.SIGHT)
		if _pulse_rooms.has(r):
			draw_rect(rect, Color(P.GOLD, 0.25 * _pulse_rooms[r]))
		var edge: Color = P.ROOM_EDGE
		if r in targets:
			edge = P.TARGET.lerp(Color.WHITE, 0.3 + 0.3 * sin(_time * 6.0))
			draw_rect(rect, Color(P.TARGET, 0.10))
		elif r == hovered:
			edge = P.TEXT_DIM
		draw_rect(rect, edge, false, 3.0 if r in targets else 1.5)
		# Name + coordinate.
		var name_text: String = room_names[r] if r < room_names.size() else ""
		var sp: String = castle.specials.get(r, "")
		var si: int = castle.seal_index(r)
		if si >= 0:
			name_text = "Seal %s" % char(65 + si)
		elif sp != "":
			name_text = Config.SPECIALS[sp]["name"]
		draw_string(font, rect.position + Vector2(8, 18), name_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40, 14, P.TEXT_DIM if not corrupted else Color(P.TEXT_DIM, 0.4))
		draw_string(font, rect.position + Vector2(rect.size.x - 30, 18), game.room_name(r), HORIZONTAL_ALIGNMENT_RIGHT, 24, 12, Color(P.TEXT_DIM, 0.6))
		if si >= 0:
			_draw_seal(rect.get_center() + Vector2(0, c * 0.05), c * 0.22, si, game.restored[si])
		elif sp != "":
			if tile != null:
				draw_circle(rect.get_center() + Vector2(0, c * 0.08), c * 0.2, Color(0, 0, 0, 0.55))
			_draw_special(rect.get_center() + Vector2(0, c * 0.08), c * 0.13 if tile != null else c * 0.16, sp, corrupted)
		if game.searched.has(r) and si < 0:
			draw_string(font, rect.position + Vector2(8, rect.size.y - 8), "searched", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(P.TEXT_DIM, 0.5))
		if corrupted:
			draw_string(font, rect.position + Vector2(8, rect.size.y - 8), "CORRUPTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8a3fa0"))

	# Noise token.
	if game.token >= 0:
		var tc := room_rect(game.token).position + Vector2(c * 0.7, c * 0.66)
		var pr := 1.0 + 0.15 * sin(_time * 5.0)
		draw_circle(tc, c * 0.09 * pr, Color(P.EMBER, 0.35))
		draw_circle(tc, c * 0.06, P.EMBER)
		draw_string(font, tc + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_CENTER, 8, 14, P.BG)

	# Knight planned route (debug) / Library reveal.
	var kstate: String = game.knight.state
	var kcol: Color = P.STATE_COLORS[kstate]
	var route: Array = game.knight.plan if show_debug else reveal_path
	if not route.is_empty():
		var pts := PackedVector2Array([room_center(game.knight.room)])
		for r in route:
			pts.append(room_center(r))
		draw_polyline(pts, Color(kcol, 0.7), 3.0)
		for p in pts:
			draw_circle(p, 4, Color(kcol, 0.8))

	# Knight intent arrow: where it is heading next.
	if _goal.has("knight") and game.phase == "player":
		var step: int = game.knight.next_step()
		if step != game.knight.room:
			var a2: Vector2 = _pos["knight"]
			var b2 := room_center(step)
			var dir := (b2 - a2).normalized()
			var tip := a2 + dir * c * 0.55
			draw_line(a2 + dir * c * 0.18, tip, Color(kcol, 0.85), 4.0)
			var side := dir.orthogonal() * c * 0.07
			draw_colored_polygon(PackedVector2Array([tip + dir * c * 0.08, tip + side, tip - side]), Color(kcol, 0.85))

	# Pieces.
	if _pos.has("spirit"):
		var sp2: Vector2 = _pos["spirit"] + Vector2(0, sin(_time * 2.5) * 3.0)
		draw_circle(sp2, c * 0.11, Color(P.SPIRIT, 0.18))
		draw_circle(sp2, c * 0.07, Color(P.SPIRIT, 0.55))
		draw_circle(sp2 + Vector2(-4, -2), 2.5, P.BG)
		draw_circle(sp2 + Vector2(4, -2), 2.5, P.BG)
	var player_tex := Art.tex(P.PLAYER_ART)
	var knight_tex := Art.tex(P.KNIGHT_ART)
	if _pos.has("player"):
		var pp: Vector2 = _pos["player"]
		if player_tex != null:
			_draw_mini(player_tex, pp, c * 0.5, P.GOLD)
		else:
			draw_circle(pp, c * 0.13, Color(P.GOLD, 0.25))
			draw_circle(pp, c * 0.1, P.GOLD)
			var initial: String = Config.HEROES[game.hero]["name"].substr(0, 1)
			draw_string(font, pp + Vector2(-10, 7), initial, HORIZONTAL_ALIGNMENT_CENTER, 20, 20, P.BG)
	if _pos.has("knight") and knight_tex != null:
		var kp2: Vector2 = _pos["knight"]
		if kstate == "HUNT":
			draw_circle(kp2, c * 0.24 * (1.0 + 0.1 * sin(_time * 10.0)), Color(kcol, 0.22))
		_draw_mini(knight_tex, kp2, c * 0.56, kcol)
		draw_string(font, kp2 + Vector2(-20, -c * 0.34), P.STATE_ICON[kstate], HORIZONTAL_ALIGNMENT_CENTER, 40, 24, kcol)
		if game.knight.skip_turns > 0:
			draw_string(font, kp2 + Vector2(-30, c * 0.3), "dazzled", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, P.GOLD)
	elif _pos.has("knight"):
		var kp: Vector2 = _pos["knight"]
		var s := c * 0.14
		if kstate == "HUNT":
			draw_circle(kp, s * (1.5 + 0.15 * sin(_time * 10.0)), Color(kcol, 0.25))
		var shield := PackedVector2Array([kp + Vector2(-s, -s), kp + Vector2(s, -s), kp + Vector2(s, s * 0.2), kp + Vector2(0, s * 1.25), kp + Vector2(-s, s * 0.2)])
		draw_colored_polygon(shield, P.BLOOD)
		shield.append(shield[0])
		draw_polyline(shield, kcol, 3.0)
		draw_rect(Rect2(kp + Vector2(-s * 0.55, -s * 0.2), Vector2(s * 1.1, s * 0.22)), Color("ff9e8a"))
		draw_string(font, kp + Vector2(-20, -s * 1.3), P.STATE_ICON[kstate], HORIZONTAL_ALIGNMENT_CENTER, 40, 22, kcol)
		if game.knight.skip_turns > 0:
			draw_string(font, kp + Vector2(-30, s * 2.1), "dazzled", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, P.GOLD)

	draw_set_transform(Vector2.ZERO)
	if flash.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), flash)


## A painted room tile per room: Seals and some specials have their own, the rest vary by seed.
func _room_tile(r: int) -> Texture2D:
	var si: int = game.castle.seal_index(r)
	if si >= 0:
		return Art.tex(P.SEAL_ROOM_ART[si])
	var sp: String = game.castle.specials.get(r, "")
	if P.SPECIAL_ROOM_ART.has(sp):
		return Art.tex(P.SPECIAL_ROOM_ART[sp])
	return Art.tex(P.ROOM_ART[posmod(r * 7 + int(game.rng.seed % 1000), P.ROOM_ART.size())])


## Source rect that fills `target` without stretching (like CSS background-size: cover).
func _cover_src(tex: Texture2D, target: Vector2) -> Rect2:
	var ts := tex.get_size()
	var scale := maxf(target.x / ts.x, target.y / ts.y)
	var src_size := target / scale
	return Rect2((ts - src_size) * 0.5, src_size)


## Miniature standing on its base, with a coloured ring for state.
func _draw_mini(tex: Texture2D, foot: Vector2, height: float, ring: Color) -> void:
	var ts := tex.get_size()
	var h := height
	var w := ts.x / ts.y * h
	var base := foot + Vector2(0, h * 0.28)
	draw_set_transform(_off + base, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, w * 0.48, Color(0, 0, 0, 0.55))
	draw_arc(Vector2.ZERO, w * 0.5, 0, TAU, 32, ring, 4.0)
	draw_set_transform(_off)
	draw_texture_rect(tex, Rect2(base - Vector2(w * 0.5, h * 0.95), Vector2(w, h)), false)


func _draw_seal(center: Vector2, rad: float, idx: int, restored: bool) -> void:
	var col: Color = P.SEAL_COLORS[idx]
	var spin := _time * (1.0 if restored else 0.2)
	var token := Art.tex(P.SEAL_TOKEN_ART[idx])
	if token != null:
		if restored:
			draw_circle(center, rad * (1.3 + 0.08 * sin(_time * 3.0)), Color(col, 0.35))
		draw_texture_rect(token, Rect2(center - Vector2(rad, rad) * 1.1, Vector2(rad, rad) * 2.2), false, Color.WHITE if restored else Color(0.55, 0.55, 0.6))
		draw_arc(center, rad * 1.15, spin, spin + TAU * (0.75 if restored else 0.25), 32, Color(col, 0.9 if restored else 0.5), 3.0)
		return
	if restored:
		draw_circle(center, rad * (1.25 + 0.08 * sin(_time * 3.0)), Color(col, 0.25))
		draw_circle(center, rad, Color(col, 0.8))
	else:
		draw_circle(center, rad, Color(col, 0.12))
	draw_arc(center, rad, 0, TAU, 40, col, 3.0)
	draw_arc(center, rad * 0.7, spin, spin + TAU * 0.75, 24, Color(col, 0.7), 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-12, 9), char(65 + idx), HORIZONTAL_ALIGNMENT_CENTER, 24, 26, P.TEXT if not restored else P.BG)


func _draw_special(center: Vector2, s: float, type: String, corrupted: bool) -> void:
	var col: Color = P.SPECIAL_COLORS[type]
	if corrupted:
		col = Color("4a2f55")
	if P.ICON_TEXTURES.has(type):
		var tex: Texture2D = load(P.ICON_TEXTURES[type])
		draw_texture_rect(tex, Rect2(center - Vector2(s, s), Vector2(s, s) * 2.0), false, Color.WHITE if not corrupted else Color(0.3, 0.3, 0.3))
		return
	match type:
		"chapel":
			draw_rect(Rect2(center + Vector2(-s * 0.12, -s), Vector2(s * 0.24, s * 2.0)), col)
			draw_rect(Rect2(center + Vector2(-s * 0.6, -s * 0.45), Vector2(s * 1.2, s * 0.24)), col)
		"library":
			draw_rect(Rect2(center + Vector2(-s, -s * 0.6), Vector2(s * 0.95, s * 1.2)), col)
			draw_rect(Rect2(center + Vector2(s * 0.05, -s * 0.6), Vector2(s * 0.95, s * 1.2)), col.darkened(0.2))
			draw_line(center + Vector2(0, -s * 0.6), center + Vector2(0, s * 0.6), P.BG, 2.0)
		"bell_tower":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.35, -s * 0.8), center + Vector2(s * 0.35, -s * 0.8), center + Vector2(s * 0.8, s * 0.6), center + Vector2(-s * 0.8, s * 0.6)]), col)
			draw_circle(center + Vector2(0, s * 0.8), s * 0.2, col)
		"armory":
			draw_line(center + Vector2(-s * 0.8, s * 0.8), center + Vector2(s * 0.8, -s * 0.8), col, 4.0)
			draw_line(center + Vector2(s * 0.8, s * 0.8), center + Vector2(-s * 0.8, -s * 0.8), col, 4.0)
			draw_circle(center, s * 0.18, col)
		"passage":
			draw_arc(center, s * 0.8, 0, TAU * 0.8, 24, col, 3.0)
			draw_arc(center, s * 0.45, PI, PI + TAU * 0.7, 18, col, 3.0)
			draw_circle(center, s * 0.12, col)
