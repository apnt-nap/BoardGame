extends Control
## Draws the Keep from the game state in the storybook style: stone rooms with thick ink
## outlines, wooden doorways, crystal shrines for the Seals and one prop per special room.
## It only reads state. Overlays show public information only (see game.knight_public()).

signal room_clicked(room: int)
signal room_hovered(room: int)
signal cancel_requested

const P = preload("res://scripts/ui/palette.gd")
const Config = preload("res://scripts/core/config.gd")
const Art = preload("res://scripts/ui/art.gd")
const Icon = preload("res://scripts/ui/icon.gd")

var game                       # scripts/core/game.gd instance
var room_names: Array = []
var targets: Array = []        # rooms the player may click right now
var show_debug := false
var hovered := -1
var shake := 0.0
var flash := Color(0, 0, 0, 0)
var vignette := 0.0            # red screen-edge glow after damage
var dim := false               # encounter: everything but your room is darkened
var reduced_motion := false
var knight_dust := 0.0         # victory: 0 = whole, 1 = crumbled

var _pos := {}                 # piece -> current pixel centre
var _goal := {}                # piece -> room it is gliding to
var _time := 0.0
var _pulse_rooms := {}         # room -> [remaining time, colour]
var _ripples: Array = []       # [room, age, colour]
var _flares := {}              # room -> remaining time (Seal restored)
var _off := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


func cell() -> float:
	return minf(size.x, size.y) / 5.0


func origin() -> Vector2:
	var s := minf(size.x, size.y)
	return (size - Vector2(s, s)) * 0.5


func room_rect(r: int) -> Rect2:
	var c := cell()
	var p := Vector2(r % 5, r / 5) * c + origin()
	var pad := 0.0 if _board_art() else c * 0.035  # painted cells share their walls
	return Rect2(p + Vector2(pad, pad), Vector2(c - pad * 2, c - pad * 2))


func _board_art() -> bool:
	return Art.tex(P.BOARD_SEAL_RING[0]) != null and Art.tex("wall_h_solid") != null


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
	if snap or reduced_motion or not _pos.has(piece):
		_pos[piece] = _piece_target(piece, r)


func pulse(r: int, t: float = 1.2, col: Color = P.AMBER) -> void:
	_pulse_rooms[r] = [t, col]


func ripple(r: int, col: Color) -> void:
	if r >= 0:
		_ripples.append([r, 0.0, col])


func flare(r: int) -> void:
	_flares[r] = 1.4


func _piece_target(piece: String, r: int) -> Vector2:
	var c := room_center(r)
	var o := cell() * 0.2
	match piece:
		"player":
			return c + Vector2(-o * 0.9, o * 1.5)
		"knight":
			return c + Vector2(o * 0.95, o * 1.5)
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
		_pos[piece] = t if reduced_motion else _pos[piece].lerp(t, minf(1.0, delta * 10.0))
	shake = 0.0 if reduced_motion else maxf(0.0, shake - delta * 2.5)
	flash.a = maxf(0.0, flash.a - delta * 1.6)
	vignette = maxf(0.0, vignette - delta * 1.2)
	for r in _pulse_rooms.keys():
		_pulse_rooms[r][0] -= delta
		if _pulse_rooms[r][0] <= 0.0:
			_pulse_rooms.erase(r)
	for rp in _ripples:
		rp[1] += delta
	_ripples = _ripples.filter(func(rp): return rp[1] < 1.2)
	for r in _flares.keys():
		_flares[r] -= delta
		if _flares[r] <= 0.0:
			_flares.erase(r)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := room_at(event.position)
		if h != hovered:
			hovered = h
			room_hovered.emit(h)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var r := room_at(event.position)
			if r >= 0:
				room_clicked.emit(r)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and game != null:
		for piece in _goal:
			_pos[piece] = _piece_target(piece, _goal[piece])
	elif what == NOTIFICATION_MOUSE_EXIT:
		if hovered != -1:
			hovered = -1
			room_hovered.emit(-1)


# ------------------------------------------------------------------ drawing

func _wave(speed: float) -> float:
	return 0.0 if reduced_motion else sin(_time * speed)


