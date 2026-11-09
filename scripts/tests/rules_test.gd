extends SceneTree
## Rules tests for the playtest rule set (movement, Search, automatic Activate, Rune Key,
## free redraw, removed content, third-Seal victory, castle generation). No UI.
##   godot --headless --path . --script res://scripts/tests/rules_test.gd

const Config = preload("res://scripts/core/config.gd")
const Game = preload("res://scripts/core/game.gd")
const Castle = preload("res://scripts/core/castle.gd")
const Bot = preload("res://scripts/core/bot.gd")
const Profile = preload("res://scripts/ui/profile.gd")

var failures := 0
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_generation()
	_test_removed_content()
	_test_movement()
	_test_noise_cards()
	_test_search()
	_test_activate()
	_test_rune_key()
	_test_third_seal_wins()
	_test_redraw()
	_test_normal_knight()
	_test_easy_hard_unchanged()
	_test_line_of_sight()
	_test_seal_signal()
	_test_spirit_removed()
	_test_previews_read_only()
	_test_bot_games()
	print("%d checks, %d failed" % [checks, failures])
	print("Rules tests passed" if failures == 0 else "Rules tests FAILED")
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


## A fresh game whose world turn cannot interfere: the Knight is stunned and far away.
func _game(hero: String = "ranger", seed_value: int = 1234) -> Object:
	var g = Game.new()
	g.new_game(hero, "normal", seed_value, false)
	_calm(g)
	return g


func _calm(g) -> void:
	g.knight.skip_turns = 1
	# Keep the Knight far away so a stun can't be the only thing preventing an encounter.
	var dist: Array = g.castle.distances(g.player_room)
	g.knight.room = dist.find(dist.max())


## Order-independent dictionary comparison.
func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in b:
		if not a.has(key) or a[key] != b[key]:
			return false
	return true


func _set_hand(g, cards: Array) -> void:
	g.discard.append_array(g.hand)
	g.hand = cards.duplicate()


# ---------------------------------------------------------------- generation

func _test_generation() -> void:
	for s in range(1, 301):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var c = Castle.new()
		c.generate(rng)
		var types := {}
		for r in c.specials:
			types[c.specials[r]] = types.get(c.specials[r], 0) + 1
			check(not (r in c.seals), "seed %d: special room on a Seal" % s)
		check(_same(types, {"passage": 2, "chapel": 1, "bell_tower": 1, "armory": 1}), "seed %d: special rooms are %s" % [s, str(types)])
		check(c.passage.size() == 2 and c.passage_exit(c.passage[0]) == c.passage[1], "seed %d: passage endpoints" % s)
		check(c.is_fully_connected(), "seed %d: castle not connected" % s)
		check(c.seals.size() == 3, "seed %d: 3 seals" % s)
		for i in 3:
			for j in range(i + 1, 3):
				check(c.distance(c.seals[i], c.seals[j]) >= Config.SEAL_MIN_DISTANCE, "seed %d: seals too close" % s)
		var corrupted: Array = c.corrupt(2)
		check(corrupted.size() == 2 and not ("library" in corrupted), "seed %d: corruption picks 2 of the 4 types" % s)


func _test_removed_content() -> void:
	check(not Config.SPECIALS.has("library"), "Library removed from special rooms")
	check(not ("passage_map" in Config.TREASURES), "Passage Map removed from the loot pool")
	check(not Config.TREASURE_INFO.has("passage_map"), "Passage Map removed from treasure info")
	check(Config.SPECIALS.size() == 4, "four special room types")
	var total := 0
	for t in Config.DECK:
		total += Config.DECK[t]
	check(total == 16 and _same(Config.DECK, {"explore": 2, "dash": 2, "search": 6, "activate": 4, "hide": 2}), "deck composition unchanged")
	var g = _game()
	check(not ("focus" in g), "Focus resource removed")


# ---------------------------------------------------------------- movement

