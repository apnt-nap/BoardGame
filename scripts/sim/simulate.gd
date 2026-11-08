extends SceneTree
## Headless balance simulation. Plays N bot games per hero per difficulty and writes a CSV.
## Run from the project folder:
##   godot --headless --path . --script res://scripts/sim/simulate.gd -- --games 1000 --out sim_results.csv

const Config = preload("res://scripts/core/config.gd")
const Game = preload("res://scripts/core/game.gd")
const Bot = preload("res://scripts/core/bot.gd")


func _init() -> void:
	var games := 1000
	var out_path := "res://sim_results.csv"
	var only_diff := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--games" and i + 1 < args.size():
			games = int(args[i + 1])
		elif args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
		elif args[i] == "--diff" and i + 1 < args.size():
			only_diff = args[i + 1]
	var bot := Bot.new()
	var lines := ["hero,difficulty,games,win_rate,avg_turns,avg_encounters,avg_damage,loss_health,loss_time"]
	var seed_base := 1000
	print("Simulating %d games per hero per difficulty..." % games)
	for diff in Config.DIFFICULTY_ORDER:
		if only_diff != "" and diff != only_diff:
			continue
		for hero in Config.HERO_ORDER:
			var wins := 0
			var turns := 0
			var found := 0
			var damage := 0
			var loss_health := 0
			var loss_time := 0
			for k in games:
				var g := Game.new()
				seed_base += 1
				g.new_game(hero, diff, seed_base, false)
				var guard := 0
				while (g.phase == "player" or g.phase == "encounter") and guard < 1000:
					bot.play_turn(g)
					g.events.clear()
					guard += 1
				assert(guard < 1000, "game did not terminate")
				if g.phase == "won":
					wins += 1
				elif g.health <= 0:
					loss_health += 1
				else:
					loss_time += 1
				turns += mini(g.turn, Config.TURN_LIMIT)
				found += g.stats["found"]
				damage += g.stats["damage"]
			var line := "%s,%s,%d,%.3f,%.2f,%.2f,%.2f,%d,%d" % [hero, diff, games, float(wins) / games,
				float(turns) / games, float(found) / games, float(damage) / games, loss_health, loss_time]
			lines.append(line)
			print(line)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % out_path)
		quit(1)
		return
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")
	f.close()
	print("Wrote ", ProjectSettings.globalize_path(out_path))
	quit()