func _draw() -> void:
	if game == null:
		return
	_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 9.0
	draw_set_transform(_off)
	var castle = game.castle
	var c := cell()
	var body := Art.body_font()
	var head := Art.heading_font()
	var sight: int = game.diff["sight"]
	var o := origin()
	var grid := Rect2(o, Vector2(c, c) * 5.0)

	# Castle wall around the rooms.
	_round_rect(grid.grow(c * 0.04), P.STONE_DARK, c * 0.08)
	_round_rect(grid.grow(c * 0.04), P.INK, c * 0.08, false, 4.0)

	# Doorways: wooden-floor corridors under the rooms, with ink edges (old look only).
	var w := room_rect(0).size.x * 0.125
	var painted := _board_art()
	for r in (0 if painted else 25):
		for g in castle.neighbors(r):
			if g > r:
				var a := room_center(r)
				var b := room_center(g)
				var rect := Rect2(a, Vector2.ZERO).expand(b).grow(w * 0.5)
				draw_rect(rect, P.INK)
				draw_rect(rect.grow(-2.0), P.DOORWAY)

	var kp_info: Dictionary = game.knight_public()
	if painted:
		for r in 25:
			_draw_board_cell(r)
		_draw_board_walls(castle, c)
	for r in 25:
		_draw_room(r, c, body, head, sight, castle)

	# Legal destinations: dashed gold outline and the number of steps.
	var dist: Array = castle.distances(game.player_room) if not targets.is_empty() else []
	for r in targets:
		var rect := room_rect(r).grow(-3.0)
		var bright := 0.7 + 0.3 * _wave(5.0)
		_dashed_rect(rect, Color(P.AMBER, bright), 4.0 if r == hovered else 3.0)
		draw_rect(rect, Color(P.AMBER, 0.12 if r != hovered else 0.22))
		var badge := rect.position + Vector2(rect.size.x - c * 0.13, rect.size.y - c * 0.13)
		draw_circle(badge, c * 0.1, P.AMBER)
		draw_arc(badge, c * 0.1, 0, TAU, 20, P.INK, 2.0)
		draw_string(head, badge + Vector2(-c * 0.1, c * 0.055), str(dist[r]), HORIZONTAL_ALIGNMENT_CENTER, c * 0.2, int(c * 0.14), P.INK)

	# Footprints along the path to the hovered destination.
	if hovered in targets:
		var path: Array = castle.path(game.player_room, hovered)
		var prev: Vector2 = room_center(game.player_room)
		for r in path:
			var nxt := room_center(r)
			for k in 3:
				var p := prev.lerp(nxt, (k + 1) / 4.0)
				Icon.draw_icon(self, "footprints", p, c * 0.08, Color(P.AMBER, 0.95))
			prev = nxt

	# Noise marker: an orange pin with "!".
	if game.token >= 0:
		var tr := room_rect(game.token)
		var tc := tr.position + Vector2(tr.size.x * 0.82, tr.size.y * 0.36)
		var bob := 2.0 * _wave(4.0)
		Icon.draw_icon(self, "marker", tc + Vector2(0, bob), c * 0.12, P.NOISE)

	# Seal signal: violet ripple and a "signal" tag until the Knight reaches it.
	var sr: int = game.knight.signal_room
	if sr >= 0:
		var sc := room_center(sr)
		for k in 2:
			var ph := fmod(_time * 0.6 + k * 0.5, 1.0) if not reduced_motion else 0.5
			draw_arc(sc, c * (0.2 + 0.25 * ph), 0, TAU, 32, Color(P.CRYSTAL_LIGHT, 0.9 * (1.0 - ph)), 3.0)
		_tag(room_rect(sr).position + Vector2(room_rect(sr).size.x * 0.5, c * 0.15), "signal", P.CRYSTAL, body, c)

	# Ripples (noise, bell).
	for rp in _ripples:
		var t: float = rp[1] / 1.2
		draw_arc(room_center(rp[0]), c * (0.1 + 0.45 * t), 0, TAU, 32, Color(rp[2], 1.0 - t), 4.0)

	# Knight planned route (debug overlay only, F1 in debug builds).
	var kstate: String = game.knight.state
	var kcol: Color = P.STATE_COLORS[kstate]
	if show_debug and not game.knight.plan.is_empty():
		var pts := PackedVector2Array([room_center(game.knight.room)])
		for r in game.knight.plan:
			pts.append(room_center(r))
		draw_polyline(pts, Color(kcol, 0.7), 3.0)

	# Knight heading arrow: only when its target is public (decision C).
	if _goal.has("knight") and game.phase == "player" and (kp_info["arrow"] or show_debug):
		var step: int = game.knight.next_step()
		if step != game.knight.room:
			var a2: Vector2 = room_center(game.knight.room)
			var b2 := room_center(step)
			var dir := (b2 - a2).normalized()
			var base := a2 + dir * c * 0.36
			var tip := a2 + dir * c * 0.62
			var side := dir.orthogonal() * c * 0.09
			var arrow := PackedVector2Array([tip, base + side, base + side * 0.4, a2 + dir * c * 0.22 + side * 0.4, a2 + dir * c * 0.22 - side * 0.4, base - side * 0.4, base - side])
			Icon._poly(self, arrow, Color(kcol, 0.95), P.INK, 2.5)

	# Pieces.
	if _pos.has("player"):
		var pp: Vector2 = _pos["player"]
		var ptex := Art.tex(P.HERO_ART.get(game.hero, ""))
		if ptex != null:
			_draw_mini(ptex, pp, c * 0.48, P.AMBER)
		else:
			draw_circle(pp, c * 0.13, P.AMBER)
			draw_arc(pp, c * 0.13, 0, TAU, 24, P.INK, 3.0)
	if _pos.has("knight"):
		var kp: Vector2 = _pos["knight"]
		var ktex := Art.tex(P.KNIGHT_ART)
		var a := 1.0 - knight_dust
		if kstate == "HUNT" and knight_dust <= 0.0:
			draw_circle(kp + Vector2(0, -c * 0.12), c * 0.26 * (1.0 + 0.08 * _wave(9.0)), Color(kcol, 0.22))
		if ktex != null:
			_draw_mini(ktex, kp + Vector2(0, knight_dust * c * 0.15), c * 0.54, kcol, a)
		else:
			draw_circle(kp, c * 0.15, Color(P.KNIGHT_ARMOR, a))
			draw_arc(kp, c * 0.15, 0, TAU, 24, Color(kcol, a), 3.0)
		if knight_dust > 0.0:
			for k in 14:
				var ang := k * 2.4
				var dpos := kp + Vector2(cos(ang) * c * 0.25 * knight_dust, -c * 0.4 + sin(ang * 1.3) * c * 0.2 + knight_dust * c * 0.3)
				draw_circle(dpos, c * 0.02 * (1.5 - knight_dust), Color(P.STONE_LIGHT, 1.0 - knight_dust))
		elif game.phase != "won":
			# State badge: icon in a coloured disc, plus the word.
			var bp := kp + Vector2(c * 0.22, -c * 0.4)
			draw_circle(bp, c * 0.11, kcol)
			draw_arc(bp, c * 0.11, 0, TAU, 24, P.INK, 2.5)
			var icon_kind: String = {"PATROL": "patrol", "INVESTIGATE": "question", "HUNT": "eye", "SEARCH": "search"}[kstate]
			if kp_info["kind"] == "hear":
				icon_kind = "ear"
			elif kp_info["kind"] == "signal":
				icon_kind = "signal"
			Icon.draw_icon(self, icon_kind, bp, c * 0.07, P.INK)
			if game.knight.skip_turns > 0:
				for k in 3:
					var sp := kp + Vector2(-c * 0.15 + c * 0.15 * k, -c * 0.68 + 4.0 * _wave(6.0 + k))
					Icon.draw_icon(self, "star", sp, c * 0.05, P.KNIGHT_TRIM)
				_tag(kp + Vector2(-c * 0.3, -c * 0.12), "Stunned", P.GOLD_DARK, body, c)

	# Seal flare when a Seal is restored.
	for r in _flares:
		var t: float = 1.0 - _flares[r] / 1.4
		var fc := room_center(r)
		draw_circle(fc, c * (0.3 + 0.5 * t), Color(P.CRYSTAL_LIGHT, 0.45 * (1.0 - t)))
		for k in 8:
			var ang := TAU * k / 8.0 + t
			Icon.draw_icon(self, "star", fc + Vector2.from_angle(ang) * c * (0.2 + 0.4 * t), c * 0.05, Color(P.STARLIGHT, 1.0 - t), true, Color(0, 0, 0, 0))

	# Encounter: darken everything but your room.
	if dim:
		for r in 25:
			if r != game.player_room:
				draw_rect(room_rect(r).grow(c * 0.09), Color(P.NIGHT, 0.6))

	draw_set_transform(Vector2.ZERO)
	if flash.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), flash)
	if vignette > 0.0:
		var vw := size.x * 0.06
		for k in 4:
			var col := Color(P.HEALTH, 0.35 * vignette * (1.0 - k / 4.0))
			var g := vw * (k + 1) / 4.0
			draw_rect(Rect2(Vector2.ZERO, size), col, false, g)


