# UI-025: History screen to the design
Stage: implementing
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
