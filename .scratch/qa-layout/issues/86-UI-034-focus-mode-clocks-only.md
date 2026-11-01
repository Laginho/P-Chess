# UI-034: Focus mode shows only the board, centred, and the two clocks
Stage: to-review
Status: ready-for-agent
Blocked by: UI-033
Review: human
Difficulty: normal

- Primary files:
  - ui/main.gd (`_set_focus`, line ~559)
  - ui/main.tscn (`Layout/Side`, the clock rows)
  - tests/ covering focus mode (grep `_set_focus` / `focus`)

#### What to build

Bruno's QA of v0.0.2 (2026-11-01), item 3. F11 today hides the panel's children but `Layout/Side` keeps its width and frame: the board stays on the left and the two clocks float at the top of an empty panel.

In focus mode:

1. The side panel is gone entirely (no frame, no background, no width).
2. The board sits at the window's centre.
3. The two clocks stand to the left of the board, stacked around its vertical centre: Maia's above, yours below, as in Bruno's [example](../focus-reference.png) (that image's player cards, draw and resign buttons are not wanted: only the clocks).
4. Nothing else shows. Resign stays on Esc Esc; there is no draw offer in focus mode (no hotkey exists for it).
5. The game-over card still appears over the board and works as outside focus mode.
6. F11 again restores the normal layout exactly as before, including a draw notice that was showing.

#### Acceptance criteria

1. With focus on, at 1920×1080 the board is centred horizontally and vertically; the side panel draws nothing.
2. Both clocks are visible left of the board, opponent above, running and turning as normal.
3. Ending a game in focus mode shows the game-over card.
4. Toggling F11 twice returns the layout to its pre-focus state.
5. Capture of focus mode at 1920×1080 compared by eye with `focus-reference.png` for placement. Gate green.

#### Verification

    Manual: a 1+0 game, press F11; only board and clocks show, board centred.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Focus mode on: `Layout/Side` (or whatever replaces it) has zero width or is hidden, the board's centre equals the viewport's, and both clocks are visible (red: today Side keeps its width).

## Comments

- 2026-11-01 Written from Bruno's QA of v0.0.2 (item 3). He chose the clocks on the left, at the board's vertical centre.
- Blocked by UI-033: same `main.tscn` layout, and focus mode must centre under the new stretch mode.

- Stage 2: the session test was red before the change (side panel visible, clocks on the right, resize grip visible); the clock-gap assertion was also red against the first implementation. Gate on commit 407e86d: 492 passed, 0 failed, exit 0; six live Lc0 checks and one graphical pixel check skipped. The focus placement test passed in the gate.
- Captured and compared `C:/Users/bruno/AppData/Local/Temp/pchess-ui034-capture/focus-final.png` (1920x1080) with `focus-reference.png`: the board is centered and the clocks are stacked to its left around the vertical center. Capture uses a fixture, not a live game.
- Acceptance pending: Bruno to judge the capture and play the requested 1+0 game, including clock changes, Esc Esc and the game-over card.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui034-gate.json