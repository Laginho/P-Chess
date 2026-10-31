# UI-017: The searching screen
Stage: implementing
Blocked by: HIST-006, UI-016
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/searching.gd
  - New: ui/searching.tscn
  - ui/main.gd (`_start`; replaces the `Starting` overlay)
  - ui/main.tscn
  - engine/uci.gd (a signal when the net's `readyok` arrives, if none exists)
  - tests/test_session.gd
  - tests/test_book.gd (test-only: the assertion on `main.starting`)
  - docs/spec.md (§15.8)

#### What to build

Between the click and the game, a screen like chess.com's "searching for opponent" shows for at least 0.5 s (§15.8). Its message follows the real work.

#### Acceptance criteria

1. Every game start (quick play, Custom game, rematch) shows the searching screen with the time control and the Maia level.
2. Its status line follows the actual steps, in order, skipping those with nothing to do: "Pausing analysis…" while the queue pauses, "Loading Maia 1500…" until the net's `readyok`, "Preparing game…" while the catalog and the opening selection load.
3. It stays at least 0.5 s, and longer when the work takes longer; the game and its clock start only when it closes.
4. An error during start (missing repertoire, bad selection, engine stopped) closes it and shows the error where it shows today.

#### Verification

    Manual: quick-play with a batch running; read the three messages.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: a start with a fake slow net shows "Loading Maia …" until readyok; a fast start still lasts 0.5 s; the clock does not run while it shows; with the queue running the first line is "Pausing analysis…" (red: no screen).

## Comments

- 2026-10-30 Written from spec §15.8 and the design brief (screen 3).

- 2026-10-31 Stage stopped (incomplete handoff): Stage left uncommitted work; saved for recovery. See C:\Users\bruno\Desktop\Pastinha\Programas\Projects\P-Chess\.artifacts-build\lanes\v010\.scratch\run-log\UI-017-implement-20261031-015246.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.

- 2026-10-31 Foreman diagnosis (run 3): no code, contract or environment defect. Terra high started well (`6b28a10`, a red test for searching before Maia is ready), then ended its turn after 2 minutes with uncommitted work and a progress report: the same early stop it made on REV-005 (run 2) and HIST-004 (this run). Its report is useful: with the screen waiting for `readyok`, the new test passed but 14 existing tests failed because they expect the game to start immediately; those tests must follow the new flow. Its work is kept: branch `recovery/20261031-0155/UI-017` (`6b28a10`) and `stash@{0}` (uncommitted screen + `readyok` wait). Reuse the test if useful; start clean otherwise. Next: the rest of this run moves to the sol lineup (authorized fallback after the foreman's one diagnosis-and-restart was spent on HIST-004). Finish every criterion and the gate before ending the turn.

- 2026-10-31 Retry: inspected recovery/20261031-0155/UI-017 and stash@{0}; both preserved. Rebuilt the recovered tracer test with isolated storage and explicit readyok completion. Callers traced: Home quick play, Custom game, game-over/review rematch and Space; all reach `_start`. Startup boundaries include pending catalog, failed repertoire/selection, engine stop, repeated starts and old finished-game clocks.
