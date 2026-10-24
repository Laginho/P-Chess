# UI-002: Board feedback and promotion
Stage: blocked
Blocked by: UI-001
Review: agent
Difficulty: normal

- Primary files:
  - ui/board_view.tscn, ui/board_view.gd
  - New: ui/promotion_picker.tscn, ui/promotion_picker.gd
  - ui/main.tscn, ui/main.gd (material counter)
  - New: tests/test_material.gd

#### What to build

The board feels like Lichess (§8.4): moves slide, the last move and a checked king are highlighted, legal targets show as dots, promotion opens a picker, and a counter shows the material difference.

#### Acceptance criteria

1. Moves that were not dragged (later: the bot's, premoves) slide over 120 ms by default; the length is a parameter and 0 means instant. A dragged move does not slide.
2. The from and to squares of the last move are highlighted; a king in check is highlighted.
3. Picking up a piece shows a dot on each empty legal target and a ring on each capture; a parameter turns the dots off.
4. A pawn reaching the last rank opens a picker with queen, rook, bishop and knight; cancelling puts the pawn back.
5. A material counter shows the captured pieces and the `+N` difference next to the side that is ahead (pawn 1, minor 3, rook 5, queen 9); the difference comes from a pure function that is tested.

#### Verification

    Manual: a two-human game showing each item above.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_material.gd`: material difference for the start position, after an exchange, and after a promotion. Red because the function does not exist.

## Comments

- Stage 2 (2026-10-24): the pure function is `ui/main.gd`'s static `material_balance(board)` → `{"diff", "w", "b"}`; `material` would shadow `CanvasItem.material`, a parse error. Red at 91aca8c: `Static function "material_balance()" not found in base "res://ui/main.gd"`. Green at e20b658: 56 passed, 0 failed (51 before + 5 new).
- Criterion 1: the only non-dragged path is the new `BoardView.play(move)`, which nothing in a two-human game calls yet (the bot will). `slide_seconds` (default 0.12) and `show_targets` are `@export`s. Only the moving piece slides; a castling rook jumps (`shortcut:` comment in `_commit`).
- Criteria 1–4 have no automated test (none named in the ticket). A throwaway headless script driving `ui/main.tscn` (not committed) checked: drag e2e4 holds `["e2e3", "e2e4"]` and does not slide; `play("d7d5")` slides and clears after 0.3 s; `slide_seconds = 0` is instant; the e7–e8 drop opens the picker with 4 buttons, cancel leaves the pawn on e7, picking n plays `e7e8n`; after exd5 the white label reads `♟ +1`. The manual two-human check of the ticket's Verification is still owed.
- Callers read: `_legal_move` (removed) had only `_drop`; `main.gd` is the only user of `BoardView`; `test_board_view.gd` uses only the unchanged static mapping.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-side\0678b999-a13e-4fe3-8c72-db673ccd0e5f\scratchpad\UI-002-gate.json

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5), first review. I read the whole diff, 3a6f557..1d3918c. The Standards and Spec axes ran as separate sub-agents, and I checked their findings myself. The branch was already cut from the session tip, so no rebase was needed. The `--no-ff` merge 0043f78 has the same tree as 1d3918c.

Criteria:

1. ✅ `BoardView.play(move)` calls `_commit(move, true)`, which tweens `_slide_pos` over `slide_seconds` (an `@export`, default 0.12). At 0 the move is instant. A drop calls `_commit(..., false)` and does not slide. Nothing calls `play()` yet. The headless script in ## Comments checked all three cases. A castling rook jumps (`shortcut:` at `ui/board_view.gd:205`), which the criterion allows.
2. ✅ `_draw` tints the from and to squares of `game.moves[-1]` (UCI, per `core/game.gd:11`) and draws a red disc under the king of the side to move when `in_check()`. That includes checkmate.
3. ✅ `_pick_up` collects the held piece's legal moves. `_draw` puts a ring on an occupied target and a dot on an empty one. A promotion is marked once, through its `q` move. `show_targets` (an `@export`) turns them off. En passant and castling targets are empty squares, so they get dots, as on Lichess.
4. ✅ A drop that matches several moves (the four promotions, with or without a capture) opens `ui/promotion_picker.gd`. It shows Q, R, B and N in a column from the promotion square towards the centre, and the column follows the flip. A click outside the buttons or Escape cancels it: `_end_snap_back` clears `_drag_from` and the pawn is drawn back on its origin square, with nothing played. The picker is a full-rect child Control with the default `MOUSE_FILTER_STOP`, so the board never sees the click that cancels it. The Spec axis worried the click could go through to the board; that worry is unfounded.
5. ✅ `Main.material_balance(board)` is pure and static. It counts the surplus of each role, and the difference is white minus black (q9 r5 b3 n3 p1). The labels show the captured glyphs plus `+N` next to the side that is ahead, and F moves each label to its own side's edge. Tested by `tests/test_material.gd`: the start position, an exchange, black ahead, and two promotions.

Red-green: I checked it myself. In a temporary worktree at 91aca8c the gate gave 51 passed, 1 failed: `test_material.gd` would not load because `Static function "material_balance()" not found in base "res://ui/main.gd"`, which is the right reason. Green on e20b658: 56 passed, 0 failed.

Test-first, from `diff --stat` on each commit:
- 91aca8c: only `tests/test_material.gd` and the Stage line (red).
- e20b658: only the six `ui/` production files.
- 1d3918c: the ticket only.

Every file touched is in Primary files.

Examined:
- Callers:
  - `ui/main.gd` is the only user of `BoardView`.
  - `tests/test_board_view.gd` uses only the static mapping, which is unchanged.
  - `_legal_move` (removed) had one caller, `_drop`.
  - The `@onready $PromotionPicker` only resolves inside `board_view.tscn`, and `main.tscn` is the only place that instances it.
  - `godot --headless --quit-after 30` loads `ui/main.tscn` with no errors and no warnings.
- Edge cases:
  - A promotion that is also a capture: one ring, then the picker.
  - Cancelling the picker.
  - A flipped board: the picker column, the last-move squares, the labels.
  - The labels at the start position are empty, which is correct at 0.
- Failure path, latent, out of criteria: `play()` called while a piece is held or the picker is open. `_commit` clears `_drag_from` but not `_held_moves`, and `_drop` never runs, so the old targets stay drawn. The next `_pick_up` appends to the old list, so a drop can match a move from an earlier position. A picker left open commits `_promoting + piece`, which is no longer legal: `game.play` returns false, but `move_played` still emits a SAN and the move list records it. No caller exists today. BOT-004 is the first caller (the human can pick up Maia's pieces while Maia is to move), and UI-007 deliberately lets the human hold pieces during Maia's turn. I added the note under both tickets' ## Comments.
- Cosmetic, out of criteria: pressing F or resizing the window while the picker is open leaves its buttons where they were. Picking still plays the right move. I noted this under UI-007 as well, since that ticket has `ui/board_view.gd` in its Primary files.
- Standards: the repo documents no coding standard. The Standards axis found no hard violations and no smell worth acting on.
- Not examined: a manual two-human game in a window, the ticket's Verification. Stage 2 drove `ui/main.tscn` headless instead (## Comments).

Gate: `godot --headless -s tests/run.gd` on e20b658, exit 0, 56 passed, 0 failed, log hash `53F7EC15…8B55C`. That matches the receipt above, and I re-hashed the log. No production file changed after e20b658.

Proxy decided lines: none.

Acceptance: pending | manual two-human game per the ticket's Verification. Evidence so far: a headless script drove `ui/main.tscn` through every criterion (## Comments), and the gate is 56/56.

Disclosure: pending | release | the manual two-human check in the ticket's Verification has not been run by a person. Stage 2's headless script covered criteria 1–4 (## Comments).
Disclosure: deferred | none | the latent `BoardView.play()` while a piece is held or the picker is open (Examined, above). No caller in this session. Routed to the open tickets BOT-004 and UI-007, under their ## Comments.

- 2026-10-24 Stage stopped (incomplete handoff): Invalid committed handoff: UI-002: code changed after gate (.scratch/core/issues/14-BOT-004-play-vs-maia.md, .scratch/core/issues/20-UI-007-premoves.md); reuse evidence only for identical code. See D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\side\.scratch\run-log\UI-002-review-20261024-121543.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
