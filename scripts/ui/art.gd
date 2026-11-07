extends RefCounted
## Loads painted art from res://art/ (made by scripts/tools/import_art.gd). Returns null when a
## file is missing, so every caller falls back to the flat vector style.

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if name == "":
		return null
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/%s.png" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = t
	return t
