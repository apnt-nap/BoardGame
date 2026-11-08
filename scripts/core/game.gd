extends RefCounted
## Full rules of Curse of Blackthorn Keep. No visuals: the UI and the headless simulation
## both drive this object and read `events` to show what happened.

const Config = preload("res://scripts/core/config.gd")
const Castle = preload("res://scripts/core/castle.gd")
const Knight = preload("res://scripts/core/knight_ai.gd")

var rng := RandomNumberGenerator.new()
var castle
var knight
var hero := "ranger"
var difficulty := "normal"
var diff: Dictionary

var player_room := 0
var health: int = Config.MAX_HEALTH
var noise := 0
var token := -1               # Last Known Noise token room (-1 = off the map)
var token_serial := 0         # bumps every time the token is placed
var shards := 0
var restored := [false, false, false]
var redraw_ready := true      # one free redraw per run (replaces Focus); a new run = a new Game
var treasures: Array = []
var hero_item_ready := true
var rune_key_ready := false   # Knight hero: once per run, an Activate may cost 1 Shard
var search_bonus := 0
var searched: Dictionary = {}
var used_once: Dictionary = {}
var room_action_used := false
var blessed_turns := 0
var spirit_room := 0
var corrupted_types: Array = []

var deck: Array = []
var discard: Array = []
var hand: Array = []

var turn := 1
var phase := "player"         # player | encounter | won | lost
var end_reason := ""
var events: Array = []
var stats := {"damage": 0, "found": 0, "noise_made": 0, "shards": 0, "searches": 0, "keep_shifts": 0, "hides": 0, "runs": 0}


func new_game(p_hero: String, p_difficulty: String, seed_value: int = 0, log_knight: bool = true) -> void:
	hero = p_hero
	difficulty = p_difficulty
	diff = Config.DIFFICULTY[difficulty]
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	castle = Castle.new()
	castle.generate(rng)

	var starts := []
	for r in castle.room_count():
		if not (r in castle.seals) and not castle.specials.has(r):
			starts.append(r)
	player_room = _pick(starts)
	var dist: Array = castle.distances(player_room)
	var far := []
	for r in castle.room_count():
		if dist[r] >= 4 and not (r in castle.seals):
			far.append(r)
	if far.is_empty():
		far = [dist.find(dist.max())]
	var knight_start: int = _pick(far)
	var spirit_opts := []
	for r in castle.room_count():
		if r != player_room and r != knight_start:
			spirit_opts.append(r)
	spirit_room = _pick(spirit_opts)

	knight = Knight.new()
	knight.logging = log_knight
	knight.setup(castle, diff, rng, knight_start, restored)

	for t in Config.DECK:
		for _i in Config.DECK[t]:
			deck.append(t)
	_shuffle(deck)
	if hero_item() == "rune_key":
		rune_key_ready = true
		hero_item_ready = false
	_draw_hand()
	_ev("start", "You slip into Blackthorn Keep as the %s. Restore the three Seals before midnight." % Config.HEROES[hero]["name"])


# ------------------------------------------------------------------ helpers

func d6() -> int:
	return rng.randi_range(1, 6)


