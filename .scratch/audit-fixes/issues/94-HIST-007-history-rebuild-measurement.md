# HIST-007: Measure History's rebuild during analysis, fix only if it stalls
Stage: implementing
Status: ready-for-agent
Blocked by: HIST-008, REV-010
Review: agent
Difficulty: normal

- Primary files:
  - ui/history_screen.gd (`_refresh`, `_queue_changed`)
  - core/history.gd (`games`), only if the cache is built
  - tests/test_history_screen.gd, tests/test_history.gd

#### What to build

Spec: `.scratch/audit-fixes/spec.md`. Audit finding 1. The audit measured 3,857 ms per progress event on the old path, which rebuilt History on every event. Since PR #41, progress updates the active card in place, and `_refresh()` runs only when the queue state changes: a game starts, finishes or fails. Each rebuild still reparses every saved PGN through `history.games()`. Measure what one rebuild costs now, and fix it only if it stalls.

#### Acceptance criteria

1. Stage 2 measures one `_refresh()` at HEAD (after REV-010) with History visible and 50 valid 40-ply saved games. It uses a probe outside the gate: generated PGNs in temporary storage, a fake engine runner and one queue state change, with rendering time excluded. The probe script and its output go in Comments, inline or as a pasted log, together with the machine it ran on.
2. If one rebuild takes **200 ms or less**, the ticket ends with that measurement and no source change.
3. If it takes longer, parsed records are cached and reused across rebuilds while a file is unchanged. The cache key is the path plus the modified time **and** the size, because Godot's modified time has whole-second resolution. Run the probe again and record the result.
   - A changed, added or deleted game still shows correctly on the next rebuild.
   - Focus, selection, paging and the inline delete confirmation behave as today.
4. No timing assertion goes into the gate.
5. Gate green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Only if criterion 3 applies, in tests/test_history_screen.gd or tests/test_history.gd:
  - After a rebuild, rewrite a game's PGN, setting the modified time explicitly or changing its size. The next rebuild shows the new content.
  - A deleted game disappears.

  These tests pass on today's uncached code, so they cannot be red first. Write them first, confirm they pass now, and keep them green through the cache change.

## Comments

- 2026-11-06 Written from the grill ([spec](../spec.md)). Both endings are valid: measurement-only (≤ 200 ms) or the cache.
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)

- Proxy decided (opus-5.5 xhigh): Hand off HIST-007 with the cache-key fix as it stands. Don't widen Primary files or the test seam. Disclose the remaining ~1.6 s stall as deferred with release impact, and open a needs-triage follow-up for it. The numbered criteria are already met, and the real cost sits in a design choice the grill never settled. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-153131-HIST-007-718613.json)
  The proxy identified additional card work and directed separate measurements, a follow-up and a spec correction. Its initial estimate used a legacy fixture without a Reason header; finished games with the normal Reason header were also measured below.
- HEAD already cached parsed PGNs by path and modified time. This change adds size, and invalidates older cache entries without size. The focused test was red on the old cache (29 passed, 1 failed) and green after the fix (30 passed, 0 failed).
- Measurement: C:\Users\bruno\AppData\Local\Temp\hist007-probe-results.txt. Pre-change was measured by copying `git show 35a0471:core/history.gd` to `.hist007_baseline.gd` and replacing the History load path in the probe, then removing the copy. Post-change uses the code at 3272985. The fake runner is held and the probe changes queue state once per scenario. Saved analysis is synthetic and complete according to the validator; no engine is started. `games()` was warmed by presenting History. No frame is awaited inside the timed state change, so rendering is excluded.

```text
Godot 4.7.stable, Windows, Intel Core i5-12400F, 16 GiB RAM
Finished PGN with Reason=resignation, 50 games x 40 plies; 20 cards visible; headless, rendering excluded.
Before (35a0471): games() 6.349 ms; refresh 805.271 ms (no analysis), 838.720 ms (synthetic analysis).
After (3272985): games() 9.376 ms; refresh 808.294 ms (no analysis), 891.171 ms (synthetic analysis).
After, separately timed 20 cards, no analysis: thumbnail 7.580 ms, board replay 159.384 ms, reason 0.092 ms, positions 331.385 ms, analysis 3.416 ms; residual 306.437 ms.
After, synthetic complete analyses: thumbnail 7.111 ms, board replay 160.734 ms, reason 0.087 ms, positions 335.175 ms, analysis 30.840 ms; residual 357.224 ms.
Separate timings are independent runs, not instrumentation inside the refresh; residual is an approximation and includes all other work. Synthetic analyses meet format validation, not engine output.
Legacy fixture without Reason (Result=*): before refresh 1450.201 ms; after refresh 1624.732 ms, games() 10.354 ms. Separate later runs: no analysis refresh 1543.009 ms (reason 678.746 ms), synthetic analysis refresh 1541.394 ms (reason 695.900 ms).
```