func _draw_room(r: int, c: float, body: Font, head: Font, sight: int, castle) -> void:
	var rect := room_rect(r)
	var corrupted: bool = castle.corrupted.has(r)
	var searched: bool = game.searched.has(r)
	var sp: String = castle.specials.get(r, "")
	var si: int = castle.seal_index(r)
	var floor_col: Color = P.FLOOR
	if si >= 0:
		floor_col = P.NIGHT_3.lerp(P.FLOOR, 0.35)
	elif sp == "chapel":
		floor_col = Color("5e5672")
	elif sp == "passage":
		floor_col = Color("3f5560")
	if corrupted:
		floor_col = Color("2e2240")
	if _board_art():
		_draw_room_overlays(r, rect, c, body, sight, castle, corrupted, searched, sp, si, true)
		return
	var tile := Art.tex(P.ROOM_TILES[0 if (si >= 0 or sp != "") else posmod(r * 7 + int(game.rng.seed % 1000), P.ROOM_TILES.size())])
	if tile != null:
		var mod := Color.WHITE
		if corrupted:
			mod = Color(0.45, 0.35, 0.55)
		elif si >= 0:
			mod = Color(0.82, 0.76, 1.0)
		elif sp == "chapel":
			mod = Color(1.0, 0.93, 0.8)
		elif sp == "passage":
			mod = Color(0.75, 0.95, 0.95)
		elif searched:
			mod = Color(0.72, 0.72, 0.78)
		draw_texture_rect(tile, rect, false, mod)
		_close_walls(r, rect, tile, mod, castle)
	else:
		_draw_plain_room(rect, floor_col, c)
	if searched and si < 0 and tile == null:
		draw_rect(rect, Color(P.NIGHT, 0.25))
	_draw_room_overlays(r, rect, c, body, sight, castle, corrupted, searched, sp, si, tile != null)