func _test_movement() -> void:
	for s in range(1, 41):
		var g = _game("ranger", s)
		var start: int = g.player_room
		var dist: Array = g.castle.distances(start)
		var sneak: Array = g.move_options("explore", "sneak_move")
		var explore: Array = g.move_options("explore", "normal")
		var dash: Array = g.move_options("dash", "normal")
		for r in sneak:
			check(dist[r] == 1, "Sneak moves exactly 1 doorway")
		for r in explore:
			check(dist[r] >= 1 and dist[r] <= 2, "Explore within 2 doorways")
		for r in dash:
			check(dist[r] >= 1 and dist[r] <= 3, "Dash within 3 doorways")
		for r in g.castle.room_count():
			if dist[r] >= 1 and dist[r] <= 2:
				check(r in explore, "Explore offers every room within 2")
			if dist[r] >= 1 and dist[r] <= 3:
				check(r in dash, "Dash offers every room within 3")

		# Explore: silent.
		_set_hand(g, ["explore", "search"])
		var far: int = explore[explore.size() - 1]
		var n0: int = g.noise
		check(g.play_card(0, "normal", far), "Explore plays")
		check(g.player_room == far and g.noise == n0, "Explore moves silently")
		var illegal := -1
		for r in g.castle.room_count():
			if g.castle.distances(g.player_room)[r] > 3:
				illegal = r
		if g.phase == "player" and illegal >= 0:
			_calm(g)
			_set_hand(g, ["dash", "search"])
			check(not g.play_card(0, "normal", illegal), "Dash can't go beyond 3 doorways")

		# Dash: +1 Noise total, token at the destination.
		if g.phase == "player":
			_calm(g)
			_set_hand(g, ["dash", "search"])
			var opts: Array = g.move_options("dash", "normal")
			var dest: int = opts[opts.size() - 1]
			n0 = g.noise
			check(g.play_card(0, "normal", dest), "Dash plays")
			check(g.player_room == dest, "Dash moves")
			check(g.noise == mini(5, n0 + 1), "Dash adds exactly 1 Noise")
			check(g.token == dest, "Dash puts the token at the destination")


func _test_noise_cards() -> void:
	var g = _game()
	g.noise = 4
	g.token = g.player_room
	_set_hand(g, ["hide", "search"])
	var here: int = g.player_room
	check(g.play_card(0, "normal"), "Hide plays at Noise 4")
	check(g.noise == 2 and g.player_room == here, "Hide card: stay, Noise -2")

	g = _game()
	g.noise = 1
	_set_hand(g, ["hide", "search"])
	check(g.play_card(0, "normal") and g.noise == 0, "Hide clamps Noise at 0")

	g = _game()
	g.noise = 0
	_set_hand(g, ["hide", "search"])
	var here0: int = g.player_room
	check(g.can_play(0, "normal"), "Hide card is playable at Noise 0 (decision A)")
	check(g.play_card(0, "normal") and g.noise == 0 and g.player_room == here0, "Hide at Noise 0: stay, Noise stays 0")

	g = _game()
	g.noise = 0
	_set_hand(g, ["search", "dash"])
	check(g.can_play(0, "sneak_quiet"), "Sneak: stay is allowed at Noise 0")
	check(g.play_card(0, "sneak_quiet") and g.noise == 0, "Sneak: stay at Noise 0 keeps Noise 0")

	g = _game()
	g.noise = 3
	_set_hand(g, ["activate", "dash"])
	check(g.play_card(0, "sneak_quiet") and g.noise == 2, "Sneak: stay lowers Noise by 1")

	g = _game()
	g.noise = 5
	_set_hand(g, ["dash", "search"])
	var opts: Array = g.move_options("dash", "normal")
	check(g.play_card(0, "normal", opts[0]) and g.noise == 5, "Noise is capped at 5")


# ---------------------------------------------------------------- search