func _pick(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _ev(type: String, text: String, extra: Dictionary = {}) -> void:
	var e := {"type": type, "text": text, "turn": turn}
	e.merge(extra)
	events.append(e)


func take_events() -> Array:
	var out := events
	events = []
	return out


func _draw_hand() -> void:
	while hand.size() < 2:
		if deck.is_empty():
			deck = discard
			discard = []
			_shuffle(deck)
			_ev("reshuffle", "The deck is reshuffled.")
		hand.append(deck.pop_back())


func room_name(r: int) -> String:
	return knight.room_name(r)


func turns_left() -> int:
	return Config.TURN_LIMIT - turn + 1


func seals_restored() -> int:
	return restored.count(true)


func rooms_within(from: int, k: int) -> Array:
	var dist: Array = castle.distances(from)
	var out := []
	for r in castle.room_count():
		if dist[r] > 0 and dist[r] <= k:
			out.append(r)
	return out


func is_searchable(r: int) -> bool:
	return not (r in castle.seals) and not searched.has(r)


func unrestored_seal_here() -> int:
	var i: int = castle.seal_index(player_room)
	return i if i >= 0 and not restored[i] else -1


# ------------------------------------------------------------------ noise

func add_noise(amount: int, at_room: int) -> void:
	noise = mini(Config.MAX_NOISE, noise + amount)
	stats["noise_made"] += amount
	token = at_room
	token_serial += 1
	_ev("noise", "Noise %d. The noise token lands in %s." % [noise, room_name(at_room)], {"room": at_room})


func reduce_noise(amount: int) -> void:
	var old := noise
	noise = maxi(0, noise - amount)
	if noise == 0:
		token = -1
	elif old >= diff["hunt_at"] and noise < diff["hunt_at"]:
		# The Knight lost your scent: it only knows where you were last.
		token = player_room
		token_serial += 1
	_ev("quiet", "Noise %d." % noise)


# ------------------------------------------------------------------ cards

func move_options(card: String, mode: String) -> Array:
	if mode == "sneak_move":
		return castle.neighbors(player_room)
	if card == "explore":
		return rooms_within(player_room, 2)
	if card == "dash":
		return rooms_within(player_room, 3)
	return []


func needs_target(card: String, mode: String) -> bool:
	return mode == "sneak_move" or (mode == "normal" and (card == "explore" or card == "dash"))


## Shards an Activate costs: 2, or 1 when spending the Rune Key.
func activate_cost(use_key: bool) -> int:
	return Config.SHARDS_PER_SEAL - 1 if use_key else Config.SHARDS_PER_SEAL


## The Rune Key can pay for this Activate: still unused, and you hold at least 1 Shard.
func can_use_rune_key() -> bool:
	return rune_key_ready and shards >= activate_cost(true)


func can_play(i: int, mode: String) -> bool:
	if phase != "player" or i < 0 or i >= hand.size():
		return false
	if mode == "sneak_move":
		return true
	if mode == "sneak_quiet":
		return true  # also works as "wait silently" at Noise 0
	if mode == "rune_key":
		# Activate paying 1 Shard with the Rune Key (optional with 2+ Shards, the only way with 1).
		return hand[i] == "activate" and unrestored_seal_here() >= 0 and can_use_rune_key()
	match hand[i]:
		"explore", "dash":
			return true
		"search":
			return is_searchable(player_room)
		"activate":
			return unrestored_seal_here() >= 0 and shards >= activate_cost(false)
		"hide":
			return noise > 0
	return false


func play_card(i: int, mode: String, target: int = -1) -> bool:
	if not can_play(i, mode):
		return false
	var card: String = hand[i]
	if needs_target(card, mode) and not (target in move_options(card, mode)):
		return false
	discard.append_array(hand)
	hand.clear()
	if mode == "rune_key":
		_ev("card", "Activate (Rune Key).", {"card": card})
		_activate(true)
	elif mode == "sneak_move":
		_ev("card", "Sneak: you creep silently to %s." % room_name(target), {"card": card, "sneak": true})
		_move_player(target)
	elif mode == "sneak_quiet":
		_ev("card", "Sneak: you hold your breath.", {"card": card, "sneak": true})
		reduce_noise(1)
	else:
		_ev("card", "%s." % Config.CARDS[card]["name"], {"card": card})
		match card:
			"explore":
				_move_player(target)
			"dash":
				_move_player(target)
				add_noise(1, target)
			"search":
				_search()
			"activate":
				_activate(false)
			"hide":
				reduce_noise(2)
	_after_player_action()
	return true


func _move_player(r: int) -> void:
	var from := player_room
	player_room = r
	_ev("move", "", {"from": from, "to": r})


func _search() -> void:
	stats["searches"] += 1
	var natural := d6()
	var roll := mini(6, natural + search_bonus)
	search_bonus = 0
	if roll <= 1:
		search_bonus = 1
		_ev("dice", "Search roll %d: you knock over a candlestick! (+1 on your next Search)" % roll, {"roll": natural, "ok": false})
		add_noise(1, player_room)
		return
	searched[player_room] = true
	# 2-5: 1 Shard. 6: 1 Shard and a treasure (modified roll, so a natural 5 + bonus counts).
	shards += 1
	stats["shards"] += 1
	_ev("dice", "Search roll %d: 1 Rune Shard%s." % [roll, " and a treasure" if roll >= 6 else ""], {"roll": natural, "ok": true})
	_ev("shard", "+1 Shard", {"amount": 1})
	if roll >= 6:
		_gain_treasure()


## Activation always succeeds (no roll): spend the Shards and restore the Seal.
func _activate(use_key: bool) -> void:
	var si := unrestored_seal_here()
	shards -= activate_cost(use_key)
	if use_key:
		rune_key_ready = false
		_ev("hero", "The Rune Key turns: the Seal takes only 1 Shard.")
	restored[si] = true
	_ev("seal", "Seal %s restored." % char(65 + si), {"seal": si})
	_on_seal_restored()


func _on_seal_restored() -> void:
	if seals_restored() == 3:
		phase = "won"
		end_reason = "The third Seal flares. The curse breaks and the Knight crumbles to dust."
		_ev("won", end_reason)
		return
	var shift: Dictionary = castle.keep_shift()
	if not shift.is_empty():
		stats["keep_shifts"] += 1
		_ev("shift", "The Keep groans: a doorway seals and another grinds open.", shift)
	knight.rebuild_patrol(restored)
	if seals_restored() == 2:
		corrupted_types = castle.corrupt(2)
		var names := []
		for t in corrupted_types:
			names.append(Config.SPECIALS[t]["name"])
		_ev("corrupt", "Darkness spreads: the %s fall silent." % " and ".join(PackedStringArray(names)), {"types": corrupted_types})
	# 1st/2nd Seal: a signal at the Seal's room (post-shift map). The Knight acts on it on its next turn.
	knight.receive_signal(player_room)
	_ev("signal", "The Seal sends a signal. The Knight is drawn to this room.", {"room": player_room})
	knight._compute_plan()


func _gain_treasure(t: String = "") -> void:
	if t == "":
		t = _pick(Config.TREASURES)
	if treasures.size() >= Config.MAX_TREASURES:
		_ev("treasure", "You find a %s but your pack is full." % Config.TREASURE_INFO[t]["name"])
		return
	treasures.append(t)
	_ev("treasure", "Found: %s." % Config.TREASURE_INFO[t]["name"], {"treasure": t})


# ------------------------------------------------------------------ free actions

func room_action() -> String:
	if phase != "player" or room_action_used:
		return ""
	var t: String = castle.special_at(player_room)
	match t:
		"chapel":
			return t if not used_once.has(t) and health < Config.MAX_HEALTH else ""
		"bell_tower", "armory":
			return t if not used_once.has(t) else ""
		"passage":
			return t if knight.room != castle.passage_exit(player_room) else ""
	return ""


func do_room_action() -> bool:
	var t := room_action()
	if t == "":
		return false
	room_action_used = true
	match t:
		"chapel":
			used_once[t] = true
			health += 1
			_ev("heal", "The Chapel's candles warm you. +1 Health.")
		"bell_tower":
			used_once[t] = true
			token = player_room
			token_serial += 1
			_ev("bell", "BONG. The bell's toll draws every ear in the Keep to the tower.", {"room": player_room})
		"armory":
			used_once[t] = true
			_ev("armory", "You pry open a weapon rack.")
			_gain_treasure()
		"passage":
			var dest: int = castle.passage_exit(player_room)
			_ev("passage", "You slip through the Secret Passage to %s." % room_name(dest))
			_move_player(dest)
	return true


## Ward Charm and Ration also work mid-encounter (you still RUN or HIDE afterwards).
func can_use_treasure(t: String) -> bool:
	if phase != "player" and phase != "encounter":
		return false
	match t:
		"ward_charm":
			return noise > 0
		"ration":
			return health == 1
		"spirit_bell":
			return phase == "player"
	return false


func use_treasure(i: int) -> bool:
	if i < 0 or i >= treasures.size() or not can_use_treasure(treasures[i]):
		return false
	var t: String = treasures[i]
	treasures.remove_at(i)
	match t:
		"ward_charm":
			reduce_noise(1)
			_ev("treasure", "The Ward Charm hums and swallows the echoes.")
		"ration":
			health += 1
			_ev("heal", "You eat the Emergency Ration. +1 Health.")
		"spirit_bell":
			_push_spirit()
	return true


func _push_spirit() -> void:
	var best: int = spirit_room
	var best_d := -1
	var dist: Array = castle.distances(player_room)
	for r in rooms_within(spirit_room, 2):
		if dist[r] > best_d:
			best_d = dist[r]
			best = r
	spirit_room = best
	_ev("spirit", "The Spirit Bell chimes and the Spirit drifts away to %s." % room_name(best))


func hero_item() -> String:
	return Config.HEROES[hero]["item"]


func can_use_hero_item() -> bool:
	if not hero_item_ready or (phase != "player" and phase != "encounter"):
		return false
	match hero_item():
		"lantern", "blessing":
			return phase == "player"
		"potion":
			return health < Config.MAX_HEALTH  # in an encounter you still RUN or HIDE afterwards
		"silence":
			return noise > 0 and phase == "player"
	return false


func use_hero_item() -> bool:
	if not can_use_hero_item():
		return false
	hero_item_ready = false
	match hero_item():
		"lantern":
			knight.skip_turns = 1
			_ev("hero", "You flash the Lantern. The Knight reels, blinded: it loses its next turn.")
		"potion":
			health += 1
			_ev("heal", "You drink the Healing Potion. +1 Health.")
		"silence":
			reduce_noise(2)
			_ev("hero", "The Silence Scroll crumbles. Every echo dies.")
		"blessing":
			blessed_turns = Config.SPIRIT_BLESS_TURNS
			_ev("hero", "A Blessing settles on you. The Spirit cannot betray you for %d turns." % blessed_turns)
	return true


## One optional free redraw per run, before you play the turn's card. Costs no turn.
func can_redraw() -> bool:
	return phase == "player" and redraw_ready and hand.size() == 2


func redraw_hand() -> bool:
	if not can_redraw():
		return false
	redraw_ready = false
	discard.append_array(hand)
	hand.clear()
	_draw_hand()
	_ev("redraw", "You steady your nerves and redraw. Your one redraw this run is used.")
	return true


# ------------------------------------------------------------------ world turn

func _after_player_action() -> void:
	if phase != "player":
		return
	# Walking into the Knight's room does not start a fight yet (rulebook step 10).
	_world_phase()


func _senses() -> Dictionary:
	# The Knight only knows where you are if it hears you (Noise at the hunt threshold)
	# or sees you down a straight corridor of open doorways, up to `sight` rooms away.
	var seen: bool = castle.in_sight(knight.room, player_room, diff["sight"])
	return {
		"noise": noise,
		"token": token,
		"token_serial": token_serial,
		"seen": seen,
		"player_room": player_room if (noise >= diff["hunt_at"] or seen) else -1,
	}


func _world_phase() -> void:
	# Wandering Spirit drifts one room.
	var nbs: Array = castle.neighbors(spirit_room)
	var from_s := spirit_room
	spirit_room = _pick(nbs)
	_ev("spirit_move", "", {"from": from_s, "to": spirit_room})
	if spirit_room == player_room:
		if blessed_turns > 0:
			_ev("spirit", "The Wandering Spirit circles you but the Blessing keeps it quiet.")
		else:
			_ev("shriek", "The Wandering Spirit finds you and SHRIEKS!")
			add_noise(1, player_room)
	# Cursed Knight.
	var from_k: int = knight.room
	var walk: Array = knight.begin_turn(_senses())
	var walked := []
	for r in walk:
		knight.step_to(r)
		walked.append(r)
		if r == player_room:
			break
	# A stunned Knight causes no encounter this turn (rulebook: "Stunned").
	var found: bool = knight.room == player_room and not knight.stunned_now
	knight.end_turn(found)
	_ev("knight", knight.log_lines.back() if knight.logging and not knight.log_lines.is_empty() else "", {"from": from_k, "path": walked, "state": knight.state, "roll": knight.last_roll, "need": diff["move_min"]})
	if found:
		_start_encounter()
		return
	_end_turn()


func _end_turn() -> void:
	if blessed_turns > 0:
		blessed_turns -= 1
	turn += 1
	if turn > Config.TURN_LIMIT:
		_lose("Midnight strikes. The curse sets like stone, and so do you.")
		return
	room_action_used = false
	_draw_hand()
	_ev("turn", "Turn %d. %d turn(s) until midnight." % [turn, turns_left()])


func _lose(reason: String) -> void:
	phase = "lost"
	end_reason = reason
	_ev("lost", reason)


# ------------------------------------------------------------------ encounters

func _start_encounter() -> void:
	phase = "encounter"
	stats["found"] += 1
	_ev("encounter", "The Cursed Knight is in the room with you!")


func encounter_options() -> Array:
	var out := [
		{"id": "run", "label": "RUN", "text": "D6 1-2: -1 Health. Always flee 1 room, Noise +1."},
		{"id": "hide", "label": "HIDE", "text": ("D6 1-4: -1 Health and flee. 5-6: safe." if diff["checks_hiding"] else "D6 1-3: -1 Health and flee. 4-6: safe.")},
	]
	if "smoke_vial" in treasures:
		out.append({"id": "smoke_vial", "label": "SMOKE VIAL", "text": "Escape 1 room. No damage, no noise."})
	if hero_item_ready:
		match hero_item():
			"lantern":
				out.append({"id": "lantern", "label": "LANTERN", "text": "Escape 1 room silently; the Knight loses its next turn."})
			"silence":
				out.append({"id": "silence", "label": "SILENCE SCROLL", "text": "Escape 1 room; Noise -2."})
			"smoke":
				out.append({"id": "smoke", "label": "SMOKE VIAL", "text": "Escape 1 room. No damage, no noise."})
	return out


func resolve_encounter(choice: String) -> bool:
	if phase != "encounter":
		return false
	var ids := []
	for o in encounter_options():
		ids.append(o["id"])
	if not (choice in ids):
		return false
	match choice:
		"run":
			stats["runs"] += 1
			var roll := d6()
			_ev("dice", "Run roll %d." % roll, {"roll": roll, "ok": roll > 2})
			if roll <= 2:
				_damage("Its blade catches you as you flee.")
			var dest := _flee_room()
			_move_player(dest)
			add_noise(1, dest)
		"hide":
			stats["hides"] += 1
			var roll := d6()
			var safe_min := 5 if diff["checks_hiding"] else 4
			_ev("dice", "Hide roll %d (safe on %d+)." % [roll, safe_min], {"roll": roll, "ok": roll >= safe_min})
			if roll >= safe_min:
				_ev("hidden", "You press into the shadows. The Knight looks straight through you.")
				knight.fooled_by_hiding()
			else:
				_damage("It drags you out of your hiding place.")
				_move_player(_flee_room())
		"smoke_vial", "smoke", "lantern", "silence":
			if choice == "smoke_vial":
				treasures.erase("smoke_vial")
			else:
				hero_item_ready = false
			_ev("escape", "You vanish in a cloud and slip away.")
			_move_player(_flee_room())
			if choice == "lantern":
				knight.skip_turns = 1
			elif choice == "silence":
				reduce_noise(2)
	if phase == "lost":
		return true
	phase = "player"
	_end_turn()
	return true


func _flee_room() -> int:
	var opts: Array = castle.neighbors(player_room)
	var safe := []
	for r in opts:
		if r != spirit_room:
			safe.append(r)
	return _pick(safe if not safe.is_empty() else opts)


func _damage(text: String) -> void:
	if "old_shield" in treasures:
		treasures.erase("old_shield")
		_ev("block", "The Old Shield takes the blow and shatters.")
		return
	health -= 1
	stats["damage"] += 1
	_ev("damage", "%s -1 Health." % text)
	if health <= 0:
		_lose("The Cursed Knight claims another soul for Blackthorn Keep.")
