# UI-017: The searching screen
Stage: to-implement
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