## Rolls Search directly many times and checks every outcome against the table.
func _test_search() -> void:
	var g = _game()
	var room := -1
	for r in g.castle.room_count():
		if not (r in g.castle.seals):
			room = r
			break
	var seen := {}
	for trial in 600:
		var bonus := 1 if trial % 2 == 1 else 0
		g.player_room = room
		g.searched.erase(room)
		g.shards = 0
		g.treasures = []
		g.noise = 0
		g.search_bonus = bonus
		g.take_events()
		g._search()
		var natural := -1
		for e in g.take_events():
			if e["type"] == "dice":
				natural = e["roll"]
		var roll := mini(6, natural + bonus)
		seen[roll] = true
		if roll <= 1:
			check(bonus == 0, "a +1 Search never fails")
			check(g.shards == 0 and g.noise == 1 and g.token == room, "Search 1: fail, Noise +1, token here")
			check(g.search_bonus == 1, "after a failed Search the next one gets +1")
			check(not g.searched.has(room), "a failed Search leaves the room searchable")
		else:
			check(g.shards == 1, "Search %d gives exactly 1 Shard" % roll)
			check(g.treasures.size() == (1 if roll == 6 else 0), "Search %d: treasure only on a modified 6" % roll)
			if natural == 5 and bonus == 1:
				seen["5+1"] = true
				check(g.treasures.size() == 1, "natural 5 + miss bonus = 6 finds a treasure")
			if natural == 5 and bonus == 0:
				seen["5"] = true
				check(g.treasures.size() == 0, "natural 5 with no bonus: Shard only")
			check(g.search_bonus == 0, "the Search bonus is used up")
			check(g.searched.has(room), "a successful Search marks the room searched")
	check(seen.has(1) and seen.has(6) and seen.has("5+1") and seen.has("5"), "Search rolled the full range in 600 tries")

	# Bonus does not stack: a fail while a bonus is pending can't happen, and a fail sets it to 1, not 2.
	g.search_bonus = 1
	g.searched.erase(room)
	g.player_room = room
	g._search()
	check(g.search_bonus == 0, "bonus consumed on the next roll")

	# Eligibility: not on a Seal, not twice.
	g = _game()
	g.player_room = g.castle.seals[0]
	_set_hand(g, ["search", "dash"])
	check(not g.can_play(0, "normal"), "can't Search a Seal room")
	g.player_room = room
	g.searched[room] = true
	check(not g.can_play(0, "normal"), "can't Search a room twice")

	# Overflow: a full pack loses the found treasure (existing rule).
	g.treasures = ["ward_charm", "ration"]
	g._gain_treasure("smoke_vial")
	check(g.treasures == ["ward_charm", "ration"], "full pack: treasure is not added")


# ---------------------------------------------------------------- activate

func _on_seal(g, si: int) -> void:
	g.player_room = g.castle.seals[si]
	_calm(g)


func _test_activate() -> void:
	var g = _game()
	_on_seal(g, 0)
	g.shards = 3
	g.noise = 2
	_set_hand(g, ["activate", "search"])
	check(g.can_play(0, "normal"), "Activate available with 2+ Shards on an unrestored Seal")
	g.take_events()
	check(g.play_card(0, "normal"), "Activate plays")
	var dice := 0
	for e in g.take_events():
		if e["type"] == "dice":
			dice += 1
	check(g.restored[0], "Activate always restores the Seal")
	check(g.shards == 1, "Activate spends exactly 2 Shards")
	check(dice == 0, "Activate makes no roll")
	check(g.noise == 2, "Activate does not change Noise")
	check(g.redraw_ready, "Activate gives no redraw/Focus reward")

	g = _game()
	_on_seal(g, 1)
	g.shards = 1
	_set_hand(g, ["activate", "search"])
	check(not g.can_play(0, "normal"), "Activate unavailable with 1 Shard and no key")
	check(not g.can_play(0, "rune_key"), "non-Knight heroes have no Rune Key")
	g.shards = 2
	g.restored[1] = true
	check(not g.can_play(0, "normal"), "Activate unavailable on a restored Seal")
	g.player_room = g.castle.neighbors(g.castle.seals[1])[0]
	g.restored[1] = false
	check(g.castle.seal_index(g.player_room) < 0 and not g.can_play(0, "normal"), "Activate needs to be on a Seal")


func _test_rune_key() -> void:
	var g = _game("knight")
	check(g.rune_key_ready, "Knight hero starts with the Rune Key")
	_on_seal(g, 0)
	g.shards = 1
	_set_hand(g, ["activate", "search"])
	check(not g.can_play(0, "normal"), "1 Shard: the normal Activate is unavailable")
	check(g.can_play(0, "rune_key"), "1 Shard + unused key: Activate is available")
	check(g.play_card(0, "rune_key"), "Activate with the Rune Key plays")
	check(g.restored[0] and g.shards == 0 and not g.rune_key_ready, "Rune Key: 1 Shard spent, key used")

	# Once per run.
	if g.phase == "player":
		_on_seal(g, 1)
		g.shards = 1
		_set_hand(g, ["activate", "search"])
		check(not g.can_play(0, "rune_key") and not g.can_play(0, "normal"), "Rune Key works once per run")

	# Optional: with 2 Shards you can keep the key.
	g = _game("knight")
	_on_seal(g, 2)
	g.shards = 2
	_set_hand(g, ["activate", "search"])
	check(g.can_play(0, "normal") and g.can_play(0, "rune_key"), "2 Shards: both ways are offered")
	check(g.play_card(0, "normal") and g.shards == 0 and g.rune_key_ready, "normal Activate keeps the key")

	# Still needs the Activate card and the Seal.
	g = _game("knight")
	g.shards = 1
	_set_hand(g, ["search", "dash"])
	_on_seal(g, 0)
	check(not g.can_play(0, "rune_key"), "Rune Key needs the Activate card")
	g.player_room = g.castle.neighbors(g.castle.seals[0])[0]
	_set_hand(g, ["activate", "dash"])
	if g.castle.seal_index(g.player_room) < 0:
		check(not g.can_play(0, "rune_key"), "Rune Key needs to be on a Seal")
	g.shards = 0
	_on_seal(g, 0)
	check(not g.can_play(0, "rune_key"), "Rune Key still needs 1 Shard")


