# UI-025: History screen to the design
Stage: to-review
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/history_screen.gd, ui/history_screen.tscn
  - tests/test_history_screen.gd

#### What to build

Restyle History to `docs/design/v0.1.0/png/History.png`, which shows every card state on one screen (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Header: back button, "History", and the tabs All, 1+0, 3+2 and 5+0 as a segmented control, each with its game count.
2. Toolbar: select-all checkbox with "N selected", "Analyze selected" (green), the queue status line with a spinner ("Analysing 2 of 7 · Background"), and "Analyze all in “<tab>”".
3. Each card matches the canvas: checkbox, thumbnail, opening name (only when known), "Bruno x Maia 1500" with colour dots, date, time-control chip, the result coloured by outcome (green win, red loss, grey draw) and the move count.
4. Every analysis state matches the canvas: analysed (both accuracy boxes, white's light and black's dark); analysing (bar and percentage, the action disabled as "Analysing…"); queued ("Queued · 3rd in line", the action disabled as "Queued"); stale (dimmed accuracies, "Stale: <reason>" and "Re-analyze" in gold); not analysed ("Not analysed", "Analyze").
5. Review (green when analysed), the Copy PGN and Delete icon buttons, and the inline delete confirm ("Delete this game?", red Delete, Cancel) replace today's controls; behaviour unchanged.
6. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the board.

#### Verification

    Manual: screenshot tool on a fixture history holding every state; delete a game; analyse two selected games.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_history_screen.gd`: tab labels carry their counts; a queued card's action reads "Queued" and is disabled; the delete confirm is inline in the card (red where today's controls differ).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. Tab counts are a canvas addition adopted in the spec.

- 2026-10-31 Stage 2: red tests for tab counts, queued action and inline delete failed on the old screen; batch selection/progress and stale-cache display were added in separate red/green cycles. Existing History/Profile tests now follow the new card controls and inline confirmation; the black-player fixture's expected outcome was corrected from loss to win because White resigned. Focused History, History screen and Profile checks: 42 passed, 0 failed.
- Screenshot fixture with six states, isolated data and a fake analysis runner: `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-final3-1280/History.png` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-final3-800/History.png`; fixture script `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-fixture.gd`. At 800x600 the list scrolls and metadata wraps. The shared BoardView and theme are reused, so board rendering and typography retain their project styling rather than duplicating the canvas components. Stage 3 still needs its own before/after comparison against the reference.
- Manual UI on isolated fixture: confirmed delete reduced All from 6 to 5; selected two games and Analyze selected changed the simulated batch from 1 of 2 to 1 of 4, with both new cards queued. This did not run Stockfish.
- Gate on `2c2c710`: 416 reported passed, including six Lc0-dependent SKIPs (410 executed), zero failed; log `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-gate-2c2c710.log`.

Acceptance: pending | Complete the two-selected-games check with a real Stockfish installation and Bruno's v0.1.0 QA; simulated evidence above.
Disclosure: pending | integration | `C:/Users/bruno/AppData/Local/Temp/pchess-ui025-fixture.gd`: the required two-game analysis completion was not verified against a real Stockfish executable, absent in this worktree.
Disclosure: pending | release | `.scratch/ui-redo/spec.md` requires Bruno's v0.1.0 QA before tagging.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui025-gate-2c2c710.json
