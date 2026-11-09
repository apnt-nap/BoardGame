extends SceneTree
## Cuts the storybook art out of "Game Presentation - Final.pdf" into res://art/*.png.
## 1) Extract the PDF's images into build/ref_images/:
##      cd build/ref_images && mutool extract "../../../Game Presentation - Final.pdf"
## 2) Run:  godot --headless --path . --script res://scripts/tools/import_art.gd
##    Add `-- --contact` to also write build/art_contact.png (all outputs on one sheet).
## Source ids are mutool's object numbers (image-0044.png ...). Canva stores transparency as a
## separate grayscale image (the SMask), which is merged back in as alpha.

const SRC := "res://build/ref_images/image-%04d.png"
const OUT := "res://art/%s.png"

## name: [source id, alpha-mask id (0 = none), crop Rect2i (empty = whole image), longest side]
## Images with a mask are trimmed to their visible pixels after cropping.
const CROPS := {
	"seal_shrine":      [44, 298, Rect2i(), 360],
	"knight":           [54, 315, Rect2i(), 520],
	"hero_mage":        [59, 325, Rect2i(), 400],
	"hero_knight":      [60, 326, Rect2i(), 400],
	"hero_thief":       [61, 327, Rect2i(), 400],
	"hero_alchemist":   [62, 328, Rect2i(), 400],
	"hero_ranger":      [63, 329, Rect2i(), 400],
	# 3x2 icon sheet, 256 px cells
	"item_lantern":     [68, 339, Rect2i(0, 0, 256, 256), 200],
	"item_potion":      [68, 339, Rect2i(256, 0, 256, 256), 200],
	"item_scroll":      [68, 339, Rect2i(512, 0, 256, 256), 200],
	"item_rune_key":    [68, 339, Rect2i(0, 256, 256, 256), 200],
	"item_smoke":       [68, 339, Rect2i(256, 256, 256, 256), 200],
	"item_ward_charm":  [68, 339, Rect2i(512, 256, 256, 256), 200],
	# Illustration window only (no title, rule text, label or frame)
	"cardart_explore":  [77, 0, Rect2i(52, 150, 460, 268), 300],
	"cardart_dash":     [78, 0, Rect2i(52, 150, 460, 268), 300],
	"cardart_search":   [79, 0, Rect2i(52, 150, 460, 186), 300],
	"cardart_activate": [80, 0, Rect2i(52, 150, 460, 246), 300],
	"cardart_hide":     [81, 0, Rect2i(52, 150, 460, 260), 300],
	# The parchment's mask object is unreadable in the PDF, so take the inner sheet without torn edges.
	"parchment":        [304, 0, Rect2i(170, 170, 2577, 1760), 1400],
	"menu_bg":          [49, 0, Rect2i(), 1600],
	"title_bg":         [33, 0, Rect2i(), 1600],
	# Asia's extra art (transparent PNGs), copied into build/ref_user/. Three tiles / four shrines per sheet.
	"room_floor_plain":     ["room_tiles", 0, Rect2i(0, 0, 724, 724), 400],
	"room_floor_desk":      ["room_tiles", 0, Rect2i(724, 0, 724, 724), 400],
	"room_floor_barrels":   ["room_tiles", 0, Rect2i(1448, 0, 724, 724), 400],
	"seal_shrine_a":        ["seal_shrines", 0, Rect2i(0, 0, 543, 724), 360],
	"seal_shrine_b":        ["seal_shrines", 0, Rect2i(543, 0, 543, 724), 360],
	"seal_shrine_c":        ["seal_shrines", 0, Rect2i(1086, 0, 543, 724), 360],
	"seal_shrine_restored": ["seal_shrines", 0, Rect2i(1629, 0, 543, 724), 360],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://art")
	var cache := {}
	var made := []
	for name in CROPS:
		var spec: Array = CROPS[name]
		var key := "%s_%d" % [str(spec[0]), spec[1]]
		if not cache.has(key):
			cache[key] = _load(spec[0], spec[1])
		var src: Image = cache[key]
		if src == null:
			continue
		var rect: Rect2i = spec[2]
		if rect.size == Vector2i.ZERO:
			rect = Rect2i(Vector2i.ZERO, src.get_size())
		var img := src.get_region(rect.intersection(Rect2i(Vector2i.ZERO, src.get_size())))
		var has_alpha := img.detect_alpha() != Image.ALPHA_NONE
		if has_alpha:
			img = _trim(img)
		var longest := maxi(img.get_width(), img.get_height())
		if longest > spec[3]:  # downsize only, never upscale
			var s := float(spec[3]) / longest
			img.resize(roundi(img.get_width() * s), roundi(img.get_height() * s), Image.INTERPOLATE_LANCZOS)
		if not has_alpha:
			img.convert(Image.FORMAT_RGB8)
		img.save_png(OUT % name)
		made.append([name, img])
		print("art/%s.png  %dx%d" % [name, img.get_width(), img.get_height()])
	if "--contact" in OS.get_cmdline_user_args():
		_contact(made)
	quit()


## id: a mutool object number (build/ref_images/) or a file name in build/ref_user/.
func _load(id, mask_id: int) -> Image:
	var path: String = SRC % id if id is int else "res://build/ref_user/%s.png" % id
	var img := Image.load_from_file(path)
	if img == null:
		push_error("Missing " + path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	if mask_id != 0:
		var mask := Image.load_from_file(SRC % mask_id)
		if mask == null or mask.get_size() != img.get_size():
			push_error("Bad mask %d for image %d" % [mask_id, id])
			return img
		mask.convert(Image.FORMAT_L8)
		var px := img.get_data()
		var m := mask.get_data()
		for i in m.size():
			px[i * 4 + 3] = m[i]
		img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, px)
	return img


## Crop away (nearly) transparent borders, ignoring faint glow below alpha 8.
func _trim(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			if px[(y * w + x) * 4 + 3] >= 8:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	return img.get_region(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)) if x1 >= 0 else img


## Every output on a checkerboard (so transparency is visible), 6 per row, 260 px cells.
func _contact(made: Array) -> void:
	var cell := 260
	var cols := 6
	var rows := ceili(made.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for y in sheet.get_height():
		for x in sheet.get_width():
			sheet.set_pixel(x, y, Color(0.8, 0.8, 0.8) if ((x / 16) + (y / 16)) % 2 == 0 else Color(0.55, 0.55, 0.6))
	for i in made.size():
		var img: Image = made[i][1].duplicate()
		img.convert(Image.FORMAT_RGBA8)
		var s := minf(float(cell - 10) / img.get_width(), float(cell - 10) / img.get_height())
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
		var at := Vector2i((i % cols) * cell + 5, (i / cols) * cell + 5)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	DirAccess.make_dir_recursive_absolute("res://build")
	sheet.save_png("res://build/art_contact.png")
	print("build/art_contact.png")