## Which painted cell a room uses. Painted label = no name/prop drawn over it.
func _board_tile(r: int) -> String:
	var castle = game.castle
	var si: int = castle.seal_index(r)
	if si >= 0:
		return P.BOARD_SEAL_CRYSTAL[si] if game.restored[si] else P.BOARD_SEAL_RING[si]
	var sp: String = castle.specials.get(r, "")
	if sp == "passage":
		return P.BOARD_PASSAGE[0 if r == castle.passage[0] else 1]
	if sp != "":
		return P.BOARD_SPECIAL[sp]
	if r == game.start_room:
		return P.BOARD_ENTRY
	var keys: Array = P.BOARD_ROOMS.keys()
	return keys[posmod(r * 7 + int(game.rng.seed % 1000), keys.size())]


func _board_labelled(r: int) -> bool:
	return not P.BOARD_ROOMS.has(_board_tile(r))


func _draw_board_cell(r: int) -> void:
	var tex := Art.tex(_board_tile(r))
	var rect := room_rect(r)
	var mod := Color.WHITE
	if game.castle.corrupted.has(r):
		mod = Color(0.5, 0.4, 0.6)
	elif game.searched.has(r):
		mod = Color(0.8, 0.8, 0.86)
	if tex != null:
		draw_texture_rect(tex, rect, false, mod)
	else:
		_draw_plain_room(rect, P.FLOOR, cell())