func _test_third_seal_wins() -> void:
	var g = _game()
	g.restored[0] = true
	g.restored[1] = true
	_on_seal(g, 2)
	g.shards = 2
	_set_hand(g, ["activate", "search"])
	check(g.play_card(0, "normal"), "third Activate plays")
	check(g.phase == "won", "restoring the third Seal wins immediately")


# ---------------------------------------------------------------- redraw

func _test_redraw() -> void:
	var g = _game()
	var turn: int = g.turn
	check(g.can_redraw(), "redraw available at the start of a run")
	var total_before: int = g.deck.size() + g.discard.size() + g.hand.size()
	check(g.redraw_hand(), "redraw works")
	check(g.hand.size() == 2, "redraw draws 2 cards")
	check(g.deck.size() + g.discard.size() + g.hand.size() == total_before, "redraw keeps all 16 cards in play")
	check(g.turn == turn and g.phase == "player", "redraw costs no turn")
	check(not g.can_redraw() and not g.redraw_hand(), "only one redraw per run")
	# Still unavailable on later turns.
	_set_hand(g, ["search", "dash"])
	g.play_card(0, "sneak_quiet")
	check(not g.can_redraw(), "redraw does not come back on a later turn")
	# A new run resets it.
	var g2 = _game()
	check(g2.can_redraw(), "a new run has its redraw again")
	# Reshuffle path: an empty deck still redraws from the discard pile.
	var g3 = _game()
	g3.discard.append_array(g3.deck)
	g3.deck.clear()
	check(g3.redraw_hand() and g3.hand.size() == 2, "redraw reshuffles the discard when the deck is empty")


# ---------------------------------------------------------------- knight movement

## Two rooms at exactly door-distance d (a, b). Returns [] if none.
func _pair_at(c, d: int) -> Array:
	for a in c.room_count():
		var dist: Array = c.distances(a)
		for b in c.room_count():
			if dist[b] == d:
				return [a, b]
	return []


## Puts the player and Knight `d` doorways apart, clears noise and the token, Knight patrolling.
func _place(g, d: int) -> bool:
	var pr := _pair_at(g.castle, d)
	if pr.is_empty():
		return false
	g.player_room = pr[0]
	g.knight.room = pr[1]
	g.noise = 0
	g.token = -1
	g.knight.state = "PATROL"
	g.knight.skip_turns = 0
	g.knight._compute_plan()
	return true