Probe (saved outside the repo and run with `godot --headless --path . --script <probe>`):

```gdscript
extends SceneTree

class FakeRunner extends RefCounted:
	signal progress(done: int, total: int)
	signal finished(success: bool, error: String)
	func start(_path: String, _maximum: bool) -> bool:
		return true
	func cancel() -> void:
		pass

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	var folder := OS.get_environment("TEMP").path_join("hist007_" + str(Time.get_ticks_usec()))
	var games_dir := folder.path_join("games")
	assert(DirAccess.make_dir_recursive_absolute(games_dir) == OK)
	var pgn := '[Event "Probe"]\n[Date "2026.11.06"]\n[White "You"]\n[Black "Maia"]\n[Result "1-0"]\n[Termination "Normal"]\n[Reason "resignation"]\n[TimeControl "60+0"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 11. Nbd2 Bb7 12. Bc2 Re8 13. Nf1 Bf8 14. Ng3 g6 15. a4 c5 16. d5 c4 17. Be3 Qc7 18. Qd2 Nc5 19. axb5 axb5 20. Rxa8 Rxa8 1-0\n'
	for i in 50:
		var file := FileAccess.open(games_dir.path_join("game_%02d.pgn" % i), FileAccess.WRITE)
		assert(file != null)
		file.store_string(pgn)
		file.close()
	var history = load("res://core/history.gd").new(folder)
	var settings = load("res://core/settings.gd").new(folder.path_join("settings.cfg"))
	var queue = load("res://core/analysis_queue.gd").new(FakeRunner.new(), folder.path_join("queue.cfg"))
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	root.add_child(screen)
	screen.present(history, settings)
	await process_frame
	var read_started := Time.get_ticks_usec()
	var records: Array = history.games()
	print("cached history.games: %.3f ms" % ((Time.get_ticks_usec() - read_started) / 1000.0))
	assert(records.size() == 50 and records.all(func(r): return r.game.moves.size() == 40))
	assert(screen.visible)
	var analyser = load("res://engine/analyser.gd")
	var game_class = load("res://core/game.gd")
	var fens: Array = analyser.positions_from_game(records[0].game)
	var analysis_dir := folder.path_join("analysis")
	DirAccess.make_dir_absolute(analysis_dir)
	for with_cache in [false, true]:
		if with_cache:
			var positions := []
			for fen in fens:
				positions.append({"fen": fen, "best_move": "e2e4", "pv": [{"moves": ["e2e4"], "cp": 20}]})
			var json := JSON.stringify({"engine_version": "Stockfish 19", "node_budget": 3000000, "positions": positions})
			for record in records:
				var file := FileAccess.open(analysis_dir.path_join(record.path.get_file() + ".json"), FileAccess.WRITE)
				file.store_string(json)
				file.close()
		var totals := {"thumbnail": 0, "board_replay": 0, "reason": 0, "positions": 0, "analysis": 0}
		for record in records.slice(0, 20):
			var moves := PackedStringArray()
			for move in record.game.moves:
				moves.append(move.uci)
			var t := Time.get_ticks_usec()
			var thumbnail: Dictionary = history.thumbnail(moves)
			totals.thumbnail += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			var game = game_class.new()
			for i in thumbnail.ply:
				game.play(moves[i])
			totals.board_replay += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			history.reason(record.game)
			totals.reason += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			var positions: Array = analyser.positions_from_game(record.game)
			totals.positions += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			screen._analysis_text(record.path, positions)
			screen._cached_accuracy(record.path, positions)
			totals.analysis += Time.get_ticks_usec() - t
		queue._items.append(records[1 if with_cache else 0].path)
		queue.batch_total += 1
		var started := Time.get_ticks_usec()
		queue.changed.emit()
		var elapsed := Time.get_ticks_usec() - started
		print("analysis_cache=", with_cache, " records=", records.size(), " plies=", records[0].game.moves.size(), " visible=", screen.visible)
		print("queue state change: %.3f ms; separate 20-card timings: %s; residual (approx): %.3f ms" % [elapsed / 1000.0, totals, (elapsed - totals.values().reduce(func(a, b): return a + b, 0)) / 1000.0])
	for file in DirAccess.get_files_at(analysis_dir):
		DirAccess.remove_absolute(analysis_dir.path_join(file))
	DirAccess.remove_absolute(analysis_dir)
	screen.free()
	queue.free()
	for file in DirAccess.get_files_at(games_dir):
		DirAccess.remove_absolute(games_dir.path_join(file))
	DirAccess.remove_absolute(games_dir)
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	quit()
```

Disclosure: deferred | release | C:\Users\bruno\AppData\Local\Temp\hist007-probe-results.txt: History rebuilds still block for about 0.8?0.9 s with saved games and up to about 1.6 s with this legacy fixture on each queue state change; see [HIST-010](100-HIST-010-history-card-build-stall.md).
