extends Control
## Small storybook icons drawn in code (thick dark outline, flat fill). Every state in the game
## has a shape as well as a colour, so nothing depends on colour alone.
## Use: var i = Icon.make("heart", Color.RED, 24)

const P = preload("res://scripts/ui/palette.gd")

var kind := "heart"
var color := Color.WHITE
var filled := true
var outline := P.INK


static func make(p_kind: String, p_color: Color, px: float = 24.0, p_filled: bool = true) -> Control:
	var i = load("res://scripts/ui/icon.gd").new()
	i.kind = p_kind
	i.color = p_color
	i.filled = p_filled
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func set_icon(p_kind: String, p_color: Color, p_filled: bool = true) -> void:
	kind = p_kind
	color = p_color
	filled = p_filled
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) * 0.5
	draw_icon(self, kind, size * 0.5, s, color, filled, outline)


## Shared with the board so pieces and badges use the same shapes.
static func draw_icon(ci: CanvasItem, k: String, c: Vector2, s: float, col: Color, fill: bool = true, ink: Color = Color("2a2238")) -> void:
	var w := maxf(1.5, s * 0.16)
	var body := col if fill else Color(col, 0.18)
	match k:
		"heart":
			var pts := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y) * s / 17.0)
			_poly(ci, pts, body, ink, w)
		"shard":
			_poly(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.62, -s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.62, -s * 0.2)]), body, ink, w)
			ci.draw_line(c + Vector2(-s * 0.62, -s * 0.2), c + Vector2(s * 0.62, -s * 0.2), Color(ink, 0.6), w * 0.6)
		"noise":
			ci.draw_circle(c + Vector2(-s * 0.55, 0), s * 0.22, col)
			for i in 3:
				var r := s * (0.45 + 0.3 * i)
				ci.draw_arc(c + Vector2(-s * 0.55, 0), r, -0.8, 0.8, 12, col if fill else Color(col, 0.35), w)
		"hourglass":
			_poly(ci, PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.9), c + Vector2(s * 0.6, -s * 0.9), c + Vector2(s * 0.08, 0), c + Vector2(s * 0.6, s * 0.9), c + Vector2(-s * 0.6, s * 0.9), c + Vector2(-s * 0.08, 0)]), body, ink, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.35, s * 0.75), c + Vector2(s * 0.35, s * 0.75), c + Vector2(0, s * 0.3)]), Color(ink, 0.55))
		"triangle":
			_poly(ci, PackedVector2Array([c + Vector2(0, -s * 0.95), c + Vector2(s * 0.9, s * 0.75), c + Vector2(-s * 0.9, s * 0.75)]), body, ink, w)
		"diamond", "objective":
			_poly(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)]), body, ink, w)
			if k == "objective":
				_poly(ci, PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.35, 0), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.35, 0)]), Color(1, 1, 1, 0.55), Color(0, 0, 0, 0), 0.0)
		"circle":
			ci.draw_circle(c, s * 0.85, body)
			ci.draw_arc(c, s * 0.85, 0, TAU, 32, ink, w)
		"movement", "gathering":
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * s * 0.95)
			_poly(ci, hex, body, ink, w)
			if k == "movement":
				var a := c + Vector2(-s * 0.45, 0)
				var b := c + Vector2(s * 0.45, 0)
				ci.draw_line(a, b, Color.WHITE, w * 1.2)
				ci.draw_colored_polygon(PackedVector2Array([b + Vector2(s * 0.12, 0), b + Vector2(-s * 0.2, -s * 0.28), b + Vector2(-s * 0.2, s * 0.28)]), Color.WHITE)
			else:
				ci.draw_arc(c + Vector2(-s * 0.08, -s * 0.08), s * 0.3, 0, TAU, 20, Color.WHITE, w)
				ci.draw_line(c + Vector2(s * 0.14, s * 0.14), c + Vector2(s * 0.45, s * 0.45), Color.WHITE, w * 1.3)
		"stealth", "shield":
			var sh := PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)])
			_poly(ci, sh, body, ink, w)
			if k == "stealth":
				ci.draw_arc(c + Vector2(0, -s * 0.15), s * 0.35, PI * 0.15, PI * 0.85, 10, Color.WHITE, w)
		"eye", "hide_enc":
			var e := PackedVector2Array()
			for i in 24:
				var t := TAU * i / 24.0
				e.append(c + Vector2(cos(t) * s * 0.95, sin(t) * s * 0.5 * (1.0 if sin(t) > 0 else 1.0)))
			_poly(ci, e, Color(1, 1, 1, 0.9) if fill else Color(1, 1, 1, 0.3), ink, w)
			ci.draw_circle(c, s * 0.3, col)
			if k == "hide_enc":
				ci.draw_line(c + Vector2(-s * 0.9, s * 0.75), c + Vector2(s * 0.9, -s * 0.75), ink, w * 1.8)
				ci.draw_line(c + Vector2(-s * 0.9, s * 0.75), c + Vector2(s * 0.9, -s * 0.75), col, w * 0.8)
		"ear":
			ci.draw_arc(c + Vector2(0, -s * 0.15), s * 0.6, PI * 0.9, TAU + PI * 0.25, 20, col, w * 1.6)
			ci.draw_line(c + Vector2(s * 0.42, s * 0.28), c + Vector2(-s * 0.05, s * 0.9), col, w * 1.6)
			ci.draw_arc(c + Vector2(0, -s * 0.15), s * 0.25, PI, TAU, 10, col, w)
		"question", "memory":
			ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.42, PI * 1.0, TAU + PI * 0.4, 16, col, w * 1.6)
			ci.draw_line(c + Vector2(s * 0.12, s * 0.05), c + Vector2(0, s * 0.35), col, w * 1.6)
			ci.draw_circle(c + Vector2(0, s * 0.75), w * 1.1, col)
		"marker":
			ci.draw_circle(c + Vector2(0, -s * 0.25), s * 0.62, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.1), c + Vector2(s * 0.4, s * 0.1), c + Vector2(0, s)]), col)
			ci.draw_arc(c + Vector2(0, -s * 0.25), s * 0.62, 0, TAU, 24, ink, w)
			ci.draw_line(c + Vector2(0, -s * 0.6), c + Vector2(0, -s * 0.2), ink, w * 1.2)
			ci.draw_circle(c + Vector2(0, s * 0.02), w * 0.7, ink)
		"search", "magnifier":
			ci.draw_arc(c + Vector2(-s * 0.15, -s * 0.15), s * 0.5, 0, TAU, 24, col, w * 1.5)
			ci.draw_line(c + Vector2(s * 0.22, s * 0.22), c + Vector2(s * 0.85, s * 0.85), col, w * 2.2)
		"patrol":
			ci.draw_arc(c, s * 0.65, 0.4, TAU - 0.4, 24, col, w * 1.4)
			var tip := c + Vector2.from_angle(0.4) * s * 0.65
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -s * 0.35), tip + Vector2(s * 0.3, s * 0.1), tip + Vector2(-s * 0.3, s * 0.1)]), col)
		"signal":
			ci.draw_circle(c, s * 0.25, col)
			for i in 2:
				ci.draw_arc(c, s * (0.55 + 0.35 * i), 0, TAU, 28, Color(col, 0.8 - 0.3 * i), w)
		"stunned", "star":
			var st := PackedVector2Array()
			for i in 10:
				var r := s * (0.95 if i % 2 == 0 else 0.42)
				st.append(c + Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * r)
			_poly(ci, st, col, ink, w)
		"hear":
			draw_icon(ci, "ear", c, s, col, fill, ink)
		"see":
			draw_icon(ci, "eye", c, s, col, fill, ink)
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.42, PI, TAU, 14, ink, w * 1.6)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.65, -s * 0.2), Vector2(s * 1.3, s * 1.05)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.65, -s * 0.2), Vector2(s * 1.3, s * 1.05)), ink, false, w)
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.13, ink)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, 0), c + Vector2(-s * 0.15, s * 0.55), c + Vector2(s * 0.75, -s * 0.6)]), col, w * 1.8)
		"cross":
			ci.draw_line(c + Vector2(-s * 0.6, -s * 0.6), c + Vector2(s * 0.6, s * 0.6), col, w * 1.8)
			ci.draw_line(c + Vector2(s * 0.6, -s * 0.6), c + Vector2(-s * 0.6, s * 0.6), col, w * 1.8)
		"warning":
			_poly(ci, PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.95, s * 0.8), c + Vector2(-s * 0.95, s * 0.8)]), col, ink, w)
			ci.draw_line(c + Vector2(0, -s * 0.35), c + Vector2(0, s * 0.25), ink, w * 1.4)
			ci.draw_circle(c + Vector2(0, s * 0.52), w * 0.8, ink)
		"redraw":
			ci.draw_arc(c, s * 0.62, -PI * 0.1, PI * 1.5, 24, col, w * 1.5)
			var t2 := c + Vector2.from_angle(-PI * 0.1) * s * 0.62
			ci.draw_colored_polygon(PackedVector2Array([t2 + Vector2(-s * 0.3, -s * 0.05), t2 + Vector2(s * 0.3, -s * 0.05), t2 + Vector2(0, s * 0.35)]), col)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * s * 0.5, c + Vector2.from_angle(a) * s * 0.95, col, w * 2.2)
			ci.draw_circle(c, s * 0.6, col)
			ci.draw_circle(c, s * 0.25, Color(ink, 0.9))
		"run":
			ci.draw_circle(c + Vector2(s * 0.25, -s * 0.7), s * 0.2, col)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.15, -s * 0.45), c + Vector2(-s * 0.1, s * 0.15), c + Vector2(-s * 0.55, s * 0.9)]), col, w * 1.6)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.1, s * 0.15), c + Vector2(s * 0.35, s * 0.45), c + Vector2(s * 0.3, s * 0.95)]), col, w * 1.6)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.15), c + Vector2(0, -s * 0.3), c + Vector2(s * 0.6, -s * 0.05)]), col, w * 1.4)
		"footprints":
			for i in 2:
				var o := Vector2(-s * 0.3 + s * 0.6 * i, s * 0.3 - s * 0.6 * i)
				ci.draw_set_transform(c + o, 0.3, Vector2(0.55, 1.0))
				ci.draw_circle(Vector2.ZERO, s * 0.32, col)
				ci.draw_set_transform(Vector2.ZERO)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.7), Vector2(s * 0.38, s * 1.4)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.17, -s * 0.7), Vector2(s * 0.38, s * 1.4)), col)
		_:
			ci.draw_circle(c, s * 0.7, body)
			ci.draw_arc(c, s * 0.7, 0, TAU, 24, ink, w)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, ink: Color, w: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	if w > 0.0 and ink.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, ink, w, true)