func _test_normal_knight() -> void:
	var g = Game.new()
	g.new_game("ranger", "normal", 77, false)
	var k = g.knight
	check(k.fixed_move(), "Normal uses fixed Knight movement")

	# Patrol: always 1 room, no die rolled or consumed.
	for i in 10:
		_place(g, 4)
		var st: int = g.rng.state
		var nr: int = k.next_roll
		var walk: Array = k.begin_turn(g._senses())
		check(k.state == "PATROL", "far and quiet: Patrol")
		check(walk.size() == mini(1, k.plan.size()), "Patrol moves 1 room every turn")
		check(g.rng.state == st, "Normal: no Knight die is rolled")
		check(k.last_roll == 0 and k.next_roll == nr, "Normal: no movement die is consumed")

	# Investigate a new token: 1 room.
	_place(g, 4)
	g.noise = 1
	g.token = g.player_room
	g.token_serial += 1
	var w: Array = k.begin_turn(g._senses())
	check(k.state == "INVESTIGATE" and w.size() == 1, "Investigate moves 1 room every turn")

	# Hunt by sight only (Noise below the threshold): 1 room.
	_place(g, 1)
	w = k.begin_turn(g._senses())
	check(k.state == "HUNT" and not k.charging and w.size() == 1, "sight-only Hunt moves 1 room")

	# Hunt by hearing: up to 2 rooms.
	_place(g, 4)
	g.noise = 3
	w = k.begin_turn(g._senses())
	check(k.state == "HUNT" and k.charging and w.size() == 2, "hearing Hunt moves 2 rooms")

	# Hearing and seeing at once still counts as hearing (charging), path is only 1 long here.
	_place(g, 1)
	g.noise = 4
	w = k.begin_turn(g._senses())
	check(k.state == "HUNT" and k.charging and w == [g.player_room], "hear + see: charging, stops on the player")

	# Memory pursuit after losing detection: Investigate at 1 room, no hearing bonus.
	_place(g, 4)
	g.noise = 3
	k.begin_turn(g._senses())            # hears you: Hunt
	g.reduce_noise(3)                    # goes quiet (token dropped on your room, already handled)
	k.handled_serial = g.token_serial    # no new clue: pure memory
	w = k.begin_turn(g._senses())
	check(k.state == "INVESTIGATE" and w.size() <= 1, "memory pursuit moves up to 1 room")

	# Search: up to 1 room.
	_place(g, 4)
	k._start_search(k.room)
	k._compute_plan()
	w = k.begin_turn(g._senses())
	check(k.state == "SEARCH" and w.size() <= 1, "Search moves up to 1 room")

	# Stunned: no move and no encounter, even in your room.
	_place(g, 0)
	k.skip_turns = 1
	g._world_phase()
	check(k.stunned_now and g.phase == "player", "stunned Knight: no move, no encounter")

	# Stops on the player: a hearing charge from 2 rooms away ends in your room with an encounter.
	g = Game.new()
	g.new_game("ranger", "normal", 78, false)
	_place(g, 2)
	g.noise = 3
	g._world_phase()
	check(g.knight.room == g.player_room and g.phase == "encounter", "charge reaches the player and stops there")

	# From 1 room away, a charge stops on the player instead of walking past.
	g = Game.new()
	g.new_game("ranger", "normal", 79, false)
	_place(g, 1)
	g.noise = 3
	var walk2: Array = g.knight.begin_turn(g._senses())
	check(walk2.size() == 1 and walk2[0] == g.player_room, "movement stops on entering the player's room")


func _test_easy_hard_unchanged() -> void:
	# Easy and Hard use Normal's Knight; only turns, hearing and encounter HIDE differ.
	var want := {
		"easy": {"turns": 42, "hunt_at": 4, "checks_hiding": false},
		"normal": {"turns": 36, "hunt_at": 3, "checks_hiding": false},
		"hard": {"turns": 36, "hunt_at": 2, "checks_hiding": true},
	}
	var n: Dictionary = Config.DIFFICULTY["normal"]
	for d in want:
		var dd: Dictionary = Config.DIFFICULTY[d]
		check(dd.size() == n.size(), "%s has the same settings as Normal" % d)
		for key in n:
			if key == "name" or want[d].has(key):
				continue
			check(dd.get(key) == n[key], "%s %s matches Normal" % [d, key])
		for key in want[d]:
			check(dd.get(key) == want[d][key], "%s %s is %s" % [d, key, str(want[d][key])])
		var g = Game.new()
		g.new_game("ranger", d, 91, false)
		check(g.knight.fixed_move(), "%s: the Knight moves every turn (no die)" % d)
		check(g.turn_limit() == want[d]["turns"] and g.turns_left() == want[d]["turns"], "%s: %d turns before midnight" % [d, want[d]["turns"]])
		check(g.hide_safe_min() == (5 if want[d]["checks_hiding"] else 4), "%s: encounter HIDE safe minimum" % d)
		# Midnight comes after the last turn of this difficulty, not before.
		g.turn = want[d]["turns"]
		check(g.turns_left() == 1, "%s: last turn counts down to 1" % d)


# ---------------------------------------------------------------- line of sight