## The painted cells carry their own doorway gaps, so every shared wall gets a patch cut from the
## same painting: a doorway where the castle has a door, solid stone where it does not. Outer
## walls get the inner half of a solid patch.
func _draw_board_walls(castle, c: float) -> void:
	var hs := Art.tex("wall_h_solid")
	var hd := Art.tex("wall_h_door")
	var vs := Art.tex("wall_v_solid")
	var vd := Art.tex("wall_v_door")
	var half := c * P.BOARD_WALL_HALF
	var ln := c * P.BOARD_WALL_LEN
	var o := origin()
	for y in 5:
		for x in 5:
			var r := y * 5 + x
			var ctr := room_center(r)
			# Right wall of this cell (and the left outer wall for column 0).
			var rx := o.x + (x + 1) * c
			if x < 4:
				var door: bool = castle.has_door(r, r + 1)
				draw_texture_rect(vd if door else vs, Rect2(rx - half, ctr.y - ln * 0.5, half * 2, ln), false)
			else:
				draw_texture_rect_region(vs, Rect2(rx - half, ctr.y - ln * 0.5, half, ln), Rect2(0, 0, vs.get_width() * 0.5, vs.get_height()))
			if x == 0:
				draw_texture_rect_region(vs, Rect2(o.x, ctr.y - ln * 0.5, half, ln), Rect2(vs.get_width() * 0.5, 0, vs.get_width() * 0.5, vs.get_height()))
			# Bottom wall (and the top outer wall for row 0).
			var by := o.y + (y + 1) * c
			if y < 4:
				var door2: bool = castle.has_door(r, r + 5)
				draw_texture_rect(hd if door2 else hs, Rect2(ctr.x - ln * 0.5, by - half, ln, half * 2), false)
			else:
				draw_texture_rect_region(hs, Rect2(ctr.x - ln * 0.5, by - half, ln, half), Rect2(0, 0, hs.get_width(), hs.get_height() * 0.5))
			if y == 0:
				draw_texture_rect_region(hs, Rect2(ctr.x - ln * 0.5, o.y, ln, half), Rect2(0, hs.get_height() * 0.5, hs.get_width(), hs.get_height() * 0.5))


## Stone patches over the tile's doorway gaps on every side without a door.
func _close_walls(r: int, rect: Rect2, tile: Texture2D, mod: Color, castle) -> void:
	var ts := tile.get_size()
	var p: Vector2i = castle.pos(r)
	var sides := [[Vector2i(0, -1), "top"], [Vector2i(0, 1), "bottom"], [Vector2i(-1, 0), "left"], [Vector2i(1, 0), "right"]]
	var t := 0.105   # wall thickness
	var g0 := 0.42   # gap start (measured gap: 0.431-0.566 on the sides, 0.4375-0.5625 top/bottom)
	var gw := 0.16   # gap width, overlapping both edges so no light sliver shows
	var sx := 0.16   # where the patch is copied from (plain wall blocks)
	for sd in sides:
		var d: Vector2i = sd[0]
		var q := p + d
		var open: bool = q.x >= 0 and q.y >= 0 and q.x < 5 and q.y < 5 and castle.has_door(r, castle.idx(q.x, q.y))
		if open:
			continue
		var dst: Rect2
		var src: Rect2
		match sd[1]:
			"top":
				dst = Rect2(rect.position + Vector2(rect.size.x * g0, 0), Vector2(rect.size.x * gw, rect.size.y * t))
				src = Rect2(ts.x * sx, 0, ts.x * gw, ts.y * t)
			"bottom":
				dst = Rect2(rect.position + Vector2(rect.size.x * g0, rect.size.y * (1.0 - t)), Vector2(rect.size.x * gw, rect.size.y * t))
				src = Rect2(ts.x * sx, ts.y * (1.0 - t), ts.x * gw, ts.y * t)
			"left":
				dst = Rect2(rect.position + Vector2(0, rect.size.y * g0), Vector2(rect.size.x * t, rect.size.y * gw))
				src = Rect2(0, ts.y * sx, ts.x * t, ts.y * gw)
			_:
				dst = Rect2(rect.position + Vector2(rect.size.x * (1.0 - t), rect.size.y * g0), Vector2(rect.size.x * t, rect.size.y * gw))
				src = Rect2(ts.x * (1.0 - t), ts.y * sx, ts.x * t, ts.y * gw)
		draw_texture_rect_region(tile, dst, src, mod)


func _draw_plain_room(rect: Rect2, floor_col: Color, c: float) -> void:
	_round_rect(rect, floor_col, c * 0.06)
	# Flagstones.
	var rows := 3
	for k in range(1, rows):
		var y := rect.position.y + rect.size.y * k / rows
		draw_line(Vector2(rect.position.x + 4, y), Vector2(rect.end.x - 4, y), P.FLOOR_LINE, 2.0)
	for k in rows:
		var y0 := rect.position.y + rect.size.y * k / rows
		var y1 := rect.position.y + rect.size.y * (k + 1) / rows
		var shift := 0.5 if k % 2 == 0 else 0.25
		for m in 2:
			var x := rect.position.x + rect.size.x * (shift + 0.5 * m)
			if x < rect.end.x - 6:
				draw_line(Vector2(x, y0 + 2), Vector2(x, y1 - 2), P.FLOOR_LINE, 2.0)



