extends Node
## Sound hooks. play("seal") looks for res://audio/seal.ogg or .wav first; if there is no file
## it plays a small synthesized placeholder, so every hook already makes a sound.

const RATE := 22050
## name -> [frequencies (Hz), duration (s), waveform]
const SYNTH := {
	"click": [[880.0], 0.05, "sine"],
	"card": [[520.0, 780.0], 0.09, "sine"],
	"move": [[240.0], 0.07, "sine"],
	"dice": [[0.0], 0.12, "noise"],
	"dice_tick": [[0.0], 0.025, "noise"],
	"good": [[660.0, 990.0], 0.14, "sine"],
	"bad": [[220.0, 160.0], 0.22, "square"],
	"noise": [[180.0, 140.0], 0.16, "square"],
	"quiet": [[420.0, 300.0], 0.16, "sine"],
	"knight_step": [[70.0], 0.14, "square"],
	"encounter": [[110.0, 104.0, 98.0], 0.5, "square"],
	"damage": [[90.0, 60.0], 0.35, "noise"],
	"seal": [[523.0, 659.0, 784.0, 1046.0], 0.5, "sine"],
	"shriek": [[1400.0, 1100.0, 1500.0], 0.35, "sine"],
	"shift": [[60.0, 55.0], 0.6, "noise"],
	"heal": [[392.0, 523.0, 659.0], 0.35, "sine"],
	"bell": [[330.0, 331.5], 1.2, "sine"],
	"win": [[392.0, 494.0, 587.0, 784.0], 1.2, "sine"],
	"lose": [[196.0, 165.0, 131.0, 98.0], 1.4, "square"],
	"heartbeat": [[55.0, 0.0, 50.0, 0.0], 0.5, "sine"],
}

var _cache := {}
var _players: Array = []
var muted := false


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)


func play(name: String) -> void:
	if muted or not SYNTH.has(name) and not _has_file(name):
		return
	var stream: AudioStream = _get_stream(name)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()


func _has_file(name: String) -> bool:
	return ResourceLoader.exists("res://audio/%s.ogg" % name) or ResourceLoader.exists("res://audio/%s.wav" % name)


func _get_stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "res://audio/%s.%s" % [name, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s == null and SYNTH.has(name):
		s = _synth(SYNTH[name][0], SYNTH[name][1], SYNTH[name][2])
	_cache[name] = s
	return s


## Plays the frequencies one after another (an arpeggio) with a soft decay.
func _synth(freqs: Array, dur: float, wave: String) -> AudioStreamWAV:
	var total := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(total * 2)
	var seg := maxi(1, total / freqs.size())
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in total:
		var f: float = freqs[mini(i / seg, freqs.size() - 1)]
		phase += TAU * f / RATE
		var local_t := float(i % seg) / seg
		var env := (1.0 - local_t) * minf(1.0, i / 200.0)
		var v := 0.0
		match wave:
			"square":
				v = 0.5 if sin(phase) >= 0.0 else -0.5
			"noise":
				v = rng.randf_range(-1.0, 1.0) * (0.6 if f == 0.0 else 0.4) + (0.0 if f == 0.0 else 0.5 * sin(phase))
			_:
				v = sin(phase)
		data.encode_s16(i * 2, int(clampf(v * env * 0.5, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