func _test_line_of_sight() -> void:
	var c = Castle.new()
	c.n = 5
	c.doors.clear()
	# Row 0: A1-B1-C1 open, C1-D1 closed. Column A: A1-A2 open. A2-B2 open (for a corner).
	c.doors[Castle.key(0, 1)] = true
	c.doors[Castle.key(1, 2)] = true
	c.doors[Castle.key(0, 5)] = true
	c.doors[Castle.key(5, 6)] = true
	check(c.in_sight(0, 0, 0), "same room is always in sight")
	check(c.in_sight(0, 1, 1), "next room through an open doorway, straight")
	check(not c.in_sight(0, 1, 0), "sight 0: only the same room")
	check(c.in_sight(0, 2, 2) and not c.in_sight(0, 2, 1), "2 rooms down a corridor needs sight 2")
	check(not c.in_sight(2, 3, 2), "a closed wall blocks sight even next door")
	check(not c.in_sight(0, 6, 2), "no sight around a corner, even with a 2-door path")
	check(c.distance(0, 6) == 2, "(the corner room is 2 doorways away)")
	check(c.in_sight(0, 5, 1) and c.in_sight(5, 0, 1), "vertical sight works both ways")


# ---------------------------------------------------------------- seal signal

## A room at least `d` doorways from `from`, or -1.
func _room_at_least(c, from: int, d: int) -> int:
	var dist: Array = c.distances(from)
	for r in c.room_count():
		if dist[r] >= d:
			return r
	return -1


func _test_seal_signal() -> void:
	for d in Config.DIFFICULTY_ORDER:
		var g = Game.new()
		g.new_game("ranger", d, 501, false)
		var k = g.knight
		check(k.signal_room == -1, "%s: no signal before any Seal" % d)
		# First Seal: signal at that room, Knight pursues 2 rooms with no die.
		g.player_room = g.castle.seals[0]
		g.knight.room = _room_at_least(g.castle, g.player_room, 5)
		g.knight.state = "PATROL"
		g.knight._compute_plan()
		g.noise = 0
		g.token = -1
		g.shards = 2
		_set_hand(g, ["activate", "search"])
		var pre_roll: int = k.next_roll
		g.take_events()
		check(g.play_card(0, "normal"), "%s: first Activate plays" % d)
		var signalled := false
		var kpath: Array = []
		var kfrom := -1
		for e in g.take_events():
			if e["type"] == "signal":
				signalled = e["room"] == g.castle.seals[0]
			if e["type"] == "knight":
				kpath = e["path"]
				kfrom = e["from"]
		check(signalled, "%s: first Seal sends a signal at its room" % d)
		var dpost: int = g.castle.distance(kfrom, g.castle.seals[0])
		check(kpath.size() == mini(2, dpost), "%s: signal pursuit moves up to 2 rooms (post-shift map)" % d)
		check(k.last_roll == 0 and k.next_roll == pre_roll, "%s: signal pursuit rolls no die" % d)
		if dpost > 2:
			check(k.signal_room == g.castle.seals[0] and k.following_signal(), "%s: keeps following until it arrives" % d)
			check(k.state == "INVESTIGATE" and k.target == g.castle.seals[0], "%s: target is the Seal room, not the player" % d)

	# Second Seal also signals; a newer signal replaces the older one.
	var g2 = Game.new()
	g2.new_game("ranger", "normal", 502, false)
	g2.restored[0] = true
	g2.player_room = g2.castle.seals[1]
	g2.knight.room = _room_at_least(g2.castle, g2.player_room, 4)
	g2.noise = 0
	g2.token = -1
	g2.knight.receive_signal(g2.castle.seals[0])
	g2.shards = 2
	g2.knight.skip_turns = 1
	_set_hand(g2, ["activate", "search"])
	g2.take_events()
	g2.play_card(0, "normal")
	var sig2 := false
	for e in g2.take_events():
		if e["type"] == "signal":
			sig2 = true
	check(sig2, "second Seal sends a signal")
	check(g2.knight.signal_room == g2.castle.seals[1], "newer signal replaces the older one")
	# Stun: turn skipped, signal kept.
	check(g2.knight.stunned_now and g2.knight.signal_room == g2.castle.seals[1], "stun skips the turn but keeps the signal")

	# Detection priority: hearing the player clears the signal and hunts.
	var g3 = Game.new()
	g3.new_game("ranger", "normal", 503, false)
	_place(g3, 4)
	var sroom: int = _room_at_least(g3.castle, g3.knight.room, 3)
	g3.knight.receive_signal(sroom)
	g3.noise = 3
	var w: Array = g3.knight.begin_turn(g3._senses())
	check(g3.knight.state == "HUNT" and g3.knight.target == g3.player_room, "hearing beats the signal")
	check(g3.knight.signal_room == -1, "Hunt clears the signal")
	check(w.size() == 2, "Normal hearing hunt still 2 rooms")

	# Arrival with nobody there: clear the signal, start Search at the Seal.
	var g4 = Game.new()
	g4.new_game("ranger", "normal", 504, false)
	_place(g4, 4)
	var nb: int = g4.castle.neighbors(g4.knight.room)[0]
	if nb == g4.player_room:
		nb = g4.castle.neighbors(g4.knight.room)[-1]
	g4.knight.receive_signal(nb)
	var w4: Array = g4.knight.begin_turn(g4._senses())
	check(w4 == [nb], "walks onto the signalled room")
	for r in w4:
		g4.knight.step_to(r)
	g4.knight.end_turn(false)
	check(g4.knight.signal_room == -1 and g4.knight.state == "SEARCH" and g4.knight.search_center == nb, "arrival clears the signal and starts Search there")

	# Encounter timing: the player stays on the Seal, the Knight arrives and stops there.
	var g5 = Game.new()
	g5.new_game("ranger", "normal", 505, false)
	var pair: Array = []
	for a in g5.castle.room_count():
		for b in g5.castle.room_count():
			if g5.castle.distance(a, b) == 2 and not g5.castle.in_sight(b, a, 1):
				pair = [a, b]
				break
		if not pair.is_empty():
			break
	g5.player_room = pair[0]
	g5.knight.room = pair[1]
	g5.noise = 0
	g5.token = -1
	g5.knight.receive_signal(pair[0])
	g5._world_phase()
	check(g5.knight.room == pair[0] and g5.phase == "encounter", "signal pursuit reaches the player and the encounter starts at the normal step")

	# Third Seal: immediate win, no signal, no Spirit or Knight action.
	var g6 = Game.new()
	g6.new_game("ranger", "normal", 506, false)
	g6.restored[0] = true
	g6.restored[1] = true
	g6.player_room = g6.castle.seals[2]
	g6.shards = 2
	var kr: int = g6.knight.room
	_set_hand(g6, ["activate", "search"])
	g6.take_events()
	g6.play_card(0, "normal")
	var any_signal := false
	for e in g6.take_events():
		if e["type"] in ["signal", "knight"]:
			any_signal = true
	check(g6.phase == "won" and not any_signal and g6.knight.room == kr, "third Seal wins with no signal and no Knight action")


