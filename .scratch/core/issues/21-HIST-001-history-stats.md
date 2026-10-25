# HIST-001: Game history and stats
Stage: implementing
Blocked by: CORE-006, UI-004
Review: agent
Difficulty: normal

- Primary files:
  - New: core/history.gd
  - core/pgn.gd (writer, if a header or clock case is missing)
  - ui/main.gd
  - New: tests/test_history.gd
  - tests/test_session.gd (only isolated History injection in the session harness and necessary test-directory lifecycle; preserve existing behavior assertions)
  - tests/test_premove.gd (only isolated History injection in the session harness and necessary test-directory lifecycle; preserve existing behavior assertions)

#### What to build

Every finished game is saved as PGN with clocks, and per-level stats are kept (§9.4).

#### Acceptance criteria

1. At game end the game is saved to `user://games/` as one PGN file, with `[%clk]` after every played move giving that side's clock after applicable move accounting. This includes the final move, increments and premoves under the existing clock rules.
2. Headers: the players are "Maia 1500" (the net's level) and "You"; `TimeControl` is `60+0`, `180+2` or `300+0`; `Result`; `Termination` (`Normal` or `Time forfeit`); `Opening` when a name is known (filled by OPEN-002). No rating headers.
3. Stats per (level, time control): wins, draws, losses, flag wins and flag losses, updated at each game end and persisted under `user://`.
4. A saved PGN parses back with `core/pgn.gd` to the same moves and clocks.
5. A failed write is reported visibly in the game's result UI and does not crash the app.
6. Flag, resignation, checkmate and draw each trigger one save and one stats update for the finished game. Repeated result handling does not duplicate either; a rematch starts with fresh move-clock snapshots and save state.
7. Automated Main session tests use isolated history storage and do not read or modify the player's normal game-history or stats files.

#### Verification

    Manual: play two games, open the files in user://games/.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_history.gd`, History persistence seam: save a finished game to isolated test storage and parse it back; verify moves, clocks and headers; verify persisted stats after a flag win and a draw, and failed-write reporting. Red because `core/history.gd` does not exist.
- `tests/test_history.gd`, Main session integration seam: instantiate the real `ui/main.tscn` using the existing session-test pattern, replacing only the external UCI/timer boundary, injecting a fake time source into the real Clock and an isolated History store. Exercise flag, resignation, checkmate and draw through their Main paths; inspect saved PGNs and stats to verify one save/update, per-move clocks including final moves, applicable increments and premoves, fresh state after rematch, and a visible result-UI error on write failure. Red because Main does not yet persist finished games or capture move clocks.
- `tests/test_session.gd` and `tests/test_premove.gd`: isolate History storage in their session helpers before Main can access normal history storage, with necessary test-directory lifecycle only. Keep existing behavior assertions unchanged; these are harness adaptations, not new behavior seams.

## Comments

- Proxy decided (gpt-6-astra high, fallback): Approve isolated History harnesses in test_session.gd and test_premove.gd plus the real-Main history integration seam — existing scene tests finish games, and persistence-only tests cannot verify clock capture, save-once behavior or visible write failures. Contract amendments above are the proxy's draft; no additional product scope or release dependency.
- Read-around before red: Main's `_show_result` is reached from claim, resignation, terminal moves and clock flags. `_on_move_played` is called synchronously by BoardView for human, Maia and premoves; `_next_turn` charges premoves before playing them. Clock flags may re-enter result handling during move accounting. Preserve terminal-move precedence, capture the last move before saving, and reset state on rematch. Degenerate cases: no moves before resignation/flag, a first untimed move, final moves, repeated result handling, and failed PGN/stats writes. PGN's existing writer/reader already support exact millisecond clocks and need no change.
- First red: focused runner (`godot --headless -s tests/run.gd -- res://build/hist-tests`, a disposable copy of test_history.gd) reports `0 passed, 1 failed`: `res://core/history.gd` does not exist. The unprivileged full run also encounters unrelated user:// write denials; subsequent filesystem tests will run with authorized Godot access.

Disclosure: decision | none | HIST-001 Comments: approved test isolation and Main integration coverage for existing history requirements; no added release dependency.

- Stage 2 red/green cycles: `7aef730` fails because History is missing; `8a93259` passes PGN round-trip (1/1). `b5ed8d4` fails because `History.stats` is missing; `7e5b8a4` passes persistence and PGN (2/2). `896b2e7` fails because Main has no history integration; `e5a4680` isolates existing scene harnesses and `b2ed7eb` passes Main's mate/rematch lifecycle (3/3). Each production commit changes only production files; test/contract commits are separate.
- Additional boundary coverage: headers for all three controls and actual Maia level/colour, known Opening, ordinary flags, claimed draw, first/later premoves, reentrant flag during move accounting, terminal-move precedence at zero time, failed game-folder creation and failed stats write with a visible result-UI error. Focused runner: `9 passed, 0 failed`. The cleanup harness initially enumerated an absent games directory after an intentional write failure; corrected it to check directory existence, also in the existing scene harnesses. No production change was needed.
- Mutation proof for the additional integration coverage, with original production restored in `finally`: zeroed clock snapshots => `6 passed, 3 failed`; disabled save-once guard => `6 passed, 3 failed`; hidden result-UI write errors => `8 passed, 1 failed`. Logs: `$TEMP/HIST-001-mutant-clock-snapshot.log`, `$TEMP/HIST-001-mutant-save-once.log`, `$TEMP/HIST-001-mutant-visible-write-error.log`.
