extends SceneTree
## UI smoke test: plays full games through the real UI handlers with the bot choosing, and
## saves screenshots to res://build/shots/. Run without --headless to get screenshots:
##   godot --path . --script res://scripts/tests/ui_smoke.gd -- --games 3

const Bot = preload("res://scripts/core/bot.gd")
const Profile = preload("res://scripts/ui/profile.gd")
const Settings = preload("res://scripts/ui/settings.gd")

var main
var shots := {}


func _init() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/shots")
	root.get_texture().get_image().save_png("res://build/shots/%s.png" % name)
	shots[name] = true


func _idle() -> void:
	while main.busy:
		await process_frame


func _run() -> void:
	var games := 3
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--games" and i + 1 < args.size():
			games = int(args[i + 1])
	main = load("res://scenes/main.tscn").instantiate()
	main.profile = Profile.new()
	main.profile.path = "user://test_profile.cfg"
	main.settings = Settings.new()
	main.settings.path = "user://test_settings.cfg"
	root.add_child(main)
	await _shot("01_title")
	main._show("heroes")
	await _shot("02_hero_select")
	main._show("difficulty")
	await _shot("03_difficulty")
	main._show("title")
	main._open_rules()
	main._rules_page(2)
	await _shot("04_how_to_play")
	main._close_rules()
	main._open_settings()
	await _shot("05_settings")
	main._close_settings()
	Engine.time_scale = 6.0
	var bot := Bot.new()
	for n in games:
		main.sel_diff = ["normal", "hard", "easy"][n % 3]
		main.sel_hero = ["ranger", "alchemist", "ranger"][n % 3]
		main.profile.wins_by_diff["normal"] = maxi(1, main.profile.wins_by_diff["normal"])
		await main._start_game()
		var steps := 0
		var seals_seen := 0
		while main.game.phase == "player" or main.game.phase == "encounter":
			await _idle()
			var g = main.game
			if g.phase == "won" or g.phase == "lost":
				break
			steps += 1
			assert(steps < 600, "UI game did not end")
			if g.seals_restored() > seals_seen:
				seals_seen = g.seals_restored()
				if not shots.has("08_seal_restored"):
					Engine.time_scale = 1.0
					await _shot("08_seal_restored")
					Engine.time_scale = 6.0
			if g.phase == "encounter":
				if not shots.has("07_encounter"):
					Engine.time_scale = 1.0
					await _shot("07_encounter")
					Engine.time_scale = 6.0
				main._on_encounter(bot.choose_encounter(g))
				continue
			if g.turn == 4 and n == 0 and not shots.has("06_main_screen"):
				await _shot("06_main_screen")
			bot._free_actions(g)
			main._after_action()
			await _idle()
			if g.phase != "player":
				continue
			var c: Dictionary = bot._choose_card(g)
			if not g.can_play(c["i"], c["mode"]):
				c = {"i": 0, "mode": "sneak_move", "target": g.castle.neighbors(g.player_room)[0]}
			main._on_card(c["i"], c["mode"])
			if not main.pending.is_empty():
				if not main.board.targets.is_empty():
					if not (c["target"] in main.board.targets):
						c["target"] = main.board.targets[0]
					main._on_room_hovered(c["target"])
					if g.turn == 6 and n == 0 and not shots.has("06b_move_preview"):
						main.board.hovered = c["target"]
						await _shot("06b_move_preview")
					main._on_room_clicked(c["target"])
				else:
					if not shots.has("06c_confirm_preview"):
						await _shot("06c_confirm_preview")
					main._confirm()
			assert(main.pending.is_empty(), "a selected card was not played")
		while main.busy or not main.end_root.visible:
			await process_frame
		Engine.time_scale = 1.0
		await _shot("09_end_%d_%s" % [n, main.game.phase])
		Engine.time_scale = 6.0
		print("UI game %d (%s, %s): %s on turn %d, found %d, Seals %d" % [n, main.game.hero, main.game.difficulty, main.game.phase, main.game.turn, main.game.stats["found"], main.game.seals_restored()])
	print("Screenshots: ", shots.keys())
	print("UI smoke test passed")
	quit()