# ---------------------------------------------------------------- spirit / priest removal

func _test_spirit_removed() -> void:
	check(Config.HERO_ORDER == ["ranger", "alchemist", "mage", "knight", "thief"], "five heroes, ids unchanged")
	check(not Config.HEROES.has("priest"), "Priest removed")
	check(Config.TREASURES == ["ward_charm", "old_shield", "ration", "smoke_vial"], "four treasures")
	check(not Config.TREASURE_INFO.has("spirit_bell"), "Spirit Bell removed")
	for h in Config.HERO_ORDER:
		check(Config.HEROES[h]["item"] != "blessing", "no hero has the Blessing")

	# New run setup and turn progression for every hero: no Spirit, turn advances, Knight acts.
	for h in Config.HERO_ORDER:
		var g = Game.new()
		g.new_game(h, "normal", 600, false)
		check(not ("spirit_room" in g) and not ("blessed_turns" in g), "%s: no Spirit state" % h)
		check(g.phase == "player" and g.hand.size() == 2 and g.turn == 1, "%s: new run starts on turn 1 with 2 cards" % h)
		g.take_events()
		_set_hand(g, ["search", "dash"])
		g.play_card(0, "sneak_quiet")
		var types := []
		for e in g.take_events():
			types.append(e["type"])
		check(not ("spirit_move" in types) and not ("shriek" in types) and not ("spirit" in types), "%s: no Spirit events" % h)
		check("knight" in types, "%s: the Knight acts right after the player" % h)
		check(g.phase != "player" or g.turn == 2, "%s: turn advances" % h)

	# Treasure generation only yields the four treasures.
	var g2 = Game.new()
	g2.new_game("ranger", "normal", 601, false)
	for i in 400:
		g2.treasures = []
		g2._gain_treasure()
		check(g2.treasures.size() == 1 and g2.treasures[0] in Config.TREASURES, "treasure drawn from the 4-item pool")

	# Encounter flee still works without a Spirit (picks a neighbouring room).
	for i in 50:
		var f: int = g2._flee_room()
		check(f in g2.castle.neighbors(g2.player_room), "flee goes to a neighbouring room")

	# Old save with the removed hero: loads, keeps unlocks, never offers the Priest.
	var path := "user://test_old_profile.cfg"
	var cf := ConfigFile.new()
	cf.set_value("p", "games", 9)
	cf.set_value("p", "wins", 4)
	cf.set_value("p", "wins_by_diff", {"easy": 1, "normal": 2, "hard": 1})
	cf.set_value("p", "heroes_won", ["ranger", "priest", "mage"])
	cf.set_value("p", "best_turns", {"hard": 25})
	cf.save(path)
	var pr = Profile.new()
	pr.path = path
	pr.load_profile()
	check(pr.wins == 4 and pr.wins_by_diff["hard"] == 1, "old save counters load")
	check(pr.hero_unlocked("thief"), "old Priest win still counts toward the Thief unlock")
	check(pr.hero_unlocked("knight") and pr.hero_unlocked("mage") and pr.difficulty_unlocked("hard"), "old unlocks preserved")
	var names := {}
	for h in Config.HERO_ORDER:
		names[h] = Config.HEROES[h]["name"]
	var unlocked: Array = pr.record("ranger", "normal", true, 20, names)
	check(not ("priest" in str(unlocked).to_lower()), "recording a win never mentions the Priest")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- bot smoke