func _draw_room_overlays(r: int, rect: Rect2, c: float, body: Font, sight: int, castle, corrupted: bool, searched: bool, sp: String, si: int, tiled: bool) -> void:
	var inset := rect.size.x * (0.1 if tiled else 0.0)
	# Knight's line of sight: hatched orange plus an eye.
	if sight > 0 and r != game.knight.room and castle.in_sight(game.knight.room, r, sight) and knight_dust <= 0.0:
		_hatch(rect, Color(P.SIGHT, 0.4))
		Icon.draw_icon(self, "eye", rect.position + Vector2(rect.size.x * 0.62, rect.size.y - c * 0.12), c * 0.08, P.SIGHT)
	if _pulse_rooms.has(r):
		var pr: Array = _pulse_rooms[r]
		draw_rect(rect, Color(pr[1], 0.35 * minf(1.0, pr[0])))
	if not tiled:
		# Thick ink outline with a light inner edge.
		_round_rect(rect, P.INK, c * 0.06, false, 3.0)
		draw_line(rect.position + Vector2(c * 0.07, 3), Vector2(rect.end.x - c * 0.07, rect.position.y + 3), Color(1, 1, 1, 0.12), 2.0)

	# Name and coordinate.
	var name_text: String = room_names[r] if r < room_names.size() else ""
	if si >= 0:
		name_text = "Seal %s%s" % [Config.SEAL_NAMES[si], ", restored" if game.restored[si] else ""]
	elif sp != "":
		name_text = Config.SPECIALS[sp]["name"]
	var fs := int(c * 0.115)
	var tc := P.STARLIGHT if not corrupted else Color(P.MOON_TEXT, 0.6)
	var name_w := rect.size.x - inset * 2.0 - c * 0.24
	var nfs := fs
	while nfs > int(fs * 0.7) and body.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > name_w:
		nfs -= 1  # shrink long names ("Scriptorium") instead of clipping them
	var np := rect.position + Vector2(inset + 5, inset + fs + 1)
	var painted := _board_art()
	var plaque: Array = P.BOARD_ROOMS.get(_board_tile(r), []) if painted else []
	if painted and _board_labelled(r):
		pass  # the painted label already names it
	elif not plaque.is_empty():
		# Dark text centred on the empty plaque, shrunk to fit.
		var pr := Rect2(rect.position + Vector2(plaque[0], plaque[1]) * rect.size, Vector2(plaque[2], plaque[3]) * rect.size)
		var pw := pr.size.x - 8.0
		var pfs := int(minf(fs, pr.size.y * 0.62))
		while pfs > 8 and body.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x > pw:
			pfs -= 1
		draw_string(body, Vector2(pr.position.x + 4, pr.get_center().y + pfs * 0.35), name_text, HORIZONTAL_ALIGNMENT_CENTER, pw, pfs, P.PARCHMENT if not corrupted else Color(P.MOON_TEXT, 0.6))
	else:
		draw_string_outline(body, np, name_text, HORIZONTAL_ALIGNMENT_LEFT, name_w, nfs, 5, Color(P.INK, 0.9))
		draw_string(body, np, name_text, HORIZONTAL_ALIGNMENT_LEFT, name_w, nfs, tc)
	var cp := Vector2(rect.end.x - inset - c * 0.22 - 4, np.y)
	if painted:
		cp.y = rect.end.y - inset - 4  # bottom-right: the painted labels and banners fill the top
	draw_string_outline(body, cp, game.room_name(r), HORIZONTAL_ALIGNMENT_RIGHT, c * 0.22, int(fs * 0.9), 4, Color(P.INK, 0.9))
	draw_string(body, cp, game.room_name(r), HORIZONTAL_ALIGNMENT_RIGHT, c * 0.22, int(fs * 0.9), P.MOON_TEXT)

	var mid := rect.get_center() + Vector2(0, c * 0.06)
	if painted:
		if si >= 0 and game.restored[si]:
			draw_circle(mid, c * (0.3 + 0.02 * _wave(3.0)), Color(P.CRYSTAL_LIGHT, 0.16))  # soft glow on a restored Seal
	elif si >= 0:
		_draw_shrine(mid, c, si, game.restored[si], body)
	elif sp != "":
		_draw_prop(mid, c * 0.2, sp, corrupted)
	if searched and si < 0:
		var sfs := int(fs * 0.85)
		var tp := rect.position + Vector2(inset + 5, rect.size.y - inset - 5)
		_outlined(body, tp, "searched", sfs, P.MOON_TEXT)
		var stamp := tp + Vector2(body.get_string_size("searched", HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x + c * 0.08, -sfs * 0.35)
		if not painted:
			stamp = rect.end - Vector2(inset + c * 0.1, inset + c * 0.1)
		Icon.draw_icon(self, "check", stamp, c * 0.07, Color(P.MOON_TEXT, 0.9))
	if corrupted:
		var cr := Color("b07cd0")
		draw_polyline(PackedVector2Array([rect.position + Vector2(rect.size.x * 0.2, 4), rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.4), rect.position + Vector2(rect.size.x * 0.28, rect.size.y * 0.6), rect.position + Vector2(rect.size.x * 0.45, rect.size.y - 4)]), cr, 2.0)
		draw_polyline(PackedVector2Array([rect.position + Vector2(rect.size.x - 4, rect.size.y * 0.3), rect.position + Vector2(rect.size.x * 0.7, rect.size.y * 0.45), rect.position + Vector2(rect.size.x * 0.75, rect.size.y * 0.7)]), cr, 2.0)
		_outlined(body, rect.position + Vector2(inset + 5, rect.size.y - inset - 5), "corrupted", int(fs * 0.85), cr)


