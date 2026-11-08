extends RefCounted
## A heuristic player used by the headless simulation. It plays through the same public
## API as the UI and only uses information a human sees on the board.

const Config = preload("res://scripts/core/config.gd")


func play_turn(g) -> void:
	if g.phase == "encounter":
		if g.hero_item() == "potion" and g.can_use_hero_item():
			g.use_hero_item()
		for i in range(g.treasures.size() - 1, -1, -1):
			var t: String = g.treasures[i]
			if (t == "ration" and g.health == 1) or (t == "ward_charm" and g.noise >= g.diff["hunt_at"] - 1):
				g.use_treasure(i)
		g.resolve_encounter(choose_encounter(g))
		return
	_free_actions(g)
	if g.phase != "player":
		return
	var c := _choose_card(g)
	if not g.play_card(c["i"], c["mode"], c["target"]):
		# Fallback that is always legal.
		g.play_card(0, "sneak_move", g.castle.neighbors(g.player_room)[0])


func choose_encounter(g) -> String:
	var ids := []
	for o in g.encounter_options():
		ids.append(o["id"])
	for esc in ["smoke_vial", "smoke", "lantern", "silence"]:
		if esc in ids and g.health <= 2:
			return esc
	# Like the paper playtests: hiding keeps you quiet and wins more often than running.
	return "hide"


func _knight_dist(g) -> int:
	return g.castle.distance(g.player_room, g.knight.room)


func _free_actions(g) -> void:
	var kd := _knight_dist(g)
	var hunt_at: int = g.diff["hunt_at"]
	# Hero item.
	match g.hero_item():
		"potion":
			if g.health <= 1 or (g.health < Config.MAX_HEALTH and g.turns_left() < 6):
				g.use_hero_item()
		"lantern":
			if kd <= 1 and g.knight.will_move_next():
				g.use_hero_item()
		"silence":
			if g.noise >= hunt_at:
				g.use_hero_item()
	# Treasures.
	for i in range(g.treasures.size() - 1, -1, -1):
		var t: String = g.treasures[i]
		if t == "ward_charm" and g.noise >= hunt_at - 1:
			g.use_treasure(i)
		elif t == "ration" and g.health == 1:
			g.use_treasure(i)
	# Room feature.
	var ra: String = g.room_action()
	match ra:
		"chapel", "armory":
			g.do_room_action()
		"bell_tower":
			if g.noise > 0 and kd <= 3:
				g.do_room_action()
		"passage":
			var exit: int = g.castle.passage_exit(g.player_room)
			var goal := _goal(g)
			if (kd <= 2 and g.castle.distance(exit, g.knight.room) > kd) or \
					(goal >= 0 and g.castle.distance(exit, goal) + 1 < g.castle.distance(g.player_room, goal)):
				g.do_room_action()
	# The one free redraw per run: swap a useless hand.
	if g.can_redraw() and not _hand_useful(g):
		g.redraw_hand()


func _hand_useful(g) -> bool:
	for i in g.hand.size():
		var c: String = g.hand[i]
		if c == "activate" and (g.can_play(i, "normal") or g.can_play(i, "rune_key")):
			return true
		if c == "search" and g.can_play(i, "normal") and g.shards < _shards_needed(g):
			return true
	return false


func _shards_needed(g) -> int:
	return (3 - g.seals_restored()) * Config.SHARDS_PER_SEAL - (1 if g.rune_key_ready else 0)


## Enough Shards to restore one Seal right now (1 with an unused Rune Key).
func _can_afford_seal(g) -> bool:
	return g.shards >= Config.SHARDS_PER_SEAL or g.can_use_rune_key()


