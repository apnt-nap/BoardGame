extends RefCounted
## Player settings saved to user://settings.cfg (separate from unlock progress).

const PATH := "user://settings.cfg"

var path := PATH
var volume := 0.8              # effects volume, 0..1
var muted := false
var reduced_motion := false    # no shake, no glides, no screen flashes
var fast := false              # skip repeated animations: steps and ripples play twice as fast
var text_scale := 1.0          # 1.0 or 1.15
var confirm := true            # one-step actions need a second click (or Space)
var seen_intro := false        # first launch: the title screen offers How to play


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	volume = cf.get_value("s", "volume", volume)
	muted = cf.get_value("s", "muted", muted)
	reduced_motion = cf.get_value("s", "reduced_motion", reduced_motion)
	fast = cf.get_value("s", "fast", fast)
	text_scale = cf.get_value("s", "text_scale", text_scale)
	confirm = cf.get_value("s", "confirm", confirm)
	seen_intro = cf.get_value("s", "seen_intro", seen_intro)


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in ["volume", "muted", "reduced_motion", "fast", "text_scale", "confirm", "seen_intro"]:
		cf.set_value("s", k, get(k))
	cf.save(path)
