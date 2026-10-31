extends SceneTree

# The launcher must set the data root before Godot starts, including its own log.
const BOARDS := ["Main", "NameDialog", "Searching", "Game", "GamePanelStates", "GameSidePanel", "GameOver", "GameOverStates", "GameOverCard", "History", "Review", "ReviewAnalysing", "ReviewNotAnalysed", "ReviewSmall", "ReviewLegend", "Profile", "Repertoire", "OpeningPicker", "RepertoireEditor", "Board", "ClassIcon", "ClassLegend", "Settings", "Setup", "PromotionPicker", "RepertoireImport"]
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free", "player_name": "You"}
const BOOK := "eco\tname\tpgn\nC20\tFixture\t1. e4 e5\nB12\tCaro-Kann Defense: Advance Variation\t1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 e6 5. Be2 Nd7\nC53\tItalian Game: Giuoco Piano\t1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5\nB90\tSicilian Defense: Najdorf Variation\t1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6\nD30\tQueen’s Gambit Declined\t1. d4 d5 2. c4 e6\nB01\tScandinavian Defense\t1. e4 d5\n"
# The review boards' game (canvas: Caro-Kann, current move 12.Bd3), with each ply's loss chosen for the class drawn.
const REVIEW_MOVES := "1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 e6 5. Be2 Nd7 6. O-O Ne7 7. Nbd2 h6 8. Nb3 g5 9. Ne1 Bg6 10. f4 gxf4 11. Bxf4 Nf5 12. Bd3 Qb6 13. Kh1 O-O-O 14. c3 c5"
const REVIEW_LOSSES := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.04, 0.08, 0.015, 0.04, 0, 0, 0, 0, 0.015, 0.15, 0, 0.3, 0.15, 0.04, 0.08]
# History cards as drawn, top to bottom: state, moves, colour, level, control, ending.
const HISTORY := [
 ["analysed", "1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 e6 5. Be2 Nd7", "w", "maia-1500", "3+2", "flag"],
 ["analysing", "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5", "b", "maia-1500", "1+0", "resign"],
 ["queued", "1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6", "w", "maia-1700", "5+0", "draw"],
 ["stale", "1. d4 d5 2. c4 e6", "b", "maia-1300", "3+2", "win"],
 ["none", "1. g3 g6 2. Bg2 Bg7", "w", "maia-1900", "1+0", "flag"],
 ["deleting", "1. e4 d5", "w", "maia-1100", "3+2", "win"],
]


# Stands in for Stockfish so the History fixture shows one running and one waiting analysis.
class FakeRunner extends Node:
 signal finished(success: bool, error: String)
 signal progress(done: int, total: int)
 signal position_ready(index: int, position: Dictionary)
 func start(_path: String, _maximum: bool) -> bool:
  return true
 func cancel() -> void:
  pass


# Plays SAN movetext and ends it from the human's side: "flag" and "win" are wins, "resign" a loss.
func _fixture_game(movetext: String, ending: String, colour: String) -> Array:
 var parsed: Dictionary = load("res://core/pgn.gd").parse(movetext + " *")
 var game = load("res://core/game.gd").new()
 var clocks := []
 for move in parsed.games[0].moves:
  game.play(move.uci)
  clocks.append(175000)
 var other := "b" if colour == "w" else "w"
 match ending:
  "draw": game.agree_draw()
  "flag": game.flag(other)
  "win": game.resign(other)
  _: game.resign(colour)
 return [game, clocks]


# Engine lines whose losses give each ply its drawn class; a zero loss plays the best move.
func _fixture_analysis(game, losses: Array, bests := {}) -> Array:
 var replay = load("res://core/game.gd").new()
 var positions := []
 var white_ep := 0.54
 for i in game.moves.size() + 1:
  var legal: Array = replay.board.legal_moves()
  var played: String = game.moves[i] if i < game.moves.size() else ""
  var loss: float = losses[i] if i < losses.size() else 0.0
  var best: String = played
  if played.is_empty() or loss > 0.0:
   best = bests.get(i, legal[0] if legal[0] != played else legal[1])
  var mover_ep := white_ep if i % 2 == 0 else 1.0 - white_ep
  var cp := roundi(log(mover_ep / (1.0 - mover_ep)) / 0.00368208)
  positions.append({"fen": replay.board.to_fen(), "pv": [{"cp": cp, "moves": [best]}], "best_move": best})
  white_ep = clampf(white_ep + (-loss if i % 2 == 0 else loss) + sin(i * 1.7) * 0.004, 0.03, 0.97)
  if not played.is_empty():
   replay.play(played)
 return positions

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
 main.get_node("Setup").book.load_tsv(BOOK)
 if args[0] == "History":
  main.analysis_queue = load("res://core/analysis_queue.gd").new(FakeRunner.new(), history.queue_file())
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
   DirAccess.remove_absolute(path)
   var paths := []
   for i in range(HISTORY.size() - 1, -1, -1):
    var row: Array = HISTORY[i]
    var made := _fixture_game(row[1], row[5], row[2])
    var card_path: String = history.save(made[0], made[1], {"colour": row[2], "level": row[3], "control": row[4], "player_name": "You"})
    paths.push_front(card_path)
    if row[0] in ["analysed", "stale", "deleting"]:
     var data := {"engine_version": "Stockfish 18" if row[0] == "stale" else "Stockfish 19",
       "node_budget": load("res://core/tunables.gd").ANALYSIS_NODES, "positions": _fixture_analysis(made[0], [0, 0.02, 0.06, 0, 0.1, 0, 0.03])}
     DirAccess.make_dir_recursive_absolute(history.analysis_folder())
     var file := FileAccess.open(history.analysis_folder().path_join(card_path.get_file() + ".json"), FileAccess.WRITE)
     file.store_string(JSON.stringify(data))
     file.close()
   main.history_screen._selected = {paths[2]: true, paths[3]: true}
   main.history_screen._delete_path = paths[5]
   main.analysis_queue.enqueue(paths[1])
   main.analysis_queue.enqueue(paths[2])
   main.analysis_queue.percent = 46
   main.analysis_queue.batch_total = 7
   main.analysis_queue.batch_done = 1
   main._show_history()
  "Profile":
   main.get_node("Home")._show_profile()
  "Review", "ReviewAnalysing", "ReviewNotAnalysed", "ReviewSmall", "ReviewLegend", "ClassIcon", "ClassLegend":
   main.get_node("Home").hide()
   var made := _fixture_game(REVIEW_MOVES, "flag", "w")
   var review_path: String = history.save(made[0], made[1], SETTINGS)
   var repertoire = load("res://bot/repertoire.gd").new()
   repertoire.parse("1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 e6 5. Be2 Nd7 6. O-O Ne7 7. Nbd2 h6 8. Nh4 *", "w")
   main.review.present(made[0], made[1], SETTINGS, "Won on time", main.setup.book.entries, repertoire.lines, true)
   if board == "ReviewNotAnalysed":
    main.review.present_history(review_path, history.analysis_folder().path_join("missing.json"), false)
   else:
    var analysis := _fixture_analysis(made[0], REVIEW_LOSSES, {22: "e1f3"})
    for i in (18 if board == "ReviewAnalysing" else analysis.size()):
     main.review.receive_position(i, analysis[i])
   main.review._show_ply(23)
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