## The crystal shrine. Unrestored: dim, empty sockets. Restored: bright, glowing, sockets lit.
func _draw_shrine(center: Vector2, c: float, idx: int, restored: bool, body: Font) -> void:
	var tex := Art.tex(P.SHRINE_RESTORED[idx] if restored else P.SHRINE_ARTS[idx])
	if tex == null:
		tex = Art.tex(P.SHRINE_ART)
	var h := c * 0.56
	if restored:
		draw_circle(center + Vector2(0, -h * 0.12), c * (0.3 + 0.02 * _wave(3.0)), Color(P.CRYSTAL_LIGHT, 0.28))
	if tex != null:
		var ts := tex.get_size()
		var wdt := ts.x / ts.y * h
		var r := Rect2(center - Vector2(wdt * 0.5, h * 0.55), Vector2(wdt, h))
		draw_texture_rect(tex, r, false, Color.WHITE if restored else Color(0.72, 0.7, 0.82))
	else:
		var col := P.CRYSTAL_LIGHT if restored else Color(0.45, 0.4, 0.55)
		Icon.draw_icon(self, "shard", center + Vector2(0, -h * 0.15), h * 0.4, col)
		draw_rect(Rect2(center + Vector2(-h * 0.3, h * 0.2), Vector2(h * 0.6, h * 0.22)), P.STONE_DARK)
	# Shape badge with the letter (shape, not colour, tells the Seals apart).
	var bp := center + Vector2(-c * 0.3, -c * 0.18)
	Icon.draw_icon(self, P.SEAL_SHAPES[idx], bp, c * 0.085, P.CRYSTAL_LIGHT if restored else Color(P.MOON_TEXT, 0.9))
	draw_string(Art.heading_font(), bp + Vector2(-c * 0.08, c * 0.04), Config.SEAL_NAMES[idx], HORIZONTAL_ALIGNMENT_CENTER, c * 0.16, int(c * 0.075), P.INK)


