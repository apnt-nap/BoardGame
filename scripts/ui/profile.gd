extends RefCounted
## Unlock progress saved to user://profile.cfg

const PATH := "user://profile.cfg"

var path := PATH   # tests point this elsewhere so they never touch real progress

var games := 0
var wins := 0
var wins_by_diff := {"easy": 0, "normal": 0, "hard": 0}
var heroes_won: Array = []
var best_turns := {}   # difficulty -> fewest turns in a win


func load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	games = cf.get_value("p", "games", 0)
	wins = cf.get_value("p", "wins", 0)
	wins_by_diff = cf.get_value("p", "wins_by_diff", wins_by_diff)
	heroes_won = cf.get_value("p", "heroes_won", [])
	best_turns = cf.get_value("p", "best_turns", {})


func save_profile() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "games", games)
	cf.set_value("p", "wins", wins)
	cf.set_value("p", "wins_by_diff", wins_by_diff)
	cf.set_value("p", "heroes_won", heroes_won)
	cf.set_value("p", "best_turns", best_turns)
	cf.save(path)


func hero_unlocked(hero: String) -> bool:
	match hero:
		"mage":
			return wins >= 1
		"knight":
			return wins_by_diff["normal"] >= 1 or wins_by_diff["hard"] >= 1
		"thief":
			# Old saves may list "priest" (removed hero); its wins still count as a different hero.
			return heroes_won.size() >= 3
	return true


func difficulty_unlocked(diff: String) -> bool:
	return diff != "hard" or wins_by_diff["normal"] >= 1 or wins_by_diff["hard"] >= 1


## Records a finished run; returns the names of anything newly unlocked.
func record(hero: String, diff: String, won: bool, turns: int, hero_names: Dictionary) -> Array:
	var before := {}
	for h in hero_names:
		before[h] = hero_unlocked(h)
	var hard_before := difficulty_unlocked("hard")
	games += 1
	if won:
		wins += 1
		wins_by_diff[diff] += 1
		if not (hero in heroes_won):
			heroes_won.append(hero)
		if not best_turns.has(diff) or turns < best_turns[diff]:
			best_turns[diff] = turns
	save_profile()
	var out := []
	for h in hero_names:
		if not before[h] and hero_unlocked(h):
			out.append("New hero: " + hero_names[h])
	if not hard_before and difficulty_unlocked("hard"):
		out.append("Hard difficulty")
	return out
