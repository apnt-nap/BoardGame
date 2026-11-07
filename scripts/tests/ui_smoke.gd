extends SceneTree
## UI smoke test: plays full games through the real UI handlers with the bot choosing,
## and saves screenshots to res://build/shots/. Run without --headless to get screenshots:
##   godot --path . --script res://scripts/tests/ui_smoke.gd -- --games 2

const Bot = preload("res://scripts/core/bot.gd")
const Profile = preload("res://scripts/ui/profile.gd")

var main


func _init() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/shots")
	root.get_texture().get_image().save_png("res://build/shots/%s.png" % name)


func _run() -> void:
	var games := 2
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--games" and i + 1 < args.size():
			games = int(args[i + 1])
	Engine.time_scale = 6.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.profile = Profile.new()
	main.profile.path = "user://test_profile.cfg"
	await _shot("menu")
	var bot := Bot.new()
	for n in games:
		main.sel_diff = ["normal", "hard", "easy"][n % 3]
		main.sel_hero = "ranger"
		main.profile.wins_by_diff["normal"] = maxi(1, main.profile.wins_by_diff["normal"])
		await main._start_game()
		var steps := 0
		var shot_taken := {}
		while main.game.phase == "player" or main.game.phase == "encounter":
			while main.busy:
				await process_frame
			var g = main.game
			if g.phase == "won" or g.phase == "lost":
				break
			steps += 1
			assert(steps < 500, "UI game did not end")
			if g.turn == 3 and not shot_taken.has("t3"):
				shot_taken["t3"] = true
				main.board.show_debug = true
				main.ui["debug"].visible = true
				main._refresh()
				await _shot("game_%d_debug" % n)
				main.board.show_debug = false
				main.ui["debug"].visible = false
			if g.phase == "encounter":
				if not shot_taken.has("enc"):
					shot_taken["enc"] = true
					await _shot("game_%d_encounter" % n)
				main._on_encounter(bot.choose_encounter(g))
				continue
			if g.turn == 8 and not shot_taken.has("t8"):
				shot_taken["t8"] = true
				await _shot("game_%d_turn8" % n)
			bot._free_actions(g)
			main._after_action()
			while main.busy:
				await process_frame
			if g.phase != "player":
				continue
			var c: Dictionary = bot._choose_card(g)
			if not g.can_play(c["i"], c["mode"]):
				c = {"i": 0, "mode": "sneak_move", "target": g.castle.neighbors(g.player_room)[0]}
			main._on_card(c["i"], c["mode"])
			if not main.pending.is_empty():
				if not (c["target"] in main.board.targets):
					c["target"] = main.board.targets[0]
				main._on_room_clicked(c["target"])
		while main.busy or not main.end_root.visible:
			await process_frame
		await _shot("game_%d_end" % n)
		print("UI game %d (%s): %s on turn %d, found %d" % [n, main.game.difficulty, main.game.phase, main.game.turn, main.game.stats["found"]])
	print("UI smoke test passed")
	quit()
