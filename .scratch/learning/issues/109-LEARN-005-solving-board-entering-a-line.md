# LEARN-005: Solving board: entering a line
Stage: implementing
Blocked by: LEARN-002
Review: agent
Difficulty: normal

- Primary files:
  - ui/board_view.gd (an entry mode: `_gui_input`, `_drop`, `_commit`, `_draw`)
  - New: ui/solving.gd, ui/solving.tscn
  - ui/main.gd (opening solving from the unit page's part request)
  - core/course.gd (which practice position is next, and the from-your-game ones first)
  - tests/test_board_view.gd
  - tests/test_course_screens.gd
  - tests/test_course.gd
  - scripts/screens.gd (`BOARDS`: SolvingEntry)

#### What to build

The solving board as designed in `SolvingEntry.dc.html` (spec §L7): the position, which side you play and your goal, how many of your moves the line needs, a progress strip over the positions, the entered line as text, Undo, Clear and Commit line. The pieces never move: each entered move leaves only a faint red mark on its two squares, and there are no arrows. Commit emits the line; grading and feedback are LEARN-006.

#### Acceptance criteria

1. In entry mode the board accepts moves by click-click and by drag for both sides in turn, starting with the side to move; each move must be legal in the position after the line so far, and no piece changes square on screen.
2. Each entered move marks its from and to squares with a translucent red drawn under the pieces; a square used by two moves is drawn darker than one used once. No arrow, legal-move dot or last-move highlight shows in entry mode.
3. A pawn move to the last rank opens the promotion picker (or auto-queens when that setting is on), and the line records the piece.
4. The line fills after N of your moves (2N−1 plies, N from the position's line length); further moves are ignored.
5. The side panel shows the line in SAN as numbered move pairs, and "k of N moves".
6. Backspace and Undo remove the last ply and its marks; Clear removes them all.
7. Enter and Commit line work only when the line is full, and then emit the position and the line (UCI and SAN); otherwise they do nothing.
8. The screen shows the position number, "White/Black to play and win/draw", "Enter N of your moves", a progress strip with one segment per practice position (solved first try, solved, current, not yet), and a "From your game" chip for such positions.
9. Opening solving shows the first from-your-game position not yet solved, else the first unsolved practice position, else the first practice position.
10. Outside entry mode the board behaves exactly as before (existing board, premove and input-mode tests pass unchanged).

#### Verification

    Manual: enter 1. Rd1+ Ke7 2. Rd4 Ra1 3. Kc7 in the Lucena position, undo twice, clear.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_board_view.gd`: in entry mode a legal click-click move adds two marks and leaves `game.board` unchanged; an illegal move is ignored; a square used twice is darker (red: no entry mode).
- `tests/test_course_screens.gd`: opening solving shows the next position; the line stops at 2N−1 plies; Backspace undoes; Enter on a short line emits nothing (red: no screen).
- `tests/test_course.gd`: the next-position rule in criterion 9 (red: no function).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L7. Mark colours: `docs/design/learning/README.md`, "Entry marks".
- Criteria check by independent subagent, rechecked after the fixes:
  - 1 ✅ `ui/board_view.gd:350`, `ui/board_view.gd:492`; `tests/test_board_view.gd:9`, `:60`.
  - 2 ✅ `ui/board_view.gd:217`; `tests/test_board_view.gd:101` checks rendered overlap in a graphical run.
  - 3 ✅ `ui/board_view.gd:441`; `tests/test_board_view.gd:36`.
  - 4 ✅ `ui/board_view.gd:182`, `:492`; `tests/test_course_screens.gd:74`.
  - 5 ✅ `ui/solving.gd:69`; `tests/test_course_screens.gd:74`.
  - 6 ✅ `ui/board_view.gd:199`, `:212`; `tests/test_board_view.gd:77`, `tests/test_course_screens.gd:74`.
  - 7 ✅ `ui/solving.gd:80`; `tests/test_course_screens.gd:74`.
  - 8 ✅ `ui/solving.gd:23`; `tests/test_course_screens.gd:74`.
  - 9 ✅ `core/course.gd:195`, `ui/main.gd:518`; `tests/test_course.gd:4`, `tests/test_course_screens.gd:74`.
  - 10 ✅ entry guards in `ui/board_view.gd:217`, `:350`, `:492`; existing input and premove tests pass in the gate.
- Resolution: implemented stationary legal line entry, promotion, undo/clear/commit, practice selection and the solving screen. The Lucena reference line was exercised by `tests/test_board_view.gd`; graphical board tests passed under Xvfb (20 passed), including the darker repeated mark. `godot --headless -s tests/run.gd`: 601 passed, 0 failed. The headless suite skips pixel checks, which were run graphically.

Gate evidence: /run/media/lage/New Volume/Scratch/learn005-gate.json

#### Resolution (2026-11-08)
Verdict: Reopen — criteria 5 and 7 fail for Black-first move pairs and Enter with a focused action button.

- Reviewed the complete diff `8c5aea5...edcb8fa` and all eleven stage-2 commits. Independent Standards and Spec reviews were read-only; the parent reviewer confirmed both Spec findings with Godot 4.7.2 runtime probes. No production code or tests were changed during review.
- Standards: 0 findings. Primary-file scope and test/production commit separation are respected. Existing navigation assertions remain unchanged; its harness now returns from the new solving screen. No actionable baseline smell or documented-standard violation was found.
- Spec: 2 findings:
  1. Criterion 5, "line in SAN as numbered move pairs": `ui/solving.gd:73` always groups the first ply as White's move. On the shipped Black-to-move `practice-01`, entering `c6c5 e8f7 c5c4` produces SAN `Rc5 Kf7 Rc4` but displays `1. Rc5 Kf7 / 2. Rc4`. It must pair by the actual side to move, e.g. `1... Rc5 / 2. Kf7 Rc4`. Cover the screen's text for Black-first entry, including undo and clear, in `tests/test_course_screens.gd`.
  2. Criterion 7, "otherwise they do nothing": `ui/solving.gd:85` handles only pressed keys through `_unhandled_key_input`, while the action buttons retain keyboard focus. Click Clear, enter only `e2e4` for a two-own-move line, then press and release Enter: Clear still owns focus, and the release empties the line, with zero commits. A full line commits on press and is then cleared on release. Exercise actual Viewport key dispatch with button focus in `tests/test_course_screens.gd`; direct calls to `_unhandled_key_input` miss this interaction. Check Undo, Clear, Back and Commit focus, as well as Enter and keypad Enter.
- Callers/interactions examined: unit-page and theory-pointer navigation into solving and back; main's course/settings injection; practice selection, empty collections and saved from-your-game entries; stationary-board click/drag legality, both starting sides, promotion/cancellation, undo/clear, move limits, SAN/commit payloads and progress rendering; shared-board premove and non-entry paths. New runtime probes used isolated user data. Live Maia/tablebase gameplay, LEARN-006 grading/playback and full-feature product acceptance were not exercised in this review.
- Criterion record:
  - 1 ✅ `ui/board_view.gd:398`, `:418`, `:492`; virtual legality and stationary click/drag are covered in `tests/test_board_view.gd`.
  - 2 ✅ `ui/board_view.gd:234`, `:279`; accumulated under-piece tint and hidden arrows/targets, including graphical overlap evidence.
  - 3 ✅ `ui/board_view.gd:441`; promotion picker/auto-queen entry tests preserve the displayed position.
  - 4 ✅ `ui/board_view.gd:182`, `:492`; the screen test rejects the extra fourth ply for N=2.
  - 5 ❌ Black-first SAN rows assign plies to the wrong numbered move pairs; reproduction above.
  - 6 ✅ `ui/board_view.gd:199`, `:212`, `ui/solving.gd:17`, `:88`; Undo, Clear and Backspace remove entries and marks.
  - 7 ❌ Enter on a short line activates the focused Clear button on key release; reproduction above. Full-line UCI/SAN signal emission and the Commit button are otherwise covered.
  - 8 ✅ `ui/solving.gd:37`, `:42`, `:44`, `:50`; position/goals/instructions, progress states and from-your-game chip are covered.
  - 9 ✅ `core/course.gd:195`, `ui/main.gd:518`; selection tests cover game-first, ordinary unsolved, solved fallback and empty input.
  - 10 ✅ Entry guards isolate the new path; the recorded full gate includes existing board, input-mode and premove tests.
- Verification: the gate receipt's log hash, exit status and tested-code identity were verified with `Assert-GateEvidence`; `601 passed, 0 failed`, exit 0. No gate rerun was needed because code is unchanged. The recorded graphical board suite has `20 passed, 0 failed`; headless pixel checks and live Windows-engine tests are skipped as recorded in the gate log. Inspected stage-2 red logs cover absent entry/screen support, missing current-position indication and the overlap-color mutation, with subsequent green evidence. The two newly reproduced defects still need regression tests and fixes in separate stage-2 commits.
- Runtime evidence: [short-line Enter probe](</run/media/lage/New Volume/Scratch/learn005-review-input-short.log>) and [Black-first SAN probe](</run/media/lage/New Volume/Scratch/learn005-review-san.log>); companion `.gd` probes live beside these logs. Reproduction steps and observed/expected results are recorded above for review on another machine.

Acceptance: pending | Criteria 5 and 7 need repairs and regression coverage; see the two reproductions in this Resolution.
Disclosure: pending|integration | [LEARN-005](109-LEARN-005-solving-board-entering-a-line.md#resolution-2026-11-08) remains open for both confirmed defects; do not integrate until a fresh stage-3 review approves them.
