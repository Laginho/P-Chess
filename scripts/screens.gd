extends SceneTree

# The launcher must set the data root before Godot starts, including its own log.
const BOARDS := ["Main", "NameDialog", "Searching", "Game", "GamePanelStates", "GameSidePanel", "GameOver", "GameOverStates", "GameOverCard", "History", "Review", "ReviewAnalysing", "ReviewNotAnalysed", "ReviewSmall", "ReviewLegend", "Profile", "Repertoire", "OpeningPicker", "RepertoireEditor", "Board", "ClassIcon", "ClassLegend", "Settings", "Setup", "PromotionPicker", "RepertoireImport"]
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free", "player_name": "You"}

func _initialize() -> void:
 call_deferred("capture")

func capture() -> void:
 var args := OS.get_cmdline_user_args()
 var isolated := OS.get_environment("PCHESS_SCREENSHOTS_ROOT").replace("\\", "/").simplify_path()
 var user_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path()
 if isolated.is_empty() or not user_dir.begins_with(isolated + "/"):
  push_error("Set PCHESS_SCREENSHOTS_ROOT and the platform data directory before launching; see the design README.")
  quit(1)
  return
 if args.size() < 4 or not args[0] in BOARDS or not args[1].is_valid_int() or not args[2].is_valid_int():
  push_error("Usage: <board> <width> <height> <absolute output.png> [state]. Boards: " + ", ".join(BOARDS))
  quit(1)
  return
 var width := int(args[1])
 var height := int(args[2])
 var output: String = args[3]
 if width < 1 or height < 1 or not output.is_absolute_path() or not output.to_lower().ends_with(".png"):
  push_error("Use positive dimensions and an absolute PNG path.")
  quit(1)
  return
 if DisplayServer.get_name() == "headless":
  push_error("Captures need a graphical display, not --headless.")
  quit(1)
  return
 root.gui_embed_subwindows = true
 root.size = Vector2i(width, height)
 var settings = load("res://core/settings.gd").new()
 if args[0] != "NameDialog":
  settings.set_value("player_name", "You")
 var game = load("res://core/game.gd").new()
 for move in ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6"]:
  game.play(move)
 game.resign("b")
 var clocks := []
 for _i in game.moves.size():
  clocks.append(175000)
 var history = load("res://core/history.gd").new()
 var path: String = history.save(game, clocks, SETTINGS)
 var main = load("res://ui/main.tscn").instantiate()
 main.preferences = settings
 main.history = history
 main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nC20\tFixture\t1. e4 e5\n")
 root.add_child(main)
 root.min_size = Vector2i.ZERO
 root.size = Vector2i(width, height)
 await process_frame
 var board: String = args[0]
 var state: String = args[4] if args.size() > 4 else ""
 # Fixture captures show the normal screen even on a machine without engine files.
 main.get_node("Home/Center/Form/Missing").hide()
 for button in main.get_node("Home/Center/Form/Quick").get_children():
  button.disabled = false
 main.setup.get_node("Center/Form/Missing").hide()
 main.setup.get_node("Center/Form/Start").show()
 if board not in ["Main", "NameDialog"]:
  main.name_dialog.hide()
 match board:
  "Searching":
   main.get_node("Home").hide()
   main.searching.present(SETTINGS)
   main.searching.status("Loading Maia 1500…")
  "Settings":
   main.settings_screen.get_node("Panel").show()
  "Setup", "PromotionPicker", "Repertoire", "OpeningPicker", "RepertoireEditor", "RepertoireImport":
   main._show_setup()
   var repertoire = main.setup.repertoire
   var err: String = repertoire.import_pgn("1. e4 e5 2. Nf3 Nc6 *", "w", "Fixture")
   if not err.is_empty():
    push_error(err)
    quit(1)
    return
   var screen = main.setup.get_node("RepertoireScreen")
   if board == "RepertoireImport":
    screen.importer.present()
   elif board == "OpeningPicker":
    screen._picker.present_repertoire(repertoire)
   elif board == "RepertoireEditor":
    screen._editor.present(repertoire, "Fixture", 0)
   elif board == "Repertoire":
    screen.present()
    screen._select_repertoire(0)
   elif board == "PromotionPicker":
    main.setup.hide()
    var picker = main.board_view.get_node("PromotionPicker")
    var loader = load("res://ui/theme_loader.gd").new()
    picker.open(loader.load_pieces("cburnett"), true)
    picker.layout(Vector2(100, 100), 64, true)
  "History":
   main._show_history()
  "Profile":
   main.get_node("Home")._show_profile()
  "Review", "ReviewAnalysing", "ReviewNotAnalysed", "ReviewSmall", "ReviewLegend", "ClassIcon", "ClassLegend":
   main.get_node("Home").hide()
   main.review.present(game, clocks, SETTINGS, "White won by resignation")
   if board == "ReviewNotAnalysed":
    main.review.present_history(path, history.analysis_folder().path_join("missing.json"), false)
   else:
    var limit: int = 3 if board == "ReviewAnalysing" else game.moves.size() + 1
    for i in limit:
     var best: String = game.moves[i] if i < game.moves.size() else ""
     main.review.receive_position(i, {"pv": [{"cp": 25 if i % 2 == 0 else -25, "moves": [best] if not best.is_empty() else []}], "best_move": best})
   if board == "ReviewAnalysing":
    main.review.get_node("Margin/Content/Progress").show()
    main.review.get_node("Margin/Content/Progress").value = 46
   elif board == "ReviewLegend" or board == "ClassLegend":
    main.review.get_node("Margin/Content/ReviewBody/Side/ClassHelp").pressed.emit()
  "Game", "GamePanelStates", "GameSidePanel", "Board", "GameOver", "GameOverStates", "GameOverCard":
   main.get_node("Home").hide()
   main.settings = SETTINGS.duplicate()
   if board in ["Game", "GamePanelStates", "GameSidePanel", "Board"]:
    game.result = "*"
    game.reason = ""
   main.board_view.game = game
   main.clock = load("res://core/clock.gd").new("3+2", Time.get_ticks_msec)
   main.white_clock.clock = main.clock
   main.black_clock.clock = main.clock
   if board == "GamePanelStates":
    if state == "declined":
     main.draw_notice.text = "Maia declined"
     main.draw_notice.show()
    else:
     main.resign_key.press()
   if board in ["GameOver", "GameOverStates", "GameOverCard"]:
    if state == "loss":
     game.result = "0-1"
    elif state == "draw":
     game.result = "1/2-1/2"
    var card = load("res://ui/game_over.tscn").instantiate()
    main.board_view.add_child(card)
    card.present(main, game, main.get_node("Layout/Side/ReviewButton"))
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 var error := image.save_png(output)
 if error != OK:
  push_error("Cannot save screenshot: " + error_string(error))
  quit(1)
  return
 print("Saved ", output, " (", image.get_width(), "x", image.get_height(), ")")
 quit()
