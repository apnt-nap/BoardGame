extends RefCounted
## The Cursed Knight: a finite state machine with memory.
## It only acts on what it senses (Noise level, the Last Known Noise token, and the
## player's room ONLY while Noise is at the hunt threshold). It never reads hidden state.

const Config = preload("res://scripts/core/config.gd")

const PATROL := "PATROL"
const INVESTIGATE := "INVESTIGATE"
const HUNT := "HUNT"
const SEARCH := "SEARCH"

var castle
var diff: Dictionary
var rng: RandomNumberGenerator

var room := 0
var state := PATROL
var patrol_route: Array = []
var patrol_i := 0
var target := -1            # room it is heading to (INVESTIGATE / HUNT)
var target_serial := -1
var memory_left := 0        # turns it keeps chasing a faded trail
var handled_serial := -1    # last noise token it has already checked
var search_center := -1
var search_left := 0
var search_pick := -1
var search_checked: Dictionary = {}
var skip_turns := 0
var next_roll := 1          # pre-rolled so the Library can reveal it honestly
var last_roll := 0          # the die it used this turn (0 = it did not roll)
var plan: Array = []        # planned path for intent cues and the debug overlay
var reason := ""
var charging := false
var stunned_now := false    # lost this turn to the Lantern: no move, no encounter       # hunting because of loud Noise (moves hunt_steps) vs. stalking by sight
var turn_no := 0
var logging := true
var log_lines: Array = []


func setup(p_castle, p_diff: Dictionary, p_rng: RandomNumberGenerator, start_room: int, restored: Array) -> void:
	castle = p_castle
	diff = p_diff
	rng = p_rng
	room = start_room
	rebuild_patrol(restored)
	next_roll = rng.randi_range(1, 6)
	_compute_plan()
	reason = "Begins its patrol of the Seals"


## Patrol loop through all three Seals; restored Seals appear twice (it guards what you fixed).
func rebuild_patrol(restored: Array) -> void:
	patrol_route = castle.seals.duplicate()
	for i in castle.seals.size():
		if restored[i]:
			patrol_route.append(castle.seals[i])
	var best := 0
	var best_d := 999
	for i in patrol_route.size():
		var d: int = castle.distance(room, patrol_route[i])
		if d < best_d:
			best_d = d
			best = i
	patrol_i = best


func log_event(text: String) -> void:
	if logging:
		log_lines.append("T%02d [%s] %s" % [turn_no, state, text])


## Senses: {noise, token, token_serial, seen, player_room (-1 unless it hears you at the hunt
## threshold or sees you within its sight range)}
func update_state(s: Dictionary) -> void:
	var hunt_at: int = diff["hunt_at"]
	if s["player_room"] >= 0:
		state = HUNT
		target = s["player_room"]
		memory_left = diff["memory"]
		handled_serial = s["token_serial"]
		charging = s["noise"] >= hunt_at
		if charging:
			reason = "Noise %d >= %d: it hears you clearly and charges %s" % [s["noise"], hunt_at, room_name(target)]
		else:
			reason = "It glimpses you through the doorway at %s and stalks closer" % room_name(target)
	elif s["token"] >= 0 and s["token_serial"] != handled_serial:
		if state == INVESTIGATE and target == s["token"]:
			reason = "Still heading for the noise at %s" % room_name(target)
		else:
			reason = "Heard something at %s: goes to investigate" % room_name(s["token"])
		state = INVESTIGATE
		target = s["token"]
		target_serial = s["token_serial"]
		memory_left = diff["memory"]
	elif state == INVESTIGATE or state == HUNT:
		if memory_left > 0 and target != room:
			memory_left -= 1
			state = INVESTIGATE
			reason = "The noise faded, but it remembers %s (%d turn(s) of memory left)" % [room_name(target), memory_left]
		else:
			_start_search(room)
			reason = "Lost the trail: searches the rooms around %s" % room_name(room)
	elif state == SEARCH:
		if search_left <= 0:
			state = PATROL
			reason = "Found nothing: returns to its patrol"
		else:
			reason = "Searching around %s (%d turn(s) left)" % [room_name(search_center), search_left]
	else:
		state = PATROL
		reason = "Patrolling toward Seal %s" % seal_letter(patrol_route[patrol_i])
	_compute_plan()