func _test_bot_games() -> void:
	var bot = Bot.new()
	var ended := 0
	for s in range(1, 61):
		var g = Game.new()
		g.new_game(Config.HERO_ORDER[s % Config.HERO_ORDER.size()], Config.DIFFICULTY_ORDER[s % 3], s, false)
		var steps := 0
		while (g.phase == "player" or g.phase == "encounter") and steps < 400:
			bot.play_turn(g)
			steps += 1
		if g.phase == "won" or g.phase == "lost":
			ended += 1
		check(g.shards >= 0, "Shards never negative")
		check(g.noise >= 0 and g.noise <= Config.MAX_NOISE, "Noise stays within 0-5")
	check(ended == 60, "all 60 bot games finish under the new rules")


# ---------------------------------------------------------------- UI previews

## preview(), why_not() and knight_public() must not change the game or advance the RNG.
func _snapshot(g) -> String:
	return str([g.player_room, g.noise, g.token, g.token_serial, g.shards, g.restored, g.hand, g.deck.size(),
		g.search_bonus, g.searched.size(), g.treasures, g.turn, g.phase, g.rng.state, g.knight.room,
		g.knight.state, g.knight.target, g.knight.plan, g.knight.next_roll, g.knight.search_pick, g.events.size()])


func _test_previews_read_only() -> void:
	for s in range(1, 41):
		var g = Game.new()
		g.new_game(Config.HERO_ORDER[s % 5], Config.DIFFICULTY_ORDER[s % 3], s, false)
		g.take_events()
		var bot := Bot.new()
		for _t in 12:
			if g.phase != "player":
				break
			var before := _snapshot(g)
			for i in g.hand.size():
				for mode in ["normal", "sneak_move", "sneak_quiet", "rune_key"]:
					g.why_not(i, mode)
					g.preview(i, mode, -1)
					if g.needs_target(g.hand[i], mode):
						for r in g.move_options(g.hand[i], mode):
							g.preview(i, mode, r)
			g.knight_public()
			check(_snapshot(g) == before, "seed %d: previews changed the game state" % s)
			bot.play_turn(g)
			g.take_events()

	var g2 = _game()
	g2.noise = 2
	_set_hand(g2, ["dash", "search"])
	var opts: Array = g2.move_options("dash", "normal")
	var p: Dictionary = g2.preview(0, "normal", opts[0])
	check(str(p["warn"]).contains("hear you"), "Dash preview warns that Noise 3 will be heard on Normal")
	g2.shards = 1
	g2.player_room = g2.castle.seals[0]
	_set_hand(g2, ["activate", "search"])
	check(g2.why_not(0, "normal") == "Needs 2 Shards (you have 1).", "Activate reason names the Shards missing")
	check(g2.why_not(1, "normal") == "You can't search a Seal room.", "Search reason on a Seal")
	g2.search_bonus = 1
	g2.player_room = g2.castle.neighbors(g2.castle.seals[0])[0]
	if g2.is_searchable(g2.player_room):
		var ps: Dictionary = g2.preview(1, "normal")
		check(" ".join(PackedStringArray(ps["will"])).contains("can't fail") and str(ps["might"]).contains("Die 1-4: 1 Shard") and str(ps["might"]).contains("Die 5-6"), "Search preview applies the +1 bonus")
