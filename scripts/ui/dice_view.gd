extends Control
## A six-sided die drawn with shapes. roll_to() tumbles through faces, slows down,
## then lands on the result with a bounce and a coloured glow.

const P = preload("res://scripts/ui/palette.gd")

## Pip positions per face, on a -1..1 grid.
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

var face := 1
var body := Color("efe6d6")
var pip := Color("1b1720")
var edge := Color("8a7a66")
var glow := Color(0, 0, 0, 0)
var sfx                        # optional sound player with play(name)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5


func _draw() -> void:
	var s := size.x
	var r := Rect2(Vector2.ZERO, size)
	if glow.a > 0.0:
		var g := StyleBoxFlat.new()
		g.bg_color = Color(glow, glow.a * 0.35)
		g.set_corner_radius_all(int(s * 0.28))
		draw_style_box(g, r.grow(s * 0.14))
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.45)
	shadow.set_corner_radius_all(int(s * 0.2))
	draw_style_box(shadow, Rect2(r.position + Vector2(s * 0.05, s * 0.08), r.size))
	var box := StyleBoxFlat.new()
	box.bg_color = body
	box.border_color = glow if glow.a > 0.0 else edge
	box.set_border_width_all(maxi(2, int(s * 0.04)))
	box.set_corner_radius_all(int(s * 0.2))
	draw_style_box(box, r)
	# soft top highlight for a bit of depth
	draw_rect(Rect2(r.position + Vector2(s * 0.12, s * 0.06), Vector2(s * 0.76, s * 0.1)), Color(1, 1, 1, 0.25))
	var c := size * 0.5
	for p in PIPS[face]:
		draw_circle(c + p * s * 0.26, s * 0.085, pip)


## Tumble for `duration` seconds, then show `result`. Await it.
func roll_to(result: int, land_color: Color, duration: float = 0.7) -> void:
	var t := 0.0
	var step := 0.045
	var home := position
	while t < duration:
		var f := randi_range(1, 6)
		while f == face:
			f = randi_range(1, 6)
		face = f
		rotation = randf_range(-0.7, 0.7)
		position = home + Vector2(randf_range(-6, 6), randf_range(-10, 4))
		queue_redraw()
		if sfx:
			sfx.play("dice_tick")
		await get_tree().create_timer(step).timeout
		t += step
		step *= 1.12
	face = result
	position = home
	glow = land_color
	queue_redraw()
	if sfx:
		sfx.play("dice")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.09)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	await tw.finished