func _start_search(center: int) -> void:
	state = SEARCH
	search_center = center
	search_left = diff["search_turns"]
	search_checked = {center: true}
	search_pick = -1


func _compute_plan() -> void:
	match state:
		HUNT, INVESTIGATE:
			plan = castle.path(room, target)
		SEARCH:
			if search_pick < 0 or search_checked.has(search_pick):
				var options := []
				for r in castle.neighbors(search_center) + castle.neighbors(room):
					if not search_checked.has(r) and r != room and not (r in options):
						options.append(r)
				search_pick = options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else -1
			plan = castle.path(room, search_pick) if search_pick >= 0 else []
		_:
			if patrol_route[patrol_i] == room:
				patrol_i = (patrol_i + 1) % patrol_route.size()
			plan = castle.path(room, patrol_route[patrol_i])


## Start of the Knight's turn. Returns the rooms it will walk (the game walks them and
## stops early if it bumps into the player).
func begin_turn(s: Dictionary) -> Array:
	turn_no += 1
	update_state(s)
	var roll := next_roll
	last_roll = 0
	next_roll = rng.randi_range(1, 6)
	stunned_now = skip_turns > 0
	if skip_turns > 0:
		skip_turns -= 1
		log_event("Dazzled by the Lantern: loses its turn in %s" % room_name(room))
		return []
	var need: int = diff["move_min"]
	last_roll = roll
	if roll < need:
		log_event("Rolled %d (needs %d+): stays in %s. %s" % [roll, need, room_name(room), reason])
		return []
	var steps: int = diff["hunt_steps"] if state == HUNT and charging else 1
	var walk := plan.slice(0, steps)
	if walk.is_empty():
		log_event("Rolled %d: no path, waits in %s. %s" % [roll, room_name(room), reason])
	else:
		log_event("Rolled %d (needs %d+): moves %s -> %s. %s" % [roll, need, room_name(room), room_name(walk.back()), reason])
	return walk


func step_to(r: int) -> void:
	room = r
	if state == SEARCH:
		search_checked[r] = true


## End of the Knight's move. `found` = it shares a room with the player.
func end_turn(found: bool) -> void:
	if found:
		log_event("Found the intruder in %s!" % room_name(room))
		return
	if state == INVESTIGATE and room == target:
		handled_serial = maxi(handled_serial, target_serial)
		_start_search(room)
		reason = "Reached the noise at %s: nobody. Starts searching" % room_name(room)
		log_event(reason)
	elif state == SEARCH:
		search_left -= 1
	_compute_plan()


## The player hid successfully in its room: it believes the room is empty and searches nearby.
## It is still standing here, so the player should slip away on their turn.
func fooled_by_hiding() -> void:
	_start_search(room)
	reason = "Searched %s and found nothing" % room_name(room)
	log_event("Swept the room but you stayed hidden")
	_compute_plan()


func next_step() -> int:
	return plan[0] if not plan.is_empty() else room


func room_name(r: int) -> String:
	if r < 0:
		return "-"
	var p: Vector2i = castle.pos(r)
	return "%s%d" % [char(65 + p.x), p.y + 1]


func seal_letter(r: int) -> String:
	var i: int = castle.seal_index(r)
	return char(65 + i) if i >= 0 else "?"


func debug_lines() -> Array:
	var names := []
	for r in plan:
		names.append(room_name(r))
	return [
		"State: %s" % state,
		"Room: %s   Target: %s" % [room_name(room), room_name(target)],
		"Memory left: %d   Search left: %d" % [memory_left, search_left],
		"Handled noise #%d   Skip: %d" % [handled_serial, skip_turns],
		"Next D6 (pre-rolled): %d (moves on %d+)" % [next_roll, diff["move_min"]],
		"Plan: %s" % (" > ".join(PackedStringArray(names)) if not names.is_empty() else "(stay)"),
		"Why: %s" % reason,
	]
