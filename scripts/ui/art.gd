extends RefCounted
## Loads art from res://art/ and fonts from res://fonts/. Returns null when a file is missing,
## so every caller falls back to shapes drawn in code.

static var _cache := {}
static var _fonts := {}


static func tex(name: String) -> Texture2D:
	if name == "":
		return null
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/%s.png" % name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		# Not imported yet (fresh checkout run without the editor): read the PNG directly.
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_cache[name] = t
	return t


## file: name in res://fonts/. weight: 0 = the font's default, else an OpenType "wght" value.
static func font(file: String, weight: int = 0) -> Font:
	var key := "%s@%d" % [file, weight]
	if _fonts.has(key):
		return _fonts[key]
	var path := "res://fonts/" + file
	var base: Font = null
	if ResourceLoader.exists(path):
		base = load(path)
	elif FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			base = ff
	if base == null:
		base = ThemeDB.fallback_font
	var out: Font = base
	if weight > 0 and base != ThemeDB.fallback_font:
		var fv := FontVariation.new()
		fv.base_font = base
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		out = fv
	_fonts[key] = out
	return out


static func title_font() -> Font:
	# Cinzel Decorative swaps in swash letters ("CHOOSE" showed a joined OO, "HERO" a barred H)
	# even with ligatures off, which reads as typos; heavy Cinzel keeps the same carved look.
	return font("Cinzel-Variable.ttf", 900)


static func heading_font() -> Font:
	return font("Cinzel-Variable.ttf", 700)


static func body_font() -> Font:
	return font("CrimsonPro-Variable.ttf", 500)


static func body_bold_font() -> Font:
	return font("CrimsonPro-Variable.ttf", 700)
