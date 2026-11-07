extends SceneTree
## Cuts the painted art out of "Game Design.pdf" into res://art/*.png.
## 1) Extract the PDF's images:  mutool extract "Game Design.pdf"   (into build/art_src/)
## 2) Run:  godot --headless --path . --script res://scripts/tools/import_art.gd
## Source image ids are the object numbers mutool gives them (image-0116.png ...).

const SRC := "res://build/art_src/image-0%d.png"
const OUT := "res://art/%s.png"

## name: [source id, alpha-mask id (0 = none), Rect2i crop, max size]
const CROPS := {
	# 3x3 castle map (rooms)
	"room_dungeon":   [116, 0, Rect2i(40, 78, 400, 232), 400],
	"room_throne":    [116, 0, Rect2i(472, 78, 400, 232), 400],
	"room_seal_blue": [116, 0, Rect2i(902, 78, 400, 232), 400],
	"room_armory":    [116, 0, Rect2i(40, 383, 400, 232), 400],
	"room_hall":      [116, 0, Rect2i(472, 383, 400, 232), 400],
	"room_forge":     [116, 0, Rect2i(902, 383, 400, 232), 400],
	"room_seal_green":[116, 0, Rect2i(40, 688, 400, 232), 400],
	"room_library":   [116, 0, Rect2i(472, 688, 400, 232), 400],
	"room_seal_red":  [116, 0, Rect2i(902, 688, 400, 232), 400],
	"map":            [116, 0, Rect2i(0, 0, 1342, 950), 1342],
	# Action card illustrations
	"card_explore":   [137, 0, Rect2i(130, 88, 390, 135), 500],
	"card_search":    [137, 0, Rect2i(560, 100, 225, 155), 400],
	"card_activate":  [137, 0, Rect2i(28, 440, 250, 148), 400],
	"card_dash":      [137, 0, Rect2i(660, 440, 395, 130), 500],
	"card_hide":      [141, 0, Rect2i(28, 100, 280, 190), 400],
	"enc_run":        [146, 0, Rect2i(22, 225, 290, 160), 400],
	"enc_hide":       [146, 0, Rect2i(333, 225, 262, 160), 400],
	"enc_item":       [146, 0, Rect2i(612, 225, 292, 160), 400],
	"enc_header":     [146, 0, Rect2i(0, 0, 330, 175), 330],
	# Hero portraits
	"hero_ranger":    [124, 0, Rect2i(70, 75, 290, 225), 345],
	"hero_knight":    [124, 0, Rect2i(446, 75, 290, 225), 345],
	"hero_mage":      [124, 0, Rect2i(820, 75, 290, 225), 345],
	"hero_alchemist": [124, 0, Rect2i(1194, 75, 290, 225), 345],
	# Item illustrations
	"item_lantern":   [152, 0, Rect2i(26, 100, 205, 188), 256],
	"item_silence":   [152, 0, Rect2i(478, 100, 210, 188), 256],
	"item_potion":    [152, 0, Rect2i(26, 400, 205, 195), 256],
	"item_shield":    [152, 0, Rect2i(478, 400, 210, 195), 256],
	# Tokens (with transparency)
	"tok_health":     [148, 230, Rect2i(0, 0, 218, 160), 160],
	"tok_shards":     [148, 230, Rect2i(217, 0, 218, 160), 160],
	"tok_noise":      [148, 230, Rect2i(0, 166, 218, 160), 160],
	"tok_turn":       [148, 230, Rect2i(217, 166, 218, 160), 160],
	"seal_a":         [161, 235, Rect2i(0, 30, 237, 295), 220],
	"seal_b":         [161, 235, Rect2i(237, 30, 237, 295), 220],
	"seal_c":         [161, 235, Rect2i(473, 30, 237, 295), 220],
	"mini_knight":    [162, 236, Rect2i(0, 0, 165, 268), 220],
	"mini_player":    [163, 237, Rect2i(0, 0, 170, 268), 220],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://art")
	var cache := {}
	for name in CROPS:
		var spec: Array = CROPS[name]
		var key := "%d_%d" % [spec[0], spec[1]]
		if not cache.has(key):
			cache[key] = _load(spec[0], spec[1])
		var src: Image = cache[key]
		if src == null:
			continue
		var rect: Rect2i = spec[2].intersection(Rect2i(Vector2i.ZERO, src.get_size()))
		var img := src.get_region(rect)
		var max_side: int = spec[3]
		var longest := maxi(img.get_width(), img.get_height())
		if longest > max_side:
			var s := float(max_side) / longest
			img.resize(int(img.get_width() * s), int(img.get_height() * s), Image.INTERPOLATE_LANCZOS)
		if spec[1] != 0:
			img = _trim(img)
		img.save_png(OUT % name)
		print("art/%s.png  %s" % [name, img.get_size()])
	quit()


func _load(id: int, mask_id: int) -> Image:
	var img := Image.load_from_file(SRC % id)
	if img == null:
		push_error("Missing " + SRC % id)
		return null
	img.convert(Image.FORMAT_RGBA8)
	if mask_id != 0:
		var mask := Image.load_from_file(SRC % mask_id)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				c.a = mask.get_pixel(x, y).r
				img.set_pixel(x, y, c)
	return img


## Crop away fully transparent borders.
func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	return img.get_region(used) if used.size.x > 0 else img
