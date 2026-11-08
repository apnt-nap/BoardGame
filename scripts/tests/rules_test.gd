extends SceneTree
## Rules tests for the playtest rule set (movement, Search, automatic Activate, Rune Key,
## free redraw, removed content, third-Seal victory, castle generation). No UI.
##   godot --headless --path . --script res://scripts/tests/rules_test.gd

const Config = preload("res://scripts/core/config.gd")
const Game = preload("res://scripts/core/game.gd")
const Castle = preload("res://scripts/core/castle.gd")
const Bot = preload("res://scripts/core/bot.gd")

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


## A fresh game whose world turn cannot interfere: the Knight is stunned and the Spirit blessed.
func _game(hero: String = "ranger", seed_value: int = 1234) -> Object:
	var g = Game.new()
	g.new_game(hero, "normal", seed_value, false)
	_calm(g)
	return g


func _calm(g) -> void:
	g.knight.skip_turns = 1
	g.blessed_turns = 2
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
	g.blessed_turns = 2
	g._world_phase()
	check(k.stunned_now and g.phase == "player", "stunned Knight: no move, no encounter")

	# Stops on the player: a hearing charge from 2 rooms away ends in your room with an encounter.
	g = Game.new()
	g.new_game("ranger", "normal", 78, false)
	_place(g, 2)
	g.noise = 3
	g.blessed_turns = 2
	g.spirit_room = g.knight.room
	g._world_phase()
	check(g.knight.room == g.player_room and g.phase == "encounter", "charge reaches the player and stops there")

	# From 1 room away, a charge stops on the player instead of walking past.
	g = Game.new()
	g.new_game("ranger", "normal", 79, false)
	_place(g, 1)
	g.noise = 3
	g.blessed_turns = 2
	var walk2: Array = g.knight.begin_turn(g._senses())
	check(walk2.size() == 1 and walk2[0] == g.player_room, "movement stops on entering the player's room")


func _test_easy_hard_unchanged() -> void:
	var want := {
		"easy": {"name": "Easy", "move_min": 4, "memory": 1, "hunt_at": 4, "hunt_steps": 1, "search_turns": 1, "sight": 0, "checks_hiding": false},
		"hard": {"name": "Hard", "move_min": 2, "memory": 3, "hunt_at": 3, "hunt_steps": 2, "search_turns": 3, "sight": 2, "checks_hiding": true},
	}
	for d in want:
		check(Config.DIFFICULTY[d].size() == want[d].size(), "%s has no new settings" % d)
		for key in want[d]:
			check(Config.DIFFICULTY[d].get(key) == want[d][key], "%s %s unchanged" % [d, key])
	for d in ["easy", "hard"]:
		var g = Game.new()
		g.new_game("ranger", d, 91, false)
		var k = g.knight
		check(not k.fixed_move(), "%s still uses the movement die" % d)
		var stays := 0
		for i in 60:
			_place(g, 4)
			var pre: int = k.next_roll
			var w: Array = k.begin_turn(g._senses())
			check(k.last_roll == pre, "%s: the pre-rolled die is used" % d)
			if pre < g.diff["move_min"]:
				stays += 1
				check(w.is_empty(), "%s: a low roll means no move" % d)
			else:
				check(w.size() == 1, "%s: Patrol moves 1 room on a good roll" % d)
		check(stays > 0 or d == "hard", "%s: some turns the Knight stays" % d)
		# Hearing charge: Hard 2 rooms, Easy 1, on a good roll.
		for i in 30:
			_place(g, 4)
			g.noise = 4
			var pre2: int = k.next_roll
			var w2: Array = k.begin_turn(g._senses())
			if pre2 >= g.diff["move_min"]:
				check(w2.size() == (2 if d == "hard" else 1), "%s: charge steps unchanged" % d)


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