## Where the bot wants to go: nearest unrestored Seal if it has shards, else nearest searchable room.
func _goal(g) -> int:
	var dist: Array = g.castle.distances(g.player_room)
	var best := -1
	var best_d := 999
	if _can_afford_seal(g):
		for i in 3:
			var s: int = g.castle.seals[i]
			if g.restored[i]:
				continue
			var score: int = dist[s] + (3 if g.castle.distance(s, g.knight.room) <= 1 else 0)
			if score < best_d:
				best_d = score
				best = s
		return best
	for r in g.castle.room_count():
		if g.is_searchable(r) and r != g.knight.room and dist[r] < best_d:
			var d: int = dist[r] + (2 if g.castle.distance(r, g.knight.room) <= 1 else 0)
			if d < best_d:
				best_d = d
				best = r
	return best


## Uses only what the board shows: the Knight's room and its intent arrow (next step).
func _danger(g, r: int) -> float:
	if r == g.knight.room:
		return 4.0
	if r == g.knight.next_step():
		return 2.0
	return 0.4 if g.castle.distance(r, g.knight.room) == 1 else 0.0


func _best_step(g, options: Array, goal: int) -> int:
	var best: int = options[0]
	var best_score := 99999.0
	for r in options:
		var score: float = g.castle.distance(r, goal) * 1.0 + _danger(g, r)
		if score < best_score:
			best_score = score
			best = r
	return best


## Somewhere to wander when there is no goal: the room farthest from the Knight.
func _far_from_knight(g) -> int:
	var dist: Array = g.castle.distances(g.knight.room)
	return dist.find(dist.max())


func _find(g, card: String) -> int:
	for i in g.hand.size():
		if g.hand[i] == card and g.can_play(i, "normal"):
			return i
	return -1


func _choose_card(g) -> Dictionary:
	var hunt_at: int = g.diff["hunt_at"]
	var kd := _knight_dist(g)
	var goal := _goal(g)
	# 1. Too loud: get quiet first.
	if g.noise >= hunt_at or (g.noise == hunt_at - 1 and kd <= 2):
		var h := _find(g, "hide")
		if h >= 0:
			return {"i": h, "mode": "normal", "target": -1}
		if kd > 1 or g.knight.state != "HUNT":
			return {"i": 0, "mode": "sneak_quiet", "target": -1}
	# 2. On a Seal with shards: activate.
	var a := _find(g, "activate")
	if a >= 0 and kd >= 1:
		return {"i": a, "mode": "normal", "target": -1}
	# With 1 Shard, the Rune Key is the only way to activate.
	for i in g.hand.size():
		if g.hand[i] == "activate" and g.can_play(i, "rune_key") and kd >= 1:
			return {"i": i, "mode": "rune_key", "target": -1}
	# 3. Need shards and this room is searchable.
	var s := _find(g, "search")
	if s >= 0 and g.shards < _shards_needed(g) and (kd >= 2 or g.noise <= hunt_at - 2) and \
			(not _can_afford_seal(g) or g.unrestored_seal_here() < 0):
		return {"i": s, "mode": "normal", "target": -1}
	# 5. Move toward the goal, away from the Knight when it is close.
	# 4. Already where it wants to be but holding the wrong cards: wait quietly.
	if goal == g.player_room and kd >= 2:
		var h2 := _find(g, "hide")
		return {"i": h2 if h2 >= 0 else 0, "mode": "normal" if h2 >= 0 else "sneak_quiet", "target": -1}
	if goal < 0 or goal == g.player_room:
		goal = _far_from_knight(g) if goal < 0 else goal
	var dist_goal: int = g.castle.distance(g.player_room, goal)
	var d := _find(g, "dash")
	if d >= 0 and dist_goal >= 2 and g.noise + 1 < hunt_at - 1 and kd >= 3:
		var opts: Array = g.move_options("dash", "normal")
		return {"i": d, "mode": "normal", "target": _best_step(g, opts, goal)}
	var e := _find(g, "explore")
	if e >= 0:
		return {"i": e, "mode": "normal", "target": _best_step(g, g.move_options("explore", "normal"), goal)}
	# Sneak-move with whichever card is least useful.
	var discard_i := 0
	for i in g.hand.size():
		if g.hand[i] == "dash" or g.hand[i] == "explore":
			discard_i = i
	return {"i": discard_i, "mode": "sneak_move", "target": _best_step(g, g.castle.neighbors(g.player_room), goal)}
