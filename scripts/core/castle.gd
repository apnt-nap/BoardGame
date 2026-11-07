extends RefCounted
## The Keep: a 5x5 grid of rooms joined by doorways. Pure data + graph helpers, no visuals.

const Config = preload("res://scripts/core/config.gd")

var n: int = Config.GRID
var doors: Dictionary = {}       # "a_b" (a < b) -> true
var seals: Array = []            # room ids for Seal A, B, C
var specials: Dictionary = {}    # room -> special type (passage appears twice)
var passage: Array = []          # the two paired corner rooms
var corrupted: Dictionary = {}   # room -> true
var rng: RandomNumberGenerator


func room_count() -> int:
	return n * n


func pos(r: int) -> Vector2i:
	return Vector2i(r % n, r / n)


func idx(x: int, y: int) -> int:
	return y * n + x


static func key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]


func grid_neighbors(r: int) -> Array:
	var p := pos(r)
	var out := []
	if p.x > 0: out.append(r - 1)
	if p.x < n - 1: out.append(r + 1)
	if p.y > 0: out.append(r - n)
	if p.y < n - 1: out.append(r + n)
	return out


func has_door(a: int, b: int) -> bool:
	return doors.has(key(a, b))


func neighbors(r: int) -> Array:
	var out := []
	for g in grid_neighbors(r):
		if has_door(r, g):
			out.append(g)
	return out


## Door-distance from `from` to every room (-1 = unreachable).
func distances(from: int) -> Array:
	var dist := []
	dist.resize(room_count())
	dist.fill(-1)
	dist[from] = 0
	var queue := [from]
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for nb in neighbors(cur):
			if dist[nb] == -1:
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return dist


func distance(a: int, b: int) -> int:
	return distances(a)[b]


## Shortest door path from `from` to `to`, excluding `from`. Empty if unreachable or same room.
## `avoid` rooms are only used if there is no other way.
func path(from: int, to: int, avoid: Array = []) -> Array:
	if from == to:
		return []
	if not avoid.is_empty():
		var p := _bfs_path(from, to, avoid)
		if not p.is_empty():
			return p
	return _bfs_path(from, to, [])


func _bfs_path(from: int, to: int, avoid: Array) -> Array:
	var prev := {}
	prev[from] = -1
	var queue := [from]
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		if cur == to:
			break
		for nb in neighbors(cur):
			if prev.has(nb) or (nb in avoid and nb != to):
				continue
			prev[nb] = cur
			queue.append(nb)
	if not prev.has(to):
		return []
	var out := []
	var c := to
	while c != from:
		out.push_front(c)
		c = prev[c]
	return out


func is_fully_connected() -> bool:
	return not (-1 in distances(0))


func special_at(r: int) -> String:
	if corrupted.has(r):
		return ""
	return specials.get(r, "")


func seal_index(r: int) -> int:
	return seals.find(r)


# ---------------------------------------------------------------- generation

func generate(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	for _attempt in 500:
		doors.clear()
		_carve_tree()
		for r in room_count():
			for g in grid_neighbors(r):
				if g > r and not has_door(r, g) and rng.randf() < Config.EXTRA_DOOR_CHANCE:
					doors[key(r, g)] = true
		if _place_seals():
			_place_specials()
			return
	push_error("Castle generation failed")


func _carve_tree() -> void:
	var visited := {}
	var start := rng.randi_range(0, room_count() - 1)
	var stack := [start]
	visited[start] = true
	while not stack.is_empty():
		var cur: int = stack.back()
		var options := []
		for g in grid_neighbors(cur):
			if not visited.has(g):
				options.append(g)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: int = options[rng.randi_range(0, options.size() - 1)]
		doors[key(cur, nxt)] = true
		visited[nxt] = true
		stack.append(nxt)


func _place_seals() -> bool:
	var corners := [0, n - 1, room_count() - n, room_count() - 1]
	for _try in 200:
		var picks := []
		for _i in 3:
			picks.append(rng.randi_range(0, room_count() - 1))
		var ok := true
		for i in 3:
			if picks[i] in corners:
				ok = false
			for j in range(i + 1, 3):
				if picks[i] == picks[j] or distance(picks[i], picks[j]) < Config.SEAL_MIN_DISTANCE:
					ok = false
		if ok:
			seals = picks
			return true
	return false


func _place_specials() -> void:
	specials.clear()
	corrupted.clear()
	passage = [0, room_count() - 1] if rng.randf() < 0.5 else [n - 1, room_count() - n]
	for r in passage:
		specials[r] = "passage"
	var free := []
	for r in room_count():
		if not (r in seals) and not specials.has(r):
			free.append(r)
	for t in ["chapel", "library", "bell_tower", "armory"]:
		var r: int = free[rng.randi_range(0, free.size() - 1)]
		free.erase(r)
		specials[r] = t


## Keep shift: close one doorway, open another, keep every room reachable.
func keep_shift() -> Dictionary:
	var existing := doors.keys()
	var closed_options := []
	for r in room_count():
		for g in grid_neighbors(r):
			if g > r and not has_door(r, g):
				closed_options.append(key(r, g))
	if closed_options.is_empty():
		return {}
	for _try in 100:
		var close_k: String = existing[rng.randi_range(0, existing.size() - 1)]
		var open_k: String = closed_options[rng.randi_range(0, closed_options.size() - 1)]
		doors.erase(close_k)
		doors[open_k] = true
		if is_fully_connected():
			return {"closed": close_k, "opened": open_k}
		doors.erase(open_k)
		doors[close_k] = true
	return {}


## Corrupt `count` random special room types (a corrupted passage closes both ends).
func corrupt(count: int) -> Array:
	var types := []
	for r in specials:
		var t: String = specials[r]
		if not corrupted.has(r) and not (t in types):
			types.append(t)
	var out := []
	for _i in mini(count, types.size()):
		var t: String = types[rng.randi_range(0, types.size() - 1)]
		types.erase(t)
		out.append(t)
		for r in specials:
			if specials[r] == t:
				corrupted[r] = true
	return out


func passage_exit(r: int) -> int:
	if special_at(r) != "passage":
		return -1
	return passage[1] if r == passage[0] else passage[0]