## One prop per special room, drawn in the same thick-outline style.
func _draw_prop(center: Vector2, s: float, type: String, corrupted: bool) -> void:
	var col: Color = P.SPECIAL_COLORS[type]
	if corrupted:
		col = Color("6a4f78")
	var ink := P.INK
	match type:
		"chapel":
			for k in 3:
				var x := center.x + (k - 1) * s * 0.7
				var hgt := s * (0.9 if k == 1 else 0.65)
				var base := center.y + s * 0.6
				var candle := Rect2(Vector2(x - s * 0.14, base - hgt), Vector2(s * 0.28, hgt))
				draw_rect(candle, col)
				draw_rect(candle, ink, false, 2.0)
				if not corrupted:
					var fl := Vector2(x, base - hgt - s * 0.2)
					draw_circle(fl, s * 0.22, Color(P.AMBER, 0.3))
					Icon._poly(self, PackedVector2Array([fl + Vector2(0, -s * 0.2), fl + Vector2(s * 0.1, s * 0.05), fl + Vector2(0, s * 0.12), fl + Vector2(-s * 0.1, s * 0.05)]), P.AMBER, ink, 1.5)
		"bell_tower":
			var bell := PackedVector2Array([center + Vector2(-s * 0.3, -s * 0.7), center + Vector2(s * 0.3, -s * 0.7), center + Vector2(s * 0.45, s * 0.1), center + Vector2(s * 0.8, s * 0.45), center + Vector2(-s * 0.8, s * 0.45), center + Vector2(-s * 0.45, s * 0.1)])
			Icon._poly(self, bell, col, ink, 2.5)
			draw_circle(center + Vector2(0, s * 0.62), s * 0.16, col)
			draw_arc(center + Vector2(0, s * 0.62), s * 0.16, 0, TAU, 16, ink, 2.0)
			draw_line(center + Vector2(0, -s * 0.7), center + Vector2(0, -s * 0.95), ink, 3.0)
		"armory":
			Icon.draw_icon(self, "shield", center + Vector2(0, s * 0.1), s * 0.55, Color("7a8ca0") if not corrupted else col)
			for k in 2:
				var d := 1.0 if k == 0 else -1.0
				var a := center + Vector2(-s * 0.9 * d, s * 0.8)
				var b := center + Vector2(s * 0.8 * d, -s * 0.9)
				draw_line(a, b, ink, 6.0)
				draw_line(a, b, col, 3.0)
		"passage":
			for k in 3:
				var rr := s * (0.25 + 0.27 * k)
				draw_arc(center, rr, k * 1.2, k * 1.2 + TAU * 0.7, 24, col, 3.0)
			draw_circle(center, s * 0.12, col)


func _draw_mini(tex: Texture2D, foot: Vector2, height: float, ring: Color, alpha: float = 1.0) -> void:
	var ts := tex.get_size()
	var h := height
	var w := ts.x / ts.y * h
	draw_set_transform(_off + foot, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, w * 0.5, Color(0, 0, 0, 0.45 * alpha))
	draw_arc(Vector2.ZERO, w * 0.52, 0, TAU, 32, Color(ring, alpha), 5.0)
	draw_set_transform(_off)
	draw_texture_rect(tex, Rect2(foot - Vector2(w * 0.5, h * 0.95), Vector2(w, h)), false, Color(1, 1, 1, alpha))


## Small parchment tag with text, used for "You", "signal", "restored", "Stunned".
func _tag(pos: Vector2, text: String, col: Color, font: Font, c: float) -> void:
	var fs := int(c * 0.1)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(pos, Vector2(tw + 10, fs + 6))
	_round_rect(r, P.PARCHMENT, 5.0)
	_round_rect(r, P.INK, 5.0, false, 1.5)
	draw_string(font, pos + Vector2(5, fs + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _round_rect(r: Rect2, col: Color, radius: float, fill: bool = true, width: float = 1.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(radius))
	if fill:
		sb.bg_color = col
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = col
		sb.set_border_width_all(int(width))
	draw_style_box(sb, r)


func _dashed_rect(r: Rect2, col: Color, width: float) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	var dash := 12.0
	var phase := 0.0 if reduced_motion else fmod(_time * 20.0, dash * 2.0)
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[k + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var t := -phase
		while t < length:
			var s0 := maxf(0.0, t)
			var s1 := minf(length, t + dash)
			if s1 > s0:
				draw_line(a + dir * s0, a + dir * s1, col, width)
			t += dash * 2.0


func _hatch(r: Rect2, col: Color) -> void:
	var step := 12.0
	var k := -r.size.y
	while k < r.size.x:
		# Line x - y = k inside the rect, clipped.
		var p0 := Vector2(maxf(0.0, k), maxf(0.0, -k))
		var x1 := minf(r.size.x, k + r.size.y)
		var p1 := Vector2(x1, x1 - k)
		if p0.x < p1.x:
			draw_line(r.position + p0, r.position + p1, col, 2.0)
		k += step


func _outlined(font: Font, pos: Vector2, text: String, fs: int, col: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(P.INK, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
